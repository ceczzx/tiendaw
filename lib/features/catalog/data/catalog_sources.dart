import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';

class CategoryModel extends Category {
  const CategoryModel({required super.id, required super.name});

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(id: map['id'] as String, name: map['name'] as String);
  }
}

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.categoryId,
    required super.name,
    required super.salePrice,
    required super.lastPurchaseCost,
    required super.stockStore,
    required super.stockWarehouse,
    required super.lowStockThreshold,
    super.nextExpiryDate,
  });

  factory ProductModel.fromSupabase(
    Map<String, dynamic> map, {
    required int stockStore,
    required int stockWarehouse,
    required DateTime? nextExpiryDate,
  }) {
    return ProductModel(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      salePrice: (map['sale_price'] as num).toDouble(),
      lastPurchaseCost: (map['last_purchase_cost'] as num).toDouble(),
      stockStore: stockStore,
      stockWarehouse: stockWarehouse,
      lowStockThreshold: map['low_stock_threshold'] as int,
      nextExpiryDate: nextExpiryDate,
    );
  }
}

class CatalogLocalDataSource {
  List<Category> _categories = const [];
  List<Product> _products = const [];
  List<PriceHistoryEntry> _priceHistory = const [];
  List<InventoryMovement> _movements = const [];

  Future<List<Category>> getCategories() async => List.unmodifiable(_categories);
  Future<List<Product>> getProducts() async => List.unmodifiable(_products);
  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId}) async {
    final source =
        productId == null
            ? _priceHistory
            : _priceHistory.where((entry) => entry.productId == productId).toList();
    return List.unmodifiable(source);
  }

  Future<List<InventoryMovement>> getInventoryMovements() async {
    return List.unmodifiable(_movements);
  }

  Future<void> saveCategories(List<Category> categories) async {
    _categories = List<Category>.unmodifiable(categories);
  }

  Future<void> saveProducts(List<Product> products) async {
    _products = List<Product>.unmodifiable(products);
  }

  Future<void> savePriceHistory(List<PriceHistoryEntry> entries) async {
    _priceHistory = List<PriceHistoryEntry>.unmodifiable(entries);
  }

  Future<void> saveInventoryMovements(List<InventoryMovement> movements) async {
    _movements = List<InventoryMovement>.unmodifiable(movements);
  }
}

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Category>> getCategories() async {
    final rows = await _client
        .from('categories')
        .select('id, name')
        .order('name');

    return _mapRows(rows).map(CategoryModel.fromMap).toList();
  }

  Future<List<Product>> getProducts() async {
    final productRows = await _client
        .from('products')
        .select(
          'id, category_id, name, sale_price, last_purchase_cost, low_stock_threshold',
        )
        .order('name');
    final stockByProduct = await _loadStockByProduct();
    final nextExpiryByProduct = await _loadNextExpiryByProduct();

    return _mapRows(productRows).map((row) {
      final stock = stockByProduct[row['id']] ?? const {'store': 0, 'warehouse': 0};
      return ProductModel.fromSupabase(
        row,
        stockStore: stock['store'] ?? 0,
        stockWarehouse: stock['warehouse'] ?? 0,
        nextExpiryDate: nextExpiryByProduct[row['id']],
      );
    }).toList();
  }

  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId}) async {
    var query = _client.from('product_prices').select(
      'id, product_id, unit_cost, effective_at, supplier:suppliers(name), product:products(name)',
    );

    if (productId != null && productId.isNotEmpty) {
      query = query.eq('product_id', productId);
    }

    final rows = await query.order('effective_at', ascending: false);

    return _mapRows(rows).map((row) {
      final supplier = _mapNullable(row['supplier']);
      final product = _mapNullable(row['product']);

      return PriceHistoryEntry(
        id: row['id'] as String,
        productId: row['product_id'] as String,
        productName: product['name']?.toString() ?? 'Producto',
        supplier: supplier['name']?.toString() ?? 'Proveedor',
        unitCost: (row['unit_cost'] as num).toDouble(),
        registeredAt: DateTime.parse(row['effective_at'] as String),
      );
    }).toList();
  }

  Future<List<InventoryMovement>> getInventoryMovements() async {
    final rows = await _client
        .from('inventory_movements')
        .select(
          'id, product_id, movement_type, quantity, happened_at, product:products(name), actor:profiles(full_name), from_location:locations!inventory_movements_from_location_id_fkey(name), to_location:locations!inventory_movements_to_location_id_fkey(name)',
        )
        .order('happened_at', ascending: false);

    return _mapRows(rows).map((row) {
      final product = _mapNullable(row['product']);
      final actor = _mapNullable(row['actor']);
      final fromLocation = _mapNullable(row['from_location']);
      final toLocation = _mapNullable(row['to_location']);

      return InventoryMovement(
        id: row['id'] as String,
        productId: row['product_id'] as String,
        productName: product['name']?.toString() ?? 'Producto',
        type: row['movement_type'] as String,
        quantity: row['quantity'] as int,
        fromLocation: fromLocation['name']?.toString() ?? 'Sin origen',
        toLocation: toLocation['name']?.toString() ?? 'Sin destino',
        actorName: actor['full_name']?.toString() ?? 'Usuario',
        occurredAt: DateTime.parse(row['happened_at'] as String),
      );
    }).toList();
  }

  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    required String actorName,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError('No hay una sesion activa para registrar la transferencia.');
    }

    final warehouseId = await _resolveLocationId('warehouse');
    final storeId = await _resolveLocationId('store');

    await _client.from('inventory_movements').insert({
      'product_id': productId,
      'movement_type': 'transfer',
      'from_location_id': warehouseId,
      'to_location_id': storeId,
      'quantity': quantity,
      'reference_table': 'app_transfer',
      'created_by': currentUserId,
    });
  }

  Future<Map<String, Map<String, int>>> _loadStockByProduct() async {
    final rows = await _client
        .from('inventory_stock')
        .select('product_id, quantity, location:locations(location_type)');

    final stockByProduct = <String, Map<String, int>>{};

    for (final row in _mapRows(rows)) {
      final productId = row['product_id'] as String;
      final location = _mapNullable(row['location']);
      final locationType = location['location_type']?.toString();
      final current = stockByProduct.putIfAbsent(
        productId,
        () => {'store': 0, 'warehouse': 0},
      );

      if (locationType == 'store') {
        current['store'] = (current['store'] ?? 0) + (row['quantity'] as int);
      } else if (locationType == 'warehouse') {
        current['warehouse'] =
            (current['warehouse'] ?? 0) + (row['quantity'] as int);
      }
    }

    return stockByProduct;
  }

  Future<Map<String, DateTime>> _loadNextExpiryByProduct() async {
    try {
      final rows =
          await _client.from('purchase_items').select('product_id, expiry_date');
      final expiries = <String, DateTime>{};

      for (final row in _mapRows(rows)) {
        final rawDate = row['expiry_date']?.toString();
        if (rawDate == null || rawDate.isEmpty) {
          continue;
        }

        final date = DateTime.parse(rawDate);
        final productId = row['product_id'] as String;
        final current = expiries[productId];

        if (current == null || date.isBefore(current)) {
          expiries[productId] = date;
        }
      }

      return expiries;
    } catch (_) {
      return {};
    }
  }

  Future<String> _resolveLocationId(String locationType) async {
    final rows = await _client
        .from('locations')
        .select('id')
        .eq('location_type', locationType)
        .limit(1);

    final data = _mapRows(rows);
    if (data.isEmpty) {
      throw StateError('No existe una ubicacion configurada para $locationType.');
    }

    return data.first['id'] as String;
  }

  List<Map<String, dynamic>> _mapRows(dynamic rows) {
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Map<String, dynamic> _mapNullable(dynamic value) {
    if (value == null) {
      return const {};
    }

    return Map<String, dynamic>.from(value as Map);
  }
}

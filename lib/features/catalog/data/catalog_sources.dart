// ignore_for_file: unused_element

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/core/utils/postgrest_compat.dart';
import 'package:tiendaw/core/sync/realtime_refresh_stream.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';

class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.prefix,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      prefix: map['prefix']?.toString() ?? '',
    );
  }
}

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.sku,
    required super.categoryId,
    required super.name,
    required super.productType,
    required super.unitsPerPackage,
    required super.costDetails,
    required super.salePrice,
    required super.lastPurchaseCost,
    required super.stockStore,
    required super.stockWarehouse,
    required super.lowStockThreshold,
    required super.packageName,
    required super.unitName,
    super.nextExpiryDate,
    required super.coldStockUnits,
    required super.coldPriceIncrement,
    super.promotionalPrice,
    super.promotionNote,
    super.promotionOffers,
  });

  factory ProductModel.fromSupabase(
    Map<String, dynamic> map, {
    required int stockStore,
    required int stockWarehouse,
    required DateTime? nextExpiryDate,
    List<ProductPromotionOffer> promotionOffers = const [],
  }) {
    final productType = map['product_type']?.toString() ?? 'proveedor';
    final sku = map['sku']?.toString() ?? '';
    final costDetails =
        map['cost_details'] is Map
            ? Map<String, dynamic>.from(map['cost_details'] as Map)
            : <String, dynamic>{};
    if (!costDetails.containsKey('tipo')) {
      costDetails['tipo'] = productType;
    }

    return ProductModel(
      id: map['id'] as String,
      sku: sku,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      productType: productType,
      unitsPerPackage: (map['units_per_package'] as num?)?.toInt() ?? 1,
      costDetails: costDetails,
      salePrice: (map['sale_price'] as num).toDouble(),
      lastPurchaseCost: (map['last_purchase_cost'] as num).toDouble(),
      stockStore: stockStore,
      stockWarehouse: stockWarehouse,
      lowStockThreshold: map['low_stock_threshold'] as int,
      packageName: map['package_name']?.toString() ?? 'caja',
      unitName: map['unit_name']?.toString() ?? 'unid',
      nextExpiryDate: nextExpiryDate,
      coldStockUnits: (map['cold_stock_units'] as num?)?.toInt() ?? 0,
      coldPriceIncrement:
          (map['cold_price_increment'] as num?)?.toDouble() ?? 0.50,
      promotionalPrice:
          promotionOffers.isNotEmpty
              ? promotionOffers
                  .map((offer) => offer.promotionalPrice)
                  .reduce((left, right) => left < right ? left : right)
              : (map['promotional_price'] as num?)?.toDouble(),
      promotionNote:
          promotionOffers.isNotEmpty
              ? promotionOffers.first.note
              : map['promotion_note']?.toString(),
      promotionOffers: List<ProductPromotionOffer>.unmodifiable(promotionOffers),
    );
  }
}

class CatalogLocalDataSource {
  List<Category> _categories = const [];
  List<Product> _products = const [];
  List<LotPromotion> _activeLotPromotions = const [];
  List<PriceHistoryEntry> _priceHistory = const [];
  List<InventoryMovement> _movements = const [];
  final Map<String, List<InventoryLotAlert>> _inventoryLotAlerts = {};
  final Map<String, List<PromotableLot>> _promotableLots = {};
  final Map<bool, List<PromotionNotice>> _promotionNotices = {};
  final Map<String, List<WarehouseSupplierLot>> _warehouseSupplierLots = {};

  Future<List<Category>> getCategories() async =>
      List.unmodifiable(_categories);
  Future<List<Product>> getProducts() async => List.unmodifiable(_products);
  Future<List<PromotableLot>> getPromotableLots({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async {
    return List.unmodifiable(
      _promotableLots[_inventoryLotAlertsKey(daysAhead, expiredOnly)] ??
          const [],
    );
  }

  Future<List<LotPromotion>> getActiveLotPromotions() async {
    return List.unmodifiable(_activeLotPromotions);
  }

  Future<List<PromotionNotice>> getPromotionNotices({
    bool openOnly = true,
  }) async {
    return List.unmodifiable(_promotionNotices[openOnly] ?? const []);
  }

  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId}) async {
    final source =
        productId == null
            ? _priceHistory
            : _priceHistory
                .where((entry) => entry.productId == productId)
                .toList();
    return List.unmodifiable(source);
  }

  Future<List<InventoryMovement>> getInventoryMovements() async {
    return List.unmodifiable(_movements);
  }

  Future<List<InventoryLotAlert>> getInventoryLotAlerts({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async {
    return List.unmodifiable(
      _inventoryLotAlerts[_inventoryLotAlertsKey(daysAhead, expiredOnly)] ??
          const [],
    );
  }

  Future<List<WarehouseSupplierLot>> getWarehouseSupplierLots({
    required String productId,
    String? supplierId,
  }) async {
    final cacheKey = _warehouseSupplierLotsKey(
      productId: productId,
      supplierId: supplierId,
    );
    return List.unmodifiable(_warehouseSupplierLots[cacheKey] ?? const []);
  }

  Future<void> saveCategories(List<Category> categories) async {
    _categories = List<Category>.unmodifiable(categories);
  }

  Future<void> saveProducts(List<Product> products) async {
    _products = List<Product>.unmodifiable(products);
  }

  Future<void> savePromotableLots({
    required int daysAhead,
    required bool expiredOnly,
    required List<PromotableLot> lots,
  }) async {
    _promotableLots[_inventoryLotAlertsKey(
      daysAhead,
      expiredOnly,
    )] = List<PromotableLot>.unmodifiable(lots);
  }

  Future<void> saveActiveLotPromotions(List<LotPromotion> promotions) async {
    _activeLotPromotions = List<LotPromotion>.unmodifiable(promotions);
  }

  Future<void> savePromotionNotices({
    required bool openOnly,
    required List<PromotionNotice> notices,
  }) async {
    _promotionNotices[openOnly] =
        List<PromotionNotice>.unmodifiable(notices);
  }

  Future<void> savePriceHistory(List<PriceHistoryEntry> entries) async {
    _priceHistory = List<PriceHistoryEntry>.unmodifiable(entries);
  }

  Future<void> saveInventoryMovements(List<InventoryMovement> movements) async {
    _movements = List<InventoryMovement>.unmodifiable(movements);
  }

  Future<void> saveInventoryLotAlerts({
    required int daysAhead,
    required bool expiredOnly,
    required List<InventoryLotAlert> alerts,
  }) async {
    _inventoryLotAlerts[_inventoryLotAlertsKey(
      daysAhead,
      expiredOnly,
    )] = List<InventoryLotAlert>.unmodifiable(alerts);
  }

  Future<void> saveWarehouseSupplierLots({
    required String productId,
    String? supplierId,
    required List<WarehouseSupplierLot> lots,
  }) async {
    final cacheKey = _warehouseSupplierLotsKey(
      productId: productId,
      supplierId: supplierId,
    );
    _warehouseSupplierLots[cacheKey] = List<WarehouseSupplierLot>.unmodifiable(
      lots,
    );
  }
}

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(this._client);

  final SupabaseClient _client;
  bool? _supportsProductEnhancements;
  bool? _supportsInventoryMovementNotes;

  Future<List<Category>> getCategories() async {
    final rows = await _client
        .from('categories')
        .select('id, name, prefix')
        .order('name');

    return _mapRows(rows).map(CategoryModel.fromMap).toList();
  }

  Stream<List<Category>> watchCategories() {
    return createRealtimeRefreshStream(
      load: getCategories,
      triggers: [
        _tableTrigger('categories', primaryKey: const ['id']),
      ],
    );
  }

  Future<Category> ensureCategory({
    required String name,
    required String prefix,
  }) async {
    final normalizedName = name.trim();
    final normalizedPrefix = prefix.trim().toUpperCase();
    if (normalizedName.isEmpty) {
      throw StateError('La categoria no puede estar vacia.');
    }
    if (!RegExp(r'^[A-Z]{3,5}$').hasMatch(normalizedPrefix)) {
      throw StateError(
        'El prefix de la categoria debe tener entre 3 y 5 letras mayusculas.',
      );
    }

    final rows = await _client
        .from('categories')
        .select('id, name, prefix')
        .eq('name', normalizedName)
        .limit(1);
    final data = _mapRows(rows);
    if (data.isNotEmpty) {
      return CategoryModel.fromMap(data.first);
    }

    final inserted =
        await _client
            .from('categories')
            .insert({'name': normalizedName, 'prefix': normalizedPrefix})
            .select('id, name, prefix')
            .single();

    return CategoryModel.fromMap(Map<String, dynamic>.from(inserted));
  }

  Future<List<Product>> getProducts() async {
    final productRows = await _withProductSelect(
      (selectClause) =>
          _client.from('products').select(selectClause).order('name'),
    );
    final stockByProduct = await _loadStockByProduct();
    final nextExpiryByProduct = await _loadNextExpiryByProduct();
    final promotionOffersByProduct = await _loadPromotionOffersByProduct();

    return _mapRows(productRows).map((row) {
      final stock =
          stockByProduct[row['id']] ?? const {'store': 0, 'warehouse': 0};
      return ProductModel.fromSupabase(
        row,
        stockStore: stock['store'] ?? 0,
        stockWarehouse: stock['warehouse'] ?? 0,
        nextExpiryDate: nextExpiryByProduct[row['id']],
        promotionOffers: promotionOffersByProduct[row['id']] ?? const [],
      );
    }).toList();
  }

  Stream<List<Product>> watchProducts() {
    return createRealtimeRefreshStream(
      load: getProducts,
      triggers: [
        _tableTrigger('products', primaryKey: const ['id']),
        _tableTrigger(
          'inventory_stock',
          primaryKey: const ['product_id', 'location_id'],
        ),
        _tableTrigger('purchase_items', primaryKey: const ['id']),
        _tableTrigger('lot_promotions', primaryKey: const ['id']),
        _tableTrigger('promotion_notices', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<PromotableLot>> getPromotableLots({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async {
    final rows = await _client.rpc(
      'get_promotable_lots',
      params: <String, dynamic>{
        'p_days_ahead': daysAhead,
        'p_expired_only': expiredOnly,
      },
    );

    return _mapRows(rows).map((row) {
      return PromotableLot(
        purchaseItemId: row['purchase_item_id'] as String,
        productId: row['product_id'] as String,
        productName: row['product_name']?.toString() ?? 'Producto',
        supplierId: row['supplier_id']?.toString(),
        supplierName: row['supplier_name']?.toString() ?? 'Proveedor',
        receivedAt: _parseSupabaseDateTime(row['received_at'] as String),
        expiryDate: DateTime.parse(row['expiry_date'] as String),
        warehouseAvailableUnits:
            (row['warehouse_available_units'] as num?)?.toInt() ?? 0,
        storeAvailableUnits:
            (row['store_available_units'] as num?)?.toInt() ?? 0,
        totalAvailableUnits: (row['total_available_units'] as num).toInt(),
        recommendedLocation:
            row['recommended_location']?.toString() ?? 'warehouse',
      );
    }).toList();
  }

  Stream<List<PromotableLot>> watchPromotableLots({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) {
    return createRealtimeRefreshStream(
      load:
          () => getPromotableLots(
            daysAhead: daysAhead,
            expiredOnly: expiredOnly,
          ),
      triggers: [
        _tableTrigger('purchase_items', primaryKey: const ['id']),
        _tableTrigger('inventory_movements', primaryKey: const ['id']),
        _tableTrigger('lot_promotions', primaryKey: const ['id']),
        _tableTrigger('products', primaryKey: const ['id']),
        _tableTrigger('suppliers', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<LotPromotion>> getActiveLotPromotions() async {
    final rows = await _client.rpc('get_active_lot_promotions');
    return _mapRows(rows).map((row) {
      return LotPromotion(
        promotionId: row['promotion_id'] as String,
        purchaseItemId: row['purchase_item_id'] as String,
        productId: row['product_id'] as String,
        productName: row['product_name']?.toString() ?? 'Producto',
        supplierId: row['supplier_id']?.toString(),
        supplierName: row['supplier_name']?.toString() ?? 'Proveedor',
        expiryDate:
            row['expiry_date'] == null
                ? null
                : DateTime.parse(row['expiry_date'] as String),
        promotionalPrice: (row['promotional_price'] as num).toDouble(),
        promoQuantityTotal: (row['promo_quantity_total'] as num).toInt(),
        promoQuantityRemaining:
            (row['promo_quantity_remaining'] as num).toInt(),
        warehouseAvailableUnits:
            (row['warehouse_available_units'] as num?)?.toInt() ?? 0,
        storeAvailableUnits: (row['store_available_units'] as num?)?.toInt() ?? 0,
        status: row['status']?.toString() ?? 'pending_transfer',
        note: row['note']?.toString(),
        createdAt: _parseSupabaseDateTime(row['created_at'] as String),
      );
    }).toList();
  }

  Stream<List<LotPromotion>> watchActiveLotPromotions() {
    return createRealtimeRefreshStream(
      load: getActiveLotPromotions,
      triggers: [
        _tableTrigger('lot_promotions', primaryKey: const ['id']),
        _tableTrigger('inventory_movements', primaryKey: const ['id']),
        _tableTrigger('sale_item_lot_allocations', primaryKey: const ['id']),
        _tableTrigger('purchase_items', primaryKey: const ['id']),
        _tableTrigger('products', primaryKey: const ['id']),
        _tableTrigger('suppliers', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<PromotionNotice>> getPromotionNotices({
    bool openOnly = true,
  }) async {
    var query = _client
        .from('promotion_notices')
        .select('id, promotion_id, notice_type, message, created_at, resolved_at');

    if (openOnly) {
      query = query.isFilter('resolved_at', null);
    }

    final rows = await query.order('created_at', ascending: false);
    return _mapRows(rows).map((row) {
      return PromotionNotice(
        id: row['id'] as String,
        promotionId: row['promotion_id'] as String,
        noticeType: row['notice_type']?.toString() ?? 'promo_exhausted',
        message: row['message']?.toString() ?? '',
        createdAt: _parseSupabaseDateTime(row['created_at'] as String),
        resolvedAt:
            row['resolved_at'] == null
                ? null
                : _parseSupabaseDateTime(row['resolved_at'] as String),
      );
    }).toList();
  }

  Stream<List<PromotionNotice>> watchPromotionNotices({bool openOnly = true}) {
    return createRealtimeRefreshStream(
      load: () => getPromotionNotices(openOnly: openOnly),
      triggers: [
        _tableTrigger('promotion_notices', primaryKey: const ['id']),
        _tableTrigger('lot_promotions', primaryKey: const ['id']),
      ],
    );
  }

  Future<Product> ensureProduct({
    required String categoryId,
    required String name,
    required String productType,
    required double salePrice,
    required double lastPurchaseCost,
    required int lowStockThreshold,
    required int unitsPerPackage,
    required Map<String, dynamic> costDetails,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw StateError('El producto no puede estar vacio.');
    }

    final rows = await _client
        .from('products')
        .select(await _productSelectClause())
        .eq('category_id', categoryId)
        .eq('name', normalizedName)
        .limit(1);
    final data = _mapRows(rows);
    if (data.isNotEmpty) {
      final updates = <String, dynamic>{};
      if ((data.first['product_type']?.toString() ?? 'proveedor') !=
          productType) {
        updates['product_type'] = productType;
      }
      if ((data.first['low_stock_threshold'] as int) != lowStockThreshold) {
        updates['low_stock_threshold'] = lowStockThreshold;
      }
      if (((data.first['units_per_package'] as num?)?.toInt() ?? 1) !=
          unitsPerPackage) {
        updates['units_per_package'] = unitsPerPackage;
      }
      updates['sale_price'] = salePrice;
      updates['last_purchase_cost'] = lastPurchaseCost;
      updates['cost_details'] = costDetails;

      if (updates.isNotEmpty) {
        final updated = await _withProductSelect(
          (selectClause) =>
              _client
                  .from('products')
                  .update(updates)
                  .eq('id', data.first['id'] as String)
                  .select(selectClause)
                  .single(),
        );
        return ProductModel.fromSupabase(
          Map<String, dynamic>.from(updated),
          stockStore: 0,
          stockWarehouse: 0,
          nextExpiryDate: null,
        );
      }

      return ProductModel.fromSupabase(
        data.first,
        stockStore: 0,
        stockWarehouse: 0,
        nextExpiryDate: null,
      );
    }

    final inserted = await _withProductSelect(
      (selectClause) =>
          _client
              .from('products')
              .insert({
                'category_id': categoryId,
                'name': normalizedName,
                'product_type': productType,
                'units_per_package': unitsPerPackage,
                'package_name': 'caja',
                'unit_name': 'unid',
                'cost_details': costDetails,
                'sale_price': salePrice,
                'last_purchase_cost': lastPurchaseCost,
                'low_stock_threshold': lowStockThreshold,
              })
              .select(selectClause)
              .single(),
    );

    return ProductModel.fromSupabase(
      Map<String, dynamic>.from(inserted),
      stockStore: 0,
      stockWarehouse: 0,
      nextExpiryDate: null,
    );
  }

  Future<void> updateProductLowStockThreshold({
    required String productId,
    required int lowStockThreshold,
  }) async {
    await _client
        .from('products')
        .update({'low_stock_threshold': lowStockThreshold})
        .eq('id', productId);
  }

  Future<void> updateProductUnitsPerPackage({
    required String productId,
    required int unitsPerPackage,
  }) async {
    await _client
        .from('products')
        .update({'units_per_package': unitsPerPackage})
        .eq('id', productId);
  }

  Future<void> updateProductCatalogData({
    required String productId,
    required String productType,
    required double salePrice,
    required double lastPurchaseCost,
    required int unitsPerPackage,
    required Map<String, dynamic> costDetails,
  }) async {
    await _client
        .from('products')
        .update({
          'product_type': productType,
          'sale_price': salePrice,
          'last_purchase_cost': lastPurchaseCost,
          'units_per_package': unitsPerPackage,
          'cost_details': costDetails,
        })
        .eq('id', productId);
  }

  Future<void> activateLotPromotion({
    required String purchaseItemId,
    required int promotionalQuantity,
    required double promotionalPrice,
    String? promotionNote,
  }) async {
    await _client.rpc(
      'activate_lot_promotion',
      params: <String, dynamic>{
        'p_purchase_item_id': purchaseItemId,
        'p_promo_quantity': promotionalQuantity,
        'p_promotional_price': promotionalPrice,
        'p_note':
            promotionNote?.trim().isEmpty ?? true
                ? null
                : promotionNote?.trim(),
      },
    );
  }

  Future<void> cancelLotPromotion({required String promotionId}) async {
    await _client.rpc(
      'cancel_lot_promotion',
      params: <String, dynamic>{'p_promotion_id': promotionId},
    );
  }

  Future<void> updateProductColdState({
    required String productId,
    required int coldStockUnits,
    required double coldPriceIncrement,
  }) async {
    await _client
        .from('products')
        .update({
          'cold_stock_units': coldStockUnits,
          'cold_price_increment': coldPriceIncrement,
        })
        .eq('id', productId);
  }

  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId}) async {
    var query = _client
        .from('product_prices')
        .select(
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
        registeredAt: _parseSupabaseDateTime(row['effective_at'] as String),
      );
    }).toList();
  }

  Stream<List<PriceHistoryEntry>> watchPriceHistory({String? productId}) {
    return createRealtimeRefreshStream(
      load: () => getPriceHistory(productId: productId),
      triggers: [
        _tableTrigger('product_prices', primaryKey: const ['id']),
        _tableTrigger('suppliers', primaryKey: const ['id']),
        _tableTrigger('products', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<InventoryMovement>> getInventoryMovements() async {
    final rows = await _withInventoryMovementSelect(
      (selectClause) => _client
          .from('inventory_movements')
          .select(selectClause)
          .order('happened_at', ascending: false),
    );

    return _mapRows(rows).map((row) {
      final product = _mapNullable(row['product']);
      final supplier = _mapNullable(row['supplier']);
      final actor = _mapNullable(row['actor']);
      final fromLocation = _mapNullable(row['from_location']);
      final toLocation = _mapNullable(row['to_location']);

      return InventoryMovement(
        id: row['id'] as String,
        productId: row['product_id'] as String,
        productName: product['name']?.toString() ?? 'Producto',
        supplierId: row['supplier_id']?.toString(),
        supplierName: supplier['name']?.toString(),
        type: row['movement_type'] as String,
        quantity: row['quantity'] as int,
        fromLocation: fromLocation['name']?.toString() ?? 'Sin origen',
        toLocation: toLocation['name']?.toString() ?? 'Sin destino',
        actorName: actor['full_name']?.toString() ?? 'Usuario',
        occurredAt: _parseSupabaseDateTime(row['happened_at'] as String),
        notes: row['notes']?.toString(),
      );
    }).toList();
  }

  Stream<List<InventoryMovement>> watchInventoryMovements() {
    return createRealtimeRefreshStream(
      load: getInventoryMovements,
      triggers: [
        _tableTrigger('inventory_movements', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<InventoryLotAlert>> getInventoryLotAlerts({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async {
    final rows = await _client.rpc(
      'get_inventory_lot_alerts',
      params: <String, dynamic>{
        'p_days_ahead': daysAhead,
        'p_expired_only': expiredOnly,
      },
    );

    return _mapRows(rows).map((row) {
      return InventoryLotAlert(
        purchaseItemId: row['purchase_item_id'] as String,
        productId: row['product_id'] as String,
        productName: row['product_name']?.toString() ?? 'Producto',
        supplierId: row['supplier_id']?.toString(),
        supplierName: row['supplier_name']?.toString() ?? 'Proveedor',
        receivedAt: _parseSupabaseDateTime(row['received_at'] as String),
        expiryDate: DateTime.parse(row['expiry_date'] as String),
        availableUnits: (row['available_units'] as num).toInt(),
      );
    }).toList();
  }

  Stream<List<InventoryLotAlert>> watchInventoryLotAlerts({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) {
    return createRealtimeRefreshStream(
      load:
          () => getInventoryLotAlerts(
            daysAhead: daysAhead,
            expiredOnly: expiredOnly,
          ),
      triggers: [
        _tableTrigger('purchase_items', primaryKey: const ['id']),
        _tableTrigger('inventory_movements', primaryKey: const ['id']),
        _tableTrigger('products', primaryKey: const ['id']),
        _tableTrigger('suppliers', primaryKey: const ['id']),
      ],
    );
  }

  Future<void> registerInventoryLoss({
    required String purchaseItemId,
    required int quantity,
    String? notes,
  }) async {
    await _client.rpc(
      'register_inventory_loss',
      params: <String, dynamic>{
        'p_purchase_item_id': purchaseItemId,
        'p_quantity': quantity,
        'p_notes': notes?.trim().isEmpty ?? true ? null : notes?.trim(),
      },
    );
  }

  Future<List<WarehouseSupplierLot>> getWarehouseSupplierLots({
    required String productId,
    String? supplierId,
  }) async {
    final params = <String, dynamic>{
      'p_product_id': productId,
      if (supplierId != null && supplierId.trim().isNotEmpty)
        'p_supplier_id': supplierId,
    };
    final rows = await _client.rpc('get_product_supplier_lots', params: params);

    return _mapRows(rows).map((row) {
      return WarehouseSupplierLot(
        purchaseItemId: row['purchase_item_id'] as String,
        productId: row['product_id'] as String,
        supplierId: row['supplier_id']?.toString(),
        supplierName: row['supplier_name']?.toString() ?? 'Proveedor',
        receivedAt: _parseSupabaseDateTime(row['received_at'] as String),
        availableUnits: (row['available_units'] as num).toInt(),
        expiryDate:
            row['expiry_date'] == null
                ? null
                : DateTime.parse(row['expiry_date'] as String),
      );
    }).toList();
  }

  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    String? supplierId,
  }) async {
    if (_client.auth.currentUser?.id == null) {
      throw StateError(
        'No hay una sesion activa para registrar la transferencia.',
      );
    }

    await _client.rpc(
      'transfer_product_supplier_stock',
      params: <String, dynamic>{
        'p_product_id': productId,
        'p_quantity': quantity,
        if (supplierId != null && supplierId.trim().isNotEmpty)
          'p_supplier_id': supplierId,
      },
    );
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
      final expiries = <String, DateTime>{};
      final nextAlerts = await getInventoryLotAlerts(daysAhead: 3650);
      final expiredAlerts = await getInventoryLotAlerts(expiredOnly: true);

      for (final alert in [...nextAlerts, ...expiredAlerts]) {
        final current = expiries[alert.productId];
        if (current == null || alert.expiryDate.isBefore(current)) {
          expiries[alert.productId] = alert.expiryDate;
        }
      }

      return expiries;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, List<ProductPromotionOffer>>>
  _loadPromotionOffersByProduct() async {
    try {
      final grouped = <String, List<ProductPromotionOffer>>{};
      final promotions = await getActiveLotPromotions();

      for (final promotion in promotions) {
        final offer = ProductPromotionOffer(
          promotionId: promotion.promotionId,
          purchaseItemId: promotion.purchaseItemId,
          supplierId: promotion.supplierId,
          supplierName: promotion.supplierName,
          expiryDate: promotion.expiryDate,
          promotionalPrice: promotion.promotionalPrice,
          promoQuantityTotal: promotion.promoQuantityTotal,
          promoQuantityRemaining: promotion.promoQuantityRemaining,
          storeAvailableUnits: promotion.storeAvailableUnits,
          warehouseAvailableUnits: promotion.warehouseAvailableUnits,
          status: promotion.status,
          note: promotion.note,
          createdAt: promotion.createdAt,
        );
        if (!offer.isActiveInStore) {
          continue;
        }
        grouped.putIfAbsent(promotion.productId, () => []).add(offer);
      }

      for (final entry in grouped.entries) {
        entry.value.sort((left, right) {
          final expiryLeft = left.expiryDate;
          final expiryRight = right.expiryDate;
          if (expiryLeft != null && expiryRight != null) {
            final expiryCompare = expiryLeft.compareTo(expiryRight);
            if (expiryCompare != 0) {
              return expiryCompare;
            }
          } else if (expiryLeft != null) {
            return -1;
          } else if (expiryRight != null) {
            return 1;
          }

          final createdCompare = left.createdAt.compareTo(right.createdAt);
          if (createdCompare != 0) {
            return createdCompare;
          }

          return left.purchaseItemId.compareTo(right.purchaseItemId);
        });
      }

      return grouped;
    } catch (_) {
      return const {};
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
      throw StateError(
        'No existe una ubicacion configurada para $locationType.',
      );
    }

    return data.first['id'] as String;
  }

  Future<bool> _usesProductEnhancementColumns() async {
    if (_supportsProductEnhancements != null) {
      return _supportsProductEnhancements!;
    }

    await _withProductSelect(
      (selectClause) => _client.from('products').select(selectClause).limit(1),
    );
    return _supportsProductEnhancements ?? false;
  }

  Future<T> _withProductSelect<T>(
    Future<T> Function(String selectClause) run,
  ) async {
    if (_supportsProductEnhancements == false) {
      return run(_legacyProductSelectClause);
    }

    try {
      final result = await run(_enhancedProductSelectClause);
      _supportsProductEnhancements = true;
      return result;
    } on PostgrestException catch (error) {
      if (!isMissingColumnError(
        error,
        column: 'cold_stock_units',
        table: 'products',
      )) {
        rethrow;
      }

      _supportsProductEnhancements = false;
      return run(_legacyProductSelectClause);
    }
  }

  Future<String> _productSelectClause() async {
    return (await _usesProductEnhancementColumns())
        ? _enhancedProductSelectClause
        : _legacyProductSelectClause;
  }

  Future<T> _withInventoryMovementSelect<T>(
    Future<T> Function(String selectClause) run,
  ) async {
    if (_supportsInventoryMovementNotes == false) {
      return run(_legacyInventoryMovementSelectClause);
    }

    try {
      final result = await run(_enhancedInventoryMovementSelectClause);
      _supportsInventoryMovementNotes = true;
      return result;
    } on PostgrestException catch (error) {
      if (!isMissingColumnError(
        error,
        column: 'notes',
        table: 'inventory_movements',
      )) {
        rethrow;
      }

      _supportsInventoryMovementNotes = false;
      return run(_legacyInventoryMovementSelectClause);
    }
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

  Stream<dynamic> _tableTrigger(
    String table, {
    required List<String> primaryKey,
  }) {
    return _client.from(table).stream(primaryKey: primaryKey).skip(1);
  }
}

const String _enhancedProductSelectClause =
    'id, sku, category_id, name, product_type, units_per_package, package_name, unit_name, cost_details, sale_price, cold_stock_units, cold_price_increment, promotional_price, promotion_note, last_purchase_cost, low_stock_threshold';

const String _legacyProductSelectClause =
    'id, sku, category_id, name, product_type, units_per_package, package_name, unit_name, cost_details, sale_price, last_purchase_cost, low_stock_threshold';

const String _enhancedInventoryMovementSelectClause =
    'id, product_id, supplier_id, movement_type, quantity, notes, happened_at, product:products(name), supplier:suppliers(name), actor:profiles(full_name), from_location:locations!inventory_movements_from_location_id_fkey(name), to_location:locations!inventory_movements_to_location_id_fkey(name)';

const String _legacyInventoryMovementSelectClause =
    'id, product_id, supplier_id, movement_type, quantity, happened_at, product:products(name), supplier:suppliers(name), actor:profiles(full_name), from_location:locations!inventory_movements_from_location_id_fkey(name), to_location:locations!inventory_movements_to_location_id_fkey(name)';

String _warehouseSupplierLotsKey({
  required String productId,
  String? supplierId,
}) {
  final normalizedSupplierId = supplierId?.trim() ?? '';
  return '$productId::$normalizedSupplierId';
}

String _inventoryLotAlertsKey(int daysAhead, bool expiredOnly) {
  return '$daysAhead::$expiredOnly';
}

DateTime _parseSupabaseDateTime(String rawValue) {
  return DateTime.parse(rawValue).toLocal();
}

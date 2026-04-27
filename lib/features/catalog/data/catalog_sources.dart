import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/shared/demo/system_w_store.dart';

class CategoryModel extends Category {
  const CategoryModel({required super.id, required super.name});

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(id: map['id'] as String, name: map['name'] as String);
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
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

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      salePrice: (map['sale_price'] as num).toDouble(),
      lastPurchaseCost: (map['last_purchase_cost'] as num).toDouble(),
      stockStore: map['stock_store'] as int,
      stockWarehouse: map['stock_warehouse'] as int,
      lowStockThreshold: map['low_stock_threshold'] as int,
      nextExpiryDate:
          map['next_expiry_date'] == null
              ? null
              : DateTime.parse(map['next_expiry_date'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'sale_price': salePrice,
      'last_purchase_cost': lastPurchaseCost,
      'stock_store': stockStore,
      'stock_warehouse': stockWarehouse,
      'low_stock_threshold': lowStockThreshold,
      'next_expiry_date': nextExpiryDate?.toIso8601String(),
    };
  }
}

class CatalogLocalDataSource {
  CatalogLocalDataSource(this._store);

  final SystemWStore _store;

  Future<List<Category>> getCategories() async => _store.listCategories();
  Future<List<Product>> getProducts() async => _store.listProducts();
  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId}) async =>
      _store.listPriceHistory(productId: productId);
  Future<List<InventoryMovement>> getInventoryMovements() async =>
      _store.listInventoryMovements();

  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    required String actorName,
  }) async {
    _store.transferWarehouseToStore(
      productId: productId,
      quantity: quantity,
      actorName: actorName,
    );
  }
}

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(this._store);

  final SystemWStore _store;

  Future<List<Category>> getCategories() async => _store.listCategories();
  Future<List<Product>> getProducts() async => _store.listProducts();
}

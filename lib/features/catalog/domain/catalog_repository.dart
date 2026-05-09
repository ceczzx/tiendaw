import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';

abstract class CatalogRepository {
  Future<List<Category>> getCategories();
  Future<List<Product>> getProducts();
  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId});
  Future<List<InventoryMovement>> getInventoryMovements();
  Future<List<WarehouseSupplierLot>> getWarehouseSupplierLots({
    required String productId,
    String? supplierId,
  });
  Future<Category> ensureCategory({
    required String name,
    required String prefix,
  });
  Future<Product> ensureProduct({
    required String categoryId,
    required String name,
    required String productType,
    required double salePrice,
    required double lastPurchaseCost,
    required int lowStockThreshold,
    required int unitsPerPackage,
    required Map<String, dynamic> costDetails,
  });
  Future<void> updateProductLowStockThreshold({
    required String productId,
    required int lowStockThreshold,
  });
  Future<void> updateProductUnitsPerPackage({
    required String productId,
    required int unitsPerPackage,
  });
  Future<void> updateProductCatalogData({
    required String productId,
    required String productType,
    required double salePrice,
    required double lastPurchaseCost,
    required int unitsPerPackage,
    required Map<String, dynamic> costDetails,
  });
  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    String? supplierId,
  });
}

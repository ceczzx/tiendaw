import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';

abstract class CatalogRepository {
  Future<List<Category>> getCategories();
  Future<List<Product>> getProducts();
  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId});
  Future<List<InventoryMovement>> getInventoryMovements();
  Future<Category> ensureCategory(String name);
  Future<Product> ensureProduct({
    required String categoryId,
    required String name,
    required double salePrice,
    required double lastPurchaseCost,
    required int lowStockThreshold,
  });
  Future<void> updateProductLowStockThreshold({
    required String productId,
    required int lowStockThreshold,
  });
  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    required String actorName,
  });
}

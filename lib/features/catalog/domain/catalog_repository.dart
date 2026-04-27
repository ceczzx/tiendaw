import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';

abstract class CatalogRepository {
  Future<List<Category>> getCategories();
  Future<List<Product>> getProducts();
  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId});
  Future<List<InventoryMovement>> getInventoryMovements();
  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    required String actorName,
  });
}

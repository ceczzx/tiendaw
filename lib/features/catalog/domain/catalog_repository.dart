import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';

abstract class CatalogRepository {
  Future<List<Category>> getCategories();
  Stream<List<Category>> watchCategories();
  Future<List<Product>> getProducts();
  Stream<List<Product>> watchProducts();
  Future<List<PromotableLot>> getPromotableLots({
    int daysAhead = 14,
    bool expiredOnly = false,
  });
  Stream<List<PromotableLot>> watchPromotableLots({
    int daysAhead = 14,
    bool expiredOnly = false,
  });
  Future<List<LotPromotion>> getActiveLotPromotions();
  Stream<List<LotPromotion>> watchActiveLotPromotions();
  Future<List<PromotionNotice>> getPromotionNotices({bool openOnly = true});
  Stream<List<PromotionNotice>> watchPromotionNotices({bool openOnly = true});
  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId});
  Stream<List<PriceHistoryEntry>> watchPriceHistory({String? productId});
  Future<List<InventoryMovement>> getInventoryMovements();
  Stream<List<InventoryMovement>> watchInventoryMovements();
  Future<List<InventoryLotAlert>> getInventoryLotAlerts({
    int daysAhead = 14,
    bool expiredOnly = false,
  });
  Stream<List<InventoryLotAlert>> watchInventoryLotAlerts({
    int daysAhead = 14,
    bool expiredOnly = false,
  });
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
  Future<void> activateLotPromotion({
    required String purchaseItemId,
    required int promotionalQuantity,
    required double promotionalPrice,
    String? promotionNote,
  });
  Future<void> updateProductColdState({
    required String productId,
    required int coldStockUnits,
    required double coldPriceIncrement,
  });
  Future<void> cancelLotPromotion({required String promotionId});
  Future<void> registerInventoryLoss({
    required String purchaseItemId,
    required int quantity,
    String? notes,
  });
  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    String? supplierId,
  });
}

import 'package:tiendaw/features/catalog/data/catalog_sources.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/catalog_repository.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({
    required CatalogLocalDataSource local,
    required CatalogRemoteDataSource remote,
  }) : _local = local,
       _remote = remote;

  final CatalogLocalDataSource _local;
  final CatalogRemoteDataSource _remote;

  @override
  Future<List<Category>> getCategories() async {
    try {
      final categories = await _remote.getCategories();
      await _local.saveCategories(categories);
      return categories;
    } catch (_) {
      final cached = await _local.getCategories();
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Stream<List<Category>> watchCategories() async* {
    try {
      await for (final categories in _remote.watchCategories()) {
        await _local.saveCategories(categories);
        yield categories;
      }
    } catch (_) {
      final cached = await _local.getCategories();
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
    }
  }

  @override
  Future<Category> ensureCategory({
    required String name,
    required String prefix,
  }) {
    return _remote.ensureCategory(name: name, prefix: prefix);
  }

  @override
  Future<List<InventoryMovement>> getInventoryMovements() async {
    try {
      final movements = await _remote.getInventoryMovements();
      await _local.saveInventoryMovements(movements);
      return movements;
    } catch (_) {
      final cached = await _local.getInventoryMovements();
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Stream<List<InventoryMovement>> watchInventoryMovements() async* {
    try {
      await for (final movements in _remote.watchInventoryMovements()) {
        await _local.saveInventoryMovements(movements);
        yield movements;
      }
    } catch (_) {
      final cached = await _local.getInventoryMovements();
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<InventoryLotAlert>> getInventoryLotAlerts({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async {
    try {
      final alerts = await _remote.getInventoryLotAlerts(
        daysAhead: daysAhead,
        expiredOnly: expiredOnly,
      );
      await _local.saveInventoryLotAlerts(
        daysAhead: daysAhead,
        expiredOnly: expiredOnly,
        alerts: alerts,
      );
      return alerts;
    } catch (_) {
      final cached = await _local.getInventoryLotAlerts(
        daysAhead: daysAhead,
        expiredOnly: expiredOnly,
      );
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Stream<List<InventoryLotAlert>> watchInventoryLotAlerts({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async* {
    try {
      await for (final alerts in _remote.watchInventoryLotAlerts(
        daysAhead: daysAhead,
        expiredOnly: expiredOnly,
      )) {
        await _local.saveInventoryLotAlerts(
          daysAhead: daysAhead,
          expiredOnly: expiredOnly,
          alerts: alerts,
        );
        yield alerts;
      }
    } catch (_) {
      final cached = await _local.getInventoryLotAlerts(
        daysAhead: daysAhead,
        expiredOnly: expiredOnly,
      );
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<WarehouseSupplierLot>> getWarehouseSupplierLots({
    required String productId,
    String? supplierId,
  }) async {
    try {
      final lots = await _remote.getWarehouseSupplierLots(
        productId: productId,
        supplierId: supplierId,
      );
      await _local.saveWarehouseSupplierLots(
        productId: productId,
        supplierId: supplierId,
        lots: lots,
      );
      return lots;
    } catch (_) {
      final cached = await _local.getWarehouseSupplierLots(
        productId: productId,
        supplierId: supplierId,
      );
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Future<List<WarehouseSupplierLot>> getStoreSupplierLots({
    required String productId,
    String? supplierId,
  }) async {
    try {
      final lots = await _remote.getStoreSupplierLots(
        productId: productId,
        supplierId: supplierId,
      );
      await _local.saveStoreSupplierLots(
        productId: productId,
        supplierId: supplierId,
        lots: lots,
      );
      return lots;
    } catch (_) {
      final cached = await _local.getStoreSupplierLots(
        productId: productId,
        supplierId: supplierId,
      );
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Future<List<Pack>> getPacks() async {
    try {
      final packs = await _remote.getPacks();
      await _local.savePacks(packs);
      return packs;
    } catch (_) {
      final cached = await _local.getPacks();
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Stream<List<Pack>> watchPacks() async* {
    try {
      await for (final packs in _remote.watchPacks()) {
        await _local.savePacks(packs);
        yield packs;
      }
    } catch (_) {
      final cached = await _local.getPacks();
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<PriceHistoryEntry>> getPriceHistory({String? productId}) async {
    try {
      final entries = await _remote.getPriceHistory(productId: productId);
      await _local.savePriceHistory(entries);
      return entries;
    } catch (_) {
      final cached = await _local.getPriceHistory(productId: productId);
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Stream<List<PriceHistoryEntry>> watchPriceHistory({String? productId}) async* {
    try {
      await for (final entries in _remote.watchPriceHistory(productId: productId)) {
        await _local.savePriceHistory(entries);
        yield entries;
      }
    } catch (_) {
      final cached = await _local.getPriceHistory(productId: productId);
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<Product>> getProducts() async {
    try {
      final products = await _remote.getProducts();
      await _local.saveProducts(products);
      return products;
    } catch (_) {
      final cached = await _local.getProducts();
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Stream<List<Product>> watchProducts() async* {
    try {
      await for (final products in _remote.watchProducts()) {
        await _local.saveProducts(products);
        yield products;
      }
    } catch (_) {
      final cached = await _local.getProducts();
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<PromotableLot>> getPromotableLots({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async {
    try {
      final lots = await _remote.getPromotableLots(
        daysAhead: daysAhead,
        expiredOnly: expiredOnly,
      );
      await _local.savePromotableLots(
        daysAhead: daysAhead,
        expiredOnly: expiredOnly,
        lots: lots,
      );
      return lots;
    } catch (_) {
      final cached = await _local.getPromotableLots(
        daysAhead: daysAhead,
        expiredOnly: expiredOnly,
      );
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Stream<List<PromotableLot>> watchPromotableLots({
    int daysAhead = 14,
    bool expiredOnly = false,
  }) async* {
    try {
      await for (final lots in _remote.watchPromotableLots(
        daysAhead: daysAhead,
        expiredOnly: expiredOnly,
      )) {
        await _local.savePromotableLots(
          daysAhead: daysAhead,
          expiredOnly: expiredOnly,
          lots: lots,
        );
        yield lots;
      }
    } catch (_) {
      final cached = await _local.getPromotableLots(
        daysAhead: daysAhead,
        expiredOnly: expiredOnly,
      );
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<LotPromotion>> getActiveLotPromotions() async {
    try {
      final promotions = await _remote.getActiveLotPromotions();
      await _local.saveActiveLotPromotions(promotions);
      return promotions;
    } catch (_) {
      final cached = await _local.getActiveLotPromotions();
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Stream<List<LotPromotion>> watchActiveLotPromotions() async* {
    try {
      await for (final promotions in _remote.watchActiveLotPromotions()) {
        await _local.saveActiveLotPromotions(promotions);
        yield promotions;
      }
    } catch (_) {
      final cached = await _local.getActiveLotPromotions();
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<PromotionNotice>> getPromotionNotices({
    bool openOnly = true,
  }) async {
    try {
      final notices = await _remote.getPromotionNotices(openOnly: openOnly);
      await _local.savePromotionNotices(openOnly: openOnly, notices: notices);
      return notices;
    } catch (_) {
      final cached = await _local.getPromotionNotices(openOnly: openOnly);
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Stream<List<PromotionNotice>> watchPromotionNotices({
    bool openOnly = true,
  }) async* {
    try {
      await for (final notices in _remote.watchPromotionNotices(
        openOnly: openOnly,
      )) {
        await _local.savePromotionNotices(
          openOnly: openOnly,
          notices: notices,
        );
        yield notices;
      }
    } catch (_) {
      final cached = await _local.getPromotionNotices(openOnly: openOnly);
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
    }
  }

  @override
  Future<Product> ensureProduct({
    required String categoryId,
    required String name,
    required String productType,
    required double salePrice,
    required double lastPurchaseCost,
    required int lowStockThreshold,
    required int unitsPerPackage,
    required Map<String, dynamic> costDetails,
  }) {
    return _remote.ensureProduct(
      categoryId: categoryId,
      name: name,
      productType: productType,
      salePrice: salePrice,
      lastPurchaseCost: lastPurchaseCost,
      lowStockThreshold: lowStockThreshold,
      unitsPerPackage: unitsPerPackage,
      costDetails: costDetails,
    );
  }

  @override
  Future<void> updateProductLowStockThreshold({
    required String productId,
    required int lowStockThreshold,
  }) {
    return _remote.updateProductLowStockThreshold(
      productId: productId,
      lowStockThreshold: lowStockThreshold,
    );
  }

  @override
  Future<void> updateProductUnitsPerPackage({
    required String productId,
    required int unitsPerPackage,
  }) {
    return _remote.updateProductUnitsPerPackage(
      productId: productId,
      unitsPerPackage: unitsPerPackage,
    );
  }

  @override
  Future<void> updateProductCatalogData({
    required String productId,
    required String productType,
    required double salePrice,
    required double lastPurchaseCost,
    required int unitsPerPackage,
    required Map<String, dynamic> costDetails,
    double? promotionalPrice,
    String? promotionNote,
    bool clearPromotionalPrice = false,
    bool clearPromotionNote = false,
  }) {
    return _remote.updateProductCatalogData(
      productId: productId,
      productType: productType,
      salePrice: salePrice,
      lastPurchaseCost: lastPurchaseCost,
      unitsPerPackage: unitsPerPackage,
      costDetails: costDetails,
      promotionalPrice: promotionalPrice,
      promotionNote: promotionNote,
      clearPromotionalPrice: clearPromotionalPrice,
      clearPromotionNote: clearPromotionNote,
    );
  }

  @override
  Future<void> activateLotPromotion({
    required String purchaseItemId,
    required int promotionalQuantity,
    required double promotionalPrice,
    String? promotionNote,
  }) {
    return _remote.activateLotPromotion(
      purchaseItemId: purchaseItemId,
      promotionalQuantity: promotionalQuantity,
      promotionalPrice: promotionalPrice,
      promotionNote: promotionNote,
    );
  }

  @override
  Future<void> updateProductColdState({
    required String productId,
    required int coldStockUnits,
    required double coldPriceIncrement,
  }) {
    return _remote.updateProductColdState(
      productId: productId,
      coldStockUnits: coldStockUnits,
      coldPriceIncrement: coldPriceIncrement,
    );
  }

  @override
  Future<void> cancelLotPromotion({required String promotionId}) {
    return _remote.cancelLotPromotion(promotionId: promotionId);
  }

  @override
  Future<void> upsertGeneralPromotion({
    required String productId,
    required double promotionalPrice,
    String? promotionNote,
    DateTime? scheduledEndAt,
  }) {
    return _remote.upsertGeneralPromotion(
      productId: productId,
      promotionalPrice: promotionalPrice,
      promotionNote: promotionNote,
      scheduledEndAt: scheduledEndAt,
    );
  }

  @override
  Future<void> clearGeneralPromotion({required String productId}) {
    return _remote.clearGeneralPromotion(productId: productId);
  }

  @override
  Future<void> registerInventoryLoss({
    required String purchaseItemId,
    required int quantity,
    required String reason,
    String? notes,
    String? storageCondition,
  }) {
    return _remote.registerInventoryLoss(
      purchaseItemId: purchaseItemId,
      quantity: quantity,
      reason: reason,
      notes: notes,
      storageCondition: storageCondition,
    );
  }

  @override
  Future<void> transferWarehouseToStore({
    required String productId,
    required int quantity,
    String? supplierId,
    String? purchaseItemId,
    String? notes,
  }) {
    return _remote.transferWarehouseToStore(
      productId: productId,
      quantity: quantity,
      supplierId: supplierId,
      purchaseItemId: purchaseItemId,
      notes: notes,
    );
  }

  @override
  Future<Pack> createPack({
    required String name,
    required int packQuantity,
    required List<PackDraftItem> items,
  }) {
    return _remote.createPack(
      name: name,
      packQuantity: packQuantity,
      items: items,
    );
  }
}

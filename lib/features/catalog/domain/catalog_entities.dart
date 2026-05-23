class Category {
  const Category({required this.id, required this.name, required this.prefix});

  final String id;
  final String name;
  final String prefix;
}

class ProductPromotionOffer {
  const ProductPromotionOffer({
    required this.promotionId,
    required this.purchaseItemId,
    required this.supplierName,
    required this.promotionalPrice,
    required this.promoQuantityTotal,
    required this.promoQuantityRemaining,
    required this.storeAvailableUnits,
    required this.warehouseAvailableUnits,
    required this.status,
    required this.createdAt,
    this.supplierId,
    this.expiryDate,
    this.note,
  });

  final String promotionId;
  final String purchaseItemId;
  final String? supplierId;
  final String supplierName;
  final DateTime? expiryDate;
  final double promotionalPrice;
  final int promoQuantityTotal;
  final int promoQuantityRemaining;
  final int storeAvailableUnits;
  final int warehouseAvailableUnits;
  final String status;
  final String? note;
  final DateTime createdAt;

  int get allocatableUnits {
    final boundedPromoUnits =
        promoQuantityRemaining < 0 ? 0 : promoQuantityRemaining;
    final boundedStoreUnits = storeAvailableUnits < 0 ? 0 : storeAvailableUnits;
    return boundedPromoUnits < boundedStoreUnits
        ? boundedPromoUnits
        : boundedStoreUnits;
  }

  bool get isActiveInStore =>
      status != 'cancelled' &&
      status != 'exhausted' &&
      storeAvailableUnits > 0 &&
      allocatableUnits > 0;
}

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.categoryId,
    required this.name,
    required this.productType,
    required this.unitsPerPackage,
    required this.costDetails,
    required this.salePrice,
    required this.lastPurchaseCost,
    required this.stockStore,
    required this.stockWarehouse,
    required this.lowStockThreshold,
    this.packageName = 'caja',
    this.unitName = 'unid',
    this.nextExpiryDate,
    this.coldStockUnits = 0,
    this.coldPriceIncrement = 0.50,
    this.promotionalPrice,
    this.promotionNote,
    this.promotionOffers = const [],
  });

  final String id;
  final String sku;
  final String categoryId;
  final String name;
  final String productType;
  final int unitsPerPackage;
  final Map<String, dynamic> costDetails;
  final double salePrice;
  final double lastPurchaseCost;
  final int stockStore;
  final int stockWarehouse;
  final int lowStockThreshold;
  final String packageName;
  final String unitName;
  final DateTime? nextExpiryDate;
  final int coldStockUnits;
  final double coldPriceIncrement;
  final double? promotionalPrice;
  final String? promotionNote;
  final List<ProductPromotionOffer> promotionOffers;

  Product copyWith({
    String? id,
    String? sku,
    String? categoryId,
    String? name,
    String? productType,
    int? unitsPerPackage,
    Map<String, dynamic>? costDetails,
    double? salePrice,
    double? lastPurchaseCost,
    int? stockStore,
    int? stockWarehouse,
    int? lowStockThreshold,
    String? packageName,
    String? unitName,
    DateTime? nextExpiryDate,
    int? coldStockUnits,
    double? coldPriceIncrement,
    double? promotionalPrice,
    String? promotionNote,
    List<ProductPromotionOffer>? promotionOffers,
    bool clearPromotionalPrice = false,
    bool clearPromotionNote = false,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      productType: productType ?? this.productType,
      unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
      costDetails: costDetails ?? this.costDetails,
      salePrice: salePrice ?? this.salePrice,
      lastPurchaseCost: lastPurchaseCost ?? this.lastPurchaseCost,
      stockStore: stockStore ?? this.stockStore,
      stockWarehouse: stockWarehouse ?? this.stockWarehouse,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      packageName: packageName ?? this.packageName,
      unitName: unitName ?? this.unitName,
      nextExpiryDate: nextExpiryDate ?? this.nextExpiryDate,
      coldStockUnits: coldStockUnits ?? this.coldStockUnits,
      coldPriceIncrement: coldPriceIncrement ?? this.coldPriceIncrement,
      promotionalPrice:
          clearPromotionalPrice
              ? null
              : promotionalPrice ?? this.promotionalPrice,
      promotionNote:
          clearPromotionNote ? null : promotionNote ?? this.promotionNote,
      promotionOffers: promotionOffers ?? this.promotionOffers,
    );
  }
}

class PromotableLot {
  const PromotableLot({
    required this.purchaseItemId,
    required this.productId,
    required this.productName,
    required this.supplierName,
    required this.receivedAt,
    required this.expiryDate,
    required this.warehouseAvailableUnits,
    required this.storeAvailableUnits,
    required this.totalAvailableUnits,
    required this.recommendedLocation,
    this.supplierId,
  });

  final String purchaseItemId;
  final String productId;
  final String productName;
  final String? supplierId;
  final String supplierName;
  final DateTime receivedAt;
  final DateTime expiryDate;
  final int warehouseAvailableUnits;
  final int storeAvailableUnits;
  final int totalAvailableUnits;
  final String recommendedLocation;
}

class LotPromotion {
  const LotPromotion({
    required this.promotionId,
    required this.purchaseItemId,
    required this.productId,
    required this.productName,
    required this.supplierName,
    required this.promotionalPrice,
    required this.promoQuantityTotal,
    required this.promoQuantityRemaining,
    required this.warehouseAvailableUnits,
    required this.storeAvailableUnits,
    required this.status,
    required this.createdAt,
    this.supplierId,
    this.expiryDate,
    this.note,
  });

  final String promotionId;
  final String purchaseItemId;
  final String productId;
  final String productName;
  final String? supplierId;
  final String supplierName;
  final DateTime? expiryDate;
  final double promotionalPrice;
  final int promoQuantityTotal;
  final int promoQuantityRemaining;
  final int warehouseAvailableUnits;
  final int storeAvailableUnits;
  final String status;
  final String? note;
  final DateTime createdAt;

  int get allocatableUnits {
    final boundedPromoUnits =
        promoQuantityRemaining < 0 ? 0 : promoQuantityRemaining;
    final boundedStoreUnits = storeAvailableUnits < 0 ? 0 : storeAvailableUnits;
    return boundedPromoUnits < boundedStoreUnits
        ? boundedPromoUnits
        : boundedStoreUnits;
  }

  bool get hasStoreAvailability => storeAvailableUnits > 0;
  bool get isActiveInStore =>
      status != 'cancelled' &&
      status != 'exhausted' &&
      storeAvailableUnits > 0 &&
      allocatableUnits > 0;
}

class PromotionNotice {
  const PromotionNotice({
    required this.id,
    required this.promotionId,
    required this.noticeType,
    required this.message,
    required this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String promotionId;
  final String noticeType;
  final String message;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  bool get isOpen => resolvedAt == null;
}

class PriceHistoryEntry {
  const PriceHistoryEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.salePrice,
    required this.coldPriceIncrement,
    required this.effectiveFrom,
    required this.createdByName,
    this.promotionalPrice,
    this.promotionNote,
    this.effectiveTo,
  });

  final String id;
  final String productId;
  final String productName;
  final double salePrice;
  final double? promotionalPrice;
  final String? promotionNote;
  final double coldPriceIncrement;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String createdByName;

  bool get hasPromotion => promotionalPrice != null;

  bool get isActive => isActiveAt(DateTime.now());

  bool isActiveAt(DateTime time) {
    if (effectiveFrom.isAfter(time)) {
      return false;
    }
    return effectiveTo == null || effectiveTo!.isAfter(time);
  }
}

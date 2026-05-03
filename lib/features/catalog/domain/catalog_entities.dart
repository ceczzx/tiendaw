class Category {
  const Category({
    required this.id,
    required this.name,
    required this.prefix,
  });

  final String id;
  final String name;
  final String prefix;
}

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.productType,
    required this.unitsPerPackage,
    required this.costDetails,
    required this.specs,
    required this.salePrice,
    required this.lastPurchaseCost,
    required this.stockStore,
    required this.stockWarehouse,
    required this.lowStockThreshold,
    this.packageName = 'caja',
    this.unitName = 'unid',
    this.nextExpiryDate,
  });

  final String id;
  final String categoryId;
  final String name;
  final String productType;
  final int unitsPerPackage;
  final Map<String, dynamic> costDetails;
  final Map<String, dynamic> specs;
  final double salePrice;
  final double lastPurchaseCost;
  final int stockStore;
  final int stockWarehouse;
  final int lowStockThreshold;
  final String packageName;
  final String unitName;
  final DateTime? nextExpiryDate;

  Product copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? productType,
    int? unitsPerPackage,
    Map<String, dynamic>? costDetails,
    Map<String, dynamic>? specs,
    double? salePrice,
    double? lastPurchaseCost,
    int? stockStore,
    int? stockWarehouse,
    int? lowStockThreshold,
    String? packageName,
    String? unitName,
    DateTime? nextExpiryDate,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      productType: productType ?? this.productType,
      unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
      costDetails: costDetails ?? this.costDetails,
      specs: specs ?? this.specs,
      salePrice: salePrice ?? this.salePrice,
      lastPurchaseCost: lastPurchaseCost ?? this.lastPurchaseCost,
      stockStore: stockStore ?? this.stockStore,
      stockWarehouse: stockWarehouse ?? this.stockWarehouse,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      packageName: packageName ?? this.packageName,
      unitName: unitName ?? this.unitName,
      nextExpiryDate: nextExpiryDate ?? this.nextExpiryDate,
    );
  }
}

class PriceHistoryEntry {
  const PriceHistoryEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.supplier,
    required this.unitCost,
    required this.registeredAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String supplier;
  final double unitCost;
  final DateTime registeredAt;
}

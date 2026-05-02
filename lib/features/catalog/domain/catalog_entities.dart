class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;
}

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.unitsPerPackage,
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
  final int unitsPerPackage;
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
    int? unitsPerPackage,
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
      unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
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

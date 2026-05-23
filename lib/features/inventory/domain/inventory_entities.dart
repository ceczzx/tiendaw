class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
    this.batchId,
    this.supplierId,
    this.supplierName,
    required this.type,
    required this.quantity,
    required this.fromLocation,
    required this.toLocation,
    required this.actorName,
    required this.occurredAt,
    this.notes,
  });

  final String id;
  final String productId;
  final String productName;
  final String? batchId;
  final String? supplierId;
  final String? supplierName;
  final String type;
  final int quantity;
  final String fromLocation;
  final String toLocation;
  final String actorName;
  final DateTime occurredAt;
  final String? notes;
}

class WarehouseSupplierLot {
  const WarehouseSupplierLot({
    required this.purchaseItemId,
    required this.productId,
    this.supplierId,
    required this.supplierName,
    required this.receivedAt,
    required this.availableUnits,
    this.expiryDate,
    this.isPromotionPriority = false,
    this.promotionId,
    this.promotionStatus,
    this.promotionalPrice,
    this.promotionNote,
  });

  final String purchaseItemId;
  final String productId;
  final String? supplierId;
  final String supplierName;
  final DateTime receivedAt;
  final int availableUnits;
  final DateTime? expiryDate;
  final bool isPromotionPriority;
  final String? promotionId;
  final String? promotionStatus;
  final double? promotionalPrice;
  final String? promotionNote;
}

enum InventoryLotAlertStatus { expiring, expired }

class InventoryLotAlert {
  const InventoryLotAlert({
    required this.purchaseItemId,
    required this.productId,
    required this.productName,
    this.supplierId,
    required this.supplierName,
    required this.receivedAt,
    required this.expiryDate,
    required this.availableUnits,
  });

  final String purchaseItemId;
  final String productId;
  final String productName;
  final String? supplierId;
  final String supplierName;
  final DateTime receivedAt;
  final DateTime expiryDate;
  final int availableUnits;

  InventoryLotAlertStatus statusAt(DateTime today) {
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedExpiry = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    return normalizedExpiry.isBefore(normalizedToday)
        ? InventoryLotAlertStatus.expired
        : InventoryLotAlertStatus.expiring;
  }

  int remainingDaysFrom(DateTime today) {
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedExpiry = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    return normalizedExpiry.difference(normalizedToday).inDays;
  }
}

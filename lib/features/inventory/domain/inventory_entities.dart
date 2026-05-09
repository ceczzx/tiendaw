class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
    this.supplierId,
    this.supplierName,
    required this.type,
    required this.quantity,
    required this.fromLocation,
    required this.toLocation,
    required this.actorName,
    required this.occurredAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String? supplierId;
  final String? supplierName;
  final String type;
  final int quantity;
  final String fromLocation;
  final String toLocation;
  final String actorName;
  final DateTime occurredAt;
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
  });

  final String purchaseItemId;
  final String productId;
  final String? supplierId;
  final String supplierName;
  final DateTime receivedAt;
  final int availableUnits;
  final DateTime? expiryDate;
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
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
  final String type;
  final int quantity;
  final String fromLocation;
  final String toLocation;
  final String actorName;
  final DateTime occurredAt;
}

import 'package:tiendaw/core/sync/sync_status.dart';

class PurchaseLine {
  const PurchaseLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitsPerPackage,
    required this.unitCost,
    this.expiryDate,
  });

  final String productId;
  final String productName;
  final int quantity;
  final int unitsPerPackage;
  final double unitCost;
  final DateTime? expiryDate;

  int get totalUnits => quantity * unitsPerPackage;

  double get subtotal => totalUnits * unitCost;
}

class Purchase {
  const Purchase({
    required this.id,
    required this.supplier,
    this.supplierPhone,
    required this.registeredBy,
    required this.items,
    required this.receivedAt,
    required this.syncStatus,
    required this.syncAttempts,
  });

  final String id;
  final String supplier;
  final String? supplierPhone;
  final String registeredBy;
  final List<PurchaseLine> items;
  final DateTime receivedAt;
  final SyncStatus syncStatus;
  final int syncAttempts;

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  Purchase copyWith({
    String? id,
    String? supplier,
    String? supplierPhone,
    bool clearSupplierPhone = false,
    String? registeredBy,
    List<PurchaseLine>? items,
    DateTime? receivedAt,
    SyncStatus? syncStatus,
    int? syncAttempts,
  }) {
    return Purchase(
      id: id ?? this.id,
      supplier: supplier ?? this.supplier,
      supplierPhone:
          clearSupplierPhone ? null : supplierPhone ?? this.supplierPhone,
      registeredBy: registeredBy ?? this.registeredBy,
      items: items ?? this.items,
      receivedAt: receivedAt ?? this.receivedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttempts: syncAttempts ?? this.syncAttempts,
    );
  }
}

import 'package:tiendaw/core/sync/sync_status.dart';

enum PaymentMethod { cash, yape }

class SaleLine {
  const SaleLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  double get subtotal => quantity * unitPrice;
}

class Sale {
  const Sale({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.items,
    required this.paymentMethod,
    required this.createdAt,
    required this.syncStatus,
    required this.syncAttempts,
  });

  final String id;
  final String sellerId;
  final String sellerName;
  final List<SaleLine> items;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final int syncAttempts;

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  Sale copyWith({
    String? id,
    String? sellerId,
    String? sellerName,
    List<SaleLine>? items,
    PaymentMethod? paymentMethod,
    DateTime? createdAt,
    SyncStatus? syncStatus,
    int? syncAttempts,
  }) {
    return Sale(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      items: items ?? this.items,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttempts: syncAttempts ?? this.syncAttempts,
    );
  }
}

class CashShift {
  const CashShift({
    required this.id,
    required this.sellerId,
    required this.openedAt,
    required this.cashSales,
    required this.yapeSales,
    this.closedAt,
  });

  final String id;
  final String sellerId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double cashSales;
  final double yapeSales;

  bool get isOpen => closedAt == null;
  double get total => cashSales + yapeSales;

  CashShift copyWith({
    String? id,
    String? sellerId,
    DateTime? openedAt,
    DateTime? closedAt,
    double? cashSales,
    double? yapeSales,
  }) {
    return CashShift(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      cashSales: cashSales ?? this.cashSales,
      yapeSales: yapeSales ?? this.yapeSales,
    );
  }
}

import 'package:tiendaw/core/sync/sync_status.dart';

enum PaymentMethod { cash, yape, transfer }

enum CashShiftStatus { pendingApproval, approved, rejected, open, closed }

class SaleLine {
  const SaleLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.baseUnitPrice,
    this.originalUnitPrice,
    this.priceAdjustment = 0,
    this.isIced = false,
    this.usedPromotionalPrice = false,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double? baseUnitPrice;
  final double? originalUnitPrice;
  final double priceAdjustment;
  final bool isIced;
  final bool usedPromotionalPrice;

  double get subtotal => quantity * unitPrice;

  String get cartKey =>
      '$productId::${isIced ? 'iced' : 'regular'}::${unitPrice.toStringAsFixed(2)}';

  Map<String, dynamic> toItemMeta() {
    return <String, dynamic>{
      'is_iced': isIced,
      'base_unit_price': baseUnitPrice ?? unitPrice,
      'original_unit_price':
          originalUnitPrice ?? baseUnitPrice ?? unitPrice,
      'price_adjustment': priceAdjustment,
      'used_promotional_price': usedPromotionalPrice,
    };
  }
}

class Sale {
  const Sale({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    this.cashShiftId,
    required this.items,
    required this.paymentMethod,
    required this.createdAt,
    required this.syncStatus,
    required this.syncAttempts,
  });

  final String id;
  final String sellerId;
  final String sellerName;
  final String? cashShiftId;
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
    String? cashShiftId,
    bool clearCashShiftId = false,
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
      cashShiftId: clearCashShiftId ? null : cashShiftId ?? this.cashShiftId,
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
    required this.openingCash,
    required this.openingYape,
    required this.cashSales,
    required this.yapeSales,
    required this.status,
    this.sellerName,
    this.closedAt,
    this.closingCash,
    this.closingYape,
    this.locationId,
    this.locationName,
    this.openingLatitude,
    this.openingLongitude,
    this.closingLatitude,
    this.closingLongitude,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
  });

  final String id;
  final String sellerId;
  final String? sellerName;
  final DateTime openedAt;
  final double openingCash;
  final double openingYape;
  final DateTime? closedAt;
  final double? closingCash;
  final double? closingYape;
  final double cashSales;
  final double yapeSales;
  final String? locationId;
  final String? locationName;
  final double? openingLatitude;
  final double? openingLongitude;
  final double? closingLatitude;
  final double? closingLongitude;
  final CashShiftStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;

  bool get isOpen =>
      status == CashShiftStatus.open || status == CashShiftStatus.approved;
  bool get isPendingApproval => status == CashShiftStatus.pendingApproval;
  bool get isClosed => status == CashShiftStatus.closed || closedAt != null;
  bool get isRejected => status == CashShiftStatus.rejected;
  bool get canSell => isOpen && !isClosed;
  double get total => cashSales + yapeSales;
  double get openingAmount => openingCash + openingYape;
  double get expectedClosingCash => openingCash + cashSales;
  double get expectedClosingYape => openingYape + yapeSales;
  double get expectedClosingAmount => expectedClosingCash + expectedClosingYape;
  double get closingAmount => (closingCash ?? 0) + (closingYape ?? 0);
  double get finalAmount => isClosed ? closingAmount : expectedClosingAmount;

  CashShift copyWith({
    String? id,
    String? sellerId,
    String? sellerName,
    DateTime? openedAt,
    double? openingCash,
    double? openingYape,
    DateTime? closedAt,
    double? closingCash,
    double? closingYape,
    double? cashSales,
    double? yapeSales,
    String? locationId,
    String? locationName,
    double? openingLatitude,
    double? openingLongitude,
    double? closingLatitude,
    double? closingLongitude,
    CashShiftStatus? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
  }) {
    return CashShift(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      openedAt: openedAt ?? this.openedAt,
      openingCash: openingCash ?? this.openingCash,
      openingYape: openingYape ?? this.openingYape,
      closedAt: closedAt ?? this.closedAt,
      closingCash: closingCash ?? this.closingCash,
      closingYape: closingYape ?? this.closingYape,
      cashSales: cashSales ?? this.cashSales,
      yapeSales: yapeSales ?? this.yapeSales,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      openingLatitude: openingLatitude ?? this.openingLatitude,
      openingLongitude: openingLongitude ?? this.openingLongitude,
      closingLatitude: closingLatitude ?? this.closingLatitude,
      closingLongitude: closingLongitude ?? this.closingLongitude,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

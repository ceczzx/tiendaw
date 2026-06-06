import 'package:tiendaw/core/sync/sync_status.dart';

enum PaymentMethod { cash, yape, transfer }

enum CashShiftStatus {
  pendingApproval,
  approved,
  rejected,
  canceled,
  open,
  closed,
}

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
    this.usedLotPromotion = false,
    this.packId,
    this.packName,
    this.batchId,
    this.packSaleQuantity,
    this.packItemQuantity,
    this.stockReservedByPack = false,
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
  final bool usedLotPromotion;
  final String? packId;
  final String? packName;
  final String? batchId;
  final int? packSaleQuantity;
  final int? packItemQuantity;
  final bool stockReservedByPack;

  double get subtotal => quantity * unitPrice;

  String get cartKey =>
      '${packId ?? 'single'}::$productId::${batchId ?? 'any'}::${isIced ? 'iced' : 'regular'}::${unitPrice.toStringAsFixed(2)}';

  Map<String, dynamic> toItemMeta() {
    return <String, dynamic>{
      'is_iced': isIced,
      'base_unit_price': baseUnitPrice ?? unitPrice,
      'original_unit_price': originalUnitPrice ?? baseUnitPrice ?? unitPrice,
      'price_adjustment': priceAdjustment,
      'used_promotional_price': usedPromotionalPrice,
      'used_lot_promotion': usedLotPromotion,
      if (packId != null) 'pack_id': packId,
      if (packName != null) 'pack_name': packName,
      if (batchId != null) 'batch_id': batchId,
      if (packSaleQuantity != null) 'pack_sale_quantity': packSaleQuantity,
      if (packItemQuantity != null) 'pack_item_quantity': packItemQuantity,
      if (stockReservedByPack) 'stock_reserved_by_pack': true,
    };
  }
}

class SaleLineDisplayGroup {
  SaleLineDisplayGroup(Iterable<SaleLine> lines)
    : lines = List<SaleLine>.unmodifiable(lines) {
    if (this.lines.isEmpty) {
      throw ArgumentError.value(lines, 'lines', 'Debe tener al menos una linea.');
    }
  }

  final List<SaleLine> lines;

  SaleLine get primaryLine => lines.first;
  bool get isPack => primaryLine.packId != null;
  bool get isIced => !isPack && primaryLine.isIced;
  bool get usedPromotionalPrice =>
      !isPack && primaryLine.usedPromotionalPrice;
  String get cartKey => primaryLine.cartKey;

  String get displayName {
    if (!isPack) {
      return primaryLine.productName;
    }
    final packName = primaryLine.packName?.trim();
    if (packName != null && packName.isNotEmpty) {
      return packName;
    }
    return primaryLine.productName;
  }

  int get quantity {
    if (!isPack) {
      return primaryLine.quantity;
    }

    var packQuantity = 0;
    for (final line in lines) {
      final inferredQuantity =
          line.packSaleQuantity ??
          ((line.packItemQuantity ?? 0) <= 0
              ? 0
              : line.quantity ~/ line.packItemQuantity!);
      if (inferredQuantity > packQuantity) {
        packQuantity = inferredQuantity;
      }
    }
    return packQuantity;
  }

  double get subtotal => lines.fold(0, (sum, line) => sum + line.subtotal);

  String get packContentsLabel {
    if (!isPack) {
      return '';
    }

    final packQuantity = quantity;
    return lines
        .map((line) {
          final componentQuantity =
              line.packItemQuantity ??
              (packQuantity <= 0 ? line.quantity : line.quantity ~/ packQuantity);
          return '${_packComponentName(line)} x$componentQuantity';
        })
        .join(' | ');
  }
}

List<SaleLineDisplayGroup> groupSaleLinesForDisplay(
  Iterable<SaleLine> lines,
) {
  final groups = <SaleLineDisplayGroup>[];
  final packIndexes = <String, int>{};
  final packLines = <String, List<SaleLine>>{};

  for (final line in lines) {
    final packId = line.packId;
    if (packId == null || packId.isEmpty) {
      groups.add(SaleLineDisplayGroup([line]));
      continue;
    }

    final index = packIndexes[packId];
    if (index == null) {
      packIndexes[packId] = groups.length;
      final linesForPack = <SaleLine>[line];
      packLines[packId] = linesForPack;
      groups.add(SaleLineDisplayGroup(linesForPack));
      continue;
    }

    final linesForPack = packLines[packId]!..add(line);
    groups[index] = SaleLineDisplayGroup(linesForPack);
  }

  return List<SaleLineDisplayGroup>.unmodifiable(groups);
}

String _packComponentName(SaleLine line) {
  final packName = line.packName?.trim();
  if (packName == null || packName.isEmpty) {
    return line.productName;
  }

  final prefixedName = '$packName / ';
  if (line.productName.startsWith(prefixedName)) {
    return line.productName.substring(prefixedName.length);
  }
  return line.productName;
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
  bool get isClosed =>
      status == CashShiftStatus.closed ||
      status == CashShiftStatus.canceled ||
      closedAt != null;
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

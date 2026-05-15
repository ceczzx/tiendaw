import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/providers.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/load_catalog_overview_use_case.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';

class AdminDesktopDashboardState {
  const AdminDesktopDashboardState({
    required this.categories,
    required this.products,
    required this.sales,
    required this.cashShifts,
    required this.purchases,
    required this.movements,
    required this.lowStockProducts,
    required this.expiringProducts,
    required this.pendingSyncCount,
    required this.sellerFilter,
    required this.periodStart,
    required this.periodEnd,
  });

  final List<Category> categories;
  final List<Product> products;
  final List<Sale> sales;
  final List<CashShift> cashShifts;
  final List<Purchase> purchases;
  final List<InventoryMovement> movements;
  final List<Product> lowStockProducts;
  final List<Product> expiringProducts;
  final int pendingSyncCount;
  final String sellerFilter;
  final DateTime periodStart;
  final DateTime periodEnd;

  List<Sale> get filteredSales {
    final start = _periodStart;
    final end = _periodEndExclusive;
    return sales.where((sale) {
      final sellerMatches =
          sellerFilter == 'all' || sale.sellerId == sellerFilter;
      return sellerMatches &&
          !sale.createdAt.isBefore(start) &&
          sale.createdAt.isBefore(end);
    }).toList();
  }

  List<Purchase> get filteredPurchases {
    final start = _periodStart;
    final end = _periodEndExclusive;
    return purchases
        .where(
          (purchase) =>
              !purchase.receivedAt.isBefore(start) &&
              purchase.receivedAt.isBefore(end),
        )
        .toList();
  }

  List<CashShift> get filteredCashShifts {
    final start = _periodStart;
    final end = _periodEndExclusive;
    return cashShifts.where((shift) {
      final sellerMatches =
          sellerFilter == 'all' || shift.sellerId == sellerFilter;
      final shiftEnd = shift.closedAt ?? DateTime.now();
      final overlapsPeriod =
          shift.openedAt.isBefore(end) && !shiftEnd.isBefore(start);
      return sellerMatches && overlapsPeriod;
    }).toList();
  }

  List<InventoryMovement> get filteredMovements {
    final start = _periodStart;
    final end = _periodEndExclusive;
    return movements
        .where(
          (movement) =>
              !movement.occurredAt.isBefore(start) &&
              movement.occurredAt.isBefore(end),
        )
        .toList();
  }

  DateTime get _periodStart =>
      DateTime(periodStart.year, periodStart.month, periodStart.day);

  DateTime get _periodEnd =>
      DateTime(periodEnd.year, periodEnd.month, periodEnd.day);

  DateTime get _periodEndExclusive => _periodEnd.add(const Duration(days: 1));

  DateTimeRange get period => DateTimeRange(start: _periodStart, end: _periodEnd);

  String get periodLabel =>
      '${SystemWFormatters.shortDate.format(_periodStart)} - ${SystemWFormatters.shortDate.format(_periodEnd)}';

  double get dailySalesTotal =>
      filteredSales.fold(0, (sum, sale) => sum + sale.total);

  double get cashSalesTotal => filteredSales
      .where((sale) => sale.paymentMethod == PaymentMethod.cash)
      .fold(0, (sum, sale) => sum + sale.total);

  double get yapeSalesTotal => filteredSales
      .where(
        (sale) =>
            sale.paymentMethod == PaymentMethod.yape ||
            sale.paymentMethod == PaymentMethod.transfer,
      )
      .fold(0, (sum, sale) => sum + sale.total);

  String get topSeller {
    if (filteredSales.isEmpty) {
      return 'Sin ventas';
    }

    final totals = <String, double>{};
    final names = <String, String>{};
    for (final sale in filteredSales) {
      totals.update(
        sale.sellerId,
        (value) => value + sale.total,
        ifAbsent: () => sale.total,
      );
      names[sale.sellerId] = sale.sellerName;
    }

    final winnerEntry = totals.entries.reduce(
      (current, next) => current.value >= next.value ? current : next,
    );
    return '${names[winnerEntry.key]} (${SystemWFormatters.currency.format(winnerEntry.value)})';
  }

  double get purchaseTotal =>
      filteredPurchases.fold(0, (sum, purchase) => sum + purchase.total);

  String get topSupplier {
    if (filteredPurchases.isEmpty) {
      return 'Sin compras';
    }

    final totals = <String, double>{};
    for (final purchase in filteredPurchases) {
      totals.update(
        purchase.supplier,
        (value) => value + purchase.total,
        ifAbsent: () => purchase.total,
      );
    }

    final winnerEntry = totals.entries.reduce(
      (current, next) => current.value >= next.value ? current : next,
    );
    return '${winnerEntry.key} (${SystemWFormatters.currency.format(winnerEntry.value)})';
  }

  int get movementUnitsTotal =>
      filteredMovements.fold(0, (sum, movement) => sum + movement.quantity);

  int get movementProductsCount =>
      filteredMovements.map((movement) => movement.productId).toSet().length;

  int get purchaseMovementCount =>
      filteredMovements
          .where((movement) => _movementBucket(movement) == 'purchase')
          .length;

  int get saleMovementCount =>
      filteredMovements
          .where((movement) => _movementBucket(movement) == 'sale')
          .length;

  int get transferMovementCount =>
      filteredMovements
          .where((movement) => _movementBucket(movement) == 'transfer')
          .length;

  int get purchaseMovementUnits => filteredMovements
      .where((movement) => _movementBucket(movement) == 'purchase')
      .fold(0, (sum, movement) => sum + movement.quantity);

  int get saleMovementUnits => filteredMovements
      .where((movement) => _movementBucket(movement) == 'sale')
      .fold(0, (sum, movement) => sum + movement.quantity);

  int get transferMovementUnits => filteredMovements
      .where((movement) => _movementBucket(movement) == 'transfer')
      .fold(0, (sum, movement) => sum + movement.quantity);

  int get activeAlertCount => lowStockProducts.length + expiringProducts.length;

  List<Map<String, String>> get sellerOptions {
    final sellers = <String, String>{};
    for (final shift in cashShifts) {
      final sellerName = shift.sellerName?.trim();
      if (sellerName != null && sellerName.isNotEmpty) {
        sellers[shift.sellerId] = sellerName;
      }
    }

    for (final sale in sales) {
      sellers[sale.sellerId] = sellers[sale.sellerId] ?? sale.sellerName;
    }

    return [
      {'id': 'all', 'name': 'Todos'},
      ...sellers.entries.map((entry) => {'id': entry.key, 'name': entry.value}),
    ];
  }

  AdminDesktopDashboardState copyWith({
    List<Category>? categories,
    List<Product>? products,
    List<Sale>? sales,
    List<CashShift>? cashShifts,
    List<Purchase>? purchases,
    List<InventoryMovement>? movements,
    List<Product>? lowStockProducts,
    List<Product>? expiringProducts,
    int? pendingSyncCount,
    String? sellerFilter,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    return AdminDesktopDashboardState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      sales: sales ?? this.sales,
      cashShifts: cashShifts ?? this.cashShifts,
      purchases: purchases ?? this.purchases,
      movements: movements ?? this.movements,
      lowStockProducts: lowStockProducts ?? this.lowStockProducts,
      expiringProducts: expiringProducts ?? this.expiringProducts,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      sellerFilter: sellerFilter ?? this.sellerFilter,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
    );
  }

  String _movementBucket(InventoryMovement movement) {
    final fromLocation = movement.fromLocation.toLowerCase();
    final toLocation = movement.toLocation.toLowerCase();
    if (fromLocation.contains('sin origen')) {
      return 'purchase';
    }
    if (toLocation.contains('sin destino')) {
      return 'sale';
    }
    return movement.type.toLowerCase();
  }
}

final adminDesktopDashboardViewModelProvider = AsyncNotifierProvider<
  AdminDesktopDashboardViewModel,
  AdminDesktopDashboardState
>(AdminDesktopDashboardViewModel.new);

class AdminDesktopDashboardViewModel
    extends AsyncNotifier<AdminDesktopDashboardState> {
  StreamSubscription<CatalogOverview>? _catalogSubscription;
  StreamSubscription<List<Sale>>? _salesSubscription;
  StreamSubscription<List<CashShift>>? _cashShiftsSubscription;
  StreamSubscription<List<Purchase>>? _purchasesSubscription;
  StreamSubscription<List<InventoryMovement>>? _movementsSubscription;

  @override
  Future<AdminDesktopDashboardState> build() async {
    ref.onDispose(_disposeRealtimeSubscriptions);
    final hydrated = await _hydrate();
    _bindRealtime();
    return hydrated;
  }

  Future<void> setSellerFilter(String sellerId) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(sellerFilter: sellerId));
  }

  Future<void> setPeriod(DateTimeRange period) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        periodStart: _dateOnly(period.start),
        periodEnd: _dateOnly(period.end),
      ),
    );
  }

  Future<AdminDesktopDashboardState> _hydrate({
    String sellerFilter = 'all',
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    final catalog = await ref.read(loadCatalogOverviewUseCaseProvider)();
    final sales = await ref.read(salesRepositoryProvider).getSales();
    final cashShifts = await ref.read(salesRepositoryProvider).getCashShifts();
    final purchases = await ref.read(purchaseRepositoryProvider).getPurchases();
    final movements =
        await ref.read(catalogRepositoryProvider).getInventoryMovements();
    final today = DateTime.now();

    final lowStockProducts =
        catalog.products
            .where((product) => product.stockStore < product.lowStockThreshold)
            .toList();
    final expiringProducts =
        catalog.products.where((product) {
          final expiryDate = product.nextExpiryDate;
          if (expiryDate == null) {
            return false;
          }

          final remainingDays = expiryDate.difference(today).inDays;
          return remainingDays <= 14;
        }).toList();

    return AdminDesktopDashboardState(
      categories: catalog.categories,
      products: catalog.products,
      sales: sales,
      cashShifts: cashShifts,
      purchases: purchases,
      movements: movements,
      lowStockProducts: lowStockProducts,
      expiringProducts: expiringProducts,
      pendingSyncCount: 0,
      sellerFilter: sellerFilter,
      periodStart: _dateOnly(periodStart ?? _currentWeekStart()),
      periodEnd: _dateOnly(periodEnd ?? _currentWeekEnd()),
    );
  }

  void _bindRealtime() {
    _disposeRealtimeSubscriptions();

    _catalogSubscription = ref.read(loadCatalogOverviewUseCaseProvider).watch().listen(
      _handleCatalogUpdate,
      onError: (_, __) {},
    );
    _salesSubscription = ref
        .read(salesRepositoryProvider)
        .watchSales()
        .listen(_handleSalesUpdate, onError: (_, __) {});
    _cashShiftsSubscription = ref
        .read(salesRepositoryProvider)
        .watchCashShifts()
        .listen(_handleCashShiftsUpdate, onError: (_, __) {});
    _purchasesSubscription = ref
        .read(purchaseRepositoryProvider)
        .watchPurchases()
        .listen(_handlePurchasesUpdate, onError: (_, __) {});
    _movementsSubscription = ref
        .read(catalogRepositoryProvider)
        .watchInventoryMovements()
        .listen(_handleMovementsUpdate, onError: (_, __) {});
  }

  void _disposeRealtimeSubscriptions() {
    _catalogSubscription?.cancel();
    _salesSubscription?.cancel();
    _cashShiftsSubscription?.cancel();
    _purchasesSubscription?.cancel();
    _movementsSubscription?.cancel();
    _catalogSubscription = null;
    _salesSubscription = null;
    _cashShiftsSubscription = null;
    _purchasesSubscription = null;
    _movementsSubscription = null;
  }

  void _handleCatalogUpdate(CatalogOverview catalog) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final alerts = _buildProductAlerts(catalog.products);
    state = AsyncData(
      current.copyWith(
        categories: catalog.categories,
        products: catalog.products,
        lowStockProducts: alerts.lowStockProducts,
        expiringProducts: alerts.expiringProducts,
      ),
    );
  }

  void _handleSalesUpdate(List<Sale> sales) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(sales: sales));
  }

  void _handleCashShiftsUpdate(List<CashShift> shifts) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(cashShifts: shifts));
  }

  void _handlePurchasesUpdate(List<Purchase> purchases) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(purchases: purchases));
  }

  void _handleMovementsUpdate(List<InventoryMovement> movements) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(movements: movements));
  }
}

_DashboardProductAlerts _buildProductAlerts(List<Product> products) {
  final today = DateTime.now();
  final lowStockProducts =
      products
          .where((product) => product.stockStore < product.lowStockThreshold)
          .toList();
  final expiringProducts =
      products.where((product) {
        final expiryDate = product.nextExpiryDate;
        if (expiryDate == null) {
          return false;
        }

        final remainingDays = expiryDate.difference(today).inDays;
        return remainingDays <= 14;
      }).toList();

  return _DashboardProductAlerts(
    lowStockProducts: lowStockProducts,
    expiringProducts: expiringProducts,
  );
}

class _DashboardProductAlerts {
  const _DashboardProductAlerts({
    required this.lowStockProducts,
    required this.expiringProducts,
  });

  final List<Product> lowStockProducts;
  final List<Product> expiringProducts;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _currentWeekStart() {
  final today = _dateOnly(DateTime.now());
  return today.subtract(Duration(days: today.weekday - DateTime.monday));
}

DateTime _currentWeekEnd() {
  return _currentWeekStart().add(const Duration(days: 6));
}

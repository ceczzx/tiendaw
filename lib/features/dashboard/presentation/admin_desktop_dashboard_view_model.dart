import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/providers.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';

enum DashboardWindow { today, week, month }

class AdminDesktopDashboardState {
  const AdminDesktopDashboardState({
    required this.sales,
    required this.purchases,
    required this.movements,
    required this.lowStockProducts,
    required this.expiringProducts,
    required this.pendingSyncCount,
    required this.sellerFilter,
    required this.window,
  });

  final List<Sale> sales;
  final List<Purchase> purchases;
  final List<InventoryMovement> movements;
  final List<Product> lowStockProducts;
  final List<Product> expiringProducts;
  final int pendingSyncCount;
  final String sellerFilter;
  final DashboardWindow window;

  List<Sale> get filteredSales {
    final threshold = DateTime.now().subtract(Duration(days: _windowDays));
    return sales.where((sale) {
      final sellerMatches =
          sellerFilter == 'all' || sale.sellerId == sellerFilter;
      return sellerMatches && sale.createdAt.isAfter(threshold);
    }).toList();
  }

  List<Purchase> get filteredPurchases {
    final threshold = DateTime.now().subtract(Duration(days: _windowDays));
    return purchases
        .where((purchase) => purchase.receivedAt.isAfter(threshold))
        .toList();
  }

  List<InventoryMovement> get filteredMovements {
    final threshold = DateTime.now().subtract(Duration(days: _windowDays));
    return movements
        .where((movement) => movement.occurredAt.isAfter(threshold))
        .toList();
  }

  int get _windowDays {
    return switch (window) {
      DashboardWindow.today => 1,
      DashboardWindow.week => 7,
      DashboardWindow.month => 30,
    };
  }

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

  int get movementUnitsTotal => filteredMovements.fold(
    0,
    (sum, movement) => sum + movement.quantity,
  );

  int get movementProductsCount =>
      filteredMovements.map((movement) => movement.productId).toSet().length;

  int get activeAlertCount =>
      lowStockProducts.length + expiringProducts.length;

  List<Map<String, String>> get sellerOptions {
    final sellers = <String, String>{};
    for (final sale in sales) {
      sellers[sale.sellerId] = sale.sellerName;
    }

    return [
      {'id': 'all', 'name': 'Todos'},
      ...sellers.entries.map((entry) => {'id': entry.key, 'name': entry.value}),
    ];
  }

  AdminDesktopDashboardState copyWith({
    List<Sale>? sales,
    List<Purchase>? purchases,
    List<InventoryMovement>? movements,
    List<Product>? lowStockProducts,
    List<Product>? expiringProducts,
    int? pendingSyncCount,
    String? sellerFilter,
    DashboardWindow? window,
  }) {
    return AdminDesktopDashboardState(
      sales: sales ?? this.sales,
      purchases: purchases ?? this.purchases,
      movements: movements ?? this.movements,
      lowStockProducts: lowStockProducts ?? this.lowStockProducts,
      expiringProducts: expiringProducts ?? this.expiringProducts,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      sellerFilter: sellerFilter ?? this.sellerFilter,
      window: window ?? this.window,
    );
  }
}

final adminDesktopDashboardViewModelProvider = AsyncNotifierProvider<
  AdminDesktopDashboardViewModel,
  AdminDesktopDashboardState
>(AdminDesktopDashboardViewModel.new);

class AdminDesktopDashboardViewModel
    extends AsyncNotifier<AdminDesktopDashboardState> {
  @override
  Future<AdminDesktopDashboardState> build() async {
    return _hydrate();
  }

  Future<void> setSellerFilter(String sellerId) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(sellerFilter: sellerId));
  }

  Future<void> setWindow(DashboardWindow window) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(window: window));
  }

  Future<AdminDesktopDashboardState> _hydrate({
    String sellerFilter = 'all',
    DashboardWindow window = DashboardWindow.week,
  }) async {
    final catalog = await ref.read(loadCatalogOverviewUseCaseProvider)();
    final sales = await ref.read(salesRepositoryProvider).getSales();
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
      sales: sales,
      purchases: purchases,
      movements: movements,
      lowStockProducts: lowStockProducts,
      expiringProducts: expiringProducts,
      pendingSyncCount: 0,
      sellerFilter: sellerFilter,
      window: window,
    );
  }
}

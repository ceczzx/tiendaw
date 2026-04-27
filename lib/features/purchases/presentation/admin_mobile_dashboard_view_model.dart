import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/providers.dart';
import 'package:tiendaw/core/sync/sync_status.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/dashboard/presentation/admin_desktop_dashboard_view_model.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:uuid/uuid.dart';

class AdminMobileDashboardState {
  const AdminMobileDashboardState({
    required this.products,
    required this.priceHistory,
    required this.purchases,
    required this.movements,
    required this.selectedProductId,
    required this.quantity,
    required this.unitCost,
    required this.supplier,
    required this.expiryDate,
    this.feedbackMessage,
  });

  final List<Product> products;
  final List<PriceHistoryEntry> priceHistory;
  final List<Purchase> purchases;
  final List<InventoryMovement> movements;
  final String? selectedProductId;
  final int quantity;
  final double unitCost;
  final String supplier;
  final DateTime expiryDate;
  final String? feedbackMessage;

  Product? get selectedProduct {
    if (selectedProductId == null) {
      return null;
    }

    for (final product in products) {
      if (product.id == selectedProductId) {
        return product;
      }
    }
    return null;
  }

  AdminMobileDashboardState copyWith({
    List<Product>? products,
    List<PriceHistoryEntry>? priceHistory,
    List<Purchase>? purchases,
    List<InventoryMovement>? movements,
    String? selectedProductId,
    bool clearSelectedProduct = false,
    int? quantity,
    double? unitCost,
    String? supplier,
    DateTime? expiryDate,
    String? feedbackMessage,
  }) {
    return AdminMobileDashboardState(
      products: products ?? this.products,
      priceHistory: priceHistory ?? this.priceHistory,
      purchases: purchases ?? this.purchases,
      movements: movements ?? this.movements,
      selectedProductId:
          clearSelectedProduct
              ? null
              : selectedProductId ?? this.selectedProductId,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      supplier: supplier ?? this.supplier,
      expiryDate: expiryDate ?? this.expiryDate,
      feedbackMessage: feedbackMessage,
    );
  }
}

final adminMobileDashboardViewModelProvider = AsyncNotifierProvider<
  AdminMobileDashboardViewModel,
  AdminMobileDashboardState
>(AdminMobileDashboardViewModel.new);

class AdminMobileDashboardViewModel
    extends AsyncNotifier<AdminMobileDashboardState> {
  final _uuid = const Uuid();

  @override
  Future<AdminMobileDashboardState> build() async {
    return _hydrate();
  }

  Future<void> selectProduct(String productId) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final product = current.products.firstWhere((item) => item.id == productId);
    state = AsyncData(
      current.copyWith(
        selectedProductId: productId,
        unitCost: product.lastPurchaseCost,
      ),
    );
  }

  Future<void> changeQuantity(int quantity) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(quantity: quantity.clamp(1, 999)));
  }

  Future<void> changeUnitCost(double unitCost) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(unitCost: unitCost));
  }

  Future<void> changeSupplier(String supplier) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(supplier: supplier));
  }

  Future<void> registerPurchase(AppUser user) async {
    final current = state.valueOrNull;
    final selectedProduct = current?.selectedProduct;

    if (current == null || selectedProduct == null) {
      return;
    }

    if (current.supplier.trim().isEmpty) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'Ingresa el nombre del proveedor.'),
      );
      return;
    }

    final purchase = Purchase(
      id: _uuid.v4(),
      supplier: current.supplier.trim(),
      registeredBy: user.name,
      items: [
        PurchaseLine(
          productId: selectedProduct.id,
          productName: selectedProduct.name,
          quantity: current.quantity,
          unitCost: current.unitCost,
          expiryDate: current.expiryDate,
        ),
      ],
      receivedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      syncAttempts: 0,
    );

    try {
      await ref.read(registerPurchaseUseCaseProvider)(purchase);
      await _refreshAll();

      state = AsyncData(
        state.requireValue.copyWith(
          quantity: 1,
          supplier: '',
          feedbackMessage: 'Compra registrada en Supabase.',
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'No se pudo registrar la compra: $error',
        ),
      );
    }
  }

  Future<void> transferToStore(AppUser user) async {
    final current = state.valueOrNull;
    final selectedProduct = current?.selectedProduct;

    if (current == null || selectedProduct == null) {
      return;
    }

    try {
      await ref
          .read(catalogRepositoryProvider)
          .transferWarehouseToStore(
            productId: selectedProduct.id,
            quantity: current.quantity,
            actorName: user.name,
          );

      await _refreshAll();
      state = AsyncData(
        state.requireValue.copyWith(
          feedbackMessage: 'Transferencia registrada en Supabase.',
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'No se pudo mover el stock: $error'),
      );
    }
  }

  Future<AdminMobileDashboardState> _hydrate({
    String? selectedProductId,
    int? quantity,
    double? unitCost,
    String? supplier,
    DateTime? expiryDate,
    String? feedbackMessage,
  }) async {
    final catalog = await ref.read(loadCatalogOverviewUseCaseProvider)();
    final priceHistory =
        await ref.read(catalogRepositoryProvider).getPriceHistory();
    final purchases = await ref.read(purchaseRepositoryProvider).getPurchases();
    final movements =
        await ref.read(catalogRepositoryProvider).getInventoryMovements();

    final productId =
        catalog.products.any((product) => product.id == selectedProductId)
            ? selectedProductId
            : catalog.products.isEmpty
            ? null
            : catalog.products.first.id;
    final selectedProduct =
        productId == null
            ? null
            : catalog.products.firstWhere((product) => product.id == productId);

    return AdminMobileDashboardState(
      products: catalog.products,
      priceHistory: priceHistory,
      purchases: purchases,
      movements: movements,
      selectedProductId: productId,
      quantity: quantity ?? 1,
      unitCost: unitCost ?? selectedProduct?.lastPurchaseCost ?? 0,
      supplier: supplier ?? '',
      expiryDate: expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      feedbackMessage: feedbackMessage,
    );
  }

  Future<void> _refreshAll() async {
    final current = state.valueOrNull;
    state = AsyncData(
      await _hydrate(
        selectedProductId: current?.selectedProductId,
        quantity: current?.quantity,
        unitCost: current?.unitCost,
        supplier: current?.supplier,
        expiryDate: current?.expiryDate,
      ),
    );

    ref.invalidate(adminDesktopDashboardViewModelProvider);
  }
}

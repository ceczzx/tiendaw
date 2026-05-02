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
    required this.categories,
    required this.products,
    required this.priceHistory,
    required this.purchases,
    required this.movements,
    required this.selectedProductId,
    required this.quantity,
    required this.lowStockThreshold,
    required this.unitCost,
    required this.supplier,
    required this.expiryDate,
    this.feedbackMessage,
  });

  final List<Category> categories;
  final List<Product> products;
  final List<PriceHistoryEntry> priceHistory;
  final List<Purchase> purchases;
  final List<InventoryMovement> movements;
  final String? selectedProductId;
  final int quantity;
  final int lowStockThreshold;
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
    List<Category>? categories,
    List<Product>? products,
    List<PriceHistoryEntry>? priceHistory,
    List<Purchase>? purchases,
    List<InventoryMovement>? movements,
    String? selectedProductId,
    bool clearSelectedProduct = false,
    int? quantity,
    int? lowStockThreshold,
    double? unitCost,
    String? supplier,
    DateTime? expiryDate,
    String? feedbackMessage,
  }) {
    return AdminMobileDashboardState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      priceHistory: priceHistory ?? this.priceHistory,
      purchases: purchases ?? this.purchases,
      movements: movements ?? this.movements,
      selectedProductId:
          clearSelectedProduct
              ? null
              : selectedProductId ?? this.selectedProductId,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
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
        lowStockThreshold: product.lowStockThreshold,
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

  Future<void> changeLowStockThreshold(int lowStockThreshold) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(lowStockThreshold: lowStockThreshold.clamp(0, 9999)),
    );
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

  Future<bool> registerPurchase(
    AppUser user, {
    String? categoryName,
    String? productName,
  }) async {
    final current = state.valueOrNull;
    var selectedProduct = current?.selectedProduct;

    if (current == null) {
      return false;
    }

    if (current.supplier.trim().isEmpty) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'Ingresa el nombre del proveedor.'),
      );
      return false;
    }

    final trimmedCategoryName = categoryName?.trim() ?? '';
    final trimmedProductName = productName?.trim() ?? '';

    if (trimmedCategoryName.isNotEmpty || trimmedProductName.isNotEmpty) {
      if (trimmedCategoryName.isEmpty || trimmedProductName.isEmpty) {
        state = AsyncData(
          current.copyWith(
            feedbackMessage:
                'Completa categoria y producto cuando quieras crear uno nuevo.',
          ),
        );
        return false;
      }

      final category = await ref
          .read(catalogRepositoryProvider)
          .ensureCategory(trimmedCategoryName);
      selectedProduct = await ref.read(catalogRepositoryProvider).ensureProduct(
        categoryId: category.id,
        name: trimmedProductName,
        salePrice: current.unitCost,
        lastPurchaseCost: current.unitCost,
        lowStockThreshold: current.lowStockThreshold,
      );
    } else if (selectedProduct != null &&
        selectedProduct.lowStockThreshold != current.lowStockThreshold) {
      await ref
          .read(catalogRepositoryProvider)
          .updateProductLowStockThreshold(
            productId: selectedProduct.id,
            lowStockThreshold: current.lowStockThreshold,
          );
      selectedProduct = selectedProduct.copyWith(
        lowStockThreshold: current.lowStockThreshold,
      );
    }

    if (selectedProduct == null) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'Selecciona un producto o crea uno nuevo.',
        ),
      );
      return false;
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
      await _refreshAll(selectedProductId: selectedProduct.id);

      state = AsyncData(
        state.requireValue.copyWith(
          selectedProductId: selectedProduct.id,
          quantity: 1,
          supplier: '',
          feedbackMessage: 'Compra registrada.',
        ),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'No se pudo registrar la compra: $error',
        ),
      );
      return false;
    }
  }

  Future<bool> transferToStore(AppUser user) async {
    final current = state.valueOrNull;
    final selectedProduct = current?.selectedProduct;

    if (current == null || selectedProduct == null) {
      return false;
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
          feedbackMessage: 'Transferencia registrada.',
        ),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'No se pudo mover el stock: $error'),
      );
      return false;
    }
  }

  Future<AdminMobileDashboardState> _hydrate({
    String? selectedProductId,
    int? quantity,
    int? lowStockThreshold,
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
      categories: catalog.categories,
      products: catalog.products,
      priceHistory: priceHistory,
      purchases: purchases,
      movements: movements,
      selectedProductId: productId,
      quantity: quantity ?? 1,
      lowStockThreshold:
          lowStockThreshold ?? selectedProduct?.lowStockThreshold ?? 20,
      unitCost: unitCost ?? selectedProduct?.lastPurchaseCost ?? 0,
      supplier: supplier ?? '',
      expiryDate: expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      feedbackMessage: feedbackMessage,
    );
  }

  Future<void> _refreshAll({String? selectedProductId}) async {
    final current = state.valueOrNull;
    state = AsyncData(
      await _hydrate(
        selectedProductId: selectedProductId ?? current?.selectedProductId,
        quantity: current?.quantity,
        lowStockThreshold: current?.lowStockThreshold,
        unitCost: current?.unitCost,
        supplier: current?.supplier,
        expiryDate: current?.expiryDate,
      ),
    );

    ref.invalidate(adminDesktopDashboardViewModelProvider);
  }
}

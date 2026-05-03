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
    required this.unitsPerPackage,
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
  final int unitsPerPackage;
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
    int? unitsPerPackage,
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
      unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
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
        unitsPerPackage: product.unitsPerPackage,
        lowStockThreshold: product.lowStockThreshold,
        unitCost: product.lastPurchaseCost,
        expiryDate: _defaultExpiryDate(product.nextExpiryDate),
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

  Future<void> changeUnitsPerPackage(int unitsPerPackage) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(unitsPerPackage: unitsPerPackage.clamp(1, 9999)),
    );
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

  Future<void> changeExpiryDate(DateTime expiryDate) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(expiryDate: _dateOnly(expiryDate)));
  }

  Future<void> changeSupplier(String supplier) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(supplier: supplier));
  }

  Future<void> clearFeedback() async {
    final current = state.valueOrNull;
    if (current == null || current.feedbackMessage == null) {
      return;
    }

    state = AsyncData(current.copyWith(feedbackMessage: null));
  }

  Future<bool> registerPurchase(
    AppUser user, {
    String? categoryName,
    String? categoryPrefix,
    String? productName,
    String? productType,
    double? salePrice,
    Map<String, dynamic>? productCostDetails,
    String? supplierPhone,
  }) async {
    final current = state.valueOrNull;
    var selectedProduct = current?.selectedProduct;

    if (current == null) {
      return false;
    }

    final trimmedCategoryName = categoryName?.trim() ?? '';
    final trimmedCategoryPrefix = categoryPrefix?.trim().toUpperCase() ?? '';
    final trimmedProductName = productName?.trim() ?? '';
    final resolvedProductType = _normalizeProductType(
      productType ?? selectedProduct?.productType,
    );
    final resolvedSalePrice = salePrice ?? selectedProduct?.salePrice ?? 0;
    final resolvedCostDetails =
        productCostDetails ??
        selectedProduct?.costDetails ??
        const <String, dynamic>{};
    final resolvedSpecs = _buildProductSpecs(
      productType: resolvedProductType,
      costDetails: resolvedCostDetails,
    );
    final requiresSupplier = resolvedProductType == 'proveedor';

    if (requiresSupplier && current.supplier.trim().isEmpty) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'Ingresa el nombre del proveedor.'),
      );
      return false;
    }

    if (trimmedCategoryName.isNotEmpty || trimmedProductName.isNotEmpty) {
      if (trimmedCategoryName.isEmpty ||
          trimmedCategoryPrefix.isEmpty ||
          trimmedProductName.isEmpty) {
        state = AsyncData(
          current.copyWith(
            feedbackMessage:
                'Completa categoria, prefix y producto cuando quieras crear uno nuevo.',
          ),
        );
        return false;
      }

      final category = await ref
          .read(catalogRepositoryProvider)
          .ensureCategory(
            name: trimmedCategoryName,
            prefix: trimmedCategoryPrefix,
          );
      selectedProduct = await ref.read(catalogRepositoryProvider).ensureProduct(
        categoryId: category.id,
        name: trimmedProductName,
        productType: resolvedProductType,
        salePrice: resolvedSalePrice,
        lastPurchaseCost: current.unitCost,
        lowStockThreshold: current.lowStockThreshold,
        unitsPerPackage: current.unitsPerPackage,
        costDetails: resolvedCostDetails,
        specs: resolvedSpecs,
      );
    } else if (selectedProduct != null) {
      await ref.read(catalogRepositoryProvider).updateProductCatalogData(
        productId: selectedProduct.id,
        productType: resolvedProductType,
        salePrice: resolvedSalePrice,
        lastPurchaseCost: current.unitCost,
        unitsPerPackage: current.unitsPerPackage,
        costDetails: resolvedCostDetails,
        specs: resolvedSpecs,
      );
      if (selectedProduct.lowStockThreshold != current.lowStockThreshold) {
        await ref
            .read(catalogRepositoryProvider)
            .updateProductLowStockThreshold(
              productId: selectedProduct.id,
              lowStockThreshold: current.lowStockThreshold,
            );
      }
      if (selectedProduct.unitsPerPackage != current.unitsPerPackage) {
        await ref
            .read(catalogRepositoryProvider)
            .updateProductUnitsPerPackage(
              productId: selectedProduct.id,
              unitsPerPackage: current.unitsPerPackage,
            );
      }
      selectedProduct = selectedProduct.copyWith(
        productType: resolvedProductType,
        salePrice: resolvedSalePrice,
        lastPurchaseCost: current.unitCost,
        lowStockThreshold: current.lowStockThreshold,
        unitsPerPackage: current.unitsPerPackage,
        costDetails: resolvedCostDetails,
        specs: resolvedSpecs,
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
      supplier: requiresSupplier ? current.supplier.trim() : '',
      supplierPhone:
          requiresSupplier
              ? _normalizeSupplierPhone(supplierPhone)
              : null,
      registeredBy: user.name,
      items: [
        PurchaseLine(
          productId: selectedProduct.id,
          productName: selectedProduct.name,
          quantity: current.quantity,
          unitsPerPackage: current.unitsPerPackage,
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
      final refreshed = state.requireValue;

      state = AsyncData(
        refreshed.copyWith(
          clearSelectedProduct: true,
          quantity: 1,
          unitsPerPackage: 1,
          lowStockThreshold: 20,
          unitCost: 0,
          supplier: '',
          expiryDate: _defaultExpiryDate(null),
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
      final refreshed = state.requireValue;
      state = AsyncData(
        refreshed.copyWith(
          clearSelectedProduct: true,
          quantity: 1,
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
    int? unitsPerPackage,
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
      unitsPerPackage: unitsPerPackage ?? selectedProduct?.unitsPerPackage ?? 1,
      lowStockThreshold:
          lowStockThreshold ?? selectedProduct?.lowStockThreshold ?? 20,
      unitCost: unitCost ?? selectedProduct?.lastPurchaseCost ?? 0,
      supplier: supplier ?? '',
      expiryDate: expiryDate ?? _defaultExpiryDate(selectedProduct?.nextExpiryDate),
      feedbackMessage: feedbackMessage,
    );
  }

  Future<void> _refreshAll({String? selectedProductId}) async {
    final current = state.valueOrNull;
    state = AsyncData(
      await _hydrate(
        selectedProductId: selectedProductId ?? current?.selectedProductId,
        quantity: current?.quantity,
        unitsPerPackage: current?.unitsPerPackage,
        lowStockThreshold: current?.lowStockThreshold,
        unitCost: current?.unitCost,
        supplier: current?.supplier,
        expiryDate: current?.expiryDate,
      ),
    );

    ref.invalidate(adminDesktopDashboardViewModelProvider);
  }

  DateTime _defaultExpiryDate(DateTime? value) {
    return _dateOnly(value ?? DateTime.now().add(const Duration(days: 30)));
  }
}

String _normalizeProductType(String? rawType) {
  final normalized = rawType?.trim().toLowerCase();
  if (normalized == 'artesanal') {
    return 'artesanal';
  }

  return 'proveedor';
}

String? _normalizeSupplierPhone(String? rawPhone) {
  final normalized = rawPhone?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

Map<String, dynamic> _buildProductSpecs({
  required String productType,
  required Map<String, dynamic> costDetails,
}) {
  final specs = <String, dynamic>{'tipo': productType};
  if (productType == 'artesanal') {
    final notes =
        costDetails['observaciones_producto']?.toString().trim() ?? '';
    if (notes.isNotEmpty) {
      specs['observaciones'] = notes;
    }
    return specs;
  }

  final brand = costDetails['marca']?.toString().trim() ?? '';
  final presentation = costDetails['presentacion']?.toString().trim() ?? '';

  if (brand.isNotEmpty) {
    specs['marca'] = brand;
  }
  if (presentation.isNotEmpty) {
    specs['presentacion'] = presentation;
  }

  return specs;
}

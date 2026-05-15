import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/providers.dart';
import 'package:tiendaw/core/sync/sync_status.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/load_catalog_overview_use_case.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:uuid/uuid.dart';

class PurchaseDraftLine {
  const PurchaseDraftLine({
    this.categoryId,
    this.categoryName,
    this.categoryPrefix,
    this.productId,
    required this.productName,
    required this.productType,
    required this.quantity,
    required this.unitsPerPackage,
    required this.lowStockThreshold,
    required this.unitCost,
    required this.salePrice,
    required this.productCostDetails,
    required this.supplier,
    this.supplierPhone,
    required this.expiryDate,
  });

  final String? categoryId;
  final String? categoryName;
  final String? categoryPrefix;
  final String? productId;
  final String productName;
  final String productType;
  final int quantity;
  final int unitsPerPackage;
  final int lowStockThreshold;
  final double unitCost;
  final double salePrice;
  final Map<String, dynamic> productCostDetails;
  final String supplier;
  final String? supplierPhone;
  final DateTime expiryDate;

  int get totalUnits => quantity * unitsPerPackage;

  double get subtotal => totalUnits * unitCost;

  bool get requiresSupplier => _normalizeProductType(productType) == 'proveedor';
}

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
    required this.purchaseDraftItems,
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
  final List<PurchaseDraftLine> purchaseDraftItems;
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

  String get purchaseDraftSupplier {
    if (purchaseDraftItems.isEmpty) {
      return '';
    }

    return purchaseDraftItems.first.supplier.trim();
  }

  String? get purchaseDraftSupplierPhone {
    if (purchaseDraftItems.isEmpty) {
      return null;
    }

    return purchaseDraftItems.first.supplierPhone;
  }

  int get purchaseDraftUnits {
    return purchaseDraftItems.fold(0, (sum, item) => sum + item.totalUnits);
  }

  double get purchaseDraftTotal {
    return purchaseDraftItems.fold(0, (sum, item) => sum + item.subtotal);
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
    List<PurchaseDraftLine>? purchaseDraftItems,
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
      purchaseDraftItems: purchaseDraftItems ?? this.purchaseDraftItems,
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
  StreamSubscription<CatalogOverview>? _catalogSubscription;
  StreamSubscription<List<PriceHistoryEntry>>? _priceHistorySubscription;
  StreamSubscription<List<Purchase>>? _purchasesSubscription;
  StreamSubscription<List<InventoryMovement>>? _movementsSubscription;

  @override
  Future<AdminMobileDashboardState> build() async {
    ref.onDispose(_disposeRealtimeSubscriptions);
    final hydrated = await _hydrate();
    _bindRealtime();
    return hydrated;
  }

  Future<void> selectProduct(String productId) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    Product? product;
    for (final item in current.products) {
      if (item.id == productId) {
        product = item;
        break;
      }
    }
    if (product == null) {
      return;
    }

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

  Future<void> clearSelectedProduct() async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        clearSelectedProduct: true,
        quantity: 1,
        unitsPerPackage: 1,
        unitCost: 0,
        supplier: '',
        expiryDate: _defaultExpiryDate(null),
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

  Future<bool> addPurchaseDraftLine(PurchaseDraftLine line) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (line.requiresSupplier && line.supplier.trim().isEmpty) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'Ingresa el nombre del proveedor.'),
      );
      return false;
    }

    if (current.purchaseDraftItems.isNotEmpty) {
      final firstLine = current.purchaseDraftItems.first;
      final currentSupplier = firstLine.supplier.trim();
      final nextSupplier = line.supplier.trim();
      final currentRequiresSupplier = firstLine.requiresSupplier;
      if (currentRequiresSupplier != line.requiresSupplier ||
          currentSupplier != nextSupplier) {
        final supplierLabel =
            currentSupplier.isEmpty ? 'produccion artesanal' : currentSupplier;
        state = AsyncData(
          current.copyWith(
            feedbackMessage:
                'Esta compra ya esta asociada a $supplierLabel. Usa el mismo proveedor o registra otra compra.',
          ),
        );
        return false;
      }
    }

    state = AsyncData(
      current.copyWith(
        purchaseDraftItems: [...current.purchaseDraftItems, line],
        feedbackMessage: null,
      ),
    );
    return true;
  }

  Future<void> removePurchaseDraftLine(int index) async {
    final current = state.valueOrNull;
    if (current == null ||
        index < 0 ||
        index >= current.purchaseDraftItems.length) {
      return;
    }

    final next = [...current.purchaseDraftItems]..removeAt(index);
    state = AsyncData(current.copyWith(purchaseDraftItems: next));
  }

  Future<void> clearPurchaseDraft() async {
    final current = state.valueOrNull;
    if (current == null || current.purchaseDraftItems.isEmpty) {
      return;
    }

    state = AsyncData(current.copyWith(purchaseDraftItems: const []));
  }

  Future<bool> registerPurchaseCart(AppUser user) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (current.purchaseDraftItems.isEmpty) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'Agrega al menos un producto antes de registrar la compra.',
        ),
      );
      return false;
    }

    try {
      final purchaseItems = <PurchaseLine>[];
      for (final draft in current.purchaseDraftItems) {
        final product = await _resolvePurchaseDraftProduct(draft, current);
        purchaseItems.add(
          PurchaseLine(
            productId: product.id,
            productName: product.name,
            quantity: draft.quantity,
            unitsPerPackage: draft.unitsPerPackage,
            unitCost: draft.unitCost,
            expiryDate: draft.expiryDate,
          ),
        );
      }

      final draftSupplier = current.purchaseDraftSupplier;
      final purchase = Purchase(
        id: _uuid.v4(),
        supplier: draftSupplier,
        supplierId: null,
        supplierPhone:
            draftSupplier.isEmpty
                ? null
                : _normalizeSupplierPhone(current.purchaseDraftSupplierPhone),
        registeredBy: user.name,
        items: purchaseItems,
        receivedAt: DateTime.now(),
        syncStatus: SyncStatus.synced,
        syncAttempts: 0,
      );

      await ref.read(registerPurchaseUseCaseProvider)(purchase);
      await _refreshAll(selectedProductId: current.selectedProductId);
      final refreshed = state.requireValue;

      state = AsyncData(
        refreshed.copyWith(
          purchaseDraftItems: const [],
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

  Future<bool> transferToStore({String? supplierId}) async {
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
            supplierId: supplierId,
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
      expiryDate:
          expiryDate ?? _defaultExpiryDate(selectedProduct?.nextExpiryDate),
      purchaseDraftItems: const [],
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
        feedbackMessage: current?.feedbackMessage,
      ),
    );
  }

  DateTime _defaultExpiryDate(DateTime? value) {
    return _dateOnly(value ?? DateTime.now().add(const Duration(days: 30)));
  }

  Future<Product> _resolvePurchaseDraftProduct(
    PurchaseDraftLine draft,
    AdminMobileDashboardState current,
  ) async {
    final repository = ref.read(catalogRepositoryProvider);
    final resolvedProductType = _normalizeProductType(draft.productType);
    final resolvedCostDetails = _normalizeCostDetails(
      productType: resolvedProductType,
      costDetails: draft.productCostDetails,
    );

    if (draft.productId == null) {
      final resolvedCategoryId =
          draft.categoryId ??
          (await repository.ensureCategory(
            name: draft.categoryName?.trim() ?? '',
            prefix: draft.categoryPrefix?.trim().toUpperCase() ?? '',
          ))
              .id;

      return repository.ensureProduct(
        categoryId: resolvedCategoryId,
        name: draft.productName,
        productType: resolvedProductType,
        salePrice: draft.salePrice,
        lastPurchaseCost: draft.unitCost,
        lowStockThreshold: draft.lowStockThreshold,
        unitsPerPackage: draft.unitsPerPackage,
        costDetails: resolvedCostDetails,
      );
    }

    final selectedProduct = _findProductByIdInList(
      current.products,
      draft.productId!,
    );
    if (selectedProduct == null) {
      throw StateError(
        'El producto ${draft.productName} ya no esta disponible para esta compra.',
      );
    }

    await repository.updateProductCatalogData(
      productId: selectedProduct.id,
      productType: resolvedProductType,
      salePrice: draft.salePrice,
      lastPurchaseCost: draft.unitCost,
      unitsPerPackage: draft.unitsPerPackage,
      costDetails: resolvedCostDetails,
    );
    if (selectedProduct.lowStockThreshold != draft.lowStockThreshold) {
      await repository.updateProductLowStockThreshold(
        productId: selectedProduct.id,
        lowStockThreshold: draft.lowStockThreshold,
      );
    }
    if (selectedProduct.unitsPerPackage != draft.unitsPerPackage) {
      await repository.updateProductUnitsPerPackage(
        productId: selectedProduct.id,
        unitsPerPackage: draft.unitsPerPackage,
      );
    }

    return selectedProduct.copyWith(
      productType: resolvedProductType,
      salePrice: draft.salePrice,
      lastPurchaseCost: draft.unitCost,
      lowStockThreshold: draft.lowStockThreshold,
      unitsPerPackage: draft.unitsPerPackage,
      costDetails: resolvedCostDetails,
    );
  }

  void _bindRealtime() {
    _disposeRealtimeSubscriptions();

    _catalogSubscription = ref.read(loadCatalogOverviewUseCaseProvider).watch().listen(
      _handleCatalogUpdate,
      onError: (_, __) {},
    );
    _priceHistorySubscription = ref
        .read(catalogRepositoryProvider)
        .watchPriceHistory()
        .listen(_handlePriceHistoryUpdate, onError: (_, __) {});
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
    _priceHistorySubscription?.cancel();
    _purchasesSubscription?.cancel();
    _movementsSubscription?.cancel();
    _catalogSubscription = null;
    _priceHistorySubscription = null;
    _purchasesSubscription = null;
    _movementsSubscription = null;
  }

  void _handleCatalogUpdate(CatalogOverview catalog) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final nextSelectedProductId = _resolveSelectedProductId(
      products: catalog.products,
      requestedProductId: current.selectedProductId,
    );
    final selectedProduct =
        nextSelectedProductId == null
            ? null
            : _findProductByIdInList(catalog.products, nextSelectedProductId);
    final selectionChanged = nextSelectedProductId != current.selectedProductId;

    state = AsyncData(
      current.copyWith(
        categories: catalog.categories,
        products: catalog.products,
        selectedProductId: nextSelectedProductId,
        clearSelectedProduct: nextSelectedProductId == null,
        unitsPerPackage:
            selectionChanged
                ? selectedProduct?.unitsPerPackage ?? 1
                : current.unitsPerPackage,
        lowStockThreshold:
            selectionChanged
                ? selectedProduct?.lowStockThreshold ?? 20
                : current.lowStockThreshold,
        unitCost:
            selectionChanged
                ? selectedProduct?.lastPurchaseCost ?? 0
                : current.unitCost,
        expiryDate:
            selectionChanged
                ? _defaultExpiryDate(selectedProduct?.nextExpiryDate)
                : current.expiryDate,
      ),
    );
  }

  void _handlePriceHistoryUpdate(List<PriceHistoryEntry> entries) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(priceHistory: entries));
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

String? _resolveSelectedProductId({
  required List<Product> products,
  required String? requestedProductId,
}) {
  if (requestedProductId != null &&
      products.any((product) => product.id == requestedProductId)) {
    return requestedProductId;
  }
  if (products.isEmpty) {
    return null;
  }
  return products.first.id;
}

Product? _findProductByIdInList(List<Product> products, String productId) {
  for (final product in products) {
    if (product.id == productId) {
      return product;
    }
  }

  return null;
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

Map<String, dynamic> _normalizeCostDetails({
  required String productType,
  required Map<String, dynamic> costDetails,
}) {
  final normalized = Map<String, dynamic>.from(costDetails);
  normalized['tipo'] = productType;
  if (productType == 'artesanal') {
    final notes = normalized['observaciones_producto']?.toString().trim() ?? '';
    final existingNotes = normalized['observaciones']?.toString().trim() ?? '';
    if (notes.isNotEmpty && existingNotes.isEmpty) {
      normalized['observaciones'] = notes;
    }
  }

  return normalized;
}

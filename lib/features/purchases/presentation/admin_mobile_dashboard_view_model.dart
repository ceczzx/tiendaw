// ignore_for_file: unused_element

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

  bool get requiresSupplier =>
      _normalizeProductType(productType) == 'proveedor';
}

class MovementDraftLine {
  const MovementDraftLine({
    required this.purchaseItemId,
    required this.productId,
    required this.productName,
    this.supplierId,
    required this.supplierName,
    required this.quantity,
    required this.availableUnits,
    required this.receivedAt,
    this.expiryDate,
    this.isPromotionPriority = false,
    this.promotionId,
    this.promotionStatus,
    this.promotionalPrice,
    this.promotionNote,
  });

  final String purchaseItemId;
  final String productId;
  final String productName;
  final String? supplierId;
  final String supplierName;
  final int quantity;
  final int availableUnits;
  final DateTime receivedAt;
  final DateTime? expiryDate;
  final bool isPromotionPriority;
  final String? promotionId;
  final String? promotionStatus;
  final double? promotionalPrice;
  final String? promotionNote;
}

class AdminMobileDashboardState {
  const AdminMobileDashboardState({
    required this.categories,
    required this.products,
    required this.promotableLots,
    required this.activeLotPromotions,
    required this.promotionNotices,
    required this.priceHistory,
    required this.purchases,
    required this.movements,
    required this.expiringLotAlerts,
    required this.expiredLotAlerts,
    required this.selectedProductId,
    required this.quantity,
    required this.unitsPerPackage,
    required this.lowStockThreshold,
    required this.unitCost,
    required this.supplier,
    required this.expiryDate,
    required this.purchaseDraftItems,
    required this.movementDraftItems,
    this.feedbackMessage,
  });

  final List<Category> categories;
  final List<Product> products;
  final List<PromotableLot> promotableLots;
  final List<LotPromotion> activeLotPromotions;
  final List<PromotionNotice> promotionNotices;
  final List<PriceHistoryEntry> priceHistory;
  final List<Purchase> purchases;
  final List<InventoryMovement> movements;
  final List<InventoryLotAlert> expiringLotAlerts;
  final List<InventoryLotAlert> expiredLotAlerts;
  final String? selectedProductId;
  final int quantity;
  final int unitsPerPackage;
  final int lowStockThreshold;
  final double unitCost;
  final String supplier;
  final DateTime expiryDate;
  final List<PurchaseDraftLine> purchaseDraftItems;
  final List<MovementDraftLine> movementDraftItems;
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

  int get movementDraftUnits {
    return movementDraftItems.fold(0, (sum, item) => sum + item.quantity);
  }

  AdminMobileDashboardState copyWith({
    List<Category>? categories,
    List<Product>? products,
    List<PromotableLot>? promotableLots,
    List<LotPromotion>? activeLotPromotions,
    List<PromotionNotice>? promotionNotices,
    List<PriceHistoryEntry>? priceHistory,
    List<Purchase>? purchases,
    List<InventoryMovement>? movements,
    List<InventoryLotAlert>? expiringLotAlerts,
    List<InventoryLotAlert>? expiredLotAlerts,
    String? selectedProductId,
    bool clearSelectedProduct = false,
    int? quantity,
    int? unitsPerPackage,
    int? lowStockThreshold,
    double? unitCost,
    String? supplier,
    DateTime? expiryDate,
    List<PurchaseDraftLine>? purchaseDraftItems,
    List<MovementDraftLine>? movementDraftItems,
    String? feedbackMessage,
  }) {
    return AdminMobileDashboardState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      promotableLots: promotableLots ?? this.promotableLots,
      activeLotPromotions: activeLotPromotions ?? this.activeLotPromotions,
      promotionNotices: promotionNotices ?? this.promotionNotices,
      priceHistory: priceHistory ?? this.priceHistory,
      purchases: purchases ?? this.purchases,
      movements: movements ?? this.movements,
      expiringLotAlerts: expiringLotAlerts ?? this.expiringLotAlerts,
      expiredLotAlerts: expiredLotAlerts ?? this.expiredLotAlerts,
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
      movementDraftItems: movementDraftItems ?? this.movementDraftItems,
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
  StreamSubscription<List<PromotableLot>>? _promotableLotsSubscription;
  StreamSubscription<List<LotPromotion>>? _activeLotPromotionsSubscription;
  StreamSubscription<List<PromotionNotice>>? _promotionNoticesSubscription;
  StreamSubscription<List<PriceHistoryEntry>>? _priceHistorySubscription;
  StreamSubscription<List<Purchase>>? _purchasesSubscription;
  StreamSubscription<List<InventoryMovement>>? _movementsSubscription;
  StreamSubscription<List<InventoryLotAlert>>? _expiringLotAlertsSubscription;
  StreamSubscription<List<InventoryLotAlert>>? _expiredLotAlertsSubscription;

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

  Future<bool> activateLotPromotion({
    required String purchaseItemId,
    required int promotionalQuantity,
    required double promotionalPrice,
    String? promotionNote,
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    try {
      await ref
          .read(catalogRepositoryProvider)
          .activateLotPromotion(
            purchaseItemId: purchaseItemId,
            promotionalQuantity: promotionalQuantity,
            promotionalPrice: promotionalPrice,
            promotionNote: promotionNote,
          );
      await _refreshAll(selectedProductId: current.selectedProductId);
      state = AsyncData(
        state.requireValue.copyWith(
          feedbackMessage: 'Promocion por lote actualizada.',
        ),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'No se pudo guardar la promocion: $error',
        ),
      );
      return false;
    }
  }

  Future<bool> cancelLotPromotion(String promotionId) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    try {
      await ref
          .read(catalogRepositoryProvider)
          .cancelLotPromotion(promotionId: promotionId);
      await _refreshAll(selectedProductId: current.selectedProductId);
      state = AsyncData(
        state.requireValue.copyWith(feedbackMessage: 'Promocion retirada.'),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'No se pudo retirar la promocion: $error',
        ),
      );
      return false;
    }
  }

  Future<bool> updateProductColdState({
    required String productId,
    required int coldStockUnits,
    required double coldPriceIncrement,
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    try {
      await ref
          .read(catalogRepositoryProvider)
          .updateProductColdState(
            productId: productId,
            coldStockUnits: coldStockUnits,
            coldPriceIncrement: coldPriceIncrement,
          );
      await _refreshAll(selectedProductId: productId);
      state = AsyncData(
        state.requireValue.copyWith(
          feedbackMessage: 'Bebida helada actualizada.',
        ),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'No se pudo actualizar el estado helado: $error',
        ),
      );
      return false;
    }
  }

  Future<bool> registerInventoryLoss({
    required String purchaseItemId,
    required int quantity,
    String? notes,
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    try {
      await ref
          .read(catalogRepositoryProvider)
          .registerInventoryLoss(
            purchaseItemId: purchaseItemId,
            quantity: quantity,
            notes: notes,
          );
      await _refreshAll(selectedProductId: current.selectedProductId);
      state = AsyncData(
        state.requireValue.copyWith(feedbackMessage: 'Perdida registrada.'),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'No se pudo registrar la perdida: $error',
        ),
      );
      return false;
    }
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

  Future<bool> addMovementDraftLine(MovementDraftLine line) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (line.quantity <= 0) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'La cantidad del movimiento debe ser mayor a cero.',
        ),
      );
      return false;
    }
    if (line.quantity > line.availableUnits) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage:
              'El lote seleccionado solo tiene ${line.availableUnits} unidades disponibles.',
        ),
      );
      return false;
    }

    final nextItems = [...current.movementDraftItems];
    final existingIndex = nextItems.indexWhere(
      (item) => item.purchaseItemId == line.purchaseItemId,
    );
    if (existingIndex >= 0) {
      final existing = nextItems[existingIndex];
      final mergedQuantity = existing.quantity + line.quantity;
      if (mergedQuantity > line.availableUnits) {
        state = AsyncData(
          current.copyWith(
            feedbackMessage:
                'Ese lote ya tiene ${existing.quantity} unidades en la lista y solo permite ${line.availableUnits} en total.',
          ),
        );
        return false;
      }
      nextItems[existingIndex] = MovementDraftLine(
        purchaseItemId: existing.purchaseItemId,
        productId: existing.productId,
        productName: existing.productName,
        supplierId: existing.supplierId,
        supplierName: existing.supplierName,
        quantity: mergedQuantity,
        availableUnits: existing.availableUnits,
        receivedAt: existing.receivedAt,
        expiryDate: existing.expiryDate,
        isPromotionPriority: existing.isPromotionPriority,
        promotionId: existing.promotionId,
        promotionStatus: existing.promotionStatus,
        promotionalPrice: existing.promotionalPrice,
        promotionNote: existing.promotionNote,
      );
    } else {
      nextItems.add(line);
    }

    state = AsyncData(
      current.copyWith(movementDraftItems: nextItems, feedbackMessage: null),
    );
    return true;
  }

  Future<void> removeMovementDraftLine(int index) async {
    final current = state.valueOrNull;
    if (current == null ||
        index < 0 ||
        index >= current.movementDraftItems.length) {
      return;
    }

    final next = [...current.movementDraftItems]..removeAt(index);
    state = AsyncData(current.copyWith(movementDraftItems: next));
  }

  Future<void> clearMovementDraft() async {
    final current = state.valueOrNull;
    if (current == null || current.movementDraftItems.isEmpty) {
      return;
    }

    state = AsyncData(current.copyWith(movementDraftItems: const []));
  }

  Future<bool> registerPurchaseCart(AppUser user) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (current.purchaseDraftItems.isEmpty) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage:
              'Agrega al menos un producto antes de registrar la compra.',
        ),
      );
      return false;
    }

    try {
      final purchaseItems = <PurchaseLine>[];
      for (final draft in current.purchaseDraftItems) {
        purchaseItems.add(
          PurchaseLine(
            productId: draft.productId ?? '',
            productName: draft.productName,
            categoryId: draft.categoryId,
            sku: null,
            productType: draft.productType,
            lowStockThreshold: draft.lowStockThreshold,
            salePrice: draft.salePrice,
            productCostDetails: draft.productCostDetails,
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

  Future<bool> registerMovementCart() async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (current.movementDraftItems.isEmpty) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage:
              'Agrega al menos un movimiento antes de registrar el traslado.',
        ),
      );
      return false;
    }

    final pendingDrafts = [...current.movementDraftItems];
    var completedCount = 0;

    try {
      for (final draft in current.movementDraftItems) {
        await ref
            .read(catalogRepositoryProvider)
            .transferWarehouseToStore(
              productId: draft.productId,
              quantity: draft.quantity,
              supplierId: draft.supplierId,
              purchaseItemId: draft.purchaseItemId,
              notes: _movementDraftNote(draft),
            );
        pendingDrafts.removeAt(0);
        completedCount += 1;
      }

      await _refreshAll(
        movementDraftItems: const [],
        purchaseDraftItems: current.purchaseDraftItems,
      );
      final refreshed = state.requireValue;
      state = AsyncData(
        refreshed.copyWith(
          movementDraftItems: const [],
          clearSelectedProduct: true,
          quantity: 1,
          feedbackMessage: 'Movimientos registrados.',
        ),
      );
      return true;
    } catch (error) {
      await _refreshAll(
        movementDraftItems: pendingDrafts,
        purchaseDraftItems: current.purchaseDraftItems,
      );
      final refreshed = state.requireValue;
      final message =
          completedCount > 0
              ? 'Se registraron $completedCount movimientos antes del error: $error'
              : 'No se pudo mover el stock: $error';
      state = AsyncData(
        refreshed.copyWith(
          movementDraftItems: pendingDrafts,
          feedbackMessage: message,
        ),
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
    List<PurchaseDraftLine>? purchaseDraftItems,
    List<MovementDraftLine>? movementDraftItems,
    String? feedbackMessage,
  }) async {
    final catalog = await ref.read(loadCatalogOverviewUseCaseProvider)();
    final promotableLots =
        await ref.read(catalogRepositoryProvider).getPromotableLots();
    final activeLotPromotions =
        await ref.read(catalogRepositoryProvider).getActiveLotPromotions();
    final promotionNotices =
        await ref.read(catalogRepositoryProvider).getPromotionNotices();
    final priceHistory =
        await ref.read(catalogRepositoryProvider).getPriceHistory();
    final purchases = await ref.read(purchaseRepositoryProvider).getPurchases();
    final movements =
        await ref.read(catalogRepositoryProvider).getInventoryMovements();
    final expiringLotAlerts =
        await ref.read(catalogRepositoryProvider).getInventoryLotAlerts();
    final expiredLotAlerts = await ref
        .read(catalogRepositoryProvider)
        .getInventoryLotAlerts(expiredOnly: true);

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
      promotableLots: promotableLots,
      activeLotPromotions: activeLotPromotions,
      promotionNotices: promotionNotices,
      priceHistory: priceHistory,
      purchases: purchases,
      movements: movements,
      expiringLotAlerts: expiringLotAlerts,
      expiredLotAlerts: expiredLotAlerts,
      selectedProductId: productId,
      quantity: quantity ?? 1,
      unitsPerPackage: unitsPerPackage ?? selectedProduct?.unitsPerPackage ?? 1,
      lowStockThreshold:
          lowStockThreshold ?? selectedProduct?.lowStockThreshold ?? 20,
      unitCost: unitCost ?? selectedProduct?.lastPurchaseCost ?? 0,
      supplier: supplier ?? '',
      expiryDate:
          expiryDate ?? _defaultExpiryDate(selectedProduct?.nextExpiryDate),
      purchaseDraftItems: purchaseDraftItems ?? const [],
      movementDraftItems: movementDraftItems ?? const [],
      feedbackMessage: feedbackMessage,
    );
  }

  Future<void> _refreshAll({
    String? selectedProductId,
    List<PurchaseDraftLine>? purchaseDraftItems,
    List<MovementDraftLine>? movementDraftItems,
  }) async {
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
        purchaseDraftItems: purchaseDraftItems ?? current?.purchaseDraftItems,
        movementDraftItems: movementDraftItems ?? current?.movementDraftItems,
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
          )).id;

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

    _catalogSubscription = ref
        .read(loadCatalogOverviewUseCaseProvider)
        .watch()
        .listen(_handleCatalogUpdate, onError: (_, __) {});
    _promotableLotsSubscription = ref
        .read(catalogRepositoryProvider)
        .watchPromotableLots()
        .listen(_handlePromotableLotsUpdate, onError: (_, __) {});
    _activeLotPromotionsSubscription = ref
        .read(catalogRepositoryProvider)
        .watchActiveLotPromotions()
        .listen(_handleActiveLotPromotionsUpdate, onError: (_, __) {});
    _promotionNoticesSubscription = ref
        .read(catalogRepositoryProvider)
        .watchPromotionNotices()
        .listen(_handlePromotionNoticesUpdate, onError: (_, __) {});
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
    _expiringLotAlertsSubscription = ref
        .read(catalogRepositoryProvider)
        .watchInventoryLotAlerts()
        .listen(_handleExpiringLotAlertsUpdate, onError: (_, __) {});
    _expiredLotAlertsSubscription = ref
        .read(catalogRepositoryProvider)
        .watchInventoryLotAlerts(expiredOnly: true)
        .listen(_handleExpiredLotAlertsUpdate, onError: (_, __) {});
  }

  void _disposeRealtimeSubscriptions() {
    _catalogSubscription?.cancel();
    _promotableLotsSubscription?.cancel();
    _activeLotPromotionsSubscription?.cancel();
    _promotionNoticesSubscription?.cancel();
    _priceHistorySubscription?.cancel();
    _purchasesSubscription?.cancel();
    _movementsSubscription?.cancel();
    _expiringLotAlertsSubscription?.cancel();
    _expiredLotAlertsSubscription?.cancel();
    _catalogSubscription = null;
    _promotableLotsSubscription = null;
    _activeLotPromotionsSubscription = null;
    _promotionNoticesSubscription = null;
    _priceHistorySubscription = null;
    _purchasesSubscription = null;
    _movementsSubscription = null;
    _expiringLotAlertsSubscription = null;
    _expiredLotAlertsSubscription = null;
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

  void _handlePromotableLotsUpdate(List<PromotableLot> lots) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(promotableLots: lots));
  }

  void _handleActiveLotPromotionsUpdate(List<LotPromotion> promotions) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(activeLotPromotions: promotions));
  }

  void _handlePromotionNoticesUpdate(List<PromotionNotice> notices) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(promotionNotices: notices));
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

  void _handleExpiringLotAlertsUpdate(List<InventoryLotAlert> alerts) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(expiringLotAlerts: alerts));
  }

  void _handleExpiredLotAlertsUpdate(List<InventoryLotAlert> alerts) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(expiredLotAlerts: alerts));
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

String _movementDraftNote(MovementDraftLine draft) {
  final parts = <String>[
    'Traslado por lote ${draft.purchaseItemId}',
    'Compra ${_movementNoteDateTime(draft.receivedAt)}',
  ];

  if (draft.expiryDate != null) {
    parts.add('Vence ${_movementNoteDate(draft.expiryDate!)}');
  }
  if (draft.isPromotionPriority) {
    parts.add(
      draft.promotionStatus == 'pending_transfer'
          ? 'Lote priorizado por promo pendiente'
          : 'Lote con promo activa',
    );
  }
  if ((draft.promotionNote ?? '').trim().isNotEmpty) {
    parts.add(draft.promotionNote!.trim());
  }

  return parts.join(' | ');
}

String _movementNoteDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _movementNoteDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${_movementNoteDate(value)} $hour:$minute';
}

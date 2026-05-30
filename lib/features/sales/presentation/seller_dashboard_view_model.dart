import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/providers.dart';
import 'package:tiendaw/core/sync/sync_status.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/load_catalog_overview_use_case.dart';
import 'package:tiendaw/features/catalog/domain/product_pricing_rules.dart';
import 'package:tiendaw/features/sales/domain/create_sale_use_case.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:uuid/uuid.dart';

class SellerDashboardState {
  const SellerDashboardState({
    required this.categories,
    required this.products,
    required this.packs,
    required this.selectedCategoryId,
    required this.selectedProductId,
    required this.quantity,
    required this.paymentMethod,
    required this.currentShift,
    required this.todaysSales,
    required this.cartItems,
    required this.searchQuery,
    required this.priceHistory,
    this.feedbackMessage,
  });

  final List<Category> categories;
  final List<Product> products;
  final List<Pack> packs;
  final String? selectedCategoryId;
  final String? selectedProductId;
  final int quantity;
  final PaymentMethod paymentMethod;
  final CashShift? currentShift;
  final List<Sale> todaysSales;
  final List<SaleLine> cartItems;
  final String searchQuery;
  final List<PriceHistoryEntry> priceHistory;
  final String? feedbackMessage;

  SellerDashboardState copyWith({
    List<Category>? categories,
    List<Product>? products,
    List<Pack>? packs,
    String? selectedCategoryId,
    bool clearSelectedCategory = false,
    String? selectedProductId,
    bool clearSelectedProduct = false,
    int? quantity,
    PaymentMethod? paymentMethod,
    CashShift? currentShift,
    bool clearCurrentShift = false,
    List<Sale>? todaysSales,
    List<SaleLine>? cartItems,
    String? searchQuery,
    List<PriceHistoryEntry>? priceHistory,
    String? feedbackMessage,
  }) {
    return SellerDashboardState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      packs: packs ?? this.packs,
      selectedCategoryId:
          clearSelectedCategory
              ? null
              : selectedCategoryId ?? this.selectedCategoryId,
      selectedProductId:
          clearSelectedProduct
              ? null
              : selectedProductId ?? this.selectedProductId,
      quantity: quantity ?? this.quantity,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      currentShift:
          clearCurrentShift ? null : currentShift ?? this.currentShift,
      todaysSales: todaysSales ?? this.todaysSales,
      cartItems: cartItems ?? this.cartItems,
      searchQuery: searchQuery ?? this.searchQuery,
      priceHistory: priceHistory ?? this.priceHistory,
      feedbackMessage: feedbackMessage,
    );
  }

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

  int get cartItemsCount =>
      cartItems.fold(0, (sum, item) => sum + item.quantity);

  double get cartTotal => cartItems.fold(0, (sum, item) => sum + item.subtotal);

  bool get hasOpenShift => currentShift?.canSell ?? false;
  bool get hasPendingShiftApproval => currentShift?.isPendingApproval ?? false;
  bool get hasRejectedShiftRequest => currentShift?.isRejected ?? false;
  bool get hasShiftRequest => currentShift != null && !currentShift!.isClosed;

  int quantityInCart(String productId) {
    var total = 0;
    for (final item in cartItems) {
      if (item.productId == productId) {
        total += item.quantity;
      }
    }
    return total;
  }

  int icedQuantityInCart(String productId) {
    var total = 0;
    for (final item in cartItems) {
      if (item.productId == productId && item.isIced) {
        total += item.quantity;
      }
    }
    return total;
  }

  int normalQuantityInCart(String productId) {
    var total = 0;
    for (final item in cartItems) {
      if (item.productId == productId && !item.isIced) {
        total += item.quantity;
      }
    }
    return total;
  }

  int promotionalQuantityInCart(String productId) {
    var total = 0;
    for (final item in cartItems) {
      if (item.productId == productId && item.usedLotPromotion) {
        total += item.quantity;
      }
    }
    return total;
  }
}

final sellerDashboardViewModelProvider =
    AsyncNotifierProvider<SellerDashboardViewModel, SellerDashboardState>(
      SellerDashboardViewModel.new,
    );

class SellerDashboardViewModel extends AsyncNotifier<SellerDashboardState> {
  final _uuid = const Uuid();
  StreamSubscription<CatalogOverview>? _catalogSubscription;
  StreamSubscription<List<Sale>>? _salesSubscription;
  StreamSubscription<CashShift?>? _openShiftSubscription;
  StreamSubscription<List<PriceHistoryEntry>>? _priceHistorySubscription;
  StreamSubscription<List<Pack>>? _packsSubscription;
  Timer? _promotionRefreshTimer;

  LoadCatalogOverviewUseCase get _catalogUseCase =>
      ref.read(loadCatalogOverviewUseCaseProvider);

  CreateSaleUseCase get _createSaleUseCase =>
      ref.read(createSaleUseCaseProvider);

  AppUser? get _currentUser =>
      ref.read(sessionViewModelProvider).valueOrNull?.currentUser;

  @override
  Future<SellerDashboardState> build() async {
    ref.onDispose(_disposeRealtimeSubscriptions);
    final hydrated = await _hydrate();
    _bindRealtime();
    _schedulePromotionRefresh(hydrated.priceHistory);
    return hydrated;
  }

  Future<void> selectCategory(String categoryId) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final productsInCategory =
        current.products
            .where((product) => product.categoryId == categoryId)
            .toList();
    final nextProductId =
        productsInCategory.isEmpty ? null : productsInCategory.first.id;

    state = AsyncData(
      current.copyWith(
        selectedCategoryId: categoryId,
        selectedProductId: nextProductId,
        clearSelectedProduct: nextProductId == null,
      ),
    );
  }

  Future<void> selectProduct(String productId) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(selectedProductId: productId));
  }

  Future<void> changeQuantity(int nextValue) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(quantity: nextValue.clamp(1, 999)));
  }

  Future<void> setPaymentMethod(PaymentMethod paymentMethod) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(paymentMethod: paymentMethod));
  }

  Future<void> setSearchQuery(String query) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(searchQuery: query));
  }

  Future<void> clearFeedback() async {
    final current = state.valueOrNull;
    if (current == null || current.feedbackMessage == null) {
      return;
    }

    state = AsyncData(current.copyWith(feedbackMessage: null));
  }

  Future<void> addToCart(
    Product product,
    int quantity, {
    bool isIced = false,
  }) async {
    final current = state.valueOrNull;
    if (current == null || quantity <= 0) {
      return;
    }

    if (!current.hasOpenShift) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage:
              'Inicia la caja antes de agregar productos a la venta.',
        ),
      );
      return;
    }

    if (isIced) {
      final availableIcedStock = _icedStockForProduct(product);
      final nextIcedQuantity =
          current.icedQuantityInCart(product.id) + quantity;
      if (availableIcedStock <= 0 || nextIcedQuantity > availableIcedStock) {
        state = AsyncData(
          current.copyWith(
            feedbackMessage:
                'Solo tienes $availableIcedStock unidades heladas disponibles para ${product.name}.',
          ),
        );
        return;
      }
    } else {
      final availableNormalStock = _normalStockForProduct(product);
      final nextNormalQuantity =
          current.normalQuantityInCart(product.id) + quantity;
      if (availableNormalStock <= 0 ||
          nextNormalQuantity > availableNormalStock) {
        state = AsyncData(
          current.copyWith(
            feedbackMessage:
                'Solo tienes $availableNormalStock unidades normales disponibles para ${product.name}.',
          ),
        );
        return;
      }
    }

    final next = [...current.cartItems];
    final newLines = _buildSaleLinesForSelection(
      product: product,
      quantity: quantity,
      isIced: isIced,
      reservedPromotionUnits: current.promotionalQuantityInCart(product.id),
    );
    for (final line in newLines) {
      _mergeCartLine(next, line);
    }

    state = AsyncData(current.copyWith(cartItems: next));
  }

  Future<void> addPackToCart(Pack pack, int quantity) async {
    final current = state.valueOrNull;
    if (current == null || quantity <= 0) {
      return;
    }

    if (!current.hasOpenShift) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'Inicia la caja antes de agregar packs a la venta.',
        ),
      );
      return;
    }

    if (pack.availableInStore <= 0 || quantity > pack.availableInStore) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage:
              'Solo hay ${pack.availableInStore} packs disponibles en tienda.',
        ),
      );
      return;
    }

    final next = [...current.cartItems];
    for (final item in pack.items) {
      _mergeCartLine(
        next,
        SaleLine(
          productId: item.productId,
          productName: '${pack.name} / ${item.productName}',
          quantity: item.quantity * quantity,
          unitPrice: item.reducedUnitPrice,
          baseUnitPrice: item.reducedUnitPrice,
          originalUnitPrice: item.salePrice,
          usedPromotionalPrice: item.reducedUnitPrice < item.salePrice,
          packId: pack.id,
          packName: pack.name,
          batchId: item.batchId,
        ),
      );
    }

    state = AsyncData(current.copyWith(cartItems: next));
  }

  Future<void> updateCartQuantity(String cartKey, int quantity) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final next = [...current.cartItems];
    final index = next.indexWhere((item) => item.cartKey == cartKey);
    if (index == -1) {
      return;
    }

    final existing = next[index];
    final productId = existing.productId;
    final product = _productById(current, productId);
    if (product == null) {
      return;
    }

    final sameModeIndexes =
        next
            .asMap()
            .entries
            .where((entry) {
              final item = entry.value;
              return item.productId == productId &&
                  item.isIced == existing.isIced;
            })
            .map((entry) => entry.key)
            .toList()
          ..sort((left, right) => right.compareTo(left));
    final otherModePromotionalUnits = next
        .where(
          (item) =>
              item.productId == productId &&
              item.isIced != existing.isIced &&
              item.usedLotPromotion,
        )
        .fold(0, (sum, item) => sum + item.quantity);
    final desiredModeQuantity =
        next
            .asMap()
            .entries
            .where(
              (entry) =>
                  entry.value.productId == productId &&
                  entry.value.isIced == existing.isIced &&
                  entry.key != index,
            )
            .fold(0, (sum, entry) => sum + entry.value.quantity) +
        (quantity > 0 ? quantity : 0);

    final availableUnits =
        existing.isIced
            ? _icedStockForProduct(product)
            : _normalStockForProduct(product);
    if (quantity > 0 &&
        (availableUnits <= 0 || desiredModeQuantity > availableUnits)) {
      final stockLabel = existing.isIced ? 'heladas' : 'normales';
      state = AsyncData(
        current.copyWith(
          feedbackMessage:
              'Solo tienes $availableUnits unidades $stockLabel disponibles para ${product.name}.',
        ),
      );
      return;
    }

    for (final sameModeIndex in sameModeIndexes) {
      next.removeAt(sameModeIndex);
    }
    final rebuiltLines = _buildSaleLinesForSelection(
      product: product,
      quantity: desiredModeQuantity,
      isIced: existing.isIced,
      reservedPromotionUnits: otherModePromotionalUnits,
    );
    for (final line in rebuiltLines) {
      _mergeCartLine(next, line);
    }

    state = AsyncData(current.copyWith(cartItems: next));
  }

  Future<void> removeFromCart(String cartKey) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final next = [...current.cartItems];
    final index = next.indexWhere((item) => item.cartKey == cartKey);
    if (index == -1) {
      return;
    }

    final existing = next[index];
    final product = _productById(current, existing.productId);
    if (product == null) {
      next.removeAt(index);
      state = AsyncData(current.copyWith(cartItems: next));
      return;
    }

    final sameModeIndexes =
        next
            .asMap()
            .entries
            .where((entry) {
              final item = entry.value;
              return item.productId == existing.productId &&
                  item.isIced == existing.isIced;
            })
            .map((entry) => entry.key)
            .toList()
          ..sort((left, right) => right.compareTo(left));
    final remainingModeQuantity = next
        .asMap()
        .entries
        .where(
          (entry) =>
              entry.key != index &&
              entry.value.productId == existing.productId &&
              entry.value.isIced == existing.isIced,
        )
        .fold(0, (sum, entry) => sum + entry.value.quantity);
    final otherModePromotionalUnits = next
        .where(
          (item) =>
              item.productId == existing.productId &&
              item.isIced != existing.isIced &&
              item.usedLotPromotion,
        )
        .fold(0, (sum, item) => sum + item.quantity);

    for (final sameModeIndex in sameModeIndexes) {
      next.removeAt(sameModeIndex);
    }
    final rebuiltLines = _buildSaleLinesForSelection(
      product: product,
      quantity: remainingModeQuantity,
      isIced: existing.isIced,
      reservedPromotionUnits: otherModePromotionalUnits,
    );
    for (final line in rebuiltLines) {
      _mergeCartLine(next, line);
    }
    state = AsyncData(current.copyWith(cartItems: next));
  }

  Future<void> clearCart() async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(cartItems: const []));
  }

  Future<void> registerSale(AppUser user) async {
    final current = state.valueOrNull;
    final selectedProduct = current?.selectedProduct;

    if (current == null || selectedProduct == null) {
      return;
    }

    if (!current.hasOpenShift) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'Inicia la caja antes de registrar ventas.',
        ),
      );
      return;
    }

    final sale = Sale(
      id: _uuid.v4(),
      sellerId: user.id,
      sellerName: user.name,
      items: [
        ..._buildSaleLinesForSelection(
          product: selectedProduct,
          quantity: current.quantity,
          reservedPromotionUnits: 0,
        ),
      ],
      paymentMethod: current.paymentMethod,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      syncAttempts: 0,
    );

    try {
      await _createSaleUseCase(sale);
      await _refreshAll();

      state = AsyncData(
        state.requireValue.copyWith(
          quantity: 1,
          feedbackMessage: 'Venta registrada.',
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'No se pudo registrar la venta: $error',
        ),
      );
    }
  }

  Future<bool> registerCartSale(
    AppUser user,
    PaymentMethod paymentMethod,
  ) async {
    final current = state.valueOrNull;
    if (current == null || current.cartItems.isEmpty) {
      return false;
    }

    if (!current.hasOpenShift) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'Inicia la caja antes de registrar ventas.',
        ),
      );
      return false;
    }

    for (final item in current.cartItems) {
      final product = _productById(current, item.productId);
      if (product == null) {
        continue;
      }
      final availableUnits =
          item.isIced
              ? _icedStockForProduct(product)
              : _normalStockForProduct(product);
      final stockLabel = item.isIced ? 'heladas' : 'normales';
      if (item.quantity > availableUnits) {
        state = AsyncData(
          current.copyWith(
            feedbackMessage:
                'La tienda solo tiene $availableUnits unidades $stockLabel disponibles para ${item.productName}.',
          ),
        );
        return false;
      }
    }

    final promotionalQuantityByProduct = <String, int>{};
    for (final item in current.cartItems) {
      if (!item.usedLotPromotion) {
        continue;
      }
      promotionalQuantityByProduct.update(
        item.productId,
        (value) => value + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    for (final entry in promotionalQuantityByProduct.entries) {
      final product = _productById(current, entry.key);
      if (product == null) {
        continue;
      }
      final availablePromo = availablePromotionUnits(product);
      if (entry.value > availablePromo) {
        state = AsyncData(
          current.copyWith(
            feedbackMessage:
                'La promo disponible para ${product.name} ahora solo cubre $availablePromo unidades. Revisa el carrito antes de vender.',
          ),
        );
        return false;
      }
    }

    final sale = Sale(
      id: _uuid.v4(),
      sellerId: user.id,
      sellerName: user.name,
      items: current.cartItems,
      paymentMethod: paymentMethod,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      syncAttempts: 0,
    );

    try {
      await _createSaleUseCase(sale);
      await _refreshAll();

      state = AsyncData(
        state.requireValue.copyWith(
          cartItems: const [],
          quantity: 1,
          feedbackMessage: 'Venta registrada.',
        ),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'No se pudo registrar la venta: $error',
        ),
      );
      return false;
    }
  }

  Future<bool> openShift(
    AppUser user, {
    required double openingCash,
    required double openingYape,
    required double openingLatitude,
    required double openingLongitude,
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (current.hasOpenShift) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'La caja ya esta iniciada.'),
      );
      return false;
    }
    if (current.hasPendingShiftApproval) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage:
              'Ya existe una solicitud enviada. Espera la aprobacion del administrador.',
        ),
      );
      return false;
    }

    try {
      final shift = await ref
          .read(salesRepositoryProvider)
          .openShift(
            sellerId: user.id,
            openingCash: openingCash,
            openingYape: openingYape,
            openingLatitude: openingLatitude,
            openingLongitude: openingLongitude,
          );
      await _refreshAll();
      state = AsyncData(
        state.requireValue.copyWith(
          currentShift: shift,
          cartItems: const [],
          quantity: 1,
          feedbackMessage:
              shift.canSell
                  ? 'Caja iniciada. Ya puedes registrar ventas.'
                  : 'Solicitud enviada, esperando que el administrador apruebe el turno.',
        ),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'No se pudo iniciar la caja: $error'),
      );
      return false;
    }
  }

  Future<bool> closeShift(
    AppUser user, {
    required double closingCash,
    required double closingYape,
    required double closingLatitude,
    required double closingLongitude,
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (current.currentShift == null || current.currentShift!.isClosed) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'No hay una caja abierta para cerrar.',
        ),
      );
      return false;
    }

    try {
      await ref
          .read(salesRepositoryProvider)
          .closeShift(
            sellerId: user.id,
            closingCash: closingCash,
            closingYape: closingYape,
            closingLatitude: closingLatitude,
            closingLongitude: closingLongitude,
          );
      await _refreshAll();
      state = AsyncData(
        state.requireValue.copyWith(
          cartItems: const [],
          quantity: 1,
          clearCurrentShift: true,
          feedbackMessage: null,
        ),
      );
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'No se pudo cerrar la caja: $error'),
      );
      return false;
    }
  }

  Future<SellerDashboardState> _hydrate({
    String? selectedCategoryId,
    String? selectedProductId,
    int? quantity,
    PaymentMethod? paymentMethod,
    List<SaleLine>? cartItems,
    String? searchQuery,
    String? feedbackMessage,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('No hay sesion activa.');
    }

    final catalog = await _catalogUseCase();
    final sales = await ref.read(salesRepositoryProvider).getSales();
    final shift = await ref.read(salesRepositoryProvider).getOpenShift(user.id);
    final priceHistory =
        await ref.read(catalogRepositoryProvider).getPriceHistory();
    final packs = await ref.read(catalogRepositoryProvider).getPacks();

    final effectiveCategoryId =
        catalog.categories.any((category) => category.id == selectedCategoryId)
            ? selectedCategoryId
            : catalog.categories.isEmpty
            ? null
            : catalog.categories.first.id;

    final productsInCategory =
        effectiveCategoryId == null
            ? const <Product>[]
            : catalog.products
                .where((product) => product.categoryId == effectiveCategoryId)
                .toList();

    final effectiveProductId =
        productsInCategory.any((product) => product.id == selectedProductId)
            ? selectedProductId
            : productsInCategory.isEmpty
            ? null
            : productsInCategory.first.id;

    final today = DateTime.now();
    final todaysSales =
        sales.where((sale) {
          return sale.createdAt.year == today.year &&
              sale.createdAt.month == today.month &&
              sale.createdAt.day == today.day;
        }).toList();

    return SellerDashboardState(
      categories: catalog.categories,
      products: catalog.products,
      packs: packs,
      priceHistory: priceHistory,
      selectedCategoryId: effectiveCategoryId,
      selectedProductId: effectiveProductId,
      quantity: quantity ?? 1,
      paymentMethod: paymentMethod ?? PaymentMethod.cash,
      currentShift: shift,
      todaysSales: todaysSales,
      cartItems: cartItems ?? const [],
      searchQuery: searchQuery ?? '',
      feedbackMessage: feedbackMessage,
    );
  }

  Future<void> _refreshAll() async {
    final current = state.valueOrNull;
    final hydrated = await _hydrate(
      selectedCategoryId: current?.selectedCategoryId,
      selectedProductId: current?.selectedProductId,
      quantity: current?.quantity,
      paymentMethod: current?.paymentMethod,
      cartItems: current?.cartItems,
      searchQuery: current?.searchQuery,
    );
    state = AsyncData(hydrated);
    _schedulePromotionRefresh(hydrated.priceHistory);
  }

  Product? _productById(SellerDashboardState state, String productId) {
    for (final product in state.products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  List<SaleLine> _buildSaleLinesForSelection({
    required Product product,
    required int quantity,
    bool isIced = false,
    required int reservedPromotionUnits,
  }) {
    if (quantity <= 0) {
      return const [];
    }

    final priceAdjustment = isIced ? coldPriceIncrement(product) : 0.0;
    final lines = <SaleLine>[];
    var remainingQuantity = quantity;
    var remainingReservedPromotionUnits = reservedPromotionUnits;

    for (final offer in activePromotionOffers(product)) {
      if (remainingQuantity <= 0) {
        break;
      }

      var availablePromoUnits = offer.allocatableUnits;
      if (remainingReservedPromotionUnits >= availablePromoUnits) {
        remainingReservedPromotionUnits -= availablePromoUnits;
        continue;
      }
      if (remainingReservedPromotionUnits > 0) {
        availablePromoUnits -= remainingReservedPromotionUnits;
        remainingReservedPromotionUnits = 0;
      }
      if (availablePromoUnits <= 0) {
        continue;
      }

      final promotionalQuantity =
          remainingQuantity < availablePromoUnits
              ? remainingQuantity
              : availablePromoUnits;
      final promotionalUnitPrice = promotionalUnitPriceForOffer(product, offer);
      lines.add(
        SaleLine(
          productId: product.id,
          productName: product.name,
          quantity: promotionalQuantity,
          unitPrice: promotionalUnitPrice + priceAdjustment,
          baseUnitPrice: promotionalUnitPrice,
          originalUnitPrice: product.salePrice,
          priceAdjustment: priceAdjustment,
          isIced: isIced,
          usedPromotionalPrice: true,
          usedLotPromotion: true,
        ),
      );
      remainingQuantity -= promotionalQuantity;
    }

    if (remainingQuantity > 0) {
      final generalPromoPrice = generalPromotionalPrice(product);
      final fallbackUnitPrice = generalPromoPrice ?? product.salePrice;
      lines.add(
        SaleLine(
          productId: product.id,
          productName: product.name,
          quantity: remainingQuantity,
          unitPrice: fallbackUnitPrice + priceAdjustment,
          baseUnitPrice: fallbackUnitPrice,
          originalUnitPrice: product.salePrice,
          priceAdjustment: priceAdjustment,
          isIced: isIced,
          usedPromotionalPrice: generalPromoPrice != null,
          usedLotPromotion: false,
        ),
      );
    }

    return lines;
  }

  void _mergeCartLine(List<SaleLine> cartItems, SaleLine incoming) {
    final index = cartItems.indexWhere(
      (item) => item.cartKey == incoming.cartKey,
    );
    if (index == -1) {
      cartItems.add(incoming);
      return;
    }

    final current = cartItems[index];
    cartItems[index] = SaleLine(
      productId: current.productId,
      productName: current.productName,
      quantity: current.quantity + incoming.quantity,
      unitPrice: current.unitPrice,
      baseUnitPrice: current.baseUnitPrice,
      originalUnitPrice: current.originalUnitPrice,
      priceAdjustment: current.priceAdjustment,
      isIced: current.isIced,
      usedPromotionalPrice: current.usedPromotionalPrice,
      usedLotPromotion: current.usedLotPromotion,
      packId: current.packId,
      packName: current.packName,
      batchId: current.batchId,
    );
  }

  // ignore: unused_element
  int _storeStockForProduct(SellerDashboardState state, String productId) {
    final product = _productById(state, productId);
    return product?.stockStore ?? 0;
  }

  void _bindRealtime() {
    _disposeRealtimeSubscriptions();

    _catalogSubscription = _catalogUseCase.watch().listen(
      _handleCatalogUpdate,
      onError: (_, __) {},
    );
    _salesSubscription = ref
        .read(salesRepositoryProvider)
        .watchSales()
        .listen(_handleSalesUpdate, onError: (_, __) {});

    final user = _currentUser;
    if (user != null) {
      _openShiftSubscription = ref
          .read(salesRepositoryProvider)
          .watchOpenShift(user.id)
          .listen(_handleOpenShiftUpdate, onError: (_, __) {});
    }
    _priceHistorySubscription = ref
        .read(catalogRepositoryProvider)
        .watchPriceHistory()
        .listen(_handlePriceHistoryUpdate, onError: (_, __) {});
    _packsSubscription = ref
        .read(catalogRepositoryProvider)
        .watchPacks()
        .listen(_handlePacksUpdate, onError: (_, __) {});
  }

  void _disposeRealtimeSubscriptions() {
    _promotionRefreshTimer?.cancel();
    _catalogSubscription?.cancel();
    _salesSubscription?.cancel();
    _openShiftSubscription?.cancel();
    _priceHistorySubscription?.cancel();
    _packsSubscription?.cancel();
    _promotionRefreshTimer = null;
    _catalogSubscription = null;
    _salesSubscription = null;
    _openShiftSubscription = null;
    _priceHistorySubscription = null;
    _packsSubscription = null;
  }

  void _handlePriceHistoryUpdate(List<PriceHistoryEntry> entries) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(priceHistory: entries));
    _schedulePromotionRefresh(entries);
  }

  void _handlePacksUpdate(List<Pack> packs) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(packs: packs));
  }

  void _schedulePromotionRefresh(List<PriceHistoryEntry> entries) {
    _promotionRefreshTimer?.cancel();

    final now = DateTime.now();
    DateTime? nextBoundary;

    for (final entry in entries) {
      final boundaries = <DateTime>[
        entry.effectiveFrom,
        if (entry.effectiveTo != null) entry.effectiveTo!,
      ];
      for (final boundary in boundaries) {
        if (boundary.isAfter(now) &&
            (nextBoundary == null || boundary.isBefore(nextBoundary))) {
          nextBoundary = boundary;
        }
      }
    }

    if (nextBoundary == null) {
      return;
    }

    final delay = nextBoundary.difference(now);
    Timer? timer;
    timer = Timer(delay, () {
      if (!identical(_promotionRefreshTimer, timer)) {
        return;
      }
      unawaited(_refreshAll());
    });
    _promotionRefreshTimer = timer;
  }

  void _handleCatalogUpdate(CatalogOverview catalog) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final effectiveCategoryId =
        catalog.categories.any(
              (category) => category.id == current.selectedCategoryId,
            )
            ? current.selectedCategoryId
            : catalog.categories.isEmpty
            ? null
            : catalog.categories.first.id;

    final productsInCategory =
        effectiveCategoryId == null
            ? const <Product>[]
            : catalog.products
                .where((product) => product.categoryId == effectiveCategoryId)
                .toList();

    final effectiveProductId =
        productsInCategory.any(
              (product) => product.id == current.selectedProductId,
            )
            ? current.selectedProductId
            : productsInCategory.isEmpty
            ? null
            : productsInCategory.first.id;

    state = AsyncData(
      current.copyWith(
        categories: catalog.categories,
        products: catalog.products,
        selectedCategoryId: effectiveCategoryId,
        clearSelectedCategory: effectiveCategoryId == null,
        selectedProductId: effectiveProductId,
        clearSelectedProduct: effectiveProductId == null,
      ),
    );
  }

  void _handleSalesUpdate(List<Sale> sales) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final today = DateTime.now();
    final todaysSales =
        sales.where((sale) {
          return sale.createdAt.year == today.year &&
              sale.createdAt.month == today.month &&
              sale.createdAt.day == today.day;
        }).toList();

    state = AsyncData(current.copyWith(todaysSales: todaysSales));
  }

  void _handleOpenShiftUpdate(CashShift? shift) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(currentShift: shift, clearCurrentShift: shift == null),
    );
  }
}

int _icedStockForProduct(Product product) {
  final icedUnits = product.coldStockUnits;
  if (icedUnits <= 0) {
    return 0;
  }
  if (icedUnits >= product.stockStore) {
    return product.stockStore;
  }
  return icedUnits;
}

int _normalStockForProduct(Product product) {
  final normalUnits = product.stockStore - _icedStockForProduct(product);
  return normalUnits < 0 ? 0 : normalUnits;
}

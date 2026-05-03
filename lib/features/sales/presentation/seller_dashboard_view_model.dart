import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/providers.dart';
import 'package:tiendaw/core/sync/sync_status.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/load_catalog_overview_use_case.dart';
import 'package:tiendaw/features/dashboard/presentation/admin_desktop_dashboard_view_model.dart';
import 'package:tiendaw/features/purchases/presentation/admin_mobile_dashboard_view_model.dart';
import 'package:tiendaw/features/sales/domain/create_sale_use_case.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:uuid/uuid.dart';

class SellerDashboardState {
  const SellerDashboardState({
    required this.categories,
    required this.products,
    required this.selectedCategoryId,
    required this.selectedProductId,
    required this.quantity,
    required this.paymentMethod,
    required this.currentShift,
    required this.todaysSales,
    required this.cartItems,
    required this.searchQuery,
    this.feedbackMessage,
  });

  final List<Category> categories;
  final List<Product> products;
  final String? selectedCategoryId;
  final String? selectedProductId;
  final int quantity;
  final PaymentMethod paymentMethod;
  final CashShift? currentShift;
  final List<Sale> todaysSales;
  final List<SaleLine> cartItems;
  final String searchQuery;
  final String? feedbackMessage;

  SellerDashboardState copyWith({
    List<Category>? categories,
    List<Product>? products,
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
    String? feedbackMessage,
  }) {
    return SellerDashboardState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
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

  double get cartTotal =>
      cartItems.fold(0, (sum, item) => sum + item.subtotal);

  bool get hasOpenShift => currentShift?.isOpen ?? false;

  int quantityInCart(String productId) {
    for (final item in cartItems) {
      if (item.productId == productId) {
        return item.quantity;
      }
    }
    return 0;
  }
}

final sellerDashboardViewModelProvider =
    AsyncNotifierProvider<SellerDashboardViewModel, SellerDashboardState>(
      SellerDashboardViewModel.new,
    );

class SellerDashboardViewModel extends AsyncNotifier<SellerDashboardState> {
  final _uuid = const Uuid();

  LoadCatalogOverviewUseCase get _catalogUseCase =>
      ref.read(loadCatalogOverviewUseCaseProvider);

  CreateSaleUseCase get _createSaleUseCase =>
      ref.read(createSaleUseCaseProvider);

  AppUser? get _currentUser =>
      ref.read(sessionViewModelProvider).valueOrNull?.currentUser;

  @override
  Future<SellerDashboardState> build() async {
    return _hydrate();
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

  Future<void> addToCart(Product product, int quantity) async {
    final current = state.valueOrNull;
    if (current == null || quantity <= 0) {
      return;
    }

    if (!current.hasOpenShift) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage: 'Inicia la caja antes de agregar productos a la venta.',
        ),
      );
      return;
    }

    final stockStore = _storeStockForProduct(current, product.id);
    final existingQuantity = current.quantityInCart(product.id);
    final nextQuantity = existingQuantity + quantity;
    if (stockStore <= 0 || nextQuantity > stockStore) {
      state = AsyncData(
        current.copyWith(
          feedbackMessage:
              'Solo tienes $stockStore unidades disponibles en tienda para ${product.name}.',
        ),
      );
      return;
    }

    final next = [...current.cartItems];
    final index = next.indexWhere((item) => item.productId == product.id);
    if (index == -1) {
      next.add(
        SaleLine(
          productId: product.id,
          productName: product.name,
          quantity: quantity,
          unitPrice: product.salePrice,
        ),
      );
    } else {
      final existing = next[index];
      next[index] = SaleLine(
        productId: existing.productId,
        productName: existing.productName,
        quantity: existing.quantity + quantity,
        unitPrice: existing.unitPrice,
      );
    }

    state = AsyncData(current.copyWith(cartItems: next));
  }

  Future<void> updateCartQuantity(String productId, int quantity) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final next = [...current.cartItems];
    final index = next.indexWhere((item) => item.productId == productId);
    if (index == -1) {
      return;
    }

    if (quantity <= 0) {
      next.removeAt(index);
    } else {
      final product = _productById(current, productId);
      final stockStore = _storeStockForProduct(current, productId);
      if (stockStore <= 0 || quantity > stockStore) {
        state = AsyncData(
          current.copyWith(
            feedbackMessage:
                'Solo tienes $stockStore unidades disponibles en tienda para ${product?.name ?? 'este producto'}.',
          ),
        );
        return;
      }
      final existing = next[index];
      next[index] = SaleLine(
        productId: existing.productId,
        productName: existing.productName,
        quantity: quantity,
        unitPrice: existing.unitPrice,
      );
    }

    state = AsyncData(current.copyWith(cartItems: next));
  }

  Future<void> removeFromCart(String productId) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final next = current.cartItems
        .where((item) => item.productId != productId)
        .toList();
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
        SaleLine(
          productId: selectedProduct.id,
          productName: selectedProduct.name,
          quantity: current.quantity,
          unitPrice: selectedProduct.salePrice,
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

  Future<bool> registerCartSale(AppUser user, PaymentMethod paymentMethod)
      async {
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
      final stockStore = _storeStockForProduct(current, item.productId);
      if (item.quantity > stockStore) {
        state = AsyncData(
          current.copyWith(
            feedbackMessage:
            'La tienda solo tiene $stockStore unidades disponibles para ${item.productName}.',
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

  Future<bool> openShift(AppUser user) async {
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

    try {
      await ref.read(salesRepositoryProvider).openShift(user.id);
      await _refreshAll();
      state = AsyncData(
        state.requireValue.copyWith(
          cartItems: const [],
          quantity: 1,
          feedbackMessage: 'Caja iniciada. Ya puedes registrar ventas.',
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

  Future<bool> closeShift(AppUser user) async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    if (!current.hasOpenShift) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'No hay una caja abierta para cerrar.'),
      );
      return false;
    }

    try {
      await ref.read(salesRepositoryProvider).closeShift(user.id);
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
    state = AsyncData(
      await _hydrate(
        selectedCategoryId: current?.selectedCategoryId,
        selectedProductId: current?.selectedProductId,
        quantity: current?.quantity,
        paymentMethod: current?.paymentMethod,
        cartItems: current?.cartItems,
        searchQuery: current?.searchQuery,
      ),
    );

    ref.invalidate(adminMobileDashboardViewModelProvider);
    ref.invalidate(adminDesktopDashboardViewModelProvider);
  }

  Product? _productById(SellerDashboardState state, String productId) {
    for (final product in state.products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  int _storeStockForProduct(SellerDashboardState state, String productId) {
    final product = _productById(state, productId);
    return product?.stockStore ?? 0;
  }
}

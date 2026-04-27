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
    this.feedbackMessage,
  });

  final List<Category> categories;
  final List<Product> products;
  final String? selectedCategoryId;
  final String? selectedProductId;
  final int quantity;
  final PaymentMethod paymentMethod;
  final CashShift currentShift;
  final List<Sale> todaysSales;
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
    List<Sale>? todaysSales,
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
      currentShift: currentShift ?? this.currentShift,
      todaysSales: todaysSales ?? this.todaysSales,
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
        current.products.where((product) => product.categoryId == categoryId).toList();
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

  Future<void> registerSale(AppUser user) async {
    final current = state.valueOrNull;
    final selectedProduct = current?.selectedProduct;

    if (current == null || selectedProduct == null) {
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
          feedbackMessage: 'Venta registrada en Supabase.',
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(feedbackMessage: 'No se pudo registrar la venta: $error'),
      );
    }
  }

  Future<void> closeShift(AppUser user) async {
    try {
      await ref.read(salesRepositoryProvider).closeShift(user.id);
      await _refreshAll();
      state = AsyncData(
        state.requireValue.copyWith(
          feedbackMessage: 'Caja cerrada y turno reabierto en Supabase.',
        ),
      );
    } catch (error) {
      final current = state.valueOrNull;
      if (current == null) {
        return;
      }
      state = AsyncData(
        current.copyWith(feedbackMessage: 'No se pudo cerrar la caja: $error'),
      );
    }
  }

  Future<SellerDashboardState> _hydrate({
    String? selectedCategoryId,
    String? selectedProductId,
    int? quantity,
    PaymentMethod? paymentMethod,
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
      ),
    );

    ref.invalidate(adminMobileDashboardViewModelProvider);
    ref.invalidate(adminDesktopDashboardViewModelProvider);
  }
}

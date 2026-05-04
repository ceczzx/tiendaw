import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/features/sales/presentation/seller_dashboard_view_model.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

class SellerDashboardPage extends ConsumerStatefulWidget {
  const SellerDashboardPage({super.key});

  @override
  ConsumerState<SellerDashboardPage> createState() =>
      _SellerDashboardPageState();
}

class _SellerDashboardPageState extends ConsumerState<SellerDashboardPage> {
  bool _initialShiftPromptHandled = false;
  bool _isActionInProgress = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SellerDashboardState>>(
      sellerDashboardViewModelProvider,
      (previous, next) {
        if (!mounted) {
          return;
        }

        final previousState = previous?.valueOrNull;
        final nextState = next.valueOrNull;
        _handleFeedback(
          previousState?.feedbackMessage,
          nextState?.feedbackMessage,
        );
        _handleShiftLifecycle(previousState, nextState);
      },
    );

    final dashboard = ref.watch(sellerDashboardViewModelProvider);
    final session = ref.watch(sessionViewModelProvider).valueOrNull;
    final currentUser = session?.currentUser;

    return dashboard.when(
      data: (state) {
        final rawQuery = state.searchQuery.trim();
        final query = rawQuery.toLowerCase();
        final sellableProducts =
            state.products.where((product) => product.stockStore > 0).toList();
        final productsInCategory =
            state.selectedCategoryId == null
                ? sellableProducts
                : sellableProducts
                    .where(
                      (product) =>
                          product.categoryId == state.selectedCategoryId,
                    )
                    .toList();
        final filteredProducts =
            query.isEmpty
                ? productsInCategory
                : productsInCategory
                    .where(
                      (product) => product.name.toLowerCase().contains(query),
                    )
                    .toList();

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Venta rapida para ${currentUser?.name ?? 'usuario'}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.hasOpenShift
                        ? 'Busca, agrega y cobra todo en una sola lista de venta.'
                        : 'Inicia caja para habilitar ventas y movimientos del turno.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'Caja del turno',
                    subtitle:
                        state.hasOpenShift
                            ? 'Resumen del turno abierto en caja.'
                            : 'No hay caja abierta. Inicia una para empezar a vender.',
                    child:
                        state.hasOpenShift
                            ? Column(
                              children: [
                                _SummaryRow(
                                  label: 'Caja efectivo',
                                  value: SystemWFormatters.currency.format(
                                    state.currentShift?.cashSales ?? 0,
                                  ),
                                ),
                                _SummaryRow(
                                  label: 'Caja Yape/Transfer',
                                  value: SystemWFormatters.currency.format(
                                    state.currentShift?.yapeSales ?? 0,
                                  ),
                                ),
                                _SummaryRow(
                                  label: 'Total turno',
                                  value: SystemWFormatters.currency.format(
                                    state.currentShift?.total ?? 0,
                                  ),
                                  isStrong: true,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed:
                                        currentUser == null ||
                                                _isActionInProgress
                                            ? null
                                            : () => _confirmCloseShift(
                                              context,
                                              currentUser,
                                            ),
                                    child: const Text('Cerrar caja del turno'),
                                  ),
                                ),
                              ],
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hasta que no abras caja, la venta queda bloqueada para evitar movimientos fuera del turno.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    FilledButton.icon(
                                      onPressed:
                                          currentUser == null ||
                                                  _isActionInProgress
                                              ? null
                                              : () => _startShift(currentUser),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      label: const Text('Iniciar caja'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          currentUser == null ||
                                                  _isActionInProgress
                                              ? null
                                              : _signOut,
                                      icon: const Icon(Icons.logout_rounded),
                                      label: const Text('Cerrar sesion'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Buscador global',
                    subtitle: 'Encuentra productos por nombre al instante.',
                    child: TextField(
                      enabled: state.hasOpenShift,
                      onChanged:
                          (value) => ref
                              .read(sellerDashboardViewModelProvider.notifier)
                              .setSearchQuery(value),
                      decoration: InputDecoration(
                        hintText: 'Busca Coca, Mani, Cerveza...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Categorias',
                    subtitle: 'Filtra rapido cuando no usas el buscador.',
                    child:
                        state.categories.isEmpty
                            ? const EmptyStateCard(
                              title: 'Sin categorias registradas',
                              caption:
                                  'Crea registros de categorias para empezar a vender.',
                            )
                            : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    state.categories.map((category) {
                                      final selected =
                                          category.id ==
                                          state.selectedCategoryId;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(category.name),
                                          selected: selected,
                                          onSelected:
                                              state.hasOpenShift
                                                  ? (_) => ref
                                                      .read(
                                                        sellerDashboardViewModelProvider
                                                            .notifier,
                                                      )
                                                      .selectCategory(
                                                        category.id,
                                                      )
                                                  : null,
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title:
                        query.isEmpty
                            ? 'Productos de tienda'
                            : 'Resultados para "$rawQuery"',
                    subtitle:
                        state.hasOpenShift
                            ? 'Solo se muestran productos con stock disponible en tienda.'
                            : 'La lista se habilita apenas inicies caja.',
                    child:
                        !state.hasOpenShift
                            ? const EmptyStateCard(
                              title: 'Caja pendiente',
                              caption:
                                  'Inicia caja para poder elegir productos y registrar ventas.',
                            )
                            : filteredProducts.isEmpty
                            ? const EmptyStateCard(
                              title: 'Sin productos disponibles en tienda',
                              caption:
                                  'Abastece la tienda o cambia la categoria seleccionada.',
                            )
                            : LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final crossAxisCount =
                                    width < 420
                                        ? 2
                                        : width < 720
                                        ? 3
                                        : 4;

                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredProducts.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.82,
                                      ),
                                  itemBuilder: (context, index) {
                                    final product = filteredProducts[index];
                                    final selected =
                                        product.id == state.selectedProductId;
                                    final remainingStock =
                                        product.stockStore -
                                        state.quantityInCart(product.id);
                                    final canAddMore = remainingStock > 0;

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap:
                                          canAddMore
                                              ? () => _openQuantitySheet(
                                                context,
                                                state,
                                                ref,
                                                product,
                                              )
                                              : null,
                                      child: Ink(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color:
                                              selected
                                                  ? const Color(0xFF0F766E)
                                                  : const Color(0xFFFAFAF9),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color:
                                                selected
                                                    ? const Color(0xFF0F766E)
                                                    : const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall?.copyWith(
                                                color:
                                                    selected
                                                        ? Colors.white
                                                        : null,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Tienda: ${product.stockStore}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color:
                                                    selected
                                                        ? Colors.white70
                                                        : const Color(
                                                          0xFF6B7280,
                                                        ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              SystemWFormatters.currency.format(
                                                product.salePrice,
                                              ),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.copyWith(
                                                color:
                                                    selected
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF0F766E,
                                                        ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed:
                                                    canAddMore
                                                        ? () =>
                                                            _openQuantitySheet(
                                                              context,
                                                              state,
                                                              ref,
                                                              product,
                                                            )
                                                        : null,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      selected
                                                          ? Colors.white
                                                          : const Color(
                                                            0xFF0F766E,
                                                          ),
                                                  foregroundColor:
                                                      selected
                                                          ? const Color(
                                                            0xFF0F766E,
                                                          )
                                                          : Colors.white,
                                                ),
                                                child: Text(
                                                  canAddMore
                                                      ? 'Anadir'
                                                      : 'Sin stock',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Lista de venta',
                    subtitle: 'Revisa cantidades antes de cobrar.',
                    child:
                        !state.hasOpenShift
                            ? const EmptyStateCard(
                              title: 'Venta bloqueada',
                              caption:
                                  'Abre la caja del turno para empezar a armar el carrito.',
                            )
                            : state.cartItems.isEmpty
                            ? const EmptyStateCard(
                              title: 'Carrito vacio',
                              caption:
                                  'Agrega productos con el boton de anadir.',
                            )
                            : Column(
                              children:
                                  state.cartItems.map((item) {
                                    final stockStore = _storeStockForItem(
                                      state,
                                      item.productId,
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _CartItemRow(
                                        item: item,
                                        stockStore: stockStore,
                                        onDecrease:
                                            () => ref
                                                .read(
                                                  sellerDashboardViewModelProvider
                                                      .notifier,
                                                )
                                                .updateCartQuantity(
                                                  item.productId,
                                                  item.quantity - 1,
                                                ),
                                        onIncrease:
                                            item.quantity >= stockStore
                                                ? null
                                                : () => ref
                                                    .read(
                                                      sellerDashboardViewModelProvider
                                                          .notifier,
                                                    )
                                                    .updateCartQuantity(
                                                      item.productId,
                                                      item.quantity + 1,
                                                    ),
                                        onRemove:
                                            () => ref
                                                .read(
                                                  sellerDashboardViewModelProvider
                                                      .notifier,
                                                )
                                                .removeFromCart(item.productId),
                                      ),
                                    );
                                  }).toList(),
                            ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: _CartSummaryBar(
                itemCount: state.cartItemsCount,
                total: state.cartTotal,
                enabled:
                    state.cartItems.isNotEmpty &&
                    currentUser != null &&
                    state.hasOpenShift &&
                    !_isActionInProgress,
                onCheckout:
                    () => _openCheckoutSheet(context, ref, state, currentUser),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (_, _) => const Center(
            child: Text('No pudimos cargar ventas en este momento.'),
          ),
    );
  }

  void _handleFeedback(String? previousMessage, String? nextMessage) {
    if (nextMessage == null ||
        nextMessage.isEmpty ||
        nextMessage == previousMessage) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await showSystemWActionDialog(
        context,
        message: nextMessage,
        isError: _isErrorFeedback(nextMessage),
      );
      if (!mounted) {
        return;
      }
      await ref.read(sellerDashboardViewModelProvider.notifier).clearFeedback();
      if (!mounted) {
        return;
      }
      setState(() => _isActionInProgress = false);
    });
  }

  void _handleShiftLifecycle(
    SellerDashboardState? previousState,
    SellerDashboardState? nextState,
  ) {
    if (nextState == null) {
      return;
    }

    final currentUser =
        ref.read(sessionViewModelProvider).valueOrNull?.currentUser;
    if (currentUser == null) {
      return;
    }

    if (nextState.hasOpenShift) {
      _initialShiftPromptHandled = false;
      return;
    }

    final hadOpenShift = previousState?.hasOpenShift ?? false;
    if (hadOpenShift) {
      _initialShiftPromptHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showPostCloseOptions(currentUser);
      });
      return;
    }

    if (_initialShiftPromptHandled) {
      return;
    }

    _initialShiftPromptHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _promptStartShift(currentUser);
    });
  }

  Future<void> _startShift(AppUser user) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() => _isActionInProgress = true);
    final success = await ref
        .read(sellerDashboardViewModelProvider.notifier)
        .openShift(user);
    if (!success) {
      _releaseActionLockIfNoFeedback();
    }
  }

  Future<void> _promptStartShift(AppUser user) async {
    final decision = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Iniciar caja'),
            content: const Text(
              'Todavia no abriste caja. Inicia el turno para registrar ventas o cierra sesion si aun no vas a operar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cerrar sesion'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Iniciar caja'),
              ),
            ],
          ),
    );

    if (!mounted) {
      return;
    }

    if (decision == true) {
      await _startShift(user);
      return;
    }

    await _signOut();
  }

  Future<void> _confirmCloseShift(BuildContext context, AppUser user) async {
    if (_isActionInProgress) {
      return;
    }

    final shouldClose = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cerrar caja'),
            content: const Text(
              'Se cerrara la caja actual y ya no podras registrar ventas hasta abrir una nueva.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cerrar caja'),
              ),
            ],
          ),
    );

    if (shouldClose != true || !mounted) {
      return;
    }

    setState(() => _isActionInProgress = true);
    final success = await ref
        .read(sellerDashboardViewModelProvider.notifier)
        .closeShift(user);
    if (!success) {
      _releaseActionLockIfNoFeedback();
    }
  }

  Future<void> _showPostCloseOptions(AppUser user) async {
    if (mounted && _isActionInProgress) {
      setState(() => _isActionInProgress = false);
    }

    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Caja cerrada'),
            content: const Text(
              'La caja ya se cerro correctamente. Ahora elige si quieres abrir una nueva caja o cerrar sesion.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('logout'),
                child: const Text('Cerrar sesion'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('open'),
                child: const Text('Iniciar otra caja'),
              ),
            ],
          ),
    );

    if (!mounted) {
      return;
    }

    if (decision == 'open') {
      await _startShift(user);
      return;
    }

    await _signOut();
  }

  Future<void> _signOut() async {
    await ref.read(sessionViewModelProvider.notifier).signOut();
  }

  Future<void> _openQuantitySheet(
    BuildContext context,
    SellerDashboardState state,
    WidgetRef ref,
    Product product,
  ) async {
    final maxAddable = product.stockStore - state.quantityInCart(product.id);
    if (maxAddable <= 0) {
      await showSystemWActionDialog(
        context,
        message:
            'Ya no queda stock disponible en tienda para seguir agregando ${product.name}.',
        isError: true,
      );
      return;
    }

    ref
        .read(sellerDashboardViewModelProvider.notifier)
        .selectProduct(product.id);
    var quantity = 1;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SystemWFormatters.currency.format(product.salePrice),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Disponible en tienda: $maxAddable unidades',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        onPressed:
                            quantity > 1
                                ? () => setState(() => quantity -= 1)
                                : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            '$quantity unidades',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            quantity >= maxAddable
                                ? null
                                : () => setState(() => quantity += 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        SystemWFormatters.currency.format(
                          product.salePrice * quantity,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(sellerDashboardViewModelProvider.notifier)
                            .addToCart(product, quantity);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Agregar a la lista'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCheckoutSheet(
    BuildContext context,
    WidgetRef ref,
    SellerDashboardState state,
    AppUser? currentUser,
  ) async {
    var selectedMethod = state.paymentMethod;
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de venta',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ...state.cartItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('x${item.quantity}'),
                          const SizedBox(width: 12),
                          Text(
                            SystemWFormatters.currency.format(item.subtotal),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'Total a cobrar',
                    value: SystemWFormatters.currency.format(state.cartTotal),
                    isStrong: true,
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<PaymentMethod>(
                      segments: const [
                        ButtonSegment(
                          value: PaymentMethod.cash,
                          label: Text('Efectivo'),
                          icon: Icon(Icons.payments_rounded),
                        ),
                        ButtonSegment(
                          value: PaymentMethod.yape,
                          label: Text('Yape'),
                          icon: Icon(Icons.qr_code_2_rounded),
                        ),
                      ],
                      selected: {selectedMethod},
                      onSelectionChanged: isSubmitting
                          ? null
                          : (selection) {
                        setState(() => selectedMethod = selection.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          currentUser == null ||
                                  state.cartItems.isEmpty ||
                                  isSubmitting ||
                                  _isActionInProgress
                              ? null
                              : () async {
                                setState(() => isSubmitting = true);
                                if (mounted) {
                                  this.setState(
                                    () => _isActionInProgress = true,
                                  );
                                }
                                final success = await ref
                                    .read(
                                      sellerDashboardViewModelProvider.notifier,
                                    )
                                    .registerCartSale(
                                      currentUser,
                                      selectedMethod,
                                    );
                                if (success && mounted) {
                                  Navigator.of(context).pop();
                                  return;
                                }

                                if (!mounted) {
                                  return;
                                }
                                setState(() => isSubmitting = false);
                                _releaseActionLockIfNoFeedback();
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        isSubmitting ? 'Registrando...' : 'Finalizar venta',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _releaseActionLockIfNoFeedback() {
    final feedback =
        ref.read(sellerDashboardViewModelProvider).valueOrNull?.feedbackMessage;
    if ((feedback == null || feedback.isEmpty) && mounted) {
      setState(() => _isActionInProgress = false);
    }
  }

  int _storeStockForItem(SellerDashboardState state, String productId) {
    for (final product in state.products) {
      if (product.id == productId) {
        return product.stockStore;
      }
    }
    return 0;
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({
    required this.item,
    required this.stockStore,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final SaleLine item;
  final int stockStore;
  final VoidCallback onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tienda: $stockStore u.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  SystemWFormatters.currency.format(item.subtotal),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onDecrease,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${item.quantity}'),
              IconButton(
                onPressed: onIncrease,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({
    required this.itemCount,
    required this.total,
    required this.enabled,
    required this.onCheckout,
  });

  final int itemCount;
  final double total;
  final bool enabled;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F111827),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carrito (${itemCount} productos)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  SystemWFormatters.currency.format(total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: enabled ? onCheckout : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Finalizar venta'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isStrong = false,
  });

  final String label;
  final String value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final style =
        isStrong
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

bool _isErrorFeedback(String message) {
  return message.trim().toLowerCase().startsWith('no se pudo') ||
      message.trim().toLowerCase().startsWith('solo tienes') ||
      message.trim().toLowerCase().startsWith('la tienda solo tiene') ||
      message.trim().toLowerCase().startsWith('inicia la caja') ||
      message.trim().toLowerCase().startsWith('no hay una caja');
}

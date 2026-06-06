import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/product_pricing_rules.dart';
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
        final availablePacks =
            state.packs.where((pack) => pack.availableForSale > 0).toList();
        _debugSellerPacksView(
          hasOpenShift: state.hasOpenShift,
          packs: state.packs,
          availablePacks: availablePacks,
        );

        if (state.hasPendingShiftApproval) {
          return _PendingShiftApprovalView(
            currentUser: currentUser,
            currentShift: state.currentShift,
            onSignOut:
                currentUser == null || _isActionInProgress
                    ? null
                    : () => _signOutWithPendingShiftCleanup(currentUser),
          );
        }

        if (state.hasRejectedShiftRequest) {
          return _RejectedShiftRequestView(
            currentUser: currentUser,
            currentShift: state.currentShift,
            onStartShift:
                currentUser == null || _isActionInProgress
                    ? null
                    : () => _startShift(currentUser),
            onSignOut:
                _isActionInProgress
                    ? null
                    : () {
                      _signOut();
                    },
          );
        }

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
                                  label: 'Inicial efectivo',
                                  value: SystemWFormatters.currency.format(
                                    state.currentShift?.openingCash ?? 0,
                                  ),
                                ),
                                _SummaryRow(
                                  label: 'Inicial Yape',
                                  value: SystemWFormatters.currency.format(
                                    state.currentShift?.openingYape ?? 0,
                                  ),
                                ),
                                _SummaryRow(
                                  label: 'Ventas efectivo',
                                  value: SystemWFormatters.currency.format(
                                    state.currentShift?.cashSales ?? 0,
                                  ),
                                ),
                                _SummaryRow(
                                  label: 'Ventas Yape/Transfer',
                                  value: SystemWFormatters.currency.format(
                                    state.currentShift?.yapeSales ?? 0,
                                  ),
                                ),
                                _SummaryRow(
                                  label: 'Total esperado',
                                  value: SystemWFormatters.currency.format(
                                    state.currentShift?.expectedClosingAmount ??
                                        0,
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
                                    final isBeverage = isBeverageProduct(
                                      product,
                                      state.categories,
                                    );
                                    final remainingNormalStock =
                                        _remainingNormalStock(state, product);
                                    final remainingIcedStock =
                                        _remainingIcedStock(state, product);
                                    final remainingPromotionStock =
                                        _remainingPromotionStock(
                                          state,
                                          product,
                                        );
                                    final remainingRegularStoreStock =
                                        _remainingRegularStoreStock(
                                          state,
                                          product,
                                        );
                                    final canAddMore =
                                        remainingNormalStock > 0 ||
                                        remainingIcedStock > 0;

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
                                              isBeverage
                                                  ? 'Normal: $remainingNormalStock | Helada: $remainingIcedStock'
                                                  : 'Tienda: ${product.stockStore}',
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
                                            if (_hasActivePromotion(
                                              state,
                                              product,
                                            )) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                availablePromotionUnits(
                                                          product,
                                                        ) >
                                                        0
                                                    ? 'Promo por lote: $remainingPromotionStock u. | Regular: $remainingRegularStoreStock u.'
                                                    : 'Descuento general activo desde ${SystemWFormatters.currency.format(_activeGeneralPromotionalPrice(state, product) ?? product.salePrice)}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall?.copyWith(
                                                  color:
                                                      selected
                                                          ? Colors.white
                                                          : const Color(
                                                            0xFFEA580C,
                                                          ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                            ],
                                            const Spacer(),
                                            Text(
                                              SystemWFormatters.currency.format(
                                                _effectiveBaseSalePrice(
                                                  state,
                                                  product,
                                                ),
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
                    title: 'Packs',
                    subtitle:
                        state.hasOpenShift
                            ? 'Combos activos armados por admin con lotes de tienda.'
                            : 'Los packs se habilitan al iniciar caja.',
                    child:
                        !state.hasOpenShift
                            ? const EmptyStateCard(
                              title: 'Caja pendiente',
                              caption: 'Inicia caja para poder vender packs.',
                            )
                            : availablePacks.isEmpty
                            ? const EmptyStateCard(
                              title: 'Sin packs disponibles',
                              caption:
                                  'Cuando admin cree packs con stock de tienda apareceran aqui.',
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
                                  itemCount: availablePacks.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.82,
                                      ),
                                  itemBuilder: (context, index) {
                                    final pack = availablePacks[index];
                                    return _PackSaleCard(
                                      pack: pack,
                                      onAdd:
                                          () => ref
                                              .read(
                                                sellerDashboardViewModelProvider
                                                    .notifier,
                                              )
                                              .addPackToCart(pack, 1),
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
                                  state.cartDisplayItems.map((item) {
                                    final availableUnits =
                                        _availableUnitsForItem(state, item);
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _CartItemRow(
                                        item: item,
                                        stockStore: availableUnits,
                                        onDecrease:
                                            () => ref
                                                .read(
                                                  sellerDashboardViewModelProvider
                                                      .notifier,
                                                )
                                                .updateCartQuantity(
                                                  item.cartKey,
                                                  item.quantity - 1,
                                                ),
                                        onIncrease:
                                            item.quantity >= availableUnits
                                                ? null
                                                : () => ref
                                                    .read(
                                                      sellerDashboardViewModelProvider
                                                          .notifier,
                                                    )
                                                    .updateCartQuantity(
                                                      item.cartKey,
                                                      item.quantity + 1,
                                                    ),
                                        onRemove:
                                            () => ref
                                                .read(
                                                  sellerDashboardViewModelProvider
                                                      .notifier,
                                                )
                                                .removeFromCart(item.cartKey),
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
      loading: () {
        // ignore: avoid_print
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stackTrace) {
        // ignore: avoid_print
        return const Center(
          child: Text('No pudimos cargar ventas en este momento.'),
        );
      },
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
    if (nextState.hasPendingShiftApproval || nextState.hasShiftRequest) {
      _initialShiftPromptHandled = true;
      return;
    }
    if (nextState.hasRejectedShiftRequest) {
      _initialShiftPromptHandled = true;
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

    final position = await _resolveShiftPosition(
      locationDisabledMessage:
          'Activa el GPS del dispositivo para poder iniciar caja.',
      permissionDeniedMessage: 'Debes permitir la ubicacion para iniciar caja.',
    );
    if (position == null || !mounted) {
      return;
    }

    final openingAmounts = await _promptOpeningAmounts();
    if (openingAmounts == null || !mounted) {
      return;
    }

    setState(() => _isActionInProgress = true);
    final success = await ref
        .read(sellerDashboardViewModelProvider.notifier)
        .openShift(
          user,
          openingCash: openingAmounts.cash,
          openingYape: openingAmounts.yape,
          openingLatitude: position.latitude,
          openingLongitude: position.longitude,
        );
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

    final currentState = ref.read(sellerDashboardViewModelProvider).valueOrNull;
    final currentShift = currentState?.currentShift;
    if (currentShift == null) {
      return;
    }

    final cashTotal = await _promptAmount(
      title: 'Cerrar caja',
      message:
          'Confirma el total final en efectivo antes de registrar el cierre.',
      fieldLabel: 'Total efectivo',
      confirmLabel: 'Continuar',
      initialValue: currentShift.expectedClosingCash.toStringAsFixed(2),
    );
    if (cashTotal == null || !mounted) {
      return;
    }
    final yapeTotal = await _promptAmount(
      title: 'Cerrar caja',
      message:
          'Confirma el total final por Yape o transferencia para cerrar el turno.',
      fieldLabel: 'Total Yape / Transfer',
      confirmLabel: 'Revisar cierre',
      initialValue: currentShift.expectedClosingYape.toStringAsFixed(2),
    );
    if (yapeTotal == null || !mounted) {
      return;
    }

    final shouldClose = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cerrar caja'),
            content: Text(
              'Se registrara el cierre con Efectivo ${SystemWFormatters.currency.format(cashTotal)} y Yape/Transfer ${SystemWFormatters.currency.format(yapeTotal)}.',
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

    final position = await _resolveShiftPosition(
      locationDisabledMessage:
          'Activa el GPS del dispositivo para poder cerrar caja.',
      permissionDeniedMessage: 'Debes permitir la ubicacion para cerrar caja.',
    );
    if (position == null || !mounted) {
      return;
    }

    setState(() => _isActionInProgress = true);
    final success = await ref
        .read(sellerDashboardViewModelProvider.notifier)
        .closeShift(
          user,
          closingCash: cashTotal,
          closingYape: yapeTotal,
          closingLatitude: position.latitude,
          closingLongitude: position.longitude,
        );
    if (!success) {
      _releaseActionLockIfNoFeedback();
    }
  }

  Future<_ShiftOpeningAmounts?> _promptOpeningAmounts() async {
    final cashController = TextEditingController(text: '0');
    final yapeController = TextEditingController(text: '0');

    return showDialog<_ShiftOpeningAmounts>(
      context: context,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setState) {
            double parseAmount(TextEditingController controller) {
              return double.tryParse(controller.text.trim()) ?? 0;
            }

            return AlertDialog(
              title: const Text('Iniciar caja'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ubicacion registrada. Ingresa el dinero inicial para efectivo y Yape.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cashController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Inicial efectivo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: yapeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Inicial Yape',
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final cash = parseAmount(cashController);
                    final yape = parseAmount(yapeController);
                    if (cash < 0 || yape < 0) {
                      setState(() {
                        errorMessage = 'Los montos no pueden ser negativos.';
                      });
                      return;
                    }
                    Navigator.of(
                      context,
                    ).pop(_ShiftOpeningAmounts(cash: cash, yape: yape));
                  },
                  child: const Text('Iniciar caja'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<double?> _promptAmount({
    required String title,
    required String message,
    required String fieldLabel,
    required String confirmLabel,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);

    return showDialog<double>(
      context: context,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(labelText: fieldLabel),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text.trim());
                    if (value == null || value < 0) {
                      setState(() {
                        errorMessage = 'Ingresa un monto valido.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Position?> _resolveShiftPosition({
    required String locationDisabledMessage,
    required String permissionDeniedMessage,
  }) async {
    final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationEnabled) {
      if (mounted) {
        await showSystemWActionDialog(
          context,
          message: locationDisabledMessage,
          isError: true,
        );
      }
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        await showSystemWActionDialog(
          context,
          message: permissionDeniedMessage,
          isError: true,
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (error) {
      if (mounted) {
        await showSystemWActionDialog(
          context,
          message: 'No pudimos obtener tu ubicacion actual: $error',
          isError: true,
        );
      }
      return null;
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

  Future<void> _signOutWithPendingShiftCleanup(AppUser user) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() => _isActionInProgress = true);
    final success = await ref
        .read(sellerDashboardViewModelProvider.notifier)
        .deletePendingShiftRequest(user);
    if (!success) {
      _releaseActionLockIfNoFeedback();
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
    final availableNormalUnits = _remainingNormalStock(state, product);
    final availableIcedUnits = _remainingIcedStock(state, product);
    final totalAvailableUnits = availableNormalUnits + availableIcedUnits;
    if (totalAvailableUnits <= 0) {
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
    var isIced = availableNormalUnits <= 0 && availableIcedUnits > 0;
    final canSellIced = availableIcedUnits > 0;
    final canSellNormal = availableNormalUnits > 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final maxAddableForMode =
                isIced ? availableIcedUnits : availableNormalUnits;
            final previewSubtotal = _previewSelectionSubtotal(
              state,
              product,
              quantity,
              isIced: isIced,
            );
            final startingPrice = _startingSelectionPrice(
              state,
              product,
              isIced: isIced,
            );
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
                    startingPrice == null
                        ? SystemWFormatters.currency.format(
                          effectiveSalePrice(product, isIced: isIced),
                        )
                        : 'Desde ${SystemWFormatters.currency.format(startingPrice)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Normal: $availableNormalUnits u. | Helada: $availableIcedUnits u.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_hasActivePromotion(state, product)) ...[
                    const SizedBox(height: 8),
                    Text(
                      availablePromotionUnits(product) > 0
                          ? 'Promo por lote: ${availablePromotionUnits(product)} u. desde ${SystemWFormatters.currency.format(bestPromotionalPrice(product) ?? product.salePrice)}.'
                          : 'Descuento general activo desde ${SystemWFormatters.currency.format(_activeGeneralPromotionalPrice(state, product) ?? product.salePrice)}.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFEA580C),
                      ),
                    ),
                  ],
                  if (canSellIced || canSellNormal) ...[
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isIced,
                      onChanged:
                          canSellIced
                              ? (value) {
                                setState(() {
                                  isIced = value;
                                  final modeMax =
                                      isIced
                                          ? availableIcedUnits
                                          : availableNormalUnits;
                                  if (modeMax <= 0) {
                                    quantity = 1;
                                  } else if (quantity > modeMax) {
                                    quantity = modeMax;
                                  }
                                });
                              }
                              : null,
                      secondary: Icon(
                        isIced
                            ? Icons.ac_unit_rounded
                            : Icons.local_drink_rounded,
                      ),
                      title: Text(
                        isIced ? 'Vender como helada' : 'Vender como normal',
                      ),
                      subtitle: Text(
                        isIced
                            ? '$availableIcedUnits u. heladas | Recargo ${SystemWFormatters.currency.format(coldPriceIncrement(product))}'
                            : '$availableNormalUnits u. normales disponibles',
                      ),
                    ),
                  ],
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
                            quantity >= maxAddableForMode
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
                        SystemWFormatters.currency.format(previewSubtotal),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          maxAddableForMode <= 0
                              ? null
                              : () {
                                ref
                                    .read(
                                      sellerDashboardViewModelProvider.notifier,
                                    )
                                    .addToCart(
                                      product,
                                      quantity,
                                      isIced: isIced,
                                    );
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
                  ...state.cartDisplayItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.isIced
                                  ? '${item.displayName} (helada)'
                                  : item.displayName,
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
                      onSelectionChanged:
                          isSubmitting
                              ? null
                              : (selection) {
                                setState(
                                  () => selectedMethod = selection.first,
                                );
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

  int _storeStockForItem(
    SellerDashboardState state,
    String productId, {
    required bool isIced,
  }) {
    for (final product in state.products) {
      if (product.id == productId) {
        return isIced
            ? _remainingIcedStock(state, product)
            : _remainingNormalStock(state, product);
      }
    }
    return 0;
  }

  int _availableUnitsForItem(
    SellerDashboardState state,
    SaleLineDisplayGroup item,
  ) {
    if (item.isPack) {
      final packId = item.primaryLine.packId;
      for (final pack in state.packs) {
        if (pack.id == packId) {
          return pack.availableForSale;
        }
      }
      return item.quantity;
    }

    return _storeStockForItem(
      state,
      item.primaryLine.productId,
      isIced: item.isIced,
    );
  }
}

class _PendingShiftApprovalView extends StatelessWidget {
  const _PendingShiftApprovalView({
    required this.currentUser,
    required this.currentShift,
    required this.onSignOut,
  });

  final AppUser? currentUser;
  final CashShift? currentShift;
  final VoidCallback? onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    if (onSignOut == null) {
      return;
    }

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cerrar sesion'),
            content: const Text(
              'Si cierras sesion, la solicitud de apertura se borrara y tendras que enviarla otra vez.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cerrar sesion'),
              ),
            ],
          ),
    );

    if (shouldSignOut == true) {
      onSignOut!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SectionCard(
              title: 'Esperando aprobacion',
              subtitle:
                  'Solicitud enviada, esperando que el administrador apruebe el turno',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vendedor(a): ${currentUser?.name ?? 'Usuario'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Hora de solicitud',
                    value:
                        currentShift == null
                            ? 'Pendiente'
                            : SystemWFormatters.shortDateTime.format(
                              currentShift!.openedAt,
                            ),
                  ),
                  _SummaryRow(
                    label: 'Monto inicial',
                    value: SystemWFormatters.currency.format(
                      currentShift?.openingAmount ?? 0,
                    ),
                  ),
                  if ((currentShift?.rejectionReason ?? '').trim().isNotEmpty)
                    _SummaryRow(
                      label: 'Observacion',
                      value: currentShift!.rejectionReason!.trim(),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          onSignOut == null
                              ? null
                              : () => _confirmSignOut(context),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Cerrar sesion'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RejectedShiftRequestView extends StatelessWidget {
  const _RejectedShiftRequestView({
    required this.currentUser,
    required this.currentShift,
    required this.onStartShift,
    required this.onSignOut,
  });

  final AppUser? currentUser;
  final CashShift? currentShift;
  final VoidCallback? onStartShift;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final reason = currentShift?.rejectionReason?.trim();
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SectionCard(
              title: 'Solicitud no aprobada',
              subtitle:
                  'El administrador reviso el permiso especial para abrir caja.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vendedora: ${currentUser?.name ?? 'Usuario'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Hora de solicitud',
                    value:
                        currentShift == null
                            ? 'Pendiente'
                            : SystemWFormatters.shortDateTime.format(
                              currentShift!.openedAt,
                            ),
                  ),
                  _SummaryRow(
                    label: 'Monto inicial',
                    value: SystemWFormatters.currency.format(
                      currentShift?.openingAmount ?? 0,
                    ),
                  ),
                  _SummaryRow(
                    label: 'Mensaje',
                    value:
                        reason == null || reason.isEmpty
                            ? 'Sin observacion registrada.'
                            : reason,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: onStartShift,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Solicitar otra vez'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Cerrar sesion'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  final SaleLineDisplayGroup item;
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
                  item.isIced
                      ? '${item.displayName} (helada)'
                      : item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  item.isPack
                      ? 'Packs disponibles: $stockStore u.'
                      : item.isIced
                      ? 'Heladas disponibles: $stockStore u.'
                      : 'Normales disponibles: $stockStore u.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  SystemWFormatters.currency.format(item.subtotal),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF0F766E),
                  ),
                ),
                if (item.isPack ||
                    item.usedPromotionalPrice ||
                    item.isIced) ...[
                  const SizedBox(height: 4),
                  Text(
                    _saleLineDescriptor(item),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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

class _PackSaleCard extends StatelessWidget {
  const _PackSaleCard({required this.pack, required this.onAdd});

  final Pack pack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final itemsLabel = pack.items
        .map(
          (item) =>
              '${item.productName} ${SystemWFormatters.currency.format(item.reducedUnitPrice)}',
        )
        .join(' | ');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onAdd,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pack.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '${pack.items.length} productos | ${pack.availableForSale} disp.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 6),
            Text(
              itemsLabel,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
            ),
            const Spacer(),
            Text(
              SystemWFormatters.currency.format(pack.totalPackPrice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: const Color(0xFF0F766E)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Anadir'),
              ),
            ),
          ],
        ),
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

class _ShiftOpeningAmounts {
  const _ShiftOpeningAmounts({required this.cash, required this.yape});

  final double cash;
  final double yape;
}

bool _isErrorFeedback(String message) {
  return message.trim().toLowerCase().startsWith('no se pudo') ||
      message.trim().toLowerCase().startsWith('solo tienes') ||
      message.trim().toLowerCase().startsWith('la tienda solo tiene') ||
      message.trim().toLowerCase().startsWith('inicia la caja') ||
      message.trim().toLowerCase().startsWith('no hay una caja');
}

String _saleLineDescriptor(SaleLineDisplayGroup item) {
  if (item.isPack) {
    final contents = item.packContentsLabel;
    return contents.isEmpty ? 'pack' : 'pack | $contents';
  }

  final line = item.primaryLine;
  final details = <String>[];
  details.add(line.isIced ? 'estado: helada' : 'estado: normal');
  final originalUnitPrice =
      line.originalUnitPrice ?? line.baseUnitPrice ?? line.unitPrice;
  final baseUnitPrice = line.baseUnitPrice ?? line.unitPrice;
  if (line.usedLotPromotion) {
    details.add('precio promo por lote');
  } else if (originalUnitPrice > baseUnitPrice) {
    details.add('descuento general');
  } else {
    details.add('precio normal');
  }
  if (line.isIced && line.priceAdjustment > 0) {
    details.add(
      'helada +${SystemWFormatters.currency.format(line.priceAdjustment)}',
    );
  }
  return details.join(' | ');
}

double? _startingSelectionPrice(
  SellerDashboardState state,
  Product product, {
  required bool isIced,
}) {
  final lines = _previewSelectionLines(state, product, 1, isIced: isIced);
  if (lines.isEmpty) {
    return null;
  }
  return lines.first.unitPrice;
}

PriceHistoryEntry? _activePriceHistoryEntryForProduct(
  SellerDashboardState state,
  Product product,
) {
  PriceHistoryEntry? activeEntry;
  for (final entry in state.priceHistory) {
    if (entry.productId != product.id || !entry.isActive) {
      continue;
    }
    if (activeEntry == null ||
        entry.effectiveFrom.isAfter(activeEntry.effectiveFrom)) {
      activeEntry = entry;
    }
  }
  return activeEntry;
}

double? _activeGeneralPromotionalPrice(
  SellerDashboardState state,
  Product product,
) {
  final activeEntry = _activePriceHistoryEntryForProduct(state, product);
  final promotionalPrice = activeEntry?.promotionalPrice;
  if (promotionalPrice == null ||
      promotionalPrice <= 0 ||
      promotionalPrice >= product.salePrice) {
    return null;
  }
  return promotionalPrice;
}

bool _hasActivePromotion(SellerDashboardState state, Product product) {
  return _activeGeneralPromotionalPrice(state, product) != null ||
      availablePromotionUnits(product) > 0;
}

double _effectiveBaseSalePrice(SellerDashboardState state, Product product) {
  final generalPrice = _activeGeneralPromotionalPrice(state, product);
  final lotPrice = bestPromotionalPrice(product);

  var effectivePrice = product.salePrice;
  if (generalPrice != null && generalPrice < effectivePrice) {
    effectivePrice = generalPrice;
  }
  if (lotPrice != null && lotPrice < effectivePrice) {
    effectivePrice = lotPrice;
  }

  return effectivePrice;
}

double _previewSelectionSubtotal(
  SellerDashboardState state,
  Product product,
  int quantity, {
  required bool isIced,
}) {
  return _previewSelectionLines(
    state,
    product,
    quantity,
    isIced: isIced,
  ).fold(0, (sum, item) => sum + item.subtotal);
}

List<SaleLine> _previewSelectionLines(
  SellerDashboardState state,
  Product product,
  int quantity, {
  required bool isIced,
}) {
  if (quantity <= 0) {
    return const [];
  }

  final priceAdjustment = isIced ? coldPriceIncrement(product) : 0.0;
  final lines = <SaleLine>[];
  var remainingQuantity = quantity;
  var reservedPromotionUnits = state.promotionalQuantityInCart(product.id);
  final generalPromotionalPrice = _activeGeneralPromotionalPrice(
    state,
    product,
  );

  for (final offer in activePromotionOffers(product)) {
    if (remainingQuantity <= 0) {
      break;
    }

    var availablePromoUnits = offer.allocatableUnits;
    if (reservedPromotionUnits >= availablePromoUnits) {
      reservedPromotionUnits -= availablePromoUnits;
      continue;
    }
    if (reservedPromotionUnits > 0) {
      availablePromoUnits -= reservedPromotionUnits;
      reservedPromotionUnits = 0;
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
    final fallbackUnitPrice = generalPromotionalPrice ?? product.salePrice;
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
        usedPromotionalPrice: generalPromotionalPrice != null,
        usedLotPromotion: false,
      ),
    );
  }

  return lines;
}

int _remainingIcedStock(SellerDashboardState state, Product product) {
  final icedStock = _icedStockForProduct(product);
  final remaining = icedStock - state.icedQuantityInCart(product.id);
  return remaining < 0 ? 0 : remaining;
}

int _remainingNormalStock(SellerDashboardState state, Product product) {
  final normalStock = _normalStockForProduct(product);
  final remaining = normalStock - state.normalQuantityInCart(product.id);
  return remaining < 0 ? 0 : remaining;
}

int _remainingPromotionStock(SellerDashboardState state, Product product) {
  final remaining =
      availablePromotionUnits(product) -
      state.promotionalQuantityInCart(product.id);
  return remaining < 0 ? 0 : remaining;
}

int _remainingRegularStoreStock(SellerDashboardState state, Product product) {
  final remainingStore = product.stockStore - state.quantityInCart(product.id);
  final remaining = remainingStore - _remainingPromotionStock(state, product);
  return remaining < 0 ? 0 : remaining;
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

void _debugSellerPacksView({
  required bool hasOpenShift,
  required List<Pack> packs,
  required List<Pack> availablePacks,
}) {}

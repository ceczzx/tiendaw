// ignore_for_file: unused_element_parameter, unused_element, unnecessary_null_comparison, unused_local_variable

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/providers.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/product_pricing_rules.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/purchases/presentation/admin_mobile_dashboard_view_model.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

enum _AdminMobileSection {
  home,
  purchases,
  suppliers,
  promotions,
  packs,
  losses,
  movements,
}

typedef _PurchaseCartSubmit = Future<bool> Function();
typedef _PromotionSubmit =
    Future<bool> Function({
      required String purchaseItemId,
      required int promotionalQuantity,
      required double promotionalPrice,
      String? promotionNote,
    });
typedef _PromotionClearSubmit = Future<bool> Function(String promotionId);
typedef _GeneralPromotionSubmit =
    Future<bool> Function({
      required String productId,
      required double promotionalPrice,
      String? promotionNote,
      DateTime? scheduledEndAt,
    });
typedef _GeneralPromotionClearSubmit =
    Future<bool> Function({required String productId});
typedef _LossSubmit =
    Future<bool> Function({
      required String purchaseItemId,
      required int quantity,
      required String reason,
      String? notes,
      String? storageCondition,
    });
typedef _ColdStateSubmit =
    Future<bool> Function({
      required String productId,
      required int coldStockUnits,
      required double coldPriceIncrement,
    });
typedef _MovementCartSubmit = Future<bool> Function();
typedef _PackSubmit =
    Future<bool> Function({
      required String name,
      required List<PackDraftItem> items,
    });

final _warehouseSupplierLotsProvider = FutureProvider.autoDispose
    .family<List<WarehouseSupplierLot>, String>((ref, productId) async {
      return ref
          .read(catalogRepositoryProvider)
          .getWarehouseSupplierLots(productId: productId);
    });

final _storeSupplierLotsProvider = FutureProvider.autoDispose
    .family<List<WarehouseSupplierLot>, String>((ref, productId) async {
      return ref
          .read(catalogRepositoryProvider)
          .getStoreSupplierLots(productId: productId);
    });

class AdminMobileDashboardPage extends ConsumerStatefulWidget {
  const AdminMobileDashboardPage({super.key});

  @override
  ConsumerState<AdminMobileDashboardPage> createState() =>
      _AdminMobileDashboardPageState();
}

class _AdminMobileDashboardPageState
    extends ConsumerState<AdminMobileDashboardPage> {
  _AdminMobileSection _activeSection = _AdminMobileSection.home;
  bool _isPurchaseComposerOpen = false;
  bool _isActionInProgress = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AdminMobileDashboardState>>(
      adminMobileDashboardViewModelProvider,
      (previous, next) {
        if (!mounted) {
          return;
        }

        _showActionFeedback(
          context: context,
          previousMessage: previous?.valueOrNull?.feedbackMessage,
          nextMessage: next.valueOrNull?.feedbackMessage,
        );
      },
    );

    final dashboard = ref.watch(adminMobileDashboardViewModelProvider);
    final currentUser =
        ref.watch(sessionViewModelProvider).valueOrNull?.currentUser;

    return dashboard.when(
      data: (state) {
        return SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_activeSection),
                    child: _buildSectionContent(state, currentUser),
                  ),
                ),
              ),
              const Divider(height: 1),
              _AdminSectionStrip(
                activeSection: _activeSection,
                onSectionSelected: (section) {
                  setState(() {
                    _activeSection = section;
                  });
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (_, _) => const Center(
            child: Text('No pudimos cargar operaciones en este momento.'),
          ),
    );
  }

  Widget _buildSectionContent(
    AdminMobileDashboardState state,
    AppUser? currentUser,
  ) {
    return switch (_activeSection) {
      _AdminMobileSection.home => _HomeSection(
        state: state,
        onOpenPurchaseComposer: () {
          setState(() {
            _activeSection = _AdminMobileSection.purchases;
            _isPurchaseComposerOpen = true;
          });
        },
        onOpenSuppliers: () {
          setState(() {
            _activeSection = _AdminMobileSection.suppliers;
          });
        },
        onOpenMovements: () {
          setState(() {
            _activeSection = _AdminMobileSection.movements;
          });
        },
      ),
      _AdminMobileSection.purchases => _PurchasesSection(
        state: state,
        isComposerOpen: _isPurchaseComposerOpen,
        isBusy: _isActionInProgress,
        currentUser: currentUser,
        onToggleComposer: () {
          setState(() {
            _isPurchaseComposerOpen = !_isPurchaseComposerOpen;
          });
        },
        onSubmitPurchaseCart:
            currentUser == null ? null : _buildPurchaseCartSubmit(currentUser),
      ),
      _AdminMobileSection.suppliers => _SuppliersSection(state: state),
      _AdminMobileSection.promotions => _PromotionsSection(
        state: state,
        isBusy: _isActionInProgress,
        onUpdatePromotion: _handlePromotionUpdate,
        onClearPromotion: _handlePromotionClear,
        onSaveGeneralPromotion: _handleSaveGeneralPromotion,
        onClearGeneralPromotion: _handleClearGeneralPromotion,
      ),
      _AdminMobileSection.packs => _PacksSection(
        state: state,
        isBusy: _isActionInProgress,
        onCreatePack: _handleCreatePack,
      ),
      _AdminMobileSection.losses => _LossesSection(
        state: state,
        isBusy: _isActionInProgress,
        onRegisterLoss: _handleRegisterLoss,
      ),
      _AdminMobileSection.movements => _MovementsSection(
        state: state,
        isBusy: _isActionInProgress,
        currentUser: currentUser,
        onSubmitMovementCart:
            currentUser == null ? null : _handleMovementCartSubmit,
        onUpdateColdState: _handleColdStateUpdate,
      ),
    };
  }

  Future<bool> _handlePurchaseCartSubmit(AppUser currentUser) async {
    if (_isActionInProgress) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    final success = await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .registerPurchaseCart(currentUser);

    if (!mounted || !success) {
      return false;
    }

    setState(() {
      _isPurchaseComposerOpen = false;
    });

    return true;
  }

  Future<bool> _handleMovementCartSubmit() async {
    if (_isActionInProgress) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    return ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .registerMovementCart();
  }

  Future<bool> _handlePromotionUpdate({
    required String purchaseItemId,
    required int promotionalQuantity,
    required double promotionalPrice,
    String? promotionNote,
  }) async {
    if (_isActionInProgress) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    return ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .activateLotPromotion(
          purchaseItemId: purchaseItemId,
          promotionalQuantity: promotionalQuantity,
          promotionalPrice: promotionalPrice,
          promotionNote: promotionNote,
        );
  }

  Future<bool> _handlePromotionClear(String promotionId) async {
    if (_isActionInProgress) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    return ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .cancelLotPromotion(promotionId);
  }

  Future<bool> _handleSaveGeneralPromotion({
    required String productId,
    required double promotionalPrice,
    String? promotionNote,
    DateTime? scheduledEndAt,
  }) async {
    if (_isActionInProgress) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    return ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .upsertGeneralPromotion(
          productId: productId,
          promotionalPrice: promotionalPrice,
          promotionNote: promotionNote,
          scheduledEndAt: scheduledEndAt,
        );
  }

  Future<bool> _handleApproveShiftRequest(CashShift shift) async {
    final currentUser =
        ref.read(sessionViewModelProvider).valueOrNull?.currentUser;
    if (_isActionInProgress || currentUser == null) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    return ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .approveShiftRequest(shiftId: shift.id, adminId: currentUser.id);
  }

  Future<bool> _handleRejectShiftRequest({
    required CashShift shift,
    required String rejectionReason,
  }) async {
    final currentUser =
        ref.read(sessionViewModelProvider).valueOrNull?.currentUser;
    if (_isActionInProgress || currentUser == null) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    return ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .rejectShiftRequest(
          shiftId: shift.id,
          adminId: currentUser.id,
          rejectionReason: rejectionReason,
        );
  }

  Future<bool> _handleClearGeneralPromotion({required String productId}) async {
    if (_isActionInProgress) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    return ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .clearGeneralPromotion(productId: productId);
  }

  Future<bool> _handleCreatePack({
    required String name,
    required List<PackDraftItem> items,
  }) async {
    if (_isActionInProgress) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    return ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .createPack(name: name, items: items);
  }

  Future<bool> _handleRegisterLoss({
    required String purchaseItemId,
    required int quantity,
    required String reason,
    String? notes,
    String? storageCondition,
  }) async {
    if (_isActionInProgress) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    return ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .registerInventoryLoss(
          purchaseItemId: purchaseItemId,
          quantity: quantity,
          reason: reason,
          notes: notes,
          storageCondition: storageCondition,
        );
  }

  Future<bool> _handleColdStateUpdate({
    required String productId,
    required int coldStockUnits,
    required double coldPriceIncrement,
  }) async {
    if (_isActionInProgress) {
      return false;
    }

    setState(() {
      _isActionInProgress = true;
    });
    return ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .updateProductColdState(
          productId: productId,
          coldStockUnits: coldStockUnits,
          coldPriceIncrement: coldPriceIncrement,
        );
  }

  _PurchaseCartSubmit _buildPurchaseCartSubmit(AppUser currentUser) {
    return () => _handlePurchaseCartSubmit(currentUser);
  }

  void _showActionFeedback({
    required BuildContext context,
    required String? previousMessage,
    required String? nextMessage,
  }) {
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
      await ref
          .read(adminMobileDashboardViewModelProvider.notifier)
          .clearFeedback();
      if (!mounted) {
        return;
      }
      setState(() {
        _isActionInProgress = false;
      });
    });
  }
}

class _AdminSectionStrip extends StatelessWidget {
  const _AdminSectionStrip({
    required this.activeSection,
    required this.onSectionSelected,
  });

  final _AdminMobileSection activeSection;
  final ValueChanged<_AdminMobileSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final items =
        <({IconData icon, String label, _AdminMobileSection section})>[
          (
            icon: Icons.home_rounded,
            label: 'Inicio',
            section: _AdminMobileSection.home,
          ),
          (
            icon: Icons.shopping_bag_rounded,
            label: 'Compras',
            section: _AdminMobileSection.purchases,
          ),
          (
            icon: Icons.local_shipping_rounded,
            label: 'Proveedores',
            section: _AdminMobileSection.suppliers,
          ),
          (
            icon: Icons.local_offer_rounded,
            label: 'Promociones',
            section: _AdminMobileSection.promotions,
          ),
          (
            icon: Icons.inventory_rounded,
            label: 'Packs',
            section: _AdminMobileSection.packs,
          ),
          (
            icon: Icons.inventory_2_rounded,
            label: 'Perdidas',
            section: _AdminMobileSection.losses,
          ),
          (
            icon: Icons.swap_horiz_rounded,
            label: 'Movimientos',
            section: _AdminMobileSection.movements,
          ),
        ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              items.map((item) {
                final selected = item.section == activeSection;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 18),
                        const SizedBox(width: 6),
                        Text(item.label),
                      ],
                    ),
                    onSelected: (_) => onSectionSelected(item.section),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }
}

class _HomeSection extends StatefulWidget {
  const _HomeSection({
    required this.state,
    required this.onOpenPurchaseComposer,
    required this.onOpenSuppliers,
    required this.onOpenMovements,
  });

  final AdminMobileDashboardState state;
  final VoidCallback onOpenPurchaseComposer;
  final VoidCallback onOpenSuppliers;
  final VoidCallback onOpenMovements;

  @override
  State<_HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends State<_HomeSection> {
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _selectedProductId =
        widget.state.selectedProductId ??
        (widget.state.products.isEmpty ? null : widget.state.products.first.id);
  }

  @override
  void didUpdateWidget(covariant _HomeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.state.products.any(
      (product) => product.id == _selectedProductId,
    )) {
      _selectedProductId =
          widget.state.products.isEmpty ? null : widget.state.products.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final supplierCount = _uniqueSupplierCount(state);
    Product? selectedProduct;
    for (final product in state.products) {
      if (product.id == _selectedProductId) {
        selectedProduct = product;
        break;
      }
    }
    selectedProduct ??= state.products.isEmpty ? null : state.products.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Inicio',
            subtitle:
                'Anade compra de productos, revisa proveedores y mueve stock sin mezclar todo en una sola pantalla.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Flujo rapido',
            subtitle:
                'El admin navega por compras, detalle de proveedores y movimientos con resumen antes de confirmar.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Si una categoria, un producto o un proveedor no existen, el formulario de compras te deja crearlos desde el mismo flujo.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: widget.onOpenPurchaseComposer,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('Agregar compra'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenSuppliers,
                      icon: const Icon(Icons.local_shipping_rounded),
                      label: const Text('Ver proveedores'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenMovements,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Mover stock'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _MetricWrap(
            children: [
              MetricCard(
                label: 'Productos',
                value: '${state.products.length}',
                detail: 'Catalogo listo para compras y traslados',
                accent: const Color(0xFF0F766E),
              ),
              MetricCard(
                label: 'Proveedores',
                value: '$supplierCount',
                detail: 'Detectados desde compras e historial de precios',
                accent: const Color(0xFFEA580C),
              ),
              MetricCard(
                label: 'Movimientos',
                value: '${state.movements.length}',
                detail: 'Bitacora operativa entre almacen y tienda',
                accent: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Productos',
            subtitle:
                'Selecciona un producto para revisar sus detalles, stock y especificaciones.',
            child:
                state.products.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin productos registrados',
                      caption:
                          'Cuando existan productos en la tabla products apareceran aqui.',
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedProduct?.id,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Producto',
                          ),
                          items:
                              state.products
                                  .map(
                                    (product) => DropdownMenuItem(
                                      value: product.id,
                                      child: Text(product.name),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedProductId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (selectedProduct != null)
                          _ProductInsightCard(
                            state: state,
                            product: selectedProduct,
                          ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({
    required this.state,
    required this.currentUser,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final AdminMobileDashboardState state;
  final AppUser? currentUser;
  final bool isBusy;
  final Future<bool> Function(CashShift shift) onApprove;
  final Future<bool> Function({
    required CashShift shift,
    required String rejectionReason,
  })
  onReject;

  @override
  Widget build(BuildContext context) {
    final pendingShifts = state.pendingShiftApprovals;
    final answeredShifts =
        state.cashShifts
            .where(
              (shift) =>
                  shift.status == CashShiftStatus.approved ||
                  shift.status == CashShiftStatus.rejected,
            )
            .take(5)
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Permisos',
            subtitle:
                'Revisa solicitudes especiales de apertura de caja y responde con aprobacion o mensaje.',
          ),
          const SizedBox(height: 16),
          _MetricWrap(
            children: [
              MetricCard(
                label: 'Pendientes',
                value: '${pendingShifts.length}',
                detail: 'Solicitudes esperando respuesta',
                accent: const Color(0xFFEA580C),
              ),
              MetricCard(
                label: 'Respondidas',
                value: '${answeredShifts.length}',
                detail: 'Ultimas decisiones de permisos',
                accent: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Notificaciones de caja',
            subtitle:
                'Solo aparecen los turnos que Supabase marco para aprobacion especial.',
            child:
                pendingShifts.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin permisos pendientes',
                      caption:
                          'Cuando un vendedor solicite apertura especial, aparecera aqui.',
                    )
                    : Column(
                      children:
                          pendingShifts
                              .map(
                                (shift) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _ShiftApprovalCard(
                                    shift: shift,
                                    isBusy: isBusy || currentUser == null,
                                    onApprove: () => onApprove(shift),
                                    onReject:
                                        (reason) => onReject(
                                          shift: shift,
                                          rejectionReason: reason,
                                        ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
          ),
          if (answeredShifts.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Ultimas respuestas',
              subtitle:
                  'Lectura rapida de permisos aprobados o rechazados recientemente.',
              child: Column(
                children:
                    answeredShifts
                        .map(
                          (shift) => _AnsweredShiftTile(
                            shift: shift,
                            key: ValueKey(shift.id),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShiftApprovalCard extends StatelessWidget {
  const _ShiftApprovalCard({
    required this.shift,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final CashShift shift;
  final bool isBusy;
  final Future<bool> Function() onApprove;
  final Future<bool> Function(String rejectionReason) onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.sellerName ?? 'Vendedor',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Solicitado ${SystemWFormatters.shortDateTime.format(shift.openedAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(
            label: 'Monto inicial',
            value: SystemWFormatters.currency.format(shift.openingAmount),
          ),
          _InfoLine(label: 'Lugar inicio', value: _shiftOpeningPlace(shift)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: isBusy ? null : onApprove,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Aceptar'),
              ),
              OutlinedButton.icon(
                onPressed:
                    isBusy
                        ? null
                        : () async {
                          final reason = await _promptRejectionReason(context);
                          if (reason == null) {
                            return;
                          }
                          await onReject(reason);
                        },
                icon: const Icon(Icons.close_rounded),
                label: const Text('Rechazar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _promptRejectionReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rechazar permiso'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mensaje para el vendedor',
                hintText: 'Explica por que no se aprueba la apertura.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Enviar respuesta'),
              ),
            ],
          ),
    );
  }
}

class _AnsweredShiftTile extends StatelessWidget {
  const _AnsweredShiftTile({required this.shift, super.key});

  final CashShift shift;

  @override
  Widget build(BuildContext context) {
    final isRejected = shift.status == CashShiftStatus.rejected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            label: isRejected ? 'Rechazado' : 'Aprobado',
            background:
                isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
            foreground:
                isRejected ? const Color(0xFFB91C1C) : const Color(0xFF047857),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.sellerName ?? 'Vendedor',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  SystemWFormatters.shortDateTime.format(shift.openedAt),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if ((shift.rejectionReason ?? '').trim().isNotEmpty)
                  Text(
                    shift.rejectionReason!.trim(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PacksSection extends ConsumerStatefulWidget {
  const _PacksSection({
    required this.state,
    required this.isBusy,
    required this.onCreatePack,
  });

  final AdminMobileDashboardState state;
  final bool isBusy;
  final _PackSubmit onCreatePack;

  @override
  ConsumerState<_PacksSection> createState() => _PacksSectionState();
}

class _PacksSectionState extends ConsumerState<_PacksSection> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final List<PackDraftItem> _draftItems = [];
  String? _selectedProductId;
  String? _selectedBatchId;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.state.products.where((p) => p.stockStore > 0).toList();
    final selectedProduct = _productById(products, _selectedProductId);
    final lotsAsync =
        selectedProduct == null
            ? const AsyncData<List<WarehouseSupplierLot>>([])
            : ref.watch(_storeSupplierLotsProvider(selectedProduct.id));
    final lots = lotsAsync.valueOrNull ?? const <WarehouseSupplierLot>[];
    final selectedLot = _lotById(lots, _selectedBatchId);
    final totalPrice = _draftItems.fold<double>(
      0,
      (sum, item) => sum + item.totalReducedPrice,
    );
    final totalCost = _draftItems.fold<double>(
      0,
      (sum, item) => sum + item.totalCost,
    );
    final profit = totalPrice - totalCost;
    final statusColor =
        profit > 0
            ? const Color(0xFF047857)
            : profit == 0
            ? const Color(0xFFB45309)
            : const Color(0xFFB91C1C);
    final statusLabel = profit > 0 ? 'Ganancia' : profit == 0 ? 'Neutral' : 'Perdida';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Packs',
            subtitle:
                'Arma packs con dos o mas productos, seleccionando estrictamente el lote de tienda para cada linea.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Crear pack',
            subtitle:
                'Selecciona producto, lote, cantidad y precio minimo por unidad.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre del pack'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedProduct?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Producto'),
                  items:
                      products
                          .map(
                            (product) => DropdownMenuItem(
                              value: product.id,
                              child: Text(product.name),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProductId = value;
                      _selectedBatchId = null;
                      _priceController.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),
                lotsAsync.isLoading
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<String>(
                      value: selectedLot?.purchaseItemId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Lote de tienda'),
                      items:
                          lots
                              .map(
                                (lot) => DropdownMenuItem(
                                  value: lot.purchaseItemId,
                                  child: Text(_packLotLabel(selectedProduct, lot)),
                                ),
                              )
                              .toList(),
                      onChanged:
                          selectedProduct == null
                              ? null
                              : (value) {
                                final lot = _lotById(lots, value);
                                setState(() {
                                  _selectedBatchId = value;
                                  _priceController.text =
                                      (selectedProduct.promotionalPrice ??
                                              selectedProduct.salePrice)
                                          .toStringAsFixed(2);
                                  if (lot != null && lot.availableUnits <= 0) {
                                    _errorMessage = 'El lote no tiene stock.';
                                  }
                                });
                              },
                    ),
                if (selectedProduct != null && selectedLot != null) ...[
                  const SizedBox(height: 12),
                  _InfoLine(
                    label: 'Costo unitario',
                    value: SystemWFormatters.currency.format(selectedLot.unitCost),
                  ),
                  _InfoLine(
                    label: 'Precio venta',
                    value: SystemWFormatters.currency.format(selectedProduct.salePrice),
                  ),
                  _InfoLine(
                    label: 'FV',
                    value:
                        selectedLot.expiryDate == null
                            ? 'Sin FV'
                            : SystemWFormatters.shortDate.format(selectedLot.expiryDate!),
                  ),
                  _InfoLine(label: 'Disponible tienda', value: '${selectedLot.availableUnits} u.'),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Cantidad'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        decoration: const InputDecoration(labelText: 'Precio minimo'),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFB91C1C),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      selectedProduct == null || selectedLot == null
                          ? null
                          : () => _addDraftItem(selectedProduct, selectedLot),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar producto'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Resumen del pack',
            subtitle:
                'El precio final se calcula con los precios minimos ingresados.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _draftItems.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin productos en el pack',
                      caption: 'Agrega al menos dos productos distintos.',
                    )
                    : Column(
                      children:
                          _draftItems.asMap().entries.map((entry) {
                            final item = entry.value;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.productName),
                              subtitle: Text(
                                'x${item.quantity} | ${SystemWFormatters.currency.format(item.reducedUnitPrice)} c/u | FV ${item.expiryDate == null ? 'Sin FV' : SystemWFormatters.shortDate.format(item.expiryDate!)}',
                              ),
                              trailing: IconButton(
                                onPressed:
                                    () => setState(
                                      () => _draftItems.removeAt(entry.key),
                                    ),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            );
                          }).toList(),
                    ),
                const Divider(height: 24),
                _InfoLine(label: 'Costo', value: SystemWFormatters.currency.format(totalCost)),
                _InfoLine(label: 'Precio pack', value: SystemWFormatters.currency.format(totalPrice)),
                _InfoLine(
                  label: statusLabel,
                  value: SystemWFormatters.currency.format(profit),
                  isStrong: true,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value:
                      totalPrice <= 0
                          ? 0
                          : (totalCost / totalPrice).clamp(0, 1).toDouble(),
                  color: statusColor,
                  backgroundColor: statusColor.withAlpha(40),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.isBusy ? null : _submitPack,
                    icon: const Icon(Icons.inventory_rounded),
                    label: const Text('Guardar pack'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Packs activos',
            subtitle: 'Stock disponible solo en tienda y margen actual.',
            child:
                widget.state.packs.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin packs registrados',
                      caption: 'Los packs creados apareceran aqui.',
                    )
                    : Column(
                      children:
                          widget.state.packs.map((pack) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(pack.name),
                              subtitle: Text(
                                '${pack.items.length} productos | tienda ${pack.availableInStore} packs',
                              ),
                              trailing: Text(
                                '${SystemWFormatters.currency.format(pack.totalPackPrice)}\n${SystemWFormatters.currency.format(pack.margin)}',
                                textAlign: TextAlign.right,
                              ),
                            );
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }

  void _addDraftItem(Product product, WarehouseSupplierLot lot) {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    if (quantity <= 0 || quantity > lot.availableUnits) {
      setState(() {
        _errorMessage = 'La cantidad debe estar entre 1 y ${lot.availableUnits}.';
      });
      return;
    }
    if (price <= 0) {
      setState(() {
        _errorMessage = 'Ingresa un precio minimo valido.';
      });
      return;
    }

    setState(() {
      _draftItems.add(
        PackDraftItem(
          productId: product.id,
          productName: product.name,
          batchId: lot.purchaseItemId,
          quantity: quantity,
          reducedUnitPrice: price,
          unitCost: lot.unitCost,
          salePrice: product.salePrice,
          storeAvailableUnits: lot.availableUnits,
          expiryDate: lot.expiryDate,
        ),
      );
      _quantityController.text = '1';
      _priceController.clear();
      _selectedBatchId = null;
      _errorMessage = null;
    });
  }

  Future<void> _submitPack() async {
    final distinctProducts = _draftItems.map((item) => item.productId).toSet();
    if (distinctProducts.length < 2) {
      setState(() {
        _errorMessage = 'El pack debe tener dos o mas productos distintos.';
      });
      return;
    }
    final success = await widget.onCreatePack(
      name: _nameController.text.trim(),
      items: List<PackDraftItem>.unmodifiable(_draftItems),
    );
    if (!success || !mounted) {
      return;
    }
    setState(() {
      _nameController.clear();
      _draftItems.clear();
      _errorMessage = null;
    });
  }
}

class _PurchasesSection extends StatefulWidget {
  const _PurchasesSection({
    required this.state,
    required this.isComposerOpen,
    required this.isBusy,
    required this.currentUser,
    required this.onToggleComposer,
    required this.onSubmitPurchaseCart,
  });

  final AdminMobileDashboardState state;
  final bool isComposerOpen;
  final bool isBusy;
  final AppUser? currentUser;
  final VoidCallback onToggleComposer;
  final _PurchaseCartSubmit? onSubmitPurchaseCart;

  @override
  State<_PurchasesSection> createState() => _PurchasesSectionState();
}

class _PurchasesSectionState extends State<_PurchasesSection> {
  String? _selectedHistoryProductId;

  @override
  void didUpdateWidget(covariant _PurchasesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isComposerOpen) {
      _selectedHistoryProductId = null;
      return;
    }

    if (_selectedHistoryProductId != null &&
        !widget.state.products.any(
          (product) => product.id == _selectedHistoryProductId,
        )) {
      _selectedHistoryProductId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final productById = {
      for (final product in state.products) product.id: product,
    };
    final effectiveHistoryProductId =
        widget.isComposerOpen ? _selectedHistoryProductId : null;
    final selectedPriceHistoryProduct = productById[effectiveHistoryProductId];
    final priceHistoryItems =
        effectiveHistoryProductId == null
            ? state.priceHistory
            : state.priceHistory
                .where((entry) => entry.productId == effectiveHistoryProductId)
                .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Compras',
            subtitle:
                'Abastecimiento con carrito de compras, historial operativo y confirmacion acumulada por proveedor.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Carrito de compras',
            subtitle:
                'Agrega varios productos a una misma compra. Si algo no existe, puedes crearlo desde este mismo flujo.',
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.isBusy ? null : widget.onToggleComposer,
                    icon: Icon(
                      widget.isComposerOpen
                          ? Icons.expand_less_rounded
                          : Icons.add_rounded,
                    ),
                    label: Text(
                      widget.isComposerOpen
                          ? 'Ocultar formulario'
                          : 'Agregar compra',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.isComposerOpen)
                  _PurchaseForm(
                    state: state,
                    isBusy: widget.isBusy,
                    currentUser: widget.currentUser,
                    onSubmitPurchaseCart: widget.onSubmitPurchaseCart,
                    onHistoryProductChanged: (productId) {
                      setState(() {
                        _selectedHistoryProductId = productId;
                      });
                    },
                  )
                else
                  const EmptyStateCard(
                    title: 'Formulario oculto',
                    caption:
                        'Abre el formulario para elegir categoria, proveedor y producto antes de registrar la compra.',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Historial de precios',
            subtitle:
                selectedPriceHistoryProduct == null
                    ? 'Ultimos precios de venta y ajustes de bebidas por producto.'
                    : 'Solo muestra el historial de ${selectedPriceHistoryProduct.name}.',
            child:
                priceHistoryItems.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin historial de precios',
                      caption:
                          'Cuando registres o ajustes precios, apareceran aqui.',
                    )
                    : _PaginatedList<PriceHistoryEntry>(
                      items: priceHistoryItems,
                      itemBuilder: (context, entry) {
                        final priceLabel =
                            entry.promotionalPrice == null
                                ? 'Venta ${SystemWFormatters.currency.format(entry.salePrice)}'
                                : 'Venta ${SystemWFormatters.currency.format(entry.salePrice)} | Promo ${SystemWFormatters.currency.format(entry.promotionalPrice!)}';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.productName),
                          subtitle: Text(
                            '${entry.createdByName} - ${SystemWFormatters.shortDate.format(entry.effectiveFrom)}${entry.isActive ? ' - vigente' : ''}',
                          ),
                          trailing: Text(
                            priceLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        );
                      },
                    ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Compras recientes',
            subtitle: 'Trazabilidad operativa de abastecimiento.',
            child:
                state.purchases.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin compras registradas',
                      caption: 'Las nuevas compras apareceran aqui.',
                    )
                    : _PaginatedList<Purchase>(
                      items: state.purchases,
                      itemBuilder: (context, purchase) {
                        return ListTile(
                          isThreeLine: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(purchase.supplier),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${purchase.registeredBy} - ${SystemWFormatters.shortDateTime.format(purchase.receivedAt)}',
                              ),
                              const SizedBox(height: 4),
                              Text(_purchaseItemsBreakdownLabel(purchase)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                SystemWFormatters.currency.format(
                                  purchase.total,
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _SuppliersSection extends StatefulWidget {
  const _SuppliersSection({required this.state});

  final AdminMobileDashboardState state;

  @override
  State<_SuppliersSection> createState() => _SuppliersSectionState();
}

class _SuppliersSectionState extends State<_SuppliersSection> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId =
        widget.state.categories.isEmpty
            ? null
            : widget.state.categories.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final supplierSummaries = _buildSupplierSummaries(state);
    final selectedCategoryId =
        state.categories.any((category) => category.id == _selectedCategoryId)
            ? _selectedCategoryId
            : state.categories.isEmpty
            ? null
            : state.categories.first.id;
    final categoryDetails =
        selectedCategoryId == null
            ? const <_CategoryDetailRow>[]
            : _buildCategoryDetailRows(state, selectedCategoryId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Proveedores',
            subtitle:
                'Selecciona una categoria y revisa a detalle sus proveedores, productos comprados, cantidades y precios.',
          ),
          const SizedBox(height: 16),
          _MetricWrap(
            children: [
              MetricCard(
                label: 'Proveedores',
                value: '${supplierSummaries.length}',
                detail: 'Con compras registradas en el historial',
                accent: const Color(0xFF0F766E),
              ),
              MetricCard(
                label: 'Productos',
                value: '${state.products.length}',
                detail: 'Disponibles para analisis por categoria',
                accent: const Color(0xFFEA580C),
              ),
              MetricCard(
                label: 'Categorias',
                value: '${state.categories.length}',
                detail: 'Seleccionables para el detalle admin',
                accent: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Historial de proveedores',
            subtitle:
                'Resumen agrupado por proveedor con monto total y ultima compra registrada.',
            child:
                supplierSummaries.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin proveedores registrados',
                      caption:
                          'Las compras y los precios historicos alimentaran esta lista.',
                    )
                    : _PaginatedList<_SupplierSummary>(
                      items: supplierSummaries,
                      itemBuilder: (context, summary) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(summary.name),
                          subtitle: Text(
                            summary.phone == null || summary.phone!.isEmpty
                                ? '${summary.categoriesLabel} - ${summary.purchaseCount} compras'
                                : '${summary.categoriesLabel}\nTel: ${summary.phone}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                SystemWFormatters.currency.format(
                                  summary.total,
                                ),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                SystemWFormatters.shortDate.format(
                                  summary.lastPurchaseAt,
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Detalle por categoria',
            subtitle:
                'Elige una categoria para ver proveedores, productos, cantidades y precios costo/venta.',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items:
                      state.categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(_categoryOptionLabel(category)),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (selectedCategoryId == null)
                  const EmptyStateCard(
                    title: 'Sin categorias registradas',
                    caption: 'Crea categorias para poder analizar proveedores.',
                  )
                else if (categoryDetails.isEmpty)
                  const EmptyStateCard(
                    title: 'Sin compras para esta categoria',
                    caption:
                        'Cuando se registren compras en esta categoria, veras aqui el detalle.',
                  )
                else
                  _PaginatedList<_CategoryDetailRow>(
                    items: categoryDetails,
                    itemBuilder: (context, detail) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.productName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Proveedor: ${detail.supplierName}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (detail.supplierPhone != null &&
                                detail.supplierPhone!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Tel: ${detail.supplierPhone}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _InfoLine(
                              label: _purchaseQuantityInfoLabel(
                                detail.productType,
                              ),
                              value:
                                  '${detail.packageQuantity} ${_purchaseQuantityNoun(detail.productType)}',
                            ),
                            _InfoLine(
                              label: 'Unidades resultantes',
                              value: '${detail.totalUnits} u.',
                            ),
                            _InfoLine(
                              label: 'Precio costo',
                              value: SystemWFormatters.currency.format(
                                detail.costPrice,
                              ),
                            ),
                            _InfoLine(
                              label: 'Precio venta',
                              value: SystemWFormatters.currency.format(
                                detail.salePrice,
                              ),
                            ),
                            _InfoLine(
                              label: 'Inicio',
                              value: SystemWFormatters.shortDate.format(
                                detail.firstPurchaseAt,
                              ),
                            ),
                            _InfoLine(
                              label: 'Ultima compra',
                              value: SystemWFormatters.shortDateTime.format(
                                detail.latestPurchaseAt,
                              ),
                            ),
                            _InfoLine(
                              label: 'Proximo vencimiento',
                              value: _formatOptionalDate(detail.nextExpiryDate),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionsSection extends ConsumerStatefulWidget {
  const _PromotionsSection({
    required this.state,
    required this.isBusy,
    required this.onUpdatePromotion,
    required this.onClearPromotion,
    required this.onSaveGeneralPromotion,
    required this.onClearGeneralPromotion,
  });

  final AdminMobileDashboardState state;
  final bool isBusy;
  final _PromotionSubmit onUpdatePromotion;
  final _PromotionClearSubmit onClearPromotion;
  final _GeneralPromotionSubmit onSaveGeneralPromotion;
  final _GeneralPromotionClearSubmit onClearGeneralPromotion;

  @override
  ConsumerState<_PromotionsSection> createState() => _PromotionsSectionState();
}

class _PromotionsSectionState extends ConsumerState<_PromotionsSection> {
  late final TextEditingController _generalPromoPriceController;
  late final TextEditingController _generalPromoNoteController;
  String? _selectedGeneralProductId;
  DateTime? _generalPromotionEndAt;
  String? _generalPromotionFormSeed;

  @override
  void initState() {
    super.initState();
    _generalPromoPriceController = TextEditingController();
    _generalPromoNoteController = TextEditingController();
  }

  @override
  void dispose() {
    _generalPromoPriceController.dispose();
    _generalPromoNoteController.dispose();
    super.dispose();
  }

  Product? _resolveSelectedGeneralProduct(List<Product> products) {
    if (products.isEmpty) {
      _selectedGeneralProductId = null;
      return null;
    }
    if (_selectedGeneralProductId == null ||
        !products.any((product) => product.id == _selectedGeneralProductId)) {
      _selectedGeneralProductId = products.first.id;
    }
    return products.firstWhere(
      (product) => product.id == _selectedGeneralProductId,
    );
  }

  void _syncGeneralPromotionForm(
    Product product,
    PriceHistoryEntry? activeEntry,
  ) {
    final seed =
        '${product.id}|${activeEntry?.effectiveFrom.toIso8601String() ?? 'sin-inicio'}|'
        '${activeEntry?.effectiveTo?.toIso8601String() ?? 'sin-fin'}|'
        '${activeEntry?.promotionalPrice?.toString() ?? 'sin-precio'}|'
        '${activeEntry?.promotionNote ?? ''}';
    if (_generalPromotionFormSeed == seed) {
      return;
    }

    _generalPromotionFormSeed = seed;
    _generalPromoPriceController.text =
        (activeEntry?.promotionalPrice ?? product.salePrice).toStringAsFixed(2);
    _generalPromoNoteController.text =
        activeEntry?.promotionNote ?? product.promotionNote ?? '';
    _generalPromotionEndAt =
        activeEntry?.effectiveTo?.toLocal() ??
        DateTime.now().add(const Duration(days: 7));
  }

  Future<void> _pickGeneralPromotionDate(BuildContext context) async {
    final currentValue = _generalPromotionEndAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: currentValue,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      final currentTime = _generalPromotionEndAt ?? DateTime.now();
      _generalPromotionEndAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        currentTime.hour,
        currentTime.minute,
      );
    });
  }

  Future<void> _pickGeneralPromotionTime(BuildContext context) async {
    final currentValue = _generalPromotionEndAt ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentValue),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      final currentDate = _generalPromotionEndAt ?? DateTime.now();
      _generalPromotionEndAt = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _openActiveGeneralPromotionDialog(
    Product product,
    PriceHistoryEntry entry,
  ) async {
    final promoController = TextEditingController(
      text: (entry.promotionalPrice ?? product.salePrice).toStringAsFixed(2),
    );
    final noteController = TextEditingController(
      text: entry.promotionNote ?? '',
    );
    DateTime selectedEndAt =
        entry.effectiveTo?.toLocal() ??
        DateTime.now().add(const Duration(days: 7));

    await showDialog<void>(
      context: context,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(product.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoLine(
                    label: 'Precio base',
                    value: SystemWFormatters.currency.format(product.salePrice),
                  ),
                  _InfoLine(
                    label: 'Promocion actual',
                    value: SystemWFormatters.currency.format(
                      entry.promotionalPrice ?? product.salePrice,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: promoController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio promocional',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedEndAt,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked == null) {
                            return;
                          }
                          setState(() {
                            selectedEndAt = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              selectedEndAt.hour,
                              selectedEndAt.minute,
                            );
                          });
                        },
                        icon: const Icon(Icons.event_rounded),
                        label: Text(
                          SystemWFormatters.shortDate.format(selectedEndAt),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedEndAt),
                          );
                          if (picked == null) {
                            return;
                          }
                          setState(() {
                            selectedEndAt = DateTime(
                              selectedEndAt.year,
                              selectedEndAt.month,
                              selectedEndAt.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        },
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(
                          TimeOfDay.fromDateTime(selectedEndAt).format(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Nota interna',
                    ),
                    maxLines: 2,
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
                  onPressed: () async {
                    final value = double.tryParse(promoController.text);
                    if (value == null || value <= 0) {
                      setState(() {
                        errorMessage = 'Ingresa un precio promocional valido.';
                      });
                      return;
                    }
                    if (value >= product.salePrice) {
                      setState(() {
                        errorMessage =
                            'El descuento general debe ser menor al precio base.';
                      });
                      return;
                    }
                    if (!selectedEndAt.isAfter(DateTime.now())) {
                      setState(() {
                        errorMessage =
                            'Programa una fecha y hora de fin validas.';
                      });
                      return;
                    }
                    final success = await widget.onSaveGeneralPromotion(
                      productId: product.id,
                      promotionalPrice: value,
                      promotionNote: noteController.text.trim(),
                      scheduledEndAt: selectedEndAt,
                    );
                    if (success && mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final generalPromotionHistory =
        widget.state.priceHistory
            .where((entry) => entry.promotionalPrice != null)
            .toList();
    final activeGeneralPromotionsByProductId = <String, PriceHistoryEntry>{};
    for (final entry in generalPromotionHistory) {
      if (!entry.isActiveAt(now) ||
          activeGeneralPromotionsByProductId.containsKey(entry.productId)) {
        continue;
      }
      activeGeneralPromotionsByProductId[entry.productId] = entry;
    }
    final generalDiscountProducts = [...widget.state.products]..sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    final items = _buildPromotionLotRows(widget.state);
    final openNotices =
        widget.state.promotionNotices.where((notice) => notice.isOpen).toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final activeGeneralPromotionCount =
        activeGeneralPromotionsByProductId.length;
    final activeGeneralEntries =
        activeGeneralPromotionsByProductId.values.toList()..sort(
          (left, right) => left.productName.toLowerCase().compareTo(
            right.productName.toLowerCase(),
          ),
        );
    final activeLotPromotionCount = widget.state.activeLotPromotions.length;
    final selectedGeneralProduct = _resolveSelectedGeneralProduct(
      generalDiscountProducts,
    );
    final selectedGeneralEntry =
        selectedGeneralProduct == null
            ? null
            : activeGeneralPromotionsByProductId[selectedGeneralProduct.id];
    if (selectedGeneralProduct != null) {
      _syncGeneralPromotionForm(selectedGeneralProduct, selectedGeneralEntry);
    }
    final today = now;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Promociones',
            subtitle:
                'Separa descuentos generales, liquidaciones por lote e historial.',
          ),
          const SizedBox(height: 16),
          _MetricWrap(
            children: [
              MetricCard(
                label: 'Descuento general',
                value: '$activeGeneralPromotionCount',
                detail: 'Activos ahora',
                accent: const Color(0xFFEA580C),
              ),
              MetricCard(
                label: 'Liquidaciones',
                value: '$activeLotPromotionCount',
                detail: 'Activas por lote',
                accent: const Color(0xFF0F766E),
              ),
              MetricCard(
                label: 'Historial',
                value: '${generalPromotionHistory.length}',
                detail: 'Registros generales con promo',
                accent: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '1. Descuentos generales',
            subtitle:
                'Selecciona un producto, revisa su informacion y programa cuando termina el descuento general.',
            child:
                generalDiscountProducts.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin productos disponibles',
                      caption:
                          'Cuando existan productos activos, apareceran aqui.',
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedGeneralProduct?.id,
                          decoration: const InputDecoration(
                            labelText: 'Producto',
                          ),
                          items:
                              generalDiscountProducts.map((product) {
                                return DropdownMenuItem(
                                  value: product.id,
                                  child: Text(product.name),
                                );
                              }).toList(),
                          onChanged:
                              widget.isBusy
                                  ? null
                                  : (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() {
                                      _selectedGeneralProductId = value;
                                      _generalPromotionFormSeed = null;
                                    });
                                  },
                        ),
                        if (selectedGeneralProduct != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedGeneralProduct.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                _InfoLine(
                                  label: 'Precio base',
                                  value: SystemWFormatters.currency.format(
                                    selectedGeneralProduct.salePrice,
                                  ),
                                ),
                                _InfoLine(
                                  label: 'Stock tienda',
                                  value:
                                      '${selectedGeneralProduct.stockStore} u.',
                                ),
                                _InfoLine(
                                  label: 'Stock almacen',
                                  value:
                                      '${selectedGeneralProduct.stockWarehouse} u.',
                                ),
                                _InfoLine(
                                  label: 'Descuento actual',
                                  value:
                                      selectedGeneralEntry == null
                                          ? 'Sin descuento general'
                                          : SystemWFormatters.currency.format(
                                            selectedGeneralEntry
                                                .promotionalPrice!,
                                          ),
                                ),
                                _InfoLine(
                                  label: 'Inicio actual',
                                  value:
                                      selectedGeneralEntry == null
                                          ? 'Se definira al guardar'
                                          : SystemWFormatters.shortDateTime
                                              .format(
                                                selectedGeneralEntry
                                                    .effectiveFrom,
                                              ),
                                ),
                                _InfoLine(
                                  label: 'Fin programado',
                                  value:
                                      selectedGeneralEntry?.effectiveTo == null
                                          ? 'Aun no programado'
                                          : SystemWFormatters.shortDateTime
                                              .format(
                                                selectedGeneralEntry!
                                                    .effectiveTo!,
                                              ),
                                ),
                                if ((selectedGeneralEntry?.promotionNote ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  _InfoLine(
                                    label: 'Nota actual',
                                    value:
                                        selectedGeneralEntry!.promotionNote!
                                            .trim(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Al guardar, la promo empieza en ese momento y termina en la fecha programada.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _generalPromoPriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Precio promocional',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    widget.isBusy
                                        ? null
                                        : () =>
                                            _pickGeneralPromotionDate(context),
                                icon: const Icon(Icons.event_rounded),
                                label: Text(
                                  _generalPromotionEndAt == null
                                      ? 'Elegir fecha fin'
                                      : 'Fecha fin: ${SystemWFormatters.shortDate.format(_generalPromotionEndAt!)}',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    widget.isBusy
                                        ? null
                                        : () =>
                                            _pickGeneralPromotionTime(context),
                                icon: const Icon(Icons.schedule_rounded),
                                label: Text(
                                  _generalPromotionEndAt == null
                                      ? 'Elegir hora fin'
                                      : 'Hora fin: ${TimeOfDay.fromDateTime(_generalPromotionEndAt!).format(context)}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _generalPromoNoteController,
                            decoration: const InputDecoration(
                              labelText: 'Nota interna',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed:
                                    widget.isBusy
                                        ? null
                                        : () async {
                                          final value = double.tryParse(
                                            _generalPromoPriceController.text,
                                          );
                                          if (value == null || value <= 0) {
                                            await showSystemWActionDialog(
                                              context,
                                              message:
                                                  'Ingresa un precio promocional valido.',
                                              isError: true,
                                            );
                                            return;
                                          }
                                          if (value >=
                                              selectedGeneralProduct
                                                  .salePrice) {
                                            await showSystemWActionDialog(
                                              context,
                                              message:
                                                  'El descuento general debe ser menor al precio base.',
                                              isError: true,
                                            );
                                            return;
                                          }
                                          final scheduledEndAt =
                                              _generalPromotionEndAt;
                                          if (scheduledEndAt == null ||
                                              !scheduledEndAt.isAfter(
                                                DateTime.now(),
                                              )) {
                                            await showSystemWActionDialog(
                                              context,
                                              message:
                                                  'Programa una fecha y hora de fin validas para la promocion.',
                                              isError: true,
                                            );
                                            return;
                                          }
                                          await widget.onSaveGeneralPromotion(
                                            productId:
                                                selectedGeneralProduct.id,
                                            promotionalPrice: value,
                                            promotionNote:
                                                _generalPromoNoteController.text
                                                    .trim(),
                                            scheduledEndAt: scheduledEndAt,
                                          );
                                        },
                                icon: const Icon(Icons.local_offer_rounded),
                                label: const Text('Registrar descuento'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Descuentos activos',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 10),
                          activeGeneralEntries.isEmpty
                              ? const EmptyStateCard(
                                title: 'Sin descuentos activos',
                                caption:
                                    'Cuando registres descuentos generales apareceran aqui por separado.',
                              )
                              : Column(
                                children:
                                    activeGeneralEntries.map((entry) {
                                      final product = _findProductById(
                                        widget.state.products,
                                        entry.productId,
                                      );
                                      if (product == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.productName,
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 8),
                                            _InfoLine(
                                              label: 'Precio base',
                                              value: SystemWFormatters.currency
                                                  .format(product.salePrice),
                                            ),
                                            _InfoLine(
                                              label: 'Promocion aplicada',
                                              value: SystemWFormatters.currency
                                                  .format(
                                                    entry.promotionalPrice!,
                                                  ),
                                            ),
                                            _InfoLine(
                                              label: 'Inicio',
                                              value: SystemWFormatters
                                                  .shortDateTime
                                                  .format(entry.effectiveFrom),
                                            ),
                                            _InfoLine(
                                              label: 'Fin',
                                              value:
                                                  entry.effectiveTo == null
                                                      ? 'Sin programar'
                                                      : SystemWFormatters
                                                          .shortDateTime
                                                          .format(
                                                            entry.effectiveTo!,
                                                          ),
                                            ),
                                            if ((entry.promotionNote ?? '')
                                                .trim()
                                                .isNotEmpty)
                                              _InfoLine(
                                                label: 'Nota',
                                                value:
                                                    entry.promotionNote!.trim(),
                                              ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: [
                                                FilledButton.icon(
                                                  onPressed:
                                                      widget.isBusy
                                                          ? null
                                                          : () =>
                                                              _openActiveGeneralPromotionDialog(
                                                                product,
                                                                entry,
                                                              ),
                                                  icon: const Icon(
                                                    Icons.edit_rounded,
                                                  ),
                                                  label: const Text(
                                                    'Actualizar',
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  onPressed:
                                                      widget.isBusy
                                                          ? null
                                                          : () => widget
                                                              .onClearGeneralPromotion(
                                                                productId:
                                                                    product.id,
                                                              ),
                                                  icon: const Icon(
                                                    Icons
                                                        .remove_circle_outline_rounded,
                                                  ),
                                                  label: const Text('Quitar'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              ),
                        ],
                      ],
                    ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '2. Liquidacion por lote',
            subtitle:
                'Usa esta parte para lotes por vencer o mercaderia puntual que quieres liquidar.',
            child:
                items.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin lotes por liquidar',
                      caption:
                          'Cuando existan lotes proximos a vencer o liquidaciones activas apareceran aqui.',
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (openNotices.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  openNotices.map((notice) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        '${_promotionNoticeLabel(notice)}: ${notice.message}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ...items.map((item) {
                          final product = item.product;
                          final activePromotion = item.activePromotion;
                          final isActive = activePromotion != null;
                          final isExpired = item.expiryDate.isBefore(
                            DateTime(today.year, today.month, today.day),
                          );
                          final currentPromoPrice =
                              activePromotion?.promotionalPrice;
                          final currentPromoQuantity =
                              activePromotion?.promoQuantityRemaining;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                _InfoLine(
                                  label: 'Proveedor',
                                  value: item.supplierName,
                                ),
                                _InfoLine(
                                  label: 'Vence',
                                  value: SystemWFormatters.shortDate.format(
                                    item.expiryDate,
                                  ),
                                ),
                                _InfoLine(
                                  label: 'Disponible total',
                                  value: '${item.totalAvailableUnits} u.',
                                ),
                                _InfoLine(
                                  label: 'Ubicacion',
                                  value: item.locationLabel,
                                ),
                                _InfoLine(
                                  label: 'En tienda',
                                  value: '${item.storeAvailableUnits} u.',
                                ),
                                _InfoLine(
                                  label: 'En almacen',
                                  value: '${item.warehouseAvailableUnits} u.',
                                ),
                                _InfoLine(
                                  label: 'Accion sugerida',
                                  value:
                                      isExpired && isActive
                                          ? 'La promo sigue activa pero el lote ya vencio: decide si mantenerla o registrarlo como perdida.'
                                          : item.recommendationLabel,
                                ),
                                _InfoLine(
                                  label: 'Precio base',
                                  value: SystemWFormatters.currency.format(
                                    product?.salePrice ?? 0,
                                  ),
                                ),
                                if (currentPromoPrice != null)
                                  _InfoLine(
                                    label: 'Precio promo',
                                    value: SystemWFormatters.currency.format(
                                      currentPromoPrice,
                                    ),
                                  ),
                                if (currentPromoQuantity != null)
                                  _InfoLine(
                                    label: 'Cantidad promo',
                                    value: '$currentPromoQuantity u.',
                                  ),
                                if (activePromotion != null)
                                  _InfoLine(
                                    label: 'Estado',
                                    value: _promotionStatusLabel(
                                      activePromotion,
                                    ),
                                  ),
                                if ((activePromotion?.note ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  _InfoLine(
                                    label: 'Nota promo',
                                    value: activePromotion!.note!,
                                  ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    FilledButton.icon(
                                      onPressed:
                                          widget.isBusy
                                              ? null
                                              : () =>
                                                  _openPromotionDialog(item),
                                      icon: const Icon(
                                        Icons.local_offer_rounded,
                                      ),
                                      label: Text(
                                        isActive
                                            ? 'Editar liquidacion'
                                            : 'Activar liquidacion',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          widget.isBusy ||
                                                  activePromotion == null
                                              ? null
                                              : () => widget.onClearPromotion(
                                                activePromotion.promotionId,
                                              ),
                                      icon: const Icon(
                                        Icons.remove_circle_outline_rounded,
                                      ),
                                      label: const Text('Quitar liquidacion'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '3. Historial de promociones',
            subtitle:
                'Se muestra el historial de descuentos generales y liquidaciones por lote ya registradas.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descuentos generales',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                generalPromotionHistory.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin descuentos generales',
                      caption: 'Cuando registres descuentos apareceran aqui.',
                    )
                    : _PaginatedList<PriceHistoryEntry>(
                      items: generalPromotionHistory,
                      itemBuilder: (context, entry) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.productName),
                          subtitle: Text(
                            'Venta ${SystemWFormatters.currency.format(entry.salePrice)} | Promo ${SystemWFormatters.currency.format(entry.promotionalPrice!)}',
                          ),
                          trailing: SizedBox(
                            width: 170,
                            child: Text(
                              '${SystemWFormatters.shortDateTime.format(entry.effectiveFrom)}\n${entry.effectiveTo == null ? 'Vigente' : SystemWFormatters.shortDateTime.format(entry.effectiveTo!)}',
                              textAlign: TextAlign.right,
                            ),
                          ),
                        );
                      },
                    ),
                const SizedBox(height: 18),
                Text(
                  'Liquidaciones por lote',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                FutureBuilder<dynamic>(
                  future: ref
                      .read(supabaseClientProvider)
                      .from('lot_promotions')
                      .select(
                        'id, promotional_price, promo_quantity_total, promo_quantity_remaining, note, status, created_at, '
                        'product:products!lot_promotions_product_id_fkey(name), '
                        'supplier:suppliers!lot_promotions_supplier_id_fkey(name), '
                        'purchase_item:purchase_items!lot_promotions_purchase_item_id_fkey(expiry_date)',
                      )
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final rows =
                        ((snapshot.data as List?) ?? const [])
                            .map((row) => Map<String, dynamic>.from(row as Map))
                            .toList();
                    if (rows.isEmpty) {
                      return const EmptyStateCard(
                        title: 'Sin liquidaciones registradas',
                        caption:
                            'Cuando actives promociones por lote apareceran aqui.',
                      );
                    }
                    return _PaginatedList<Map<String, dynamic>>(
                      items: rows,
                      itemBuilder: (context, row) {
                        final product =
                            row['product'] is Map
                                ? Map<String, dynamic>.from(
                                  row['product'] as Map,
                                )
                                : const <String, dynamic>{};
                        final supplier =
                            row['supplier'] is Map
                                ? Map<String, dynamic>.from(
                                  row['supplier'] as Map,
                                )
                                : const <String, dynamic>{};
                        final purchaseItem =
                            row['purchase_item'] is Map
                                ? Map<String, dynamic>.from(
                                  row['purchase_item'] as Map,
                                )
                                : const <String, dynamic>{};
                        final expiryDateRaw =
                            purchaseItem['expiry_date']?.toString();
                        final expiryDate =
                            expiryDateRaw == null || expiryDateRaw.isEmpty
                                ? null
                                : DateTime.parse(expiryDateRaw);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            product['name']?.toString() ?? 'Producto',
                          ),
                          subtitle: Text(
                            '${supplier['name']?.toString() ?? 'Proveedor'} | ${_promotionStatusText(row['status']?.toString())} | ${row['promo_quantity_remaining']} / ${row['promo_quantity_total']} u.',
                          ),
                          trailing: SizedBox(
                            width: 170,
                            child: Text(
                              '${SystemWFormatters.currency.format((row['promotional_price'] as num).toDouble())}\n${expiryDate == null ? 'Sin vencimiento' : SystemWFormatters.shortDate.format(expiryDate)}',
                              textAlign: TextAlign.right,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPromotionDialog(_PromotionLotRow item) async {
    final product = item.product;
    final activePromotion = item.activePromotion;
    final priceController = TextEditingController(
      text: (activePromotion?.promotionalPrice ?? product?.salePrice ?? 0)
          .toStringAsFixed(2),
    );
    final quantityController = TextEditingController(
      text:
          (activePromotion?.promoQuantityRemaining ?? item.totalAvailableUnits)
              .toString(),
    );
    final noteController = TextEditingController(
      text:
          activePromotion?.note ??
          'Promo por lote ${item.supplierName} | vence ${SystemWFormatters.shortDate.format(item.expiryDate)}',
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(item.productName),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Proveedor ${item.supplierName} | vence ${SystemWFormatters.shortDate.format(item.expiryDate)} | ${item.totalAvailableUnits} u. disponibles.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ubicacion: ${item.locationLabel}. ${item.recommendationLabel}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Cantidad en promo',
                      helperText:
                          'Maximo ${item.totalAvailableUnits} unidades de este lote.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio promocional',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Nota interna',
                    ),
                    maxLines: 2,
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
                  onPressed: () async {
                    final quantity = int.tryParse(quantityController.text);
                    final value = double.tryParse(priceController.text);
                    if (quantity == null || quantity <= 0) {
                      setState(() {
                        errorMessage =
                            'Ingresa una cantidad promocional valida.';
                      });
                      return;
                    }
                    if (quantity > item.totalAvailableUnits) {
                      setState(() {
                        errorMessage =
                            'Solo hay ${item.totalAvailableUnits} unidades disponibles en este lote.';
                      });
                      return;
                    }
                    if (value == null || value <= 0) {
                      setState(() {
                        errorMessage = 'Ingresa un precio promocional valido.';
                      });
                      return;
                    }
                    final salePrice = product?.salePrice ?? 0;
                    if (salePrice <= 0) {
                      setState(() {
                        errorMessage =
                            'No encontramos el precio base del producto para este lote.';
                      });
                      return;
                    }
                    if (value >= salePrice) {
                      setState(() {
                        errorMessage =
                            'La promocion debe ser menor al precio base.';
                      });
                      return;
                    }
                    final success = await widget.onUpdatePromotion(
                      purchaseItemId: item.purchaseItemId,
                      promotionalQuantity: quantity,
                      promotionalPrice: value,
                      promotionNote: noteController.text.trim(),
                    );
                    if (success && mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LossesSection extends ConsumerStatefulWidget {
  const _LossesSection({
    required this.state,
    required this.isBusy,
    required this.onRegisterLoss,
  });

  final AdminMobileDashboardState state;
  final bool isBusy;
  final _LossSubmit onRegisterLoss;

  @override
  ConsumerState<_LossesSection> createState() => _LossesSectionState();
}

class _LossesSectionState extends ConsumerState<_LossesSection> {
  String? _selectedLotLookupPurchaseItemId;

  InventoryLotAlert? _resolveSelectedLot(List<InventoryLotAlert> alerts) {
    if (alerts.isEmpty) {
      _selectedLotLookupPurchaseItemId = null;
      return null;
    }
    if (_selectedLotLookupPurchaseItemId == null ||
        !alerts.any(
          (alert) => alert.purchaseItemId == _selectedLotLookupPurchaseItemId,
        )) {
      _selectedLotLookupPurchaseItemId = alerts.first.purchaseItemId;
    }
    return alerts.firstWhere(
      (alert) => alert.purchaseItemId == _selectedLotLookupPurchaseItemId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final alerts = [...widget.state.expiredLotAlerts]
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    final selectedLotAlert = _resolveSelectedLot(alerts);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Perdidas',
            subtitle:
                'Gestiona lotes vencidos del almacen y registra la salida por perdida con proveedor y cantidad trazable.',
          ),
          const SizedBox(height: 16),
          FutureBuilder<dynamic>(
            future: ref
                .read(supabaseClientProvider)
                .from('losses')
                .select('quantity, financial_impact'),
            builder: (context, snapshot) {
              final rows =
                  ((snapshot.data as List?) ?? const [])
                      .map((row) => Map<String, dynamic>.from(row as Map))
                      .toList();
              final totalUnits = rows.fold<int>(
                0,
                (sum, row) => sum + ((row['quantity'] as num?)?.toInt() ?? 0),
              );
              final totalImpact = rows.fold<double>(
                0,
                (sum, row) =>
                    sum + ((row['financial_impact'] as num?)?.toDouble() ?? 0),
              );
              return _MetricWrap(
                children: [
                  MetricCard(
                    label: 'Total perdidas',
                    value: '$totalUnits u.',
                    detail:
                        '${rows.length} registros | ${SystemWFormatters.currency.format(totalImpact)}',
                    accent: const Color(0xFFB91C1C),
                  ),
                  _LossLotLookupCard(
                    alerts: alerts,
                    selectedAlert: selectedLotAlert,
                    onChanged: (purchaseItemId) {
                      setState(() {
                        _selectedLotLookupPurchaseItemId = purchaseItemId;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Lotes vencidos',
            subtitle:
                'El formulario usa motivo, cantidad y notas, y completa el resto con la informacion real del lote.',
            child:
                alerts.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin lotes vencidos',
                      caption:
                          'Cuando existan unidades vencidas disponibles en almacen, apareceran aqui.',
                    )
                    : Column(
                      children:
                          alerts.map((alert) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.productName,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  _InfoLine(
                                    label: 'Proveedor',
                                    value: alert.supplierName,
                                  ),
                                  _InfoLine(
                                    label: 'Vencio',
                                    value: SystemWFormatters.shortDate.format(
                                      alert.expiryDate,
                                    ),
                                  ),
                                  _InfoLine(
                                    label: 'Disponible',
                                    value: '${alert.availableUnits} u.',
                                  ),
                                  _InfoLine(
                                    label: 'Recepcion',
                                    value: SystemWFormatters.shortDate.format(
                                      alert.receivedAt,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed:
                                        widget.isBusy
                                            ? null
                                            : () => _openLossRegistrationDialog(
                                              alert,
                                            ),
                                    icon: const Icon(
                                      Icons.delete_sweep_rounded,
                                    ),
                                    label: const Text('Marcar perdida'),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Historial de perdidas',
            subtitle:
                'Lectura directa de losses con motivo, impacto, ubicacion, condicion y responsable.',
            child: FutureBuilder<dynamic>(
              future: ref
                  .read(supabaseClientProvider)
                  .from('losses')
                  .select(
                    'id, batch_id, quantity, reason, financial_impact, storage_condition, notes, created_at, '
                    'product:products!losses_product_id_fkey(name), '
                    'location:locations!losses_location_id_fkey(name), '
                    'reporter:profiles!losses_reported_by_fkey(full_name)',
                  )
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final rows =
                    ((snapshot.data as List?) ?? const [])
                        .map((row) => Map<String, dynamic>.from(row as Map))
                        .toList();
                if (rows.isEmpty) {
                  return const EmptyStateCard(
                    title: 'Sin perdidas registradas',
                    caption:
                        'Cuando registres perdidas en losses apareceran aqui.',
                  );
                }
                return _PaginatedList<Map<String, dynamic>>(
                  items: rows,
                  itemBuilder: (context, row) {
                    final product =
                        row['product'] is Map
                            ? Map<String, dynamic>.from(row['product'] as Map)
                            : const <String, dynamic>{};
                    final location =
                        row['location'] is Map
                            ? Map<String, dynamic>.from(row['location'] as Map)
                            : const <String, dynamic>{};
                    final reporter =
                        row['reporter'] is Map
                            ? Map<String, dynamic>.from(row['reporter'] as Map)
                            : const <String, dynamic>{};
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name']?.toString() ?? 'Producto',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          _InfoLine(
                            label: 'Motivo',
                            value: _lossReasonLabel(row['reason']?.toString()),
                          ),
                          _InfoLine(
                            label: 'Cantidad',
                            value: '${row['quantity']} u.',
                          ),
                          _InfoLine(
                            label: 'Impacto',
                            value: SystemWFormatters.currency.format(
                              (row['financial_impact'] as num).toDouble(),
                            ),
                          ),
                          _InfoLine(
                            label: 'Ubicacion',
                            value:
                                location['name']?.toString() ?? 'Sin ubicacion',
                          ),
                          _InfoLine(
                            label: 'Condicion',
                            value: _storageConditionLabel(
                              row['storage_condition']?.toString(),
                            ),
                          ),
                          _InfoLine(
                            label: 'Reportado por',
                            value:
                                reporter['full_name']?.toString() ?? 'Usuario',
                          ),
                          _InfoLine(
                            label: 'Fecha',
                            value: SystemWFormatters.shortDateTime.format(
                              DateTime.parse(
                                row['created_at'] as String,
                              ).toLocal(),
                            ),
                          ),
                          if ((row['notes']?.toString() ?? '')
                              .trim()
                              .isNotEmpty)
                            _InfoLine(
                              label: 'Notas',
                              value: row['notes'].toString().trim(),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLossDialog(InventoryLotAlert alert) async {
    final quantityController = TextEditingController(
      text: '${alert.availableUnits}',
    );
    final notesController = TextEditingController(
      text: 'Perdida por vencimiento',
    );
    final auditFuture = Future.wait<dynamic>([
      ref
          .read(supabaseClientProvider)
          .from('purchase_items')
          .select('unit_cost')
          .eq('id', alert.purchaseItemId)
          .limit(1),
      ref
          .read(supabaseClientProvider)
          .from('inventory_stock')
          .select(
            'quantity, storage_condition, location:locations!inventory_stock_location_id_fkey(name)',
          )
          .eq('batch_id', alert.purchaseItemId)
          .gt('quantity', 0),
    ]);

    await showDialog<void>(
      context: context,
      builder: (context) {
        String? errorMessage;
        var selectedReason = 'expired';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(alert.productName),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${alert.supplierName} | Vencio ${SystemWFormatters.shortDate.format(alert.expiryDate)}',
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<dynamic>>(
                    future: auditFuture,
                    builder: (context, snapshot) {
                      final quantityValue =
                          int.tryParse(quantityController.text) ?? 0;
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        );
                      }
                      final purchaseRows =
                          ((snapshot.data![0] as List?) ?? const [])
                              .map(
                                (row) => Map<String, dynamic>.from(row as Map),
                              )
                              .toList();
                      final stockRows =
                          ((snapshot.data![1] as List?) ?? const [])
                              .map(
                                (row) => Map<String, dynamic>.from(row as Map),
                              )
                              .toList();
                      final unitCost =
                          purchaseRows.isEmpty
                              ? 0.0
                              : (purchaseRows.first['unit_cost'] as num)
                                  .toDouble();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoLine(
                            label: 'Impacto Final',
                            value: SystemWFormatters.currency.format(
                              unitCost * quantityValue,
                            ),
                          ),
                          _InfoLine(
                            label: 'Reportado por',
                            value:
                                ref
                                    .read(sessionViewModelProvider)
                                    .valueOrNull
                                    ?.currentUser
                                    ?.name ??
                                'Usuario actual',
                          ),
                          _InfoLine(
                            label: 'Cuando se registro',
                            value: SystemWFormatters.shortDateTime.format(
                              DateTime.now(),
                            ),
                          ),
                          ...stockRows.map((row) {
                            final location =
                                row['location'] is Map
                                    ? Map<String, dynamic>.from(
                                      row['location'] as Map,
                                    )
                                    : const <String, dynamic>{};
                            return _InfoLine(
                              label: 'Lugar - Condicion',
                              value:
                                  '${location['name']?.toString() ?? 'Sin ubicacion'} | ${row['storage_condition']?.toString() ?? 'Sin condicion'} | ${row['quantity']} u.',
                            );
                          }),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: const InputDecoration(labelText: 'reason'),
                    items: const [
                      DropdownMenuItem(
                        value: 'expired',
                        child: Text('Expirado'),
                      ),
                      DropdownMenuItem(value: 'damaged', child: Text('Dañado')),
                      DropdownMenuItem(value: 'theft', child: Text('Robo')),
                      DropdownMenuItem(
                        value: 'quality_issue',
                        child: Text('Problema de calidad'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Otro')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value ?? 'expired';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'quantity'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'notes'),
                    maxLines: 2,
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
                  onPressed: () async {
                    final value = int.tryParse(quantityController.text);
                    if (value == null || value <= 0) {
                      setState(() {
                        errorMessage = 'Ingresa una cantidad valida.';
                      });
                      return;
                    }
                    if (value > alert.availableUnits) {
                      setState(() {
                        errorMessage =
                            'Solo tienes ${alert.availableUnits} u. disponibles en este lote.';
                      });
                      return;
                    }
                    final success = await widget.onRegisterLoss(
                      purchaseItemId: alert.purchaseItemId,
                      quantity: value,
                      reason: selectedReason,
                      notes: notesController.text.trim(),
                    );
                    if (success && mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openLossRegistrationDialog(InventoryLotAlert alert) async {
    final quantityController = TextEditingController(
      text: '${alert.availableUnits}',
    );
    final notesController = TextEditingController(
      text: 'Perdida por vencimiento',
    );
    final matchingProducts = widget.state.products
        .where((item) => item.id == alert.productId)
        .toList(growable: false);
    final product = matchingProducts.isEmpty ? null : matchingProducts.first;
    final isBeverage =
        product != null && isBeverageProduct(product, widget.state.categories);
    final auditFuture = Future.wait<dynamic>([
      ref
          .read(supabaseClientProvider)
          .from('purchase_items')
          .select('unit_cost')
          .eq('id', alert.purchaseItemId)
          .limit(1),
      ref
          .read(supabaseClientProvider)
          .from('inventory_stock')
          .select(
            'quantity, storage_condition, location:locations!inventory_stock_location_id_fkey(name)',
          )
          .eq('batch_id', alert.purchaseItemId)
          .gt('quantity', 0),
    ]);

    await showDialog<void>(
      context: context,
      builder: (context) {
        String? errorMessage;
        var selectedReason = 'expired';
        String? selectedStorageCondition;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(alert.productName),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${alert.supplierName} | Vencio ${SystemWFormatters.shortDate.format(alert.expiryDate)}',
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<dynamic>>(
                    future: auditFuture,
                    builder: (context, snapshot) {
                      final quantityValue =
                          int.tryParse(quantityController.text) ?? 0;
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        );
                      }

                      final purchaseRows =
                          ((snapshot.data![0] as List?) ?? const [])
                              .map(
                                (row) => Map<String, dynamic>.from(row as Map),
                              )
                              .toList();
                      final stockRows =
                          ((snapshot.data![1] as List?) ?? const [])
                              .map(
                                (row) => Map<String, dynamic>.from(row as Map),
                              )
                              .toList();
                      final unitCost =
                          purchaseRows.isEmpty
                              ? 0.0
                              : (purchaseRows.first['unit_cost'] as num)
                                  .toDouble();
                      final quantityByCondition = <String, int>{
                        'ambiente': 0,
                        'frio': 0,
                      };
                      for (final row in stockRows) {
                        final condition =
                            row['storage_condition']?.toString() ?? 'ambiente';
                        quantityByCondition.update(
                          condition,
                          (value) =>
                              value + ((row['quantity'] as num?)?.toInt() ?? 0),
                          ifAbsent:
                              () => ((row['quantity'] as num?)?.toInt() ?? 0),
                        );
                      }
                      if (isBeverage &&
                          (selectedStorageCondition == null ||
                              (quantityByCondition[selectedStorageCondition] ??
                                      0) <=
                                  0)) {
                        selectedStorageCondition =
                            (quantityByCondition['ambiente'] ?? 0) > 0
                                ? 'ambiente'
                                : (quantityByCondition['frio'] ?? 0) > 0
                                ? 'frio'
                                : null;
                      }
                      final availableForCondition =
                          selectedStorageCondition == null
                              ? alert.availableUnits
                              : (quantityByCondition[selectedStorageCondition] ??
                                  0);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoLine(
                            label: 'Impacto final',
                            value: SystemWFormatters.currency.format(
                              unitCost * quantityValue,
                            ),
                          ),
                          _InfoLine(
                            label: 'Reportado por',
                            value:
                                ref
                                    .read(sessionViewModelProvider)
                                    .valueOrNull
                                    ?.currentUser
                                    ?.name ??
                                'Usuario actual',
                          ),
                          _InfoLine(
                            label: 'Cuando se registra',
                            value: SystemWFormatters.shortDateTime.format(
                              DateTime.now(),
                            ),
                          ),
                          if (isBeverage) ...[
                            _InfoLine(
                              label: 'Ambientado',
                              value:
                                  '${quantityByCondition['ambiente'] ?? 0} u.',
                            ),
                            _InfoLine(
                              label: 'Helado',
                              value: '${quantityByCondition['frio'] ?? 0} u.',
                            ),
                            _InfoLine(
                              label: 'Disponible en condicion',
                              value: '$availableForCondition u.',
                            ),
                          ],
                          ...stockRows.map((row) {
                            final location =
                                row['location'] is Map
                                    ? Map<String, dynamic>.from(
                                      row['location'] as Map,
                                    )
                                    : const <String, dynamic>{};
                            return _InfoLine(
                              label: 'Lugar - Condicion',
                              value:
                                  '${location['name']?.toString() ?? 'Sin ubicacion'} | ${_storageConditionLabel(row['storage_condition']?.toString())} | ${row['quantity']} u.',
                            );
                          }),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    decoration: const InputDecoration(labelText: 'Motivo'),
                    items: const [
                      DropdownMenuItem(
                        value: 'expired',
                        child: Text('Expirado'),
                      ),
                      DropdownMenuItem(value: 'damaged', child: Text('Danado')),
                      DropdownMenuItem(value: 'theft', child: Text('Robo')),
                      DropdownMenuItem(
                        value: 'quality_issue',
                        child: Text('Problema de calidad'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Otro')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value ?? 'expired';
                      });
                    },
                  ),
                  if (isBeverage) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedStorageCondition,
                      decoration: const InputDecoration(labelText: 'Condicion'),
                      items: const [
                        DropdownMenuItem(
                          value: 'ambiente',
                          child: Text('Ambientado'),
                        ),
                        DropdownMenuItem(value: 'frio', child: Text('Helado')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedStorageCondition = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notas'),
                    maxLines: 2,
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
                  onPressed: () async {
                    final value = int.tryParse(quantityController.text);
                    if (value == null || value <= 0) {
                      setState(() {
                        errorMessage = 'Ingresa una cantidad valida.';
                      });
                      return;
                    }

                    final maxAllowed =
                        await (() async {
                          if (!isBeverage || selectedStorageCondition == null) {
                            return alert.availableUnits;
                          }
                          final rows = await ref
                              .read(supabaseClientProvider)
                              .from('inventory_stock')
                              .select('quantity')
                              .eq('batch_id', alert.purchaseItemId)
                              .eq(
                                'storage_condition',
                                selectedStorageCondition!,
                              )
                              .gt('quantity', 0);
                          return ((rows as List?) ?? const [])
                              .map(
                                (row) => Map<String, dynamic>.from(row as Map),
                              )
                              .fold<int>(
                                0,
                                (sum, row) =>
                                    sum +
                                    ((row['quantity'] as num?)?.toInt() ?? 0),
                              );
                        })();
                    if (value > maxAllowed) {
                      setState(() {
                        errorMessage =
                            isBeverage && selectedStorageCondition != null
                                ? 'Solo tienes $maxAllowed u. en ${_storageConditionLabel(selectedStorageCondition)} para este lote.'
                                : 'Solo tienes ${alert.availableUnits} u. disponibles en este lote.';
                      });
                      return;
                    }

                    final success = await widget.onRegisterLoss(
                      purchaseItemId: alert.purchaseItemId,
                      quantity: value,
                      reason: selectedReason,
                      notes: notesController.text.trim(),
                      storageCondition: selectedStorageCondition,
                    );
                    if (success && mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LossLotLookupCard extends ConsumerWidget {
  const _LossLotLookupCard({
    required this.alerts,
    required this.selectedAlert,
    required this.onChanged,
  });

  final List<InventoryLotAlert> alerts;
  final InventoryLotAlert? selectedAlert;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child:
          alerts.isEmpty || selectedAlert == null
              ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stock por lote'),
                  SizedBox(height: 8),
                  Text(
                    'Cuando exista un lote vencido podras consultarlo aqui.',
                  ),
                ],
              )
              : FutureBuilder<dynamic>(
                future: ref
                    .read(supabaseClientProvider)
                    .from('inventory_stock')
                    .select('quantity, storage_condition')
                    .eq('batch_id', selectedAlert!.purchaseItemId)
                    .gt('quantity', 0),
                builder: (context, snapshot) {
                  final rows =
                      ((snapshot.data as List?) ?? const [])
                          .map((row) => Map<String, dynamic>.from(row as Map))
                          .toList();
                  final ambientUnits = rows
                      .where(
                        (row) =>
                            row['storage_condition']?.toString() == 'ambiente',
                      )
                      .fold<int>(
                        0,
                        (sum, row) =>
                            sum + ((row['quantity'] as num?)?.toInt() ?? 0),
                      );
                  final coldUnits = rows
                      .where(
                        (row) => row['storage_condition']?.toString() == 'frio',
                      )
                      .fold<int>(
                        0,
                        (sum, row) =>
                            sum + ((row['quantity'] as num?)?.toInt() ?? 0),
                      );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedAlert!.purchaseItemId,
                        decoration: const InputDecoration(
                          labelText: 'Consultar lote',
                        ),
                        items:
                            alerts.map((alert) {
                              return DropdownMenuItem(
                                value: alert.purchaseItemId,
                                child: Text(
                                  '${alert.productName} | ${alert.supplierName}',
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            onChanged(value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Stock del lote',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _InfoLine(
                        label: 'Total disponible',
                        value: '${selectedAlert!.availableUnits} u.',
                      ),
                      _InfoLine(label: 'Ambientado', value: '$ambientUnits u.'),
                      _InfoLine(label: 'Helado', value: '$coldUnits u.'),
                    ],
                  );
                },
              ),
    );
  }
}

class _MovementsSection extends ConsumerStatefulWidget {
  const _MovementsSection({
    required this.state,
    required this.isBusy,
    required this.currentUser,
    required this.onSubmitMovementCart,
    required this.onUpdateColdState,
  });

  final AdminMobileDashboardState state;
  final bool isBusy;
  final AppUser? currentUser;
  final _MovementCartSubmit? onSubmitMovementCart;
  final _ColdStateSubmit onUpdateColdState;

  @override
  ConsumerState<_MovementsSection> createState() => _MovementsSectionState();
}

class _MovementsSectionState extends ConsumerState<_MovementsSection> {
  String? _selectedCategoryId;
  String _searchQuery = '';
  String _coldSearchQuery = '';
  String? _selectedColdProductId;
  String? _selectedWarehouseLotId;

  @override
  void didUpdateWidget(covariant _MovementsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedProductId != widget.state.selectedProductId) {
      _selectedWarehouseLotId = null;
    }
    if (!widget.state.products.any(
      (product) => product.id == _selectedColdProductId,
    )) {
      _selectedColdProductId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final selectedProduct = state.selectedProduct;
    final beverageProducts =
        state.products.where((product) {
            return isBeverageProduct(product, state.categories);
          }).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final filteredColdProducts =
        beverageProducts.where((product) {
            final query = _coldSearchQuery.trim().toLowerCase();
            if (query.isEmpty) {
              return true;
            }
            return product.name.toLowerCase().contains(query);
          }).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final selectedColdProduct =
        filteredColdProducts.any(
              (product) => product.id == _selectedColdProductId,
            )
            ? filteredColdProducts.firstWhere(
              (product) => product.id == _selectedColdProductId,
            )
            : filteredColdProducts.isEmpty
            ? null
            : filteredColdProducts.first;
    final activeColdProducts =
        beverageProducts.where((product) => product.coldStockUnits > 0).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final effectiveCategoryId =
        state.categories.any((category) => category.id == _selectedCategoryId)
            ? _selectedCategoryId
            : null;
    final filteredProducts =
        state.products.where((product) {
            final matchesCategory =
                effectiveCategoryId == null ||
                product.categoryId == effectiveCategoryId;
            final matchesQuery =
                _searchQuery.trim().isEmpty ||
                product.name.toLowerCase().contains(_searchQuery.toLowerCase());
            return matchesCategory && matchesQuery;
          }).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final totalStoreUnits = filteredProducts.fold<int>(
      0,
      (sum, product) => sum + product.stockStore,
    );
    final totalWarehouseUnits = filteredProducts.fold<int>(
      0,
      (sum, product) => sum + product.stockWarehouse,
    );
    final quantity = state.quantity;
    final warehouseLotsAsync =
        selectedProduct == null
            ? const AsyncData<List<WarehouseSupplierLot>>([])
            : ref.watch(_warehouseSupplierLotsProvider(selectedProduct.id));
    final warehouseLots = [
      ...(warehouseLotsAsync.valueOrNull ?? const <WarehouseSupplierLot>[]),
    ]..sort(_compareWarehouseLots);
    final selectedWarehouseLot =
        warehouseLots.any(
              (lot) => lot.purchaseItemId == _selectedWarehouseLotId,
            )
            ? warehouseLots.firstWhere(
              (lot) => lot.purchaseItemId == _selectedWarehouseLotId,
            )
            : warehouseLots.isEmpty
            ? null
            : warehouseLots.first;
    final hiddenExpiredLots =
        selectedProduct == null
              ? <InventoryLotAlert>[]
              : state.expiredLotAlerts
                  .where(
                    (alert) =>
                        alert.productId == selectedProduct.id &&
                        alert.availableUnits > 0,
                  )
                  .toList()
          ..sort((left, right) => left.expiryDate.compareTo(right.expiryDate));
    final promotionPriorityLots = warehouseLots.where(
      (lot) => lot.isPromotionPriority,
    );
    final warehouseStock = selectedWarehouseLot?.availableUnits ?? 0;
    final storeStock = selectedProduct?.stockStore ?? 0;
    final remainingWarehouse = warehouseStock - quantity;
    final nextStoreStock = storeStock + quantity;
    final hasEnoughStock =
        selectedWarehouseLot != null && quantity > 0 && remainingWarehouse >= 0;
    final purchaseMovementsCount =
        state.movements
            .where((movement) => movement.type.toLowerCase() == 'purchase')
            .length;
    final saleMovementsCount =
        state.movements
            .where((movement) => movement.type.toLowerCase() == 'sale')
            .length;
    final transferMovementsCount =
        state.movements
            .where((movement) => movement.type.toLowerCase() == 'transfer')
            .length;
    final lossMovementsCount =
        state.movements
            .where((movement) => movement.type.toLowerCase() == 'loss')
            .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Movimientos',
            subtitle:
                'Elige el producto, selecciona el lote exacto y acumula varios traslados antes de confirmarlos juntos.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Panorama de stock',
            subtitle:
                'Resumen total de tienda y almacen con busqueda y filtro por categoria.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Buscar producto',
                    hintText: 'Busca por nombre',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: effectiveCategoryId,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas las categorias'),
                    ),
                    ...state.categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(_categoryOptionLabel(category)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _MetricWrap(
                  children: [
                    MetricCard(
                      label: 'Tienda',
                      value: '$totalStoreUnits u.',
                      detail: '${filteredProducts.length} productos filtrados',
                      accent: const Color(0xFF0F766E),
                    ),
                    MetricCard(
                      label: 'Almacen',
                      value: '$totalWarehouseUnits u.',
                      detail: 'Stock disponible para movimiento',
                      accent: const Color(0xFFEA580C),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (filteredProducts.isEmpty)
                  const EmptyStateCard(
                    title: 'Sin productos para este filtro',
                    caption:
                        'Prueba con otra categoria o una busqueda mas amplia.',
                  )
                else
                  _PaginatedList<Product>(
                    items: filteredProducts,
                    itemBuilder: (context, product) {
                      final providerLabel = _supplierLabelForProduct(
                        state,
                        product,
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Proveedor: $providerLabel',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            _InfoLine(
                              label: 'Tienda',
                              value: '${product.stockStore} u.',
                            ),
                            _InfoLine(
                              label: 'Almacen',
                              value: '${product.stockWarehouse} u.',
                            ),
                            _InfoLine(
                              label: 'Faltantes',
                              value: '${_missingUnits(product)} u.',
                            ),
                            _InfoLine(
                              label: 'Umbral',
                              value: '${product.lowStockThreshold} u.',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Mover de almacen a tienda',
            subtitle:
                'Los lotes en promo salen primero, los vencidos se ocultan y cada traslado queda amarrado al lote exacto.',
            child: Consumer(
              builder: (context, ref, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.products.isEmpty)
                      const EmptyStateCard(
                        title: 'Sin productos registrados',
                        caption:
                            'Agrega productos en Supabase para poder mover stock.',
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        value: state.selectedProductId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Producto',
                        ),
                        items:
                            state.products
                                .map(
                                  (product) => DropdownMenuItem(
                                    value: product.id,
                                    child: Text(product.name),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedWarehouseLotId = null;
                          });
                          ref
                              .read(
                                adminMobileDashboardViewModelProvider.notifier,
                              )
                              .selectProduct(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (hiddenExpiredLots.isNotEmpty) ...[
                        _ExpiredMovementLotsNoticeCard(
                          alerts: hiddenExpiredLots,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (selectedProduct == null)
                        const EmptyStateCard(
                          title: 'Sin producto seleccionado',
                          caption:
                              'Elige un producto para revisar sus lotes disponibles en almacen.',
                        )
                      else if (warehouseLotsAsync.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (warehouseLotsAsync.hasError)
                        const EmptyStateCard(
                          title: 'No pudimos cargar los lotes',
                          caption:
                              'Intenta nuevamente para consultar los lotes disponibles de este producto.',
                        )
                      else if (warehouseLots.isEmpty)
                        EmptyStateCard(
                          title: 'Sin lotes movibles en almacen',
                          caption:
                              hiddenExpiredLots.isEmpty
                                  ? 'Este producto no tiene lotes disponibles para trasladar ahora mismo.'
                                  : 'Los lotes disponibles de este producto se ocultaron porque ya vencieron.',
                        )
                      else ...[
                        _MovementLotSelectorCard(
                          lots: warehouseLots,
                          selectedPurchaseItemId:
                              selectedWarehouseLot?.purchaseItemId,
                          onSelectLot:
                              widget.isBusy
                                  ? null
                                  : (purchaseItemId) {
                                    setState(() {
                                      _selectedWarehouseLotId = purchaseItemId;
                                    });
                                  },
                        ),
                        const SizedBox(height: 12),
                        if (promotionPriorityLots.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Primero veras ${promotionPriorityLots.length} lote(s) en promocion para que salgan rapido de almacen hacia tienda.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                      if (warehouseLots.isNotEmpty) ...[
                        TextFormField(
                          key: ValueKey(
                            'movement-quantity-${state.selectedProductId ?? 'none'}-${selectedWarehouseLot?.purchaseItemId ?? 'none'}-${state.quantity}',
                          ),
                          initialValue: '${state.quantity}',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cantidad a mover',
                          ),
                          onChanged: (value) {
                            ref
                                .read(
                                  adminMobileDashboardViewModelProvider
                                      .notifier,
                                )
                                .changeQuantity(
                                  int.tryParse(value) ?? state.quantity,
                                );
                          },
                        ),
                        const SizedBox(height: 16),
                        _MovementPreviewCard(
                          productName: selectedProduct?.name,
                          supplierName: selectedWarehouseLot?.supplierName,
                          receivedAt: selectedWarehouseLot?.receivedAt,
                          expiryDate: selectedWarehouseLot?.expiryDate,
                          isPromotionPriority:
                              selectedWarehouseLot?.isPromotionPriority ??
                              false,
                          promotionStatus:
                              selectedWarehouseLot?.promotionStatus,
                          promotionalPrice:
                              selectedWarehouseLot?.promotionalPrice,
                          promotionNote: selectedWarehouseLot?.promotionNote,
                          quantity: quantity,
                          warehouseBefore: warehouseStock,
                          warehouseAfter: remainingWarehouse,
                          storeBefore: storeStock,
                          storeAfter: nextStoreStock,
                          hasEnoughStock: hasEnoughStock,
                        ),
                        const SizedBox(height: 16),
                        _MovementDraftCard(
                          items: state.movementDraftItems,
                          totalUnits: state.movementDraftUnits,
                          onRemoveItem: (index) {
                            ref
                                .read(
                                  adminMobileDashboardViewModelProvider
                                      .notifier,
                                )
                                .removeMovementDraftLine(index);
                          },
                          onClear:
                              state.movementDraftItems.isEmpty
                                  ? null
                                  : () {
                                    ref
                                        .read(
                                          adminMobileDashboardViewModelProvider
                                              .notifier,
                                        )
                                        .clearMovementDraft();
                                  },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                widget.currentUser == null ||
                                        widget.isBusy ||
                                        selectedProduct == null ||
                                        selectedWarehouseLot == null ||
                                        !hasEnoughStock ||
                                        warehouseLotsAsync.isLoading
                                    ? null
                                    : () {
                                      ref
                                          .read(
                                            adminMobileDashboardViewModelProvider
                                                .notifier,
                                          )
                                          .addMovementDraftLine(
                                            MovementDraftLine(
                                              purchaseItemId:
                                                  selectedWarehouseLot
                                                      .purchaseItemId,
                                              productId: selectedProduct.id,
                                              productName: selectedProduct.name,
                                              supplierId:
                                                  selectedWarehouseLot
                                                      .supplierId,
                                              supplierName:
                                                  selectedWarehouseLot
                                                      .supplierName,
                                              quantity: quantity,
                                              availableUnits:
                                                  selectedWarehouseLot
                                                      .availableUnits,
                                              receivedAt:
                                                  selectedWarehouseLot
                                                      .receivedAt,
                                              expiryDate:
                                                  selectedWarehouseLot
                                                      .expiryDate,
                                              isPromotionPriority:
                                                  selectedWarehouseLot
                                                      .isPromotionPriority,
                                              promotionId:
                                                  selectedWarehouseLot
                                                      .promotionId,
                                              promotionStatus:
                                                  selectedWarehouseLot
                                                      .promotionStatus,
                                              promotionalPrice:
                                                  selectedWarehouseLot
                                                      .promotionalPrice,
                                              promotionNote:
                                                  selectedWarehouseLot
                                                      .promotionNote,
                                            ),
                                          );
                                    },
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: const Text('Agregar a lista'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                widget.currentUser == null ||
                                        widget.isBusy ||
                                        widget.onSubmitMovementCart == null ||
                                        state.movementDraftItems.isEmpty
                                    ? null
                                    : () async {
                                      await widget.onSubmitMovementCart!();
                                    },
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: Text(
                              state.movementDraftItems.isEmpty
                                  ? 'Agrega movimientos para registrar'
                                  : 'Registrar movimientos',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Bebidas heladas - En tienda',
            subtitle:
                'Busca la bebida, define cuantas unidades pasan a helarse y deja visible solo lo que ya esta en estado helado.',
            child:
                beverageProducts.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin bebidas registradas',
                      caption:
                          'Cuando existan bebidas en el catalogo, podras definir cuantas pasan a estado helado.',
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              _coldSearchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Buscar bebida',
                            hintText: 'Ej. Coca Cola, Inca Kola, Agua...',
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
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedColdProduct?.id,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Bebida seleccionada',
                          ),
                          items:
                              filteredColdProducts
                                  .map(
                                    (product) => DropdownMenuItem(
                                      value: product.id,
                                      child: Text(product.name),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              filteredColdProducts.isEmpty
                                  ? null
                                  : (value) {
                                    setState(() {
                                      _selectedColdProductId = value;
                                    });
                                  },
                        ),
                        if (selectedColdProduct != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedColdProduct.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 10),
                                _InfoLine(
                                  label: 'Normal en tienda',
                                  value:
                                      '${_normalStoreUnits(selectedColdProduct)} u.',
                                ),
                                _InfoLine(
                                  label: 'Helada en tienda',
                                  value:
                                      '${_icedStoreUnits(selectedColdProduct)} u.',
                                ),
                                _InfoLine(
                                  label: 'Precio normal',
                                  value: SystemWFormatters.currency.format(
                                    effectiveBaseSalePrice(selectedColdProduct),
                                  ),
                                ),
                                _InfoLine(
                                  label: 'Precio helado',
                                  value: SystemWFormatters.currency.format(
                                    effectiveSalePrice(
                                      selectedColdProduct,
                                      isIced: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        widget.isBusy
                                            ? null
                                            : () => _openColdStateDialog(
                                              selectedColdProduct,
                                            ),
                                    icon: const Icon(Icons.ac_unit_rounded),
                                    label: const Text(
                                      'Definir cantidad a helar',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (selectedColdProduct == null) ...[
                          const SizedBox(height: 16),
                          const EmptyStateCard(
                            title: 'Sin bebida seleccionada',
                            caption:
                                'Busca una bebida y selecciona una opcion para configurar sus unidades heladas.',
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          'Bebidas ya heladas',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        activeColdProducts.isEmpty
                            ? const EmptyStateCard(
                              title: 'Aun no hay bebidas heladas',
                              caption:
                                  'Cuando una bebida tenga unidades heladas, aparecera aqui con su precio y cantidades.',
                            )
                            : _PaginatedList<Product>(
                              items: activeColdProducts,
                              itemBuilder: (context, product) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFE5E7EB),
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 8),
                                      _InfoLine(
                                        label: 'Normal',
                                        value:
                                            '${_normalStoreUnits(product)} u.',
                                      ),
                                      _InfoLine(
                                        label: 'Helada',
                                        value: '${_icedStoreUnits(product)} u.',
                                      ),
                                      _InfoLine(
                                        label: 'Recargo',
                                        value: SystemWFormatters.currency
                                            .format(
                                              coldPriceIncrement(product),
                                            ),
                                      ),
                                      _InfoLine(
                                        label: 'Precio helado',
                                        value: SystemWFormatters.currency
                                            .format(
                                              effectiveSalePrice(
                                                product,
                                                isIced: true,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                      ],
                    ),
          ),
          const SizedBox(height: 16),
          _MetricWrap(
            children: [
              MetricCard(
                label: 'Total movimientos',
                value: '${state.movements.length}',
                detail: 'Compras, ventas, traslados y perdidas',
                accent: const Color(0xFF2563EB),
              ),
              MetricCard(
                label: 'Compras',
                value: '$purchaseMovementsCount',
                detail: 'Ingresos al almacen',
                accent: const Color(0xFF0F766E),
              ),
              MetricCard(
                label: 'Ventas',
                value: '$saleMovementsCount',
                detail: 'Salidas por atencion en tienda',
                accent: const Color(0xFFEA580C),
              ),
              MetricCard(
                label: 'Traslados y perdidas',
                value: '${transferMovementsCount + lossMovementsCount}',
                detail:
                    '$transferMovementsCount traslados | $lossMovementsCount perdidas',
                accent: const Color(0xFFB45309),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Todos los movimientos',
            subtitle:
                'Lista completa de compras, ventas, transferencias y perdidas con el mismo seguimiento operativo del modulo.',
            child:
                state.movements.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin movimientos registrados',
                      caption:
                          'Las compras, ventas y transferencias apareceran aqui.',
                    )
                    : _PaginatedList<InventoryMovement>(
                      items: state.movements,
                      itemBuilder: (context, movement) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          movement.productName,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _movementTypeLabel(movement),
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${movement.quantity} u.',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _InfoLine(
                                label: 'Ruta',
                                value:
                                    '${_movementOriginLabel(movement)} -> ${_movementDestinationLabel(movement)}',
                              ),
                              _InfoLine(
                                label: 'Responsable',
                                value: movement.actorName,
                              ),
                              if ((movement.supplierName ?? '')
                                  .trim()
                                  .isNotEmpty)
                                _InfoLine(
                                  label: 'Proveedor',
                                  value: movement.supplierName!.trim(),
                                ),
                              _InfoLine(
                                label: 'Fecha',
                                value: SystemWFormatters.shortDateTime.format(
                                  movement.occurredAt,
                                ),
                              ),
                              if ((movement.notes ?? '').trim().isNotEmpty)
                                _InfoLine(
                                  label: 'Notas',
                                  value: movement.notes!.trim(),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _openColdStateDialog(Product product) async {
    final quantityController = TextEditingController(
      text: '${product.coldStockUnits}',
    );
    final incrementController = TextEditingController(
      text: product.coldPriceIncrement.toStringAsFixed(2),
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(product.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Disponible en tienda: ${product.stockStore} u.'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad a helar',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: incrementController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Recargo por helada',
                    ),
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
                  onPressed: () async {
                    final quantity = int.tryParse(quantityController.text);
                    final increment = double.tryParse(incrementController.text);
                    if (quantity == null || quantity < 0) {
                      setState(() {
                        errorMessage = 'Ingresa una cantidad valida.';
                      });
                      return;
                    }
                    if (quantity > product.stockStore) {
                      setState(() {
                        errorMessage =
                            'No puedes helar mas de ${product.stockStore} u. en tienda.';
                      });
                      return;
                    }
                    if (increment == null || increment < 0) {
                      setState(() {
                        errorMessage = 'Ingresa un recargo valido.';
                      });
                      return;
                    }
                    final success = await widget.onUpdateColdState(
                      productId: product.id,
                      coldStockUnits: quantity,
                      coldPriceIncrement: increment,
                    );
                    if (success && mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PurchaseForm extends ConsumerStatefulWidget {
  const _PurchaseForm({
    required this.state,
    required this.isBusy,
    required this.currentUser,
    required this.onSubmitPurchaseCart,
    this.onHistoryProductChanged,
  });

  final AdminMobileDashboardState state;
  final bool isBusy;
  final AppUser? currentUser;
  final _PurchaseCartSubmit? onSubmitPurchaseCart;
  final ValueChanged<String?>? onHistoryProductChanged;

  @override
  ConsumerState<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<_PurchaseForm> {
  static const _newCategoryValue = '__new_category__';
  static const _newProductValue = '__new_product__';
  static const _newSupplierValue = '__new_supplier__';
  static const _artisanType = 'artesanal';
  static const _supplierType = 'proveedor';

  late final TextEditingController _newCategoryController;
  late final TextEditingController _newCategoryPrefixController;
  late final TextEditingController _newProductController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _brandController;
  late final TextEditingController _presentationController;
  late final TextEditingController _packageCostController;
  late final TextEditingController _costNotesController;
  late final TextEditingController _newSupplierController;
  late final TextEditingController _supplierPhoneController;
  String? _selectedCategoryValue;
  String? _selectedProductValue;
  String? _selectedSupplierValue;
  String _selectedProductType = _supplierType;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final selectedProduct = widget.state.selectedProduct;
    _newCategoryController = TextEditingController();
    _newCategoryPrefixController = TextEditingController();
    _newProductController = TextEditingController();
    _salePriceController = TextEditingController();
    _brandController = TextEditingController();
    _presentationController = TextEditingController();
    _packageCostController = TextEditingController();
    _costNotesController = TextEditingController();
    _newSupplierController = TextEditingController();
    _supplierPhoneController = TextEditingController();
    final supplierOptions = _allSupplierOptions(widget.state);
    _selectedCategoryValue = selectedProduct?.categoryId;
    _selectedProductValue = selectedProduct?.id;
    _selectedSupplierValue =
        widget.state.supplier.trim().isEmpty
            ? (supplierOptions.isEmpty ? null : supplierOptions.first)
            : widget.state.supplier.trim();
    _syncSupplierPhone();
    _loadProductFields(selectedProduct);
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    _newCategoryPrefixController.dispose();
    _newProductController.dispose();
    _salePriceController.dispose();
    _brandController.dispose();
    _presentationController.dispose();
    _packageCostController.dispose();
    _costNotesController.dispose();
    _newSupplierController.dispose();
    _supplierPhoneController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PurchaseForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentProductId = _selectedProductValue;
    if (currentProductId == null || currentProductId == _newProductValue) {
      return;
    }

    final previousProduct = _findProductById(
      oldWidget.state.products,
      currentProductId,
    );
    final nextProduct = _findProductById(
      widget.state.products,
      currentProductId,
    );
    final priceHistoryChanged =
        oldWidget.state.priceHistory.length != widget.state.priceHistory.length;
    final productPricingChanged =
        previousProduct?.salePrice != nextProduct?.salePrice ||
        previousProduct?.lastPurchaseCost != nextProduct?.lastPurchaseCost;
    final shouldRefresh =
        nextProduct != null &&
        (_salePriceController.text.trim().isEmpty ||
            priceHistoryChanged ||
            productPricingChanged);

    if (!shouldRefresh || nextProduct == null) {
      return;
    }

    _loadProductFields(nextProduct);
  }

  void _loadProductFields(Product? product) {
    if (product == null) {
      _selectedProductType = _supplierType;
      _salePriceController.clear();
      _brandController.clear();
      _presentationController.clear();
      _packageCostController.clear();
      _costNotesController.clear();
      return;
    }

    final costDetails = product.costDetails;
    final packageCost =
        _toDouble(costDetails['precio_caja']) ??
        (product.lastPurchaseCost * product.unitsPerPackage);
    final resolvedSalePrice = _latestKnownSalePrice(widget.state, product);

    _selectedProductType = product.productType;
    _salePriceController.text =
        resolvedSalePrice > 0 ? resolvedSalePrice.toStringAsFixed(2) : '';
    _brandController.text = costDetails['marca']?.toString() ?? '';
    _presentationController.text =
        costDetails['presentacion']?.toString() ?? '';
    _packageCostController.text =
        packageCost > 0 ? packageCost.toStringAsFixed(2) : '';
    _costNotesController.text =
        product.productType == _artisanType
            ? costDetails['observaciones_producto']?.toString() ?? ''
            : costDetails['observaciones']?.toString() ?? '';
  }

  void _applySuggestedUnitCost(int unitsPerPackage) {
    final packageCost = double.tryParse(_packageCostController.text);
    if (packageCost == null || packageCost <= 0 || unitsPerPackage <= 0) {
      return;
    }

    ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .changeUnitCost(packageCost / unitsPerPackage);
  }

  void _resetExpirySuggestion() {
    ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .changeExpiryDate(DateTime.now().add(const Duration(days: 30)));
  }

  void _syncSupplierPhone() {
    final supplierName =
        _selectedSupplierValue == null ||
                _selectedSupplierValue == _newSupplierValue
            ? _newSupplierController.text.trim()
            : _selectedSupplierValue!;
    _supplierPhoneController.text = _supplierPhoneForName(
      widget.state,
      supplierName,
    );
  }

  Future<void> _pickExpiryDate(DateTime initialDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'PE'),
    );
    if (picked == null) {
      return;
    }

    await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .changeExpiryDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final categories = state.categories;
    final supplierOptions = _allSupplierOptions(state);
    late final String categoryValue;
    if (_selectedCategoryValue == _newCategoryValue) {
      categoryValue = _newCategoryValue;
    } else if (_selectedCategoryValue != null &&
        categories.any((category) => category.id == _selectedCategoryValue)) {
      categoryValue = _selectedCategoryValue!;
    } else if (categories.isEmpty) {
      categoryValue = _newCategoryValue;
    } else {
      categoryValue = categories.first.id;
    }
    final isNewCategory = categoryValue == _newCategoryValue;
    final productsForCategory =
        isNewCategory
            ? <Product>[]
            : state.products
                .where((product) => product.categoryId == categoryValue)
                .toList();
    productsForCategory.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    late final String productValue;
    if (_selectedProductValue == _newProductValue) {
      productValue = _newProductValue;
    } else if (_selectedProductValue != null &&
        productsForCategory.any(
          (product) => product.id == _selectedProductValue,
        )) {
      productValue = _selectedProductValue!;
    } else if (productsForCategory.isEmpty) {
      productValue = _newProductValue;
    } else {
      productValue = productsForCategory.first.id;
    }
    final isNewProduct = isNewCategory || productValue == _newProductValue;
    late final String supplierValue;
    if (_selectedSupplierValue == _newSupplierValue) {
      supplierValue = _newSupplierValue;
    } else if (_selectedSupplierValue != null &&
        supplierOptions.contains(_selectedSupplierValue)) {
      supplierValue = _selectedSupplierValue!;
    } else if (supplierOptions.isEmpty) {
      supplierValue = _newSupplierValue;
    } else {
      supplierValue = supplierOptions.first;
    }

    final selectedProduct =
        isNewProduct
            ? null
            : _findProductById(productsForCategory, productValue);
    final effectiveProductType = _normalizePurchaseProductType(
      _selectedProductType,
    );
    final isSupplierProduct = _isSupplierProductType(effectiveProductType);
    final quantityLabel =
        isSupplierProduct ? 'Cajas compradas' : 'Cantidad producida';
    final unitsLabel =
        isSupplierProduct ? 'Unidades por caja' : 'Unidades por lote';
    final quantityNoun = isSupplierProduct ? 'cajas' : 'lotes';
    final unitLabel = selectedProduct?.unitName ?? 'unidades';
    final unitsPerPackage = state.unitsPerPackage;
    final totalUnits = state.quantity * unitsPerPackage;
    final currentMissingUnits =
        selectedProduct == null ? 0 : _missingUnits(selectedProduct);
    final packageCost = double.tryParse(_packageCostController.text) ?? 0;
    final salePriceValue = double.tryParse(_salePriceController.text) ?? 0;
    final effectiveUnitCost =
        isSupplierProduct && packageCost > 0 && unitsPerPackage > 0
            ? packageCost / unitsPerPackage
            : state.unitCost;
    final estimatedProfit = salePriceValue - effectiveUnitCost;
    final estimatedMargin =
        salePriceValue > 0 ? (estimatedProfit / salePriceValue) * 100 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: categoryValue,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: [
            ...categories.map(
              (category) => DropdownMenuItem(
                value: category.id,
                child: Text(_categoryOptionLabel(category)),
              ),
            ),
            const DropdownMenuItem(
              value: _newCategoryValue,
              child: Text('Crear nueva categoria'),
            ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _formError = null;
              _selectedCategoryValue = value;
              if (value == _newCategoryValue) {
                _selectedProductValue = _newProductValue;
                widget.onHistoryProductChanged?.call(null);
                _loadProductFields(null);
                _resetExpirySuggestion();
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .clearSelectedProduct();
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .changeUnitsPerPackage(1);
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .changeUnitCost(0);
              } else {
                Product? firstProduct;
                for (final product in state.products) {
                  if (product.categoryId == value) {
                    firstProduct = product;
                    break;
                  }
                }
                _selectedProductValue =
                    firstProduct == null ? _newProductValue : firstProduct.id;
                widget.onHistoryProductChanged?.call(firstProduct?.id);
                if (firstProduct != null) {
                  _loadProductFields(firstProduct);
                  ref
                      .read(adminMobileDashboardViewModelProvider.notifier)
                      .selectProduct(firstProduct.id);
                } else {
                  _loadProductFields(null);
                  _resetExpirySuggestion();
                  ref
                      .read(adminMobileDashboardViewModelProvider.notifier)
                      .clearSelectedProduct();
                  ref
                      .read(adminMobileDashboardViewModelProvider.notifier)
                      .changeUnitsPerPackage(1);
                  ref
                      .read(adminMobileDashboardViewModelProvider.notifier)
                      .changeUnitCost(0);
                }
              }
            });
          },
        ),
        if (isNewCategory) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _newCategoryController,
            decoration: const InputDecoration(
              labelText: 'Nombre de la nueva categoria',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _newCategoryPrefixController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Prefix de la categoria',
              helperText: 'Usa entre 3 y 5 letras mayusculas.',
            ),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: productValue,
          decoration: const InputDecoration(labelText: 'Producto'),
          items: [
            ...productsForCategory.map(
              (product) => DropdownMenuItem(
                value: product.id,
                child: Text(product.name),
              ),
            ),
            const DropdownMenuItem(
              value: _newProductValue,
              child: Text('Crear nuevo producto'),
            ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _formError = null;
              _selectedProductValue = value;
            });

            if (value != _newProductValue) {
              widget.onHistoryProductChanged?.call(value);
              final product = _findProductById(state.products, value);
              _loadProductFields(product);
              if (product != null) {
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .selectProduct(value);
              } else {
                _resetExpirySuggestion();
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .clearSelectedProduct();
              }
            } else {
              widget.onHistoryProductChanged?.call(null);
              _loadProductFields(null);
              _resetExpirySuggestion();
              ref
                  .read(adminMobileDashboardViewModelProvider.notifier)
                  .clearSelectedProduct();
              ref
                  .read(adminMobileDashboardViewModelProvider.notifier)
                  .changeUnitsPerPackage(1);
              ref
                  .read(adminMobileDashboardViewModelProvider.notifier)
                  .changeUnitCost(0);
            }
          },
        ),
        if (isNewProduct) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _newProductController,
            decoration: const InputDecoration(
              labelText: 'Nombre del nuevo producto',
            ),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedProductType,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: const [
            DropdownMenuItem(value: _supplierType, child: Text('Proveedor')),
            DropdownMenuItem(value: _artisanType, child: Text('Artesanal')),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _selectedProductType = value;
            });
            if (value == _artisanType) {
              ref
                  .read(adminMobileDashboardViewModelProvider.notifier)
                  .changeSupplier('');
            }
          },
        ),
        if (isSupplierProduct) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _brandController,
            decoration: const InputDecoration(labelText: 'Marca'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _presentationController,
            decoration: const InputDecoration(
              labelText: 'Presentacion',
              helperText: 'Ejemplo: 500 ml, 1 kg, bolsa x 24.',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _packageCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Precio caja/bolsa'),
            onChanged: (_) => _applySuggestedUnitCost(unitsPerPackage),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _costNotesController,
            decoration: const InputDecoration(
              labelText: 'Observaciones de costo',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: supplierValue,
            decoration: const InputDecoration(labelText: 'Proveedor'),
            items: [
              ...supplierOptions.map(
                (supplier) =>
                    DropdownMenuItem(value: supplier, child: Text(supplier)),
              ),
              const DropdownMenuItem(
                value: _newSupplierValue,
                child: Text('Crear nuevo proveedor'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _formError = null;
                _selectedSupplierValue = value;
              });

              if (value != _newSupplierValue) {
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .changeSupplier(value);
              }
              _syncSupplierPhone();
            },
          ),
          const SizedBox(height: 12),
          if (supplierValue == _newSupplierValue)
            TextFormField(
              controller: _newSupplierController,
              decoration: const InputDecoration(
                labelText: 'Nombre del nuevo proveedor',
              ),
              onChanged: (_) => _syncSupplierPhone(),
            ),
          if (supplierValue == _newSupplierValue) const SizedBox(height: 12),
          TextFormField(
            controller: _supplierPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
              _PhoneNumberFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Numero del proveedor',
              helperText: 'Opcional, util para contacto rapido.',
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _costNotesController,
            decoration: const InputDecoration(
              labelText: 'Observaciones del producto',
            ),
            maxLines: 3,
          ),
        ],
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _pickExpiryDate(state.expiryDate),
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha de vencimiento',
              helperText: 'Se guardara en el registro de esta compra.',
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(SystemWFormatters.shortDate.format(state.expiryDate)),
                const Icon(Icons.calendar_month_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;

            final quantityField = TextFormField(
              key: ValueKey(
                'purchase-quantity-$productValue-${state.quantity}',
              ),
              initialValue: '${state.quantity}',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: quantityLabel),
              onChanged: (value) {
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .changeQuantity(int.tryParse(value) ?? state.quantity);
              },
            );

            final unitsField = TextFormField(
              key: ValueKey('units-$productValue'),
              initialValue: '${state.unitsPerPackage}',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: unitsLabel),
              onChanged: (value) {
                final nextUnits = int.tryParse(value) ?? state.unitsPerPackage;
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .changeUnitsPerPackage(nextUnits);
                _applySuggestedUnitCost(nextUnits);
              },
            );

            final costField =
                isSupplierProduct
                    ? InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Costo unitario',
                        helperText:
                            'Calculado automaticamente con precio caja / unidades.',
                      ),
                      child: Text(
                        effectiveUnitCost > 0
                            ? effectiveUnitCost.toStringAsFixed(2)
                            : '0.00',
                      ),
                    )
                    : TextFormField(
                      key: ValueKey('cost-$productValue'),
                      initialValue: state.unitCost.toStringAsFixed(2),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Costo unitario',
                      ),
                      onChanged: (value) {
                        ref
                            .read(
                              adminMobileDashboardViewModelProvider.notifier,
                            )
                            .changeUnitCost(
                              double.tryParse(value) ?? state.unitCost,
                            );
                      },
                    );

            final salePriceField = TextFormField(
              controller: _salePriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio venta',
                helperText: 'Usa multiplos de S/ 0.10: 1.00, 1.20, 1.50.',
              ),
              onChanged: (_) => setState(() {}),
            );

            if (compact) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: quantityField),
                      const SizedBox(width: 12),
                      Expanded(child: unitsField),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: costField),
                      const SizedBox(width: 12),
                      Expanded(child: salePriceField),
                    ],
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: quantityField),
                const SizedBox(width: 12),
                Expanded(child: unitsField),
                const SizedBox(width: 12),
                Expanded(child: costField),
                const SizedBox(width: 12),
                Expanded(child: salePriceField),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _InfoLine(
          label: 'Fecha vencimiento',
          value: SystemWFormatters.shortDate.format(state.expiryDate),
        ),
        _InfoLine(
          label: 'Conversion a unidades',
          value:
              '${state.quantity} $quantityNoun x $unitsPerPackage = $totalUnits $unitLabel',
        ),
        _InfoLine(
          label: 'Costo unitario',
          value: SystemWFormatters.currency.format(effectiveUnitCost),
        ),
        _InfoLine(
          label: 'Ganancia unitaria',
          value: SystemWFormatters.currency.format(estimatedProfit),
        ),
        _InfoLine(
          label: 'Margen estimado',
          value: '${estimatedMargin.toStringAsFixed(1)}%',
        ),
        if (selectedProduct != null) ...[
          _InfoLine(
            label: 'Stock almacen actual',
            value: '${selectedProduct.stockWarehouse} u.',
          ),
          _InfoLine(
            label: isSupplierProduct ? 'Presentacion' : 'Produccion base',
            value:
                '1 ${_purchaseQuantitySingleLabel(effectiveProductType)} = $unitsPerPackage $unitLabel',
          ),
          _InfoLine(
            label: 'Costo anterior',
            value: SystemWFormatters.currency.format(
              selectedProduct.lastPurchaseCost,
            ),
          ),
          _InfoLine(
            label: 'Umbral guardado',
            value: '${state.lowStockThreshold} u.',
          ),
        ],
        _InfoLine(
          label: 'Total compra',
          value: SystemWFormatters.currency.format(
            totalUnits * effectiveUnitCost,
          ),
          isStrong: true,
        ),
        const SizedBox(height: 16),
        _PurchaseDraftCard(
          items: state.purchaseDraftItems,
          supplierName: state.purchaseDraftSupplier,
          supplierPhone: state.purchaseDraftSupplierPhone,
          totalUnits: state.purchaseDraftUnits,
          total: state.purchaseDraftTotal,
          onRemoveItem: (index) {
            ref
                .read(adminMobileDashboardViewModelProvider.notifier)
                .removePurchaseDraftLine(index);
          },
          onClear:
              state.purchaseDraftItems.isEmpty
                  ? null
                  : () {
                    ref
                        .read(adminMobileDashboardViewModelProvider.notifier)
                        .clearPurchaseDraft();
                  },
        ),
        if (_formError != null) ...[
          const SizedBox(height: 12),
          Text(
            _formError!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFFB91C1C)),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                widget.isBusy || widget.currentUser == null
                    ? null
                    : () => _addLineToDraft(
                      categoryValue: categoryValue,
                      productValue: productValue,
                      supplierValue: supplierValue,
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Agregar al carrito'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                widget.isBusy ||
                        widget.currentUser == null ||
                        widget.onSubmitPurchaseCart == null ||
                        state.purchaseDraftItems.isEmpty
                    ? null
                    : () async {
                      setState(() {
                        _formError = null;
                      });
                      await widget.onSubmitPurchaseCart!();
                    },
            icon: const Icon(Icons.save_rounded),
            label: Text(
              state.purchaseDraftItems.isEmpty
                  ? 'Agrega productos para registrar'
                  : 'Registrar compra completa',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addLineToDraft({
    required String categoryValue,
    required String productValue,
    required String supplierValue,
  }) async {
    final currentState =
        ref.read(adminMobileDashboardViewModelProvider).valueOrNull ??
        widget.state;
    String? categoryNameForCreation;
    String? categoryPrefixForCreation;
    String? productNameForCreation;

    if (categoryValue == _newCategoryValue) {
      final newCategoryName = _newCategoryController.text.trim();
      if (newCategoryName.isEmpty) {
        setState(() {
          _formError = 'Ingresa el nombre de la nueva categoria.';
        });
        return;
      }
      final newCategoryPrefix =
          _newCategoryPrefixController.text.trim().toUpperCase();
      if (newCategoryPrefix.isEmpty) {
        setState(() {
          _formError = 'Ingresa el prefix de la nueva categoria.';
        });
        return;
      }
      if (!RegExp(r'^[A-Z]{3,5}$').hasMatch(newCategoryPrefix)) {
        setState(() {
          _formError = 'El prefix debe tener entre 3 y 5 letras mayusculas.';
        });
        return;
      }
      categoryNameForCreation = newCategoryName;
      categoryPrefixForCreation = newCategoryPrefix;
    } else {
      final selectedCategory = _findCategoryById(
        widget.state.categories,
        categoryValue,
      );
      if (selectedCategory == null) {
        setState(() {
          _formError =
              'La categoria seleccionada ya no esta disponible. Vuelve a elegirla.';
        });
        return;
      }
      categoryNameForCreation = selectedCategory.name;
      categoryPrefixForCreation = selectedCategory.prefix;
    }

    if (productValue == _newProductValue ||
        categoryValue == _newCategoryValue) {
      final newProductName = _newProductController.text.trim();
      if (newProductName.isEmpty) {
        setState(() {
          _formError = 'Ingresa el nombre del producto.';
        });
        return;
      }
      productNameForCreation = newProductName;
    } else {
      final selectedProduct = _findProductById(
        widget.state.products,
        productValue,
      );
      if (selectedProduct == null) {
        setState(() {
          _formError =
              'El producto seleccionado ya no esta disponible. Vuelve a elegirlo.';
        });
        return;
      }
      productNameForCreation = selectedProduct.name;
    }

    final salePrice = double.tryParse(_salePriceController.text);
    if (salePrice == null || salePrice <= 0) {
      setState(() {
        _formError = 'Ingresa un precio de venta valido.';
      });
      return;
    }
    if (!_isSalePriceStepValid(salePrice)) {
      setState(() {
        _formError =
            'El precio de venta debe ser multiplo de S/ 0.10. Usa valores como 1.00, 1.20 o 1.50.';
      });
      return;
    }

    final effectiveProductType = _normalizePurchaseProductType(
      _selectedProductType,
    );
    final isSupplierProduct = _isSupplierProductType(effectiveProductType);
    late final double effectiveUnitCost;
    late final Map<String, dynamic> productCostDetails;
    late final String supplierName;
    String? supplierPhone;

    if (isSupplierProduct) {
      final brand = _brandController.text.trim();
      if (brand.isEmpty) {
        setState(() {
          _formError = 'Ingresa la marca para detallar el costo.';
        });
        return;
      }

      final presentation = _presentationController.text.trim();
      if (presentation.isEmpty) {
        setState(() {
          _formError = 'Ingresa la presentacion del producto.';
        });
        return;
      }

      final packageCost = double.tryParse(_packageCostController.text);
      if (packageCost == null || packageCost <= 0) {
        setState(() {
          _formError = 'Ingresa un precio de caja valido.';
        });
        return;
      }

      supplierName =
          supplierValue == _newSupplierValue
              ? _newSupplierController.text.trim()
              : supplierValue;
      if (supplierName.isEmpty) {
        setState(() {
          _formError = 'Selecciona o crea un proveedor.';
        });
        return;
      }

      final normalizedSupplierPhone = _supplierPhoneController.text.trim();
      supplierPhone =
          normalizedSupplierPhone.isEmpty ? null : normalizedSupplierPhone;

      effectiveUnitCost = packageCost / currentState.unitsPerPackage;
      productCostDetails = <String, dynamic>{
        'marca': brand,
        'presentacion': presentation,
        'precio_caja': packageCost,
        'cantidad_caja': currentState.unitsPerPackage,
        'observaciones': _costNotesController.text.trim(),
      };
    } else {
      supplierName = '';
      effectiveUnitCost = currentState.unitCost;
      productCostDetails = <String, dynamic>{
        'observaciones_producto': _costNotesController.text.trim(),
      };
    }

    if (effectiveUnitCost <= 0) {
      setState(() {
        _formError = 'Ingresa un costo unitario valido.';
      });
      return;
    }

    setState(() {
      _formError = null;
    });

    await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .changeSupplier(supplierName);
    await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .changeUnitCost(effectiveUnitCost);

    final draftLine = PurchaseDraftLine(
      categoryId: categoryValue == _newCategoryValue ? null : categoryValue,
      categoryName:
          categoryValue == _newCategoryValue ? categoryNameForCreation : null,
      categoryPrefix:
          categoryValue == _newCategoryValue ? categoryPrefixForCreation : null,
      productId:
          productValue == _newProductValue || categoryValue == _newCategoryValue
              ? null
              : productValue,
      productName: productNameForCreation,
      productType: effectiveProductType,
      quantity: currentState.quantity,
      unitsPerPackage: currentState.unitsPerPackage,
      lowStockThreshold: currentState.lowStockThreshold,
      unitCost: effectiveUnitCost,
      salePrice: salePrice,
      productCostDetails: productCostDetails,
      supplier: supplierName,
      supplierPhone: supplierPhone,
      expiryDate: currentState.expiryDate,
    );

    final added = await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .addPurchaseDraftLine(draftLine);
    if (!added || !mounted) {
      return;
    }

    setState(() {
      _formError = null;
    });
  }
}

class _PurchaseDraftCard extends StatelessWidget {
  const _PurchaseDraftCard({
    required this.items,
    required this.supplierName,
    required this.supplierPhone,
    required this.totalUnits,
    required this.total,
    required this.onRemoveItem,
    this.onClear,
  });

  final List<PurchaseDraftLine> items;
  final String supplierName;
  final String? supplierPhone;
  final int totalUnits;
  final double total;
  final ValueChanged<int> onRemoveItem;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final supplierLabel =
        supplierName.trim().isEmpty ? 'Produccion artesanal' : supplierName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Compra acumulada',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onClear != null)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: const Text('Vaciar'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'Todavia no agregas productos. Usa el formulario para ir acumulando lineas antes de registrar la compra.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else ...[
            _InfoLine(label: 'Proveedor', value: supplierLabel),
            if (supplierPhone != null && supplierPhone!.trim().isNotEmpty)
              _InfoLine(label: 'Telefono', value: supplierPhone!),
            _InfoLine(label: 'Lineas', value: '${items.length}'),
            _InfoLine(label: 'Unidades acumuladas', value: '$totalUnits u.'),
            _InfoLine(
              label: 'Total acumulado',
              value: SystemWFormatters.currency.format(total),
              isStrong: true,
            ),
            const SizedBox(height: 8),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final quantityLabel =
                  '${item.quantity} ${_purchaseQuantityNoun(item.productType)}';
              final unitLabel =
                  '${item.totalUnits} u. - ${SystemWFormatters.currency.format(item.subtotal)}';
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$quantityLabel x ${item.unitsPerPackage} = $unitLabel',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vence: ${SystemWFormatters.shortDate.format(item.expiryDate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => onRemoveItem(index),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _MobileSectionHeading extends StatelessWidget {
  const _MobileSectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _ProductInsightCard extends StatelessWidget {
  const _ProductInsightCard({required this.state, required this.product});

  final AdminMobileDashboardState state;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final costDetailsEntries =
        product.costDetails.entries.toList()
          ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    final purchaseSnapshot = _buildProductPurchaseSnapshot(state, product);
    final isSupplierProduct = _isSupplierProductType(product.productType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _InfoLine(
            label: 'Categoria',
            value: _categoryNameForProduct(state, product),
          ),
          _InfoLine(
            label: 'Precio venta',
            value: SystemWFormatters.currency.format(product.salePrice),
          ),
          _InfoLine(
            label: 'Costo compra',
            value: SystemWFormatters.currency.format(product.lastPurchaseCost),
          ),
          _InfoLine(
            label: 'Ganancia unitaria',
            value: SystemWFormatters.currency.format(_unitProfit(product)),
          ),
          _InfoLine(
            label: 'Margen estimado',
            value: '${_unitMargin(product).toStringAsFixed(1)}%',
          ),
          _InfoLine(label: 'Tienda', value: '${product.stockStore} u.'),
          _InfoLine(label: 'Almacen', value: '${product.stockWarehouse} u.'),
          _InfoLine(label: 'Faltantes', value: '${_missingUnits(product)} u.'),
          if (isSupplierProduct && _packageCostForProduct(product) > 0)
            _InfoLine(
              label: 'Precio caja',
              value: SystemWFormatters.currency.format(
                _packageCostForProduct(product),
              ),
            ),
          if (isSupplierProduct)
            _InfoLine(
              label: 'Presentacion',
              value: _presentationForProduct(product),
            ),
          if (purchaseSnapshot != null) ...[
            _InfoLine(
              label: _purchaseQuantityInfoLabel(product.productType),
              value:
                  '${purchaseSnapshot.latestPackageQuantity} ${_purchaseQuantityNoun(product.productType)}'
                  ' | ${purchaseSnapshot.latestTotalUnits} ${product.unitName}',
            ),
            _InfoLine(
              label: 'Inicio(CpPVez)',
              value: SystemWFormatters.shortDate.format(
                purchaseSnapshot.firstPurchaseAt,
              ),
            ),
            _InfoLine(
              label: 'Ultima compra',
              value: SystemWFormatters.shortDateTime.format(
                purchaseSnapshot.latestPurchaseAt,
              ),
            ),
            if (isSupplierProduct)
              _InfoLine(
                label: 'Proveedor reciente',
                value: purchaseSnapshot.latestSupplierName,
              ),
            _InfoLine(
              label: 'Proximo vencimiento',
              value: _formatOptionalDate(
                product.nextExpiryDate ?? purchaseSnapshot.nextExpiryDate,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Especificaciones',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (costDetailsEntries.isEmpty)
            const Text('Este producto no tiene especificaciones registradas.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  costDetailsEntries
                      .map(
                        (entry) => _SpecPill(
                          label: entry.key,
                          value: _formatSpecValue(entry.value),
                        ),
                      )
                      .toList(),
            ),
        ],
      ),
    );
  }
}

class _SpecPill extends StatelessWidget {
  const _SpecPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _MetricWrap extends StatelessWidget {
  const _MetricWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const minCardWidth = 240.0;
        final maxWidth = constraints.maxWidth;
        final isCompact = maxWidth < 720;
        if (children.isEmpty) {
          return const SizedBox.shrink();
        }
        if (isCompact) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          );
        }

        final cardsPerRow = math.max(
          1,
          ((maxWidth + spacing) / (minCardWidth + spacing)).floor(),
        );
        final normalizedCardsPerRow = math.min(cardsPerRow, children.length);
        final cardWidth =
            (maxWidth - spacing * (normalizedCardsPerRow - 1)) /
            normalizedCardsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}

class _PaginatedList<T> extends StatefulWidget {
  const _PaginatedList({
    required this.items,
    required this.itemBuilder,
    this.pageSize = 10,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int pageSize;

  @override
  State<_PaginatedList<T>> createState() => _PaginatedListState<T>();
}

class _PaginatedListState<T> extends State<_PaginatedList<T>> {
  int _pageIndex = 0;

  @override
  void didUpdateWidget(covariant _PaginatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pageIndex > _maxPage) {
      _pageIndex = _maxPage;
    }
  }

  int get _maxPage {
    if (widget.items.isEmpty) {
      return 0;
    }
    return (widget.items.length - 1) ~/ widget.pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final start = _pageIndex * widget.pageSize;
    final pageItems = widget.items.skip(start).take(widget.pageSize).toList();
    final end = start + pageItems.length;

    return Column(
      children: [
        ...pageItems.map((item) => widget.itemBuilder(context, item)),
        if (widget.items.length > widget.pageSize) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${start + 1}-$end de ${widget.items.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Pagina anterior',
                onPressed:
                    _pageIndex == 0
                        ? null
                        : () => setState(() => _pageIndex -= 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Pagina siguiente',
                onPressed:
                    _pageIndex >= _maxPage
                        ? null
                        : () => setState(() => _pageIndex += 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MovementPreviewCard extends StatelessWidget {
  const _MovementPreviewCard({
    required this.productName,
    required this.supplierName,
    this.receivedAt,
    this.expiryDate,
    required this.isPromotionPriority,
    this.promotionStatus,
    this.promotionalPrice,
    this.promotionNote,
    required this.quantity,
    required this.warehouseBefore,
    required this.warehouseAfter,
    required this.storeBefore,
    required this.storeAfter,
    required this.hasEnoughStock,
  });

  final String? productName;
  final String? supplierName;
  final DateTime? receivedAt;
  final DateTime? expiryDate;
  final bool isPromotionPriority;
  final String? promotionStatus;
  final double? promotionalPrice;
  final String? promotionNote;
  final int quantity;
  final int warehouseBefore;
  final int warehouseAfter;
  final int storeBefore;
  final int storeAfter;
  final bool hasEnoughStock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              hasEnoughStock
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFFCA5A5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen final', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _InfoLine(label: 'Producto', value: productName ?? 'Sin seleccionar'),
          _InfoLine(
            label: 'Proveedor',
            value: supplierName ?? 'Selecciona un lote',
          ),
          if (receivedAt != null)
            _InfoLine(
              label: 'Compra',
              value: SystemWFormatters.shortDateTime.format(receivedAt!),
            ),
          if (expiryDate != null)
            _InfoLine(
              label: 'Vencimiento',
              value: SystemWFormatters.shortDate.format(expiryDate!),
            ),
          if (isPromotionPriority)
            _InfoLine(
              label: 'Promo por lote',
              value:
                  promotionalPrice == null
                      ? _movementPromotionStatusLabel(promotionStatus)
                      : '${_movementPromotionStatusLabel(promotionStatus)} | ${SystemWFormatters.currency.format(promotionalPrice!)}',
              isStrong: true,
            ),
          if (!isPromotionPriority)
            const _InfoLine(label: 'Tipo de lote', value: 'Stock normal'),
          if ((promotionNote ?? '').trim().isNotEmpty)
            _InfoLine(label: 'Nota promo', value: promotionNote!.trim()),
          _InfoLine(label: 'Cantidad a mover', value: '$quantity u.'),
          _InfoLine(
            label: 'Almacen',
            value: '$warehouseBefore u. -> $warehouseAfter u.',
          ),
          _InfoLine(
            label: 'Tienda',
            value: '$storeBefore u. -> $storeAfter u.',
          ),
          if (!hasEnoughStock)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'La cantidad supera el stock disponible del lote seleccionado.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFB91C1C)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MovementLotSelectorCard extends StatelessWidget {
  const _MovementLotSelectorCard({
    required this.lots,
    required this.selectedPurchaseItemId,
    this.onSelectLot,
  });

  final List<WarehouseSupplierLot> lots;
  final String? selectedPurchaseItemId;
  final ValueChanged<String>? onSelectLot;

  @override
  Widget build(BuildContext context) {
    final totalAvailableUnits = lots.fold<int>(
      0,
      (sum, lot) => sum + lot.availableUnits,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lotes disponibles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _InfoLine(
            label: 'Disponible para mover',
            value: '$totalAvailableUnits u.',
            isStrong: true,
          ),
          _InfoLine(label: 'Lotes visibles', value: '${lots.length}'),
          const SizedBox(height: 8),
          Column(
            children:
                lots.map((lot) {
                  final selected = lot.purchaseItemId == selectedPurchaseItemId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap:
                          onSelectLot == null
                              ? null
                              : () => onSelectLot!(lot.purchaseItemId),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                selected
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFFE2E8F0),
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    lot.supplierName,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color:
                                      selected
                                          ? const Color(0xFF0F766E)
                                          : const Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _InfoLine(
                              label: 'Compra',
                              value: SystemWFormatters.shortDateTime.format(
                                lot.receivedAt,
                              ),
                            ),
                            _InfoLine(
                              label: 'Disponible',
                              value: '${lot.availableUnits} u.',
                              isStrong: selected,
                            ),
                            _InfoLine(
                              label: 'Vencimiento',
                              value: _formatOptionalDate(lot.expiryDate),
                            ),
                            if (lot.isPromotionPriority)
                              _InfoLine(
                                label: 'Promo por lote',
                                value:
                                    lot.promotionalPrice == null
                                        ? _movementPromotionStatusLabel(
                                          lot.promotionStatus,
                                        )
                                        : '${_movementPromotionStatusLabel(lot.promotionStatus)} | ${SystemWFormatters.currency.format(lot.promotionalPrice!)}',
                                isStrong: true,
                              ),
                            if (!lot.isPromotionPriority)
                              const _InfoLine(
                                label: 'Tipo de lote',
                                value: 'Stock normal',
                              ),
                            if ((lot.promotionNote ?? '').trim().isNotEmpty)
                              _InfoLine(
                                label: 'Nota promo',
                                value: lot.promotionNote!.trim(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ExpiredMovementLotsNoticeCard extends StatelessWidget {
  const _ExpiredMovementLotsNoticeCard({required this.alerts});

  final List<InventoryLotAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lotes ocultos por vencimiento',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Estos lotes no aparecen en la lista de movimientos porque ya vencieron. Revisalos en perdidas.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          ...alerts.map((alert) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.supplierName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    _InfoLine(
                      label: 'Vencio',
                      value: SystemWFormatters.shortDate.format(
                        alert.expiryDate,
                      ),
                    ),
                    _InfoLine(
                      label: 'Disponible',
                      value: '${alert.availableUnits} u.',
                    ),
                    _InfoLine(
                      label: 'Compra',
                      value: SystemWFormatters.shortDateTime.format(
                        alert.receivedAt,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MovementDraftCard extends StatelessWidget {
  const _MovementDraftCard({
    required this.items,
    required this.totalUnits,
    required this.onRemoveItem,
    this.onClear,
  });

  final List<MovementDraftLine> items;
  final int totalUnits;
  final ValueChanged<int> onRemoveItem;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final promoPriorityCount =
        items.where((item) => item.isPromotionPriority).length;
    final regularCount = items.length - promoPriorityCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Movimientos acumulados',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onClear != null)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: const Text('Vaciar'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'Todavia no agregas traslados. Selecciona un lote y acumula varios movimientos antes de registrarlos.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else ...[
            _InfoLine(label: 'Lineas', value: '${items.length}'),
            _InfoLine(label: 'Unidades acumuladas', value: '$totalUnits u.'),
            _InfoLine(label: 'Lotes en promo', value: '$promoPriorityCount'),
            _InfoLine(label: 'Lotes normales', value: '$regularCount'),
            const SizedBox(height: 8),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.quantity} u. desde ${item.supplierName}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Compra: ${SystemWFormatters.shortDateTime.format(item.receivedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Vence: ${_formatOptionalDate(item.expiryDate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.isPromotionPriority
                                ? 'Tipo: lote en promo'
                                : 'Tipo: stock normal',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (item.isPromotionPriority) ...[
                            Text(
                              item.promotionalPrice == null
                                  ? 'Promo por lote: ${_movementPromotionStatusLabel(item.promotionStatus)}'
                                  : 'Promo por lote: ${_movementPromotionStatusLabel(item.promotionStatus)} | ${SystemWFormatters.currency.format(item.promotionalPrice!)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFB45309)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => onRemoveItem(index),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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

class _SupplierSummary {
  const _SupplierSummary({
    required this.name,
    required this.purchaseCount,
    required this.total,
    required this.lastPurchaseAt,
    required this.categoriesLabel,
    this.phone,
  });

  final String name;
  final int purchaseCount;
  final double total;
  final DateTime lastPurchaseAt;
  final String categoriesLabel;
  final String? phone;
}

class _CategoryDetailRow {
  const _CategoryDetailRow({
    required this.supplierName,
    this.supplierPhone,
    required this.productName,
    required this.productType,
    required this.packageQuantity,
    required this.totalUnits,
    required this.costPrice,
    required this.salePrice,
    required this.firstPurchaseAt,
    required this.latestPurchaseAt,
    this.nextExpiryDate,
  });

  final String supplierName;
  final String? supplierPhone;
  final String productName;
  final String productType;
  final int packageQuantity;
  final int totalUnits;
  final double costPrice;
  final double salePrice;
  final DateTime firstPurchaseAt;
  final DateTime latestPurchaseAt;
  final DateTime? nextExpiryDate;
}

String _categoryNameForProduct(
  AdminMobileDashboardState state,
  Product product,
) {
  for (final category in state.categories) {
    if (category.id == product.categoryId) {
      return _categoryOptionLabel(category);
    }
  }

  return 'Sin categoria';
}

String _categoryOptionLabel(Category category) {
  final prefix = category.prefix.trim();
  if (prefix.isEmpty) {
    return category.name;
  }

  return '${category.name} ($prefix)';
}

bool _isBeverageSelection({
  required List<Category> categories,
  required String categoryValue,
  required String newCategoryName,
  required String newCategoryPrefix,
  String? productValue,
  List<Product>? products,
}) {
  if (productValue != null && products != null) {
    final product = _findProductById(products, productValue);
    if (product != null) {
      return isBeverageProduct(product, categories);
    }
  }

  if (categoryValue == _PurchaseFormState._newCategoryValue) {
    final draftCategory = Category(
      id: 'draft',
      name: newCategoryName.trim(),
      prefix: newCategoryPrefix.trim(),
    );
    return isBeverageCategory(draftCategory);
  }

  final category = _findCategoryById(categories, categoryValue);
  return category != null && isBeverageCategory(category);
}

int _missingUnits(Product product) {
  final missing = product.lowStockThreshold - product.stockWarehouse;
  return missing > 0 ? missing : 0;
}

double? _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '');
}

double _packageCostForProduct(Product product) {
  return _toDouble(product.costDetails['precio_caja']) ??
      (product.lastPurchaseCost * product.unitsPerPackage);
}

double _unitProfit(Product product) {
  return product.salePrice - product.lastPurchaseCost;
}

double _unitMargin(Product product) {
  if (product.salePrice <= 0) {
    return 0;
  }

  return (_unitProfit(product) / product.salePrice) * 100;
}

double _latestKnownSalePrice(AdminMobileDashboardState state, Product product) {
  for (final entry in state.priceHistory) {
    if (entry.productId != product.id) {
      continue;
    }
    if (entry.salePrice > 0) {
      return entry.salePrice;
    }
  }
  return product.salePrice;
}

String _productTypeLabel(String type) {
  return type.trim().toLowerCase() == 'artesanal' ? 'Artesanal' : 'Proveedor';
}

String _presentationForProduct(Product product) {
  final presentation =
      product.costDetails['presentacion']?.toString().trim() ?? '';
  if (presentation.isNotEmpty) {
    return presentation;
  }

  return '1 ${product.packageName} = ${product.unitsPerPackage} ${product.unitName}';
}

String _formatSpecValue(dynamic value) {
  if (value == null) {
    return '-';
  }
  if (value is List) {
    return value.join(', ');
  }
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
  }
  return value.toString();
}

String _formatOptionalDate(DateTime? value) {
  if (value == null) {
    return 'Sin fecha registrada';
  }

  return SystemWFormatters.shortDate.format(value);
}

String _normalizePurchaseProductType(String rawType) {
  return rawType.trim().toLowerCase() == 'artesanal'
      ? 'artesanal'
      : 'proveedor';
}

bool _isSupplierProductType(String rawType) {
  return _normalizePurchaseProductType(rawType) == 'proveedor';
}

String _purchaseQuantityInfoLabel(String rawType) {
  return _isSupplierProductType(rawType)
      ? 'Cajas compradas'
      : 'Cantidad producida';
}

String _purchaseQuantityNoun(String rawType) {
  return _isSupplierProductType(rawType) ? 'cajas' : 'lotes';
}

String _purchaseQuantitySingleLabel(String rawType) {
  return _isSupplierProductType(rawType) ? 'caja' : 'lote';
}

bool _isErrorFeedback(String message) {
  final normalized = message.trim().toLowerCase();
  return normalized.startsWith('no se pudo') ||
      normalized.startsWith('ingresa ') ||
      normalized.startsWith('selecciona ') ||
      normalized.startsWith('completa ');
}

bool _isSalePriceStepValid(double value) {
  final stepped = value * 10;
  return (stepped - stepped.round()).abs() < 0.000001;
}

bool _hasOperationalSupplier(String value) {
  final normalized = value.trim();
  return normalized.isNotEmpty && normalized != 'Produccion artesanal';
}

_ProductPurchaseSnapshot? _buildProductPurchaseSnapshot(
  AdminMobileDashboardState state,
  Product product,
) {
  DateTime? firstPurchaseAt;
  DateTime? latestPurchaseAt;
  String latestSupplierName = '';
  int latestPackageQuantity = 0;
  int latestTotalUnits = 0;
  DateTime? nextExpiryDate;

  for (final purchase in state.purchases) {
    for (final item in purchase.items) {
      if (item.productId != product.id) {
        continue;
      }

      if (firstPurchaseAt == null ||
          purchase.receivedAt.isBefore(firstPurchaseAt)) {
        firstPurchaseAt = purchase.receivedAt;
      }
      if (latestPurchaseAt == null ||
          purchase.receivedAt.isAfter(latestPurchaseAt)) {
        latestPurchaseAt = purchase.receivedAt;
        latestSupplierName = purchase.supplier;
        latestPackageQuantity = item.quantity;
        latestTotalUnits = item.totalUnits;
      }

      final expiryDate = item.expiryDate;
      if (expiryDate != null &&
          (nextExpiryDate == null || expiryDate.isBefore(nextExpiryDate))) {
        nextExpiryDate = expiryDate;
      }
    }
  }

  if (firstPurchaseAt == null || latestPurchaseAt == null) {
    return null;
  }

  return _ProductPurchaseSnapshot(
    firstPurchaseAt: firstPurchaseAt,
    latestPurchaseAt: latestPurchaseAt,
    latestSupplierName:
        latestSupplierName.trim().isEmpty
            ? 'Sin proveedor relacionado'
            : latestSupplierName,
    latestPackageQuantity: latestPackageQuantity,
    latestTotalUnits: latestTotalUnits,
    nextExpiryDate: nextExpiryDate,
  );
}

int _uniqueSupplierCount(AdminMobileDashboardState state) {
  final names = <String>{};

  for (final purchase in state.purchases) {
    final name = purchase.supplier.trim();
    if (_hasOperationalSupplier(name)) {
      names.add(name);
    }
  }

  return names.length;
}

Product? _findProductById(List<Product> products, String productId) {
  for (final product in products) {
    if (product.id == productId) {
      return product;
    }
  }

  return null;
}

Category? _findCategoryById(List<Category> categories, String categoryId) {
  for (final category in categories) {
    if (category.id == categoryId) {
      return category;
    }
  }

  return null;
}

List<String> _allSupplierOptions(AdminMobileDashboardState state) {
  final names = <String>{};

  for (final purchase in state.purchases) {
    final name = purchase.supplier.trim();
    if (_hasOperationalSupplier(name)) {
      names.add(name);
    }
  }

  final result =
      names.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}

class _SupplierOption {
  const _SupplierOption({required this.id, required this.name});

  final String id;
  final String name;
}

_SupplierOption? _supplierOptionById(
  List<_SupplierOption> options,
  String? supplierId,
) {
  if (supplierId == null) {
    return null;
  }

  for (final option in options) {
    if (option.id == supplierId) {
      return option;
    }
  }

  return null;
}

String _supplierLabelForProduct(
  AdminMobileDashboardState state,
  Product product,
) {
  final suppliers = _supplierOptionsForProduct(state, product);
  if (suppliers.isEmpty) {
    return 'Sin proveedor relacionado';
  }
  if (suppliers.length <= 2) {
    return suppliers.map((supplier) => supplier.name).join(', ');
  }
  return '${suppliers.take(2).map((supplier) => supplier.name).join(', ')} +${suppliers.length - 2}';
}

List<_SupplierOption> _supplierOptionsForProduct(
  AdminMobileDashboardState state,
  Product? selectedProduct,
) {
  if (selectedProduct == null) {
    return const [];
  }

  final optionsById = <String, _SupplierOption>{};

  for (final purchase in state.purchases) {
    final hasProduct = purchase.items.any(
      (item) => item.productId == selectedProduct.id,
    );
    if (!hasProduct) {
      continue;
    }

    final supplierId = purchase.supplierId?.trim();
    final supplierName = purchase.supplier.trim();
    if (supplierId == null ||
        supplierId.isEmpty ||
        !_hasOperationalSupplier(supplierName)) {
      continue;
    }

    optionsById[supplierId] = _SupplierOption(
      id: supplierId,
      name: supplierName,
    );
  }

  final result =
      optionsById.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
}

List<_SupplierSummary> _buildSupplierSummaries(
  AdminMobileDashboardState state,
) {
  final productById = {
    for (final product in state.products) product.id: product,
  };
  final categoryById = {
    for (final category in state.categories) category.id: category.name,
  };
  final grouped = <String, List<Purchase>>{};

  for (final purchase in state.purchases) {
    final supplierName = purchase.supplier.trim();
    if (supplierName.isEmpty) {
      continue;
    }
    grouped.putIfAbsent(supplierName, () => []).add(purchase);
  }

  final summaries =
      grouped.entries.map((entry) {
          final categories = <String>{};
          DateTime latestPurchase = entry.value.first.receivedAt;
          double total = 0;

          for (final purchase in entry.value) {
            total += purchase.total;
            if (purchase.receivedAt.isAfter(latestPurchase)) {
              latestPurchase = purchase.receivedAt;
            }

            for (final item in purchase.items) {
              final categoryId = productById[item.productId]?.categoryId;
              final categoryName =
                  categoryId == null ? null : categoryById[categoryId];
              if (categoryName != null && categoryName.trim().isNotEmpty) {
                categories.add(categoryName);
              }
            }
          }

          return _SupplierSummary(
            name: entry.key,
            purchaseCount: entry.value.length,
            total: total,
            lastPurchaseAt: latestPurchase,
            categoriesLabel:
                categories.isEmpty ? 'Sin categoria' : categories.join(', '),
            phone: _latestSupplierPhone(entry.value),
          );
        }).toList()
        ..sort((a, b) => b.lastPurchaseAt.compareTo(a.lastPurchaseAt));

  return summaries;
}

List<_CategoryDetailRow> _buildCategoryDetailRows(
  AdminMobileDashboardState state,
  String categoryId,
) {
  final productById = {
    for (final product in state.products) product.id: product,
  };
  final grouped = <String, _CategoryDetailAccumulator>{};

  for (final purchase in state.purchases) {
    for (final item in purchase.items) {
      final product = productById[item.productId];
      if (product == null || product.categoryId != categoryId) {
        continue;
      }

      final key = '${purchase.supplier}::${item.productId}';
      final existing =
          grouped[key] ??
          _CategoryDetailAccumulator(
            supplierName: purchase.supplier,
            supplierPhone: purchase.supplierPhone,
            productName: item.productName,
            productType: product.productType,
            salePrice: product.salePrice,
            firstPurchaseAt: purchase.receivedAt,
            latestPurchaseAt: purchase.receivedAt,
          );
      existing.packageQuantity += item.quantity;
      existing.totalUnits += item.totalUnits;
      existing.costPrice = item.unitCost;
      existing.salePrice = product.salePrice;
      if (purchase.receivedAt.isBefore(existing.firstPurchaseAt)) {
        existing.firstPurchaseAt = purchase.receivedAt;
      }
      if (purchase.receivedAt.isAfter(existing.latestPurchaseAt)) {
        existing.latestPurchaseAt = purchase.receivedAt;
      }
      final expiryDate = item.expiryDate;
      if (expiryDate != null &&
          (existing.nextExpiryDate == null ||
              expiryDate.isBefore(existing.nextExpiryDate!))) {
        existing.nextExpiryDate = expiryDate;
      }
      final supplierPhone = purchase.supplierPhone?.trim();
      if ((existing.supplierPhone == null || existing.supplierPhone!.isEmpty) &&
          supplierPhone != null &&
          supplierPhone.isNotEmpty) {
        existing.supplierPhone = supplierPhone;
      }
      grouped[key] = existing;
    }
  }

  final rows =
      grouped.values
          .map(
            (row) => _CategoryDetailRow(
              supplierName: row.supplierName,
              supplierPhone: row.supplierPhone,
              productName: row.productName,
              productType: row.productType,
              packageQuantity: row.packageQuantity,
              totalUnits: row.totalUnits,
              costPrice: row.costPrice,
              salePrice: row.salePrice,
              firstPurchaseAt: row.firstPurchaseAt,
              latestPurchaseAt: row.latestPurchaseAt,
              nextExpiryDate: row.nextExpiryDate,
            ),
          )
          .toList()
        ..sort(
          (a, b) => a.productName.toLowerCase().compareTo(
            b.productName.toLowerCase(),
          ),
        );

  return rows;
}

List<_PromotionLotRow> _buildPromotionLotRows(AdminMobileDashboardState state) {
  final productById = {
    for (final product in state.products) product.id: product,
  };
  final activeByPurchaseItemId = {
    for (final promotion in state.activeLotPromotions)
      promotion.purchaseItemId: promotion,
  };
  final items = <_PromotionLotRow>[];
  final seenPurchaseItemIds = <String>{};

  for (final promotion in state.activeLotPromotions) {
    seenPurchaseItemIds.add(promotion.purchaseItemId);
    items.add(
      _PromotionLotRow(
        purchaseItemId: promotion.purchaseItemId,
        productId: promotion.productId,
        productName: promotion.productName,
        product: productById[promotion.productId],
        supplierName: promotion.supplierName,
        expiryDate: promotion.expiryDate ?? DateTime.now(),
        warehouseAvailableUnits: promotion.warehouseAvailableUnits,
        storeAvailableUnits: promotion.storeAvailableUnits,
        totalAvailableUnits:
            promotion.warehouseAvailableUnits + promotion.storeAvailableUnits,
        locationLabel: _promotionLocationLabel(
          storeAvailableUnits: promotion.storeAvailableUnits,
          warehouseAvailableUnits: promotion.warehouseAvailableUnits,
        ),
        recommendationLabel: _promotionRecommendationLabel(
          storeAvailableUnits: promotion.storeAvailableUnits,
          warehouseAvailableUnits: promotion.warehouseAvailableUnits,
        ),
        activePromotion: promotion,
      ),
    );
  }

  for (final lot in state.promotableLots) {
    if (seenPurchaseItemIds.contains(lot.purchaseItemId)) {
      continue;
    }
    items.add(
      _PromotionLotRow(
        purchaseItemId: lot.purchaseItemId,
        productId: lot.productId,
        productName: lot.productName,
        product: productById[lot.productId],
        supplierName: lot.supplierName,
        expiryDate: lot.expiryDate,
        warehouseAvailableUnits: lot.warehouseAvailableUnits,
        storeAvailableUnits: lot.storeAvailableUnits,
        totalAvailableUnits: lot.totalAvailableUnits,
        locationLabel: _promotionLocationLabel(
          storeAvailableUnits: lot.storeAvailableUnits,
          warehouseAvailableUnits: lot.warehouseAvailableUnits,
        ),
        recommendationLabel: _promotionRecommendationLabel(
          storeAvailableUnits: lot.storeAvailableUnits,
          warehouseAvailableUnits: lot.warehouseAvailableUnits,
        ),
        activePromotion: activeByPurchaseItemId[lot.purchaseItemId],
      ),
    );
  }

  items.sort((left, right) {
    final expiryCompare = left.expiryDate.compareTo(right.expiryDate);
    if (expiryCompare != 0) {
      return expiryCompare;
    }
    return left.productName.toLowerCase().compareTo(
      right.productName.toLowerCase(),
    );
  });
  return items;
}

class _CategoryDetailAccumulator {
  _CategoryDetailAccumulator({
    required this.supplierName,
    this.supplierPhone,
    required this.productName,
    required this.productType,
    required this.salePrice,
    required this.firstPurchaseAt,
    required this.latestPurchaseAt,
    this.packageQuantity = 0,
    this.totalUnits = 0,
    this.costPrice = 0,
    this.nextExpiryDate,
  });

  final String supplierName;
  String? supplierPhone;
  final String productName;
  final String productType;
  int packageQuantity;
  int totalUnits;
  double costPrice;
  double salePrice;
  DateTime firstPurchaseAt;
  DateTime latestPurchaseAt;
  DateTime? nextExpiryDate;
}

class _PromotionLotRow {
  const _PromotionLotRow({
    required this.purchaseItemId,
    required this.productId,
    required this.productName,
    required this.product,
    required this.supplierName,
    required this.expiryDate,
    required this.warehouseAvailableUnits,
    required this.storeAvailableUnits,
    required this.totalAvailableUnits,
    required this.locationLabel,
    required this.recommendationLabel,
    this.activePromotion,
  });

  final String purchaseItemId;
  final String productId;
  final String productName;
  final Product? product;
  final String supplierName;
  final DateTime expiryDate;
  final int warehouseAvailableUnits;
  final int storeAvailableUnits;
  final int totalAvailableUnits;
  final String locationLabel;
  final String recommendationLabel;
  final LotPromotion? activePromotion;
}

String _promotionLocationLabel({
  required int storeAvailableUnits,
  required int warehouseAvailableUnits,
}) {
  if (storeAvailableUnits > 0 && warehouseAvailableUnits > 0) {
    return 'Tienda y almacen';
  }
  if (storeAvailableUnits > 0) {
    return 'Tienda';
  }
  if (warehouseAvailableUnits > 0) {
    return 'Solo almacen';
  }
  return 'Sin stock';
}

Product? _productById(List<Product> products, String? productId) {
  if (productId == null) {
    return null;
  }
  for (final product in products) {
    if (product.id == productId) {
      return product;
    }
  }
  return null;
}

WarehouseSupplierLot? _lotById(
  List<WarehouseSupplierLot> lots,
  String? purchaseItemId,
) {
  if (purchaseItemId == null) {
    return null;
  }
  for (final lot in lots) {
    if (lot.purchaseItemId == purchaseItemId) {
      return lot;
    }
  }
  return null;
}

String _packLotLabel(Product? product, WarehouseSupplierLot lot) {
  final salePrice = product == null ? 0 : product.salePrice;
  final expiry =
      lot.expiryDate == null
          ? 'Sin FV'
          : 'FV ${SystemWFormatters.shortDate.format(lot.expiryDate!)}';
  return '${lot.supplierName} | ${lot.availableUnits} u. | Costo ${SystemWFormatters.currency.format(lot.unitCost)} | Venta ${SystemWFormatters.currency.format(salePrice)} | $expiry';
}

String _promotionRecommendationLabel({
  required int storeAvailableUnits,
  required int warehouseAvailableUnits,
}) {
  if (storeAvailableUnits > 0 && warehouseAvailableUnits > 0) {
    return 'Ya puedes vender la promo en tienda y conviene mover el resto antes de que venza.';
  }
  if (storeAvailableUnits > 0) {
    return 'La promo ya esta lista para mostrarse en productos de tienda.';
  }
  if (warehouseAvailableUnits > 0) {
    return 'El lote sigue en almacen: muevelo rapido a tienda antes de vender la promo.';
  }
  return 'Este lote ya no tiene stock disponible para promo.';
}

String _promotionStatusLabel(LotPromotion promotion) {
  if (promotion.status == 'active_store') {
    return 'Activa en tienda';
  }
  if (promotion.status == 'pending_transfer') {
    return 'Pendiente de mover a tienda';
  }
  if (promotion.status == 'exhausted') {
    return 'Agotada';
  }
  return 'Cancelada';
}

String _promotionStatusText(String? status) {
  switch (status) {
    case 'active_store':
      return 'Activa en tienda';
    case 'pending_transfer':
      return 'Pendiente de mover a tienda';
    case 'exhausted':
      return 'Agotada';
    case 'cancelled':
      return 'Cancelada';
    default:
      return 'Promo registrada';
  }
}

String _promotionNoticeLabel(PromotionNotice notice) {
  if (notice.noticeType == 'promo_pending_transfer') {
    return 'Promo pendiente de traslado';
  }
  if (notice.noticeType == 'promo_exhausted') {
    return 'Promo agotada';
  }
  return 'Aviso de promocion';
}

String _shiftOpeningPlace(CashShift shift) {
  return _shiftPlaceLabel(
    locationName: shift.locationName,
    latitude: shift.openingLatitude,
    longitude: shift.openingLongitude,
    fallback: 'Sin ubicacion de inicio',
  );
}

String _shiftPlaceLabel({
  required String? locationName,
  required double? latitude,
  required double? longitude,
  required String fallback,
}) {
  final name = locationName?.trim();
  final coordinates = _coordinatesLabel(
    latitude: latitude,
    longitude: longitude,
  );
  if (name != null && name.isNotEmpty && coordinates != null) {
    return '$name | $coordinates';
  }
  if (coordinates != null) {
    return coordinates;
  }
  if (name != null && name.isNotEmpty) {
    return name;
  }
  return fallback;
}

String? _coordinatesLabel({
  required double? latitude,
  required double? longitude,
}) {
  if (latitude == null || longitude == null) {
    return null;
  }
  return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

String _movementPromotionStatusLabel(String? status) {
  if (status == 'pending_transfer') {
    return 'Pendiente de tienda';
  }
  if (status == 'active_store') {
    return 'Activa en tienda';
  }
  return 'Promo por lote';
}

String _lossReasonLabel(String? reason) {
  switch (reason) {
    case 'expired':
      return 'Expirado';
    case 'damaged':
      return 'Danado';
    case 'theft':
      return 'Robo';
    case 'quality_issue':
      return 'Problema de calidad';
    case 'other':
      return 'Otro';
    default:
      return 'Sin motivo';
  }
}

String _storageConditionLabel(String? storageCondition) {
  switch (storageCondition) {
    case 'ambiente':
      return 'Ambientado';
    case 'frio':
      return 'Helado';
    default:
      return 'Sin condicion';
  }
}

int _compareWarehouseLots(
  WarehouseSupplierLot left,
  WarehouseSupplierLot right,
) {
  final leftRank = _warehouseLotPriorityRank(left);
  final rightRank = _warehouseLotPriorityRank(right);
  if (leftRank != rightRank) {
    return leftRank.compareTo(rightRank);
  }

  final leftExpiry = left.expiryDate;
  final rightExpiry = right.expiryDate;
  if (leftExpiry != null && rightExpiry != null) {
    final expiryCompare = leftExpiry.compareTo(rightExpiry);
    if (expiryCompare != 0) {
      return expiryCompare;
    }
  } else if (leftExpiry != null) {
    return -1;
  } else if (rightExpiry != null) {
    return 1;
  }

  return left.receivedAt.compareTo(right.receivedAt);
}

int _warehouseLotPriorityRank(WarehouseSupplierLot lot) {
  if (!lot.isPromotionPriority) {
    return 2;
  }
  if (lot.promotionStatus == 'pending_transfer') {
    return 0;
  }
  if (lot.promotionStatus == 'active_store') {
    return 1;
  }
  return 2;
}

class _PhoneNumberFormatter extends TextInputFormatter {
  const _PhoneNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 9 ? digits.substring(0, 9) : digits;

    final formatted = switch (trimmed.length) {
      <= 3 => trimmed,
      <= 6 => '${trimmed.substring(0, 3)} ${trimmed.substring(3)}',
      _ =>
        '${trimmed.substring(0, 3)} ${trimmed.substring(3, 6)} ${trimmed.substring(6)}',
    };

    final digitsBeforeCursor =
        newValue.selection.baseOffset <= 0
            ? 0
            : newValue.text
                .substring(0, newValue.selection.baseOffset)
                .replaceAll(RegExp(r'\D'), '')
                .length;

    var cursorOffset = digitsBeforeCursor;
    if (digitsBeforeCursor > 3) {
      cursorOffset += 1;
    }
    if (digitsBeforeCursor > 6) {
      cursorOffset += 1;
    }
    if (cursorOffset > formatted.length) {
      cursorOffset = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
      composing: TextRange.empty,
    );
  }
}

String _supplierPhoneForName(
  AdminMobileDashboardState state,
  String supplierName,
) {
  final normalizedName = supplierName.trim().toLowerCase();
  if (normalizedName.isEmpty) {
    return '';
  }

  for (final purchase in state.purchases) {
    if (purchase.supplier.trim().toLowerCase() != normalizedName) {
      continue;
    }
    final phone = purchase.supplierPhone?.trim() ?? '';
    if (phone.isNotEmpty) {
      return phone;
    }
  }

  return '';
}

String? _latestSupplierPhone(List<Purchase> purchases) {
  for (final purchase in purchases) {
    final phone = purchase.supplierPhone?.trim() ?? '';
    if (phone.isNotEmpty) {
      return phone;
    }
  }
  return null;
}

String _movementTypeLabel(InventoryMovement movement) {
  switch (movement.type.toLowerCase()) {
    case 'purchase':
      return 'Compra';
    case 'sale':
      return 'Venta';
    case 'loss':
      return 'Perdida';
    default:
      return 'Transferencia';
  }
}

String _movementOriginLabel(InventoryMovement movement) {
  if (movement.fromLocation.toLowerCase().contains('sin origen')) {
    return 'Compra';
  }
  return movement.fromLocation;
}

String _movementDestinationLabel(InventoryMovement movement) {
  if (movement.type.toLowerCase() == 'loss') {
    return 'Perdida';
  }
  if (movement.toLocation.toLowerCase().contains('sin destino')) {
    return 'Venta';
  }
  return movement.toLocation;
}

int _icedStoreUnits(Product product) {
  final icedUnits = product.coldStockUnits;
  if (icedUnits <= 0) {
    return 0;
  }
  if (icedUnits >= product.stockStore) {
    return product.stockStore;
  }
  return icedUnits;
}

int _normalStoreUnits(Product product) {
  final normalUnits = product.stockStore - _icedStoreUnits(product);
  return normalUnits < 0 ? 0 : normalUnits;
}

String _purchaseItemsBreakdownLabel(Purchase purchase) {
  final grouped = <String, _PurchaseItemBreakdown>{};

  for (final item in purchase.items) {
    final key = '${item.productId}::${item.unitsPerPackage}';
    final current = grouped[key];
    if (current == null) {
      grouped[key] = _PurchaseItemBreakdown(
        productName: item.productName,
        quantity: item.quantity,
        unitsPerPackage: item.unitsPerPackage,
        totalUnits: item.totalUnits,
      );
      continue;
    }

    grouped[key] = _PurchaseItemBreakdown(
      productName: current.productName,
      quantity: current.quantity + item.quantity,
      unitsPerPackage: current.unitsPerPackage,
      totalUnits: current.totalUnits + item.totalUnits,
    );
  }

  return grouped.values
      .map(
        (item) =>
            '${item.productName}: ${item.quantity} x ${item.unitsPerPackage} = ${item.totalUnits} u.',
      )
      .join('\n');
}

class _ProductPurchaseSnapshot {
  const _ProductPurchaseSnapshot({
    required this.firstPurchaseAt,
    required this.latestPurchaseAt,
    required this.latestSupplierName,
    required this.latestPackageQuantity,
    required this.latestTotalUnits,
    this.nextExpiryDate,
  });

  final DateTime firstPurchaseAt;
  final DateTime latestPurchaseAt;
  final String latestSupplierName;
  final int latestPackageQuantity;
  final int latestTotalUnits;
  final DateTime? nextExpiryDate;
}

class _PurchaseItemBreakdown {
  const _PurchaseItemBreakdown({
    required this.productName,
    required this.quantity,
    required this.unitsPerPackage,
    required this.totalUnits,
  });

  final String productName;
  final int quantity;
  final int unitsPerPackage;
  final int totalUnits;
}

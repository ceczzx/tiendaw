// ignore_for_file: unused_element_parameter, unused_element, unnecessary_null_comparison

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/purchases/presentation/admin_mobile_dashboard_view_model.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

enum _AdminMobileSection { home, purchases, suppliers, movements }

typedef _PurchaseSubmit =
    Future<void> Function({
      String? categoryName,
      String? categoryPrefix,
      String? productName,
      String? productType,
      double? salePrice,
      Map<String, dynamic>? productCostDetails,
      String? supplierPhone,
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
                  child: KeyedSubtree(
                    key: ValueKey(_activeSection),
                    child: _buildSectionContent(state, currentUser),
                  ),
                ),
              ),
              const Divider(height: 1),
              NavigationBar(
                selectedIndex: _activeSection.index,
                onDestinationSelected: (index) {
                  setState(() {
                    _activeSection = _AdminMobileSection.values[index];
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Inicio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.shopping_bag_outlined),
                    selectedIcon: Icon(Icons.shopping_bag_rounded),
                    label: 'Compras',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.local_shipping_outlined),
                    selectedIcon: Icon(Icons.local_shipping_rounded),
                    label: 'Proveedores',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.swap_horiz_outlined),
                    selectedIcon: Icon(Icons.swap_horiz_rounded),
                    label: 'Movimientos',
                  ),
                ],
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
        onSubmitPurchase:
            currentUser == null ? null : _buildPurchaseSubmit(currentUser),
      ),
      _AdminMobileSection.suppliers => _SuppliersSection(state: state),
      _AdminMobileSection.movements => _MovementsSection(
        state: state,
        isBusy: _isActionInProgress,
        currentUser: currentUser,
        onTransfer:
            currentUser == null ? null : () => _handleTransfer(currentUser),
      ),
    };
  }

  Future<void> _handlePurchase(
    AppUser currentUser, {
    String? categoryName,
    String? categoryPrefix,
    String? productName,
    String? productType,
    double? salePrice,
    Map<String, dynamic>? productCostDetails,
    String? supplierPhone,
  }) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() {
      _isActionInProgress = true;
    });
    final success = await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .registerPurchase(
          currentUser,
          categoryName: categoryName,
          categoryPrefix: categoryPrefix,
          productName: productName,
          productType: productType,
          salePrice: salePrice,
          productCostDetails: productCostDetails,
          supplierPhone: supplierPhone,
        );

    if (!mounted || !success) {
      return;
    }

    setState(() {
      _isPurchaseComposerOpen = false;
    });
  }

  Future<void> _handleTransfer(AppUser currentUser) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() {
      _isActionInProgress = true;
    });
    await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .transferToStore(currentUser);
  }

  _PurchaseSubmit _buildPurchaseSubmit(AppUser currentUser) {
    return ({
      String? categoryName,
      String? categoryPrefix,
      String? productName,
      String? productType,
      double? salePrice,
      Map<String, dynamic>? productCostDetails,
      String? supplierPhone,
    }) {
      return _handlePurchase(
        currentUser,
        categoryName: categoryName,
        categoryPrefix: categoryPrefix,
        productName: productName,
        productType: productType,
        salePrice: salePrice,
        productCostDetails: productCostDetails,
        supplierPhone: supplierPhone,
      );
    };
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
                detail: 'Detectados desde compras e historial de costos',
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

class _PurchasesSection extends StatelessWidget {
  const _PurchasesSection({
    required this.state,
    required this.isComposerOpen,
    required this.isBusy,
    required this.currentUser,
    required this.onToggleComposer,
    required this.onSubmitPurchase,
  });

  final AdminMobileDashboardState state;
  final bool isComposerOpen;
  final bool isBusy;
  final AppUser? currentUser;
  final VoidCallback onToggleComposer;
  final _PurchaseSubmit? onSubmitPurchase;

  @override
  Widget build(BuildContext context) {
    final productById = {
      for (final product in state.products) product.id: product,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Compras',
            subtitle:
                'Abastecimiento con formulario guiado y listas paginadas cuando el historial supera 10 registros.',
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Agregar cosas',
            subtitle:
                'Primero define categoria, proveedor y producto. Si no existen, puedes crearlos desde aqui.',
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onToggleComposer,
                    icon: Icon(
                      isComposerOpen
                          ? Icons.expand_less_rounded
                          : Icons.add_rounded,
                    ),
                    label: Text(
                      isComposerOpen ? 'Ocultar formulario' : 'Agregar compra',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (isComposerOpen)
                  _PurchaseForm(
                    state: state,
                    isBusy: isBusy,
                    currentUser: currentUser,
                    onSubmitPurchase: onSubmitPurchase,
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
                'Ultimos costos registrados | Precio_unit - Cantidad en 1 caja',
            child:
                state.priceHistory.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin historial de precios',
                      caption:
                          'Las compras nuevas alimentaran este historial automaticamente.',
                    )
                    : _PaginatedList<PriceHistoryEntry>(
                      items: state.priceHistory,
                      itemBuilder: (context, entry) {
                        final product = productById[entry.productId];
                        final unitLabel =
                            product == null
                                ? 'u.'
                                : '${product.unitsPerPackage} ${product.unitName}';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.productName),
                          subtitle: Text(
                            '${entry.supplier} - ${SystemWFormatters.shortDate.format(entry.registeredAt)}',
                          ),
                          trailing: Text(
                            '${SystemWFormatters.currency.format(entry.unitCost)} - $unitLabel',
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
                        var totalPackages = 0;
                        var totalUnits = 0;
                        for (final item in purchase.items) {
                          totalPackages += item.quantity;
                          totalUnits += item.totalUnits;
                        }
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(purchase.supplier),
                          subtitle: Text(
                            '${purchase.registeredBy} - ${SystemWFormatters.shortDateTime.format(purchase.receivedAt)}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$totalPackages cajas | $totalUnits unid',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
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

class _MovementsSection extends StatefulWidget {
  const _MovementsSection({
    required this.state,
    required this.isBusy,
    required this.currentUser,
    required this.onTransfer,
  });

  final AdminMobileDashboardState state;
  final bool isBusy;
  final AppUser? currentUser;
  final Future<void> Function()? onTransfer;

  @override
  State<_MovementsSection> createState() => _MovementsSectionState();
}

class _MovementsSectionState extends State<_MovementsSection> {
  String? _selectedSupplier;
  String? _selectedCategoryId;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final selectedProduct = state.selectedProduct;
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
    final supplierOptions = _supplierOptionsForProduct(state, selectedProduct);
    final requiresSupplierReference =
        selectedProduct != null &&
        _isSupplierProductType(selectedProduct.productType);
    final effectiveSupplier =
        supplierOptions.contains(_selectedSupplier) ? _selectedSupplier : null;
    final quantity = state.quantity;
    final warehouseStock = selectedProduct?.stockWarehouse ?? 0;
    final storeStock = selectedProduct?.stockStore ?? 0;
    final remainingWarehouse = warehouseStock - quantity;
    final nextStoreStock = storeStock + quantity;
    final hasEnoughStock = selectedProduct == null || remainingWarehouse >= 0;
    final transferAllocations = _buildWarehouseTransferPreview(
      state,
      selectedProduct,
      quantity,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Movimientos',
            subtitle:
                'Define producto, proveedor de referencia y revisa un resumen final antes de mover stock de almacen a tienda.',
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
                'El proveedor se toma como referencia del producto elegido para que el admin tenga mas contexto.',
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
                            _selectedSupplier = null;
                          });
                          ref
                              .read(
                                adminMobileDashboardViewModelProvider.notifier,
                              )
                              .selectProduct(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (!requiresSupplierReference && selectedProduct != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Producto artesanal: no requiere proveedor para mover stock.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          value: effectiveSupplier,
                          decoration: const InputDecoration(
                            labelText: 'Proveedor de referencia',
                          ),
                          items:
                              supplierOptions
                                  .map(
                                    (supplier) => DropdownMenuItem(
                                      value: supplier,
                                      child: Text(supplier),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              supplierOptions.isEmpty
                                  ? null
                                  : (value) {
                                    setState(() {
                                      _selectedSupplier = value;
                                    });
                                  },
                        ),
                        if (supplierOptions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Aun no hay proveedores relacionados con este producto en compras o historial de precios.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: '${state.quantity}',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad a mover',
                        ),
                        onChanged: (value) {
                          ref
                              .read(
                                adminMobileDashboardViewModelProvider.notifier,
                              )
                              .changeQuantity(
                                int.tryParse(value) ?? state.quantity,
                              );
                        },
                      ),
                      const SizedBox(height: 16),
                      _MovementPreviewCard(
                        productName: selectedProduct?.name,
                        supplierName:
                            requiresSupplierReference
                                ? effectiveSupplier
                                : 'No aplica',
                        quantity: quantity,
                        warehouseBefore: warehouseStock,
                        warehouseAfter: remainingWarehouse,
                        storeBefore: storeStock,
                        storeAfter: nextStoreStock,
                        hasEnoughStock: hasEnoughStock,
                        allocations: transferAllocations,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              widget.currentUser == null ||
                                      widget.isBusy ||
                                      widget.onTransfer == null ||
                                      !hasEnoughStock ||
                                      (requiresSupplierReference &&
                                          supplierOptions.isNotEmpty &&
                                          effectiveSupplier == null)
                                  ? null
                                  : () => widget.onTransfer!(),
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Confirmar movimiento'),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Movimientos recientes',
            subtitle:
                'Compras, ventas y transferencias con paginacion desde 10 registros.',
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
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${movement.productName} - ${movement.quantity} u.',
                          ),
                          subtitle: Text(
                            '${movement.fromLocation} -> ${movement.toLocation} - ${movement.actorName}',
                          ),
                          trailing: Text(
                            SystemWFormatters.shortDate.format(
                              movement.occurredAt,
                            ),
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

class _PurchaseForm extends ConsumerStatefulWidget {
  const _PurchaseForm({
    required this.state,
    required this.isBusy,
    required this.currentUser,
    required this.onSubmitPurchase,
  });

  final AdminMobileDashboardState state;
  final bool isBusy;
  final AppUser? currentUser;
  final _PurchaseSubmit? onSubmitPurchase;

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

    _selectedProductType = product.productType;
    _salePriceController.text =
        product.salePrice > 0 ? product.salePrice.toStringAsFixed(2) : '';
    _brandController.text = costDetails['marca']?.toString() ?? '';
    _presentationController.text =
        costDetails['presentacion']?.toString() ?? '';
    _packageCostController.text =
        packageCost > 0 ? packageCost.toStringAsFixed(2) : '';
    _costNotesController.text =
        product.productType == _artisanType
            ? product.specs['observaciones']?.toString() ?? ''
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
            : productsForCategory.firstWhere(
              (product) => product.id == productValue,
            );
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
                _loadProductFields(null);
                _resetExpirySuggestion();
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
              final product = state.products.firstWhere(
                (item) => item.id == value,
              );
              _loadProductFields(product);
              ref
                  .read(adminMobileDashboardViewModelProvider.notifier)
                  .selectProduct(value);
            } else {
              _loadProductFields(null);
              _resetExpirySuggestion();
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
                widget.isBusy ||
                        widget.currentUser == null ||
                        widget.onSubmitPurchase == null
                    ? null
                    : () => _submit(
                      categoryValue: categoryValue,
                      productValue: productValue,
                      supplierValue: supplierValue,
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Guardar compra'),
          ),
        ),
      ],
    );
  }

  Future<void> _submit({
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
      final selectedCategory = widget.state.categories.firstWhere(
        (category) => category.id == categoryValue,
      );
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

      supplierPhone = _supplierPhoneController.text.trim();
      if (supplierPhone != null && supplierPhone.isEmpty) {
        supplierPhone = null;
      }

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

    await widget.onSubmitPurchase!(
      categoryName:
          productNameForCreation == null ? null : categoryNameForCreation,
      categoryPrefix:
          productNameForCreation == null ? null : categoryPrefixForCreation,
      productName: productNameForCreation,
      productType: effectiveProductType,
      salePrice: salePrice,
      productCostDetails: productCostDetails,
      supplierPhone: supplierPhone,
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
    final specsEntries =
        product.specs.entries.toList()
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
          if (specsEntries.isEmpty)
            const Text('Este producto no tiene especificaciones registradas.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  specsEntries
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
        final isCompact = constraints.maxWidth < 720;
        if (isCompact) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                SizedBox(height: 168, child: children[i]),
              ],
            ],
          );
        }

        return SizedBox(
          height: 180,
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: children[i]),
              ],
            ],
          ),
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
    required this.quantity,
    required this.warehouseBefore,
    required this.warehouseAfter,
    required this.storeBefore,
    required this.storeAfter,
    required this.hasEnoughStock,
    required this.allocations,
  });

  final String? productName;
  final String? supplierName;
  final int quantity;
  final int warehouseBefore;
  final int warehouseAfter;
  final int storeBefore;
  final int storeAfter;
  final bool hasEnoughStock;
  final List<_WarehouseTransferAllocation> allocations;

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
            value: supplierName ?? 'Selecciona un proveedor',
          ),
          _InfoLine(label: 'Cantidad a mover', value: '$quantity u.'),
          _InfoLine(
            label: 'Almacen',
            value: '$warehouseBefore u. -> $warehouseAfter u.',
          ),
          _InfoLine(
            label: 'Tienda',
            value: '$storeBefore u. -> $storeAfter u.',
          ),
          const SizedBox(height: 12),
          Text(
            'Detalle por cola',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (allocations.isEmpty)
            Text(
              productName == null
                  ? 'Selecciona un producto para ver que ingresos saldrian primero del almacen.'
                  : 'No pudimos reconstruir ingresos suficientes para detallar la salida desde el historial.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Column(
              children:
                  allocations.map((allocation) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allocation.sourceLabel,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            _InfoLine(
                              label: 'Ingreso',
                              value: SystemWFormatters.shortDateTime.format(
                                allocation.receivedAt,
                              ),
                            ),
                            _InfoLine(
                              label: 'Tomara',
                              value: '${allocation.pickedUnits} u.',
                            ),
                            _InfoLine(
                              label: 'Disponible en ese ingreso',
                              value: '${allocation.availableUnits} u.',
                            ),
                            if (allocation.expiryDate != null)
                              _InfoLine(
                                label: 'Vence',
                                value: SystemWFormatters.shortDate.format(
                                  allocation.expiryDate!,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          if (!hasEnoughStock)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'La cantidad supera el stock disponible en almacen.',
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

String _formatSpecsSummary(Map<String, dynamic> specs) {
  if (specs.isEmpty) {
    return 'Sin especificar';
  }

  if (specs.length == 1) {
    final entry = specs.entries.first;
    final key = entry.key.trim().toLowerCase();
    if (key == 'specs' || key == 'detalle' || key == 'descripcion') {
      return _formatSpecValue(entry.value);
    }
  }

  return specs.entries
      .map((entry) => '${entry.key}: ${_formatSpecValue(entry.value)}')
      .join(' | ');
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

  for (final entry in state.priceHistory) {
    final name = entry.supplier.trim();
    if (_hasOperationalSupplier(name)) {
      names.add(name);
    }
  }

  return names.length;
}

List<String> _allSupplierOptions(AdminMobileDashboardState state) {
  final names = <String>{};

  for (final purchase in state.purchases) {
    final name = purchase.supplier.trim();
    if (_hasOperationalSupplier(name)) {
      names.add(name);
    }
  }

  for (final entry in state.priceHistory) {
    final name = entry.supplier.trim();
    if (_hasOperationalSupplier(name)) {
      names.add(name);
    }
  }

  final result =
      names.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
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
    return suppliers.join(', ');
  }
  return '${suppliers.take(2).join(', ')} +${suppliers.length - 2}';
}

List<String> _supplierOptionsForProduct(
  AdminMobileDashboardState state,
  Product? selectedProduct,
) {
  if (selectedProduct == null) {
    return const [];
  }

  final names = <String>{};

  for (final entry in state.priceHistory) {
    if (entry.productId == selectedProduct.id) {
      final name = entry.supplier.trim();
      if (_hasOperationalSupplier(name)) {
        names.add(name);
      }
    }
  }

  for (final purchase in state.purchases) {
    final hasProduct = purchase.items.any(
      (item) => item.productId == selectedProduct.id,
    );
    if (hasProduct) {
      final name = purchase.supplier.trim();
      if (_hasOperationalSupplier(name)) {
        names.add(name);
      }
    }
  }

  final result =
      names.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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

List<_WarehouseTransferAllocation> _buildWarehouseTransferPreview(
  AdminMobileDashboardState state,
  Product? product,
  int requestedUnits,
) {
  if (product == null || requestedUnits <= 0 || product.stockWarehouse <= 0) {
    return const [];
  }

  final lots = <_WarehouseLotBalance>[];
  var totalPurchasedUnits = 0;

  for (final purchase in state.purchases) {
    for (final item in purchase.items) {
      if (item.productId != product.id) {
        continue;
      }

      final lotUnits = item.totalUnits;
      if (lotUnits <= 0) {
        continue;
      }

      totalPurchasedUnits += lotUnits;
      lots.add(
        _WarehouseLotBalance(
          sourceLabel:
              purchase.supplier.trim().isEmpty
                  ? 'Produccion artesanal'
                  : purchase.supplier,
          receivedAt: purchase.receivedAt,
          availableUnits: lotUnits,
          expiryDate: item.expiryDate,
        ),
      );
    }
  }

  if (lots.isEmpty) {
    return const [];
  }

  lots.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

  var alreadyMovedUnits = totalPurchasedUnits - product.stockWarehouse;
  if (alreadyMovedUnits < 0) {
    alreadyMovedUnits = 0;
  }

  for (final lot in lots) {
    if (alreadyMovedUnits <= 0) {
      break;
    }

    final consumedUnits = math.min(lot.availableUnits, alreadyMovedUnits);
    lot.availableUnits -= consumedUnits;
    alreadyMovedUnits -= consumedUnits;
  }

  final remainingLots =
      lots.where((lot) => lot.availableUnits > 0).toList()
        ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

  var unitsToPick = math.min(requestedUnits, product.stockWarehouse);
  final allocations = <_WarehouseTransferAllocation>[];

  for (final lot in remainingLots) {
    if (unitsToPick <= 0) {
      break;
    }

    final pickedUnits = math.min(lot.availableUnits, unitsToPick);
    allocations.add(
      _WarehouseTransferAllocation(
        sourceLabel: lot.sourceLabel,
        receivedAt: lot.receivedAt,
        availableUnits: lot.availableUnits,
        pickedUnits: pickedUnits,
        expiryDate: lot.expiryDate,
      ),
    );
    unitsToPick -= pickedUnits;
  }

  return allocations;
}

class _WarehouseLotBalance {
  _WarehouseLotBalance({
    required this.sourceLabel,
    required this.receivedAt,
    required this.availableUnits,
    this.expiryDate,
  });

  final String sourceLabel;
  final DateTime receivedAt;
  int availableUnits;
  final DateTime? expiryDate;
}

class _WarehouseTransferAllocation {
  const _WarehouseTransferAllocation({
    required this.sourceLabel,
    required this.receivedAt,
    required this.availableUnits,
    required this.pickedUnits,
    this.expiryDate,
  });

  final String sourceLabel;
  final DateTime receivedAt;
  final int availableUnits;
  final int pickedUnits;
  final DateTime? expiryDate;
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

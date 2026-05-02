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
    Future<void> Function({String? categoryName, String? productName});

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

  @override
  Widget build(BuildContext context) {
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
        currentUser: currentUser,
        onTransfer:
            currentUser == null ? null : () => _handleTransfer(currentUser),
      ),
    };
  }

  Future<void> _handlePurchase(
    AppUser currentUser, {
    String? categoryName,
    String? productName,
  }) async {
    final success = await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .registerPurchase(
          currentUser,
          categoryName: categoryName,
          productName: productName,
        );

    if (!mounted || !success) {
      return;
    }

    setState(() {
      _isPurchaseComposerOpen = false;
    });
  }

  Future<void> _handleTransfer(AppUser currentUser) async {
    await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .transferToStore(currentUser);
  }

  _PurchaseSubmit _buildPurchaseSubmit(AppUser currentUser) {
    return ({String? categoryName, String? productName}) {
      return _handlePurchase(
        currentUser,
        categoryName: categoryName,
        productName: productName,
      );
    };
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
    if (!widget.state.products.any((product) => product.id == _selectedProductId)) {
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
          if (state.feedbackMessage != null) ...[
            const SizedBox(height: 16),
            _FeedbackBanner(message: state.feedbackMessage!),
          ],
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
    required this.currentUser,
    required this.onToggleComposer,
    required this.onSubmitPurchase,
  });

  final AdminMobileDashboardState state;
  final bool isComposerOpen;
  final AppUser? currentUser;
  final VoidCallback onToggleComposer;
  final _PurchaseSubmit? onSubmitPurchase;

  @override
  Widget build(BuildContext context) {
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
          if (state.feedbackMessage != null) ...[
            const SizedBox(height: 16),
            _FeedbackBanner(message: state.feedbackMessage!),
          ],
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
                    onPressed: onToggleComposer,
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
            subtitle: 'Ultimos costos registrados en product_prices.',
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
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.productName),
                          subtitle: Text(
                            '${entry.supplier} - ${SystemWFormatters.shortDate.format(entry.registeredAt)}',
                          ),
                          trailing: Text(
                            SystemWFormatters.currency.format(entry.unitCost),
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
                          contentPadding: EdgeInsets.zero,
                          title: Text(purchase.supplier),
                          subtitle: Text(
                            '${purchase.registeredBy} - ${SystemWFormatters.shortDateTime.format(purchase.receivedAt)}',
                          ),
                          trailing: Text(
                            SystemWFormatters.currency.format(purchase.total),
                            style: Theme.of(context).textTheme.titleMedium,
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
        widget.state.categories.isEmpty ? null : widget.state.categories.first.id;
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
          if (state.feedbackMessage != null) ...[
            const SizedBox(height: 16),
            _FeedbackBanner(message: state.feedbackMessage!),
          ],
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
                            '${summary.categoriesLabel} - ${summary.purchaseCount} compras',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                SystemWFormatters.currency.format(summary.total),
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
                              child: Text(category.name),
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
                            const SizedBox(height: 8),
                            _InfoLine(
                              label: 'Cantidad comprada',
                              value: '${detail.quantity} u.',
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
    required this.currentUser,
    required this.onTransfer,
  });

  final AdminMobileDashboardState state;
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
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final totalStoreUnits = filteredProducts.fold<int>(
      0,
      (sum, product) => sum + product.stockStore,
    );
    final totalWarehouseUnits = filteredProducts.fold<int>(
      0,
      (sum, product) => sum + product.stockWarehouse,
    );
    final supplierOptions = _supplierOptionsForProduct(state, selectedProduct);
    final effectiveSupplier =
        supplierOptions.contains(_selectedSupplier) ? _selectedSupplier : null;
    final quantity = state.quantity;
    final warehouseStock = selectedProduct?.stockWarehouse ?? 0;
    final storeStock = selectedProduct?.stockStore ?? 0;
    final remainingWarehouse = warehouseStock - quantity;
    final nextStoreStock = storeStock + quantity;
    final hasEnoughStock = selectedProduct == null || remainingWarehouse >= 0;

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
          if (state.feedbackMessage != null) ...[
            const SizedBox(height: 16),
            _FeedbackBanner(message: state.feedbackMessage!),
          ],
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
                        child: Text(category.name),
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
                        decoration: const InputDecoration(labelText: 'Producto'),
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
                        supplierName: effectiveSupplier,
                        quantity: quantity,
                        warehouseBefore: warehouseStock,
                        warehouseAfter: remainingWarehouse,
                        storeBefore: storeStock,
                        storeAfter: nextStoreStock,
                        hasEnoughStock: hasEnoughStock,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              widget.currentUser == null ||
                                      widget.onTransfer == null ||
                                      !hasEnoughStock ||
                                      (supplierOptions.isNotEmpty &&
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
    required this.currentUser,
    required this.onSubmitPurchase,
  });

  final AdminMobileDashboardState state;
  final AppUser? currentUser;
  final _PurchaseSubmit? onSubmitPurchase;

  @override
  ConsumerState<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<_PurchaseForm> {
  static const _newCategoryValue = '__new_category__';
  static const _newProductValue = '__new_product__';
  static const _newSupplierValue = '__new_supplier__';

  late final TextEditingController _newCategoryController;
  late final TextEditingController _newProductController;
  late final TextEditingController _newSupplierController;
  String? _selectedCategoryValue;
  String? _selectedProductValue;
  String? _selectedSupplierValue;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final selectedProduct = widget.state.selectedProduct;
    _newCategoryController = TextEditingController();
    _newProductController = TextEditingController();
    _newSupplierController = TextEditingController();
    _selectedCategoryValue = selectedProduct?.categoryId;
    _selectedProductValue = selectedProduct?.id;
    _selectedSupplierValue =
        widget.state.supplier.trim().isEmpty ? null : widget.state.supplier.trim();
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    _newProductController.dispose();
    _newSupplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final categories = state.categories;
    final supplierOptions = _allSupplierOptions(state);
    late final String categoryValue;
    if (_selectedCategoryValue == _newCategoryValue) {
      categoryValue = _newCategoryValue;
    } else if (
        _selectedCategoryValue != null &&
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
    } else if (
        _selectedProductValue != null &&
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
    } else if (
        _selectedSupplierValue != null &&
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
            : productsForCategory.firstWhere((product) => product.id == productValue);
    final packageLabel = selectedProduct?.packageName ?? 'paquetes';
    final unitLabel = selectedProduct?.unitName ?? 'unidades';
    final unitsPerPackage = selectedProduct?.unitsPerPackage ?? 1;
    final totalUnits = state.quantity * unitsPerPackage;
    final currentMissingUnits =
        selectedProduct == null ? 0 : _missingUnits(selectedProduct);

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
                child: Text(category.name),
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
                  ref
                      .read(adminMobileDashboardViewModelProvider.notifier)
                      .selectProduct(firstProduct.id);
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
              ref
                  .read(adminMobileDashboardViewModelProvider.notifier)
                  .selectProduct(value);
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
          value: supplierValue,
          decoration: const InputDecoration(labelText: 'Proveedor'),
          items: [
            ...supplierOptions.map(
              (supplier) => DropdownMenuItem(
                value: supplier,
                child: Text(supplier),
              ),
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
          },
        ),
        if (supplierValue == _newSupplierValue) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _newSupplierController,
            decoration: const InputDecoration(
              labelText: 'Nombre del nuevo proveedor',
            ),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;

            final quantityField = TextFormField(
              initialValue: '${state.quantity}',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad ($packageLabel)',
              ),
              onChanged: (value) {
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .changeQuantity(int.tryParse(value) ?? state.quantity);
              },
            );

            final missingField = TextFormField(
              initialValue: '${state.lowStockThreshold}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Faltantes'),
              onChanged: (value) {
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .changeLowStockThreshold(
                      int.tryParse(value) ?? state.lowStockThreshold,
                    );
              },
            );

            final costField = TextFormField(
              initialValue: state.unitCost.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Costo unitario'),
              onChanged: (value) {
                ref
                    .read(adminMobileDashboardViewModelProvider.notifier)
                    .changeUnitCost(double.tryParse(value) ?? state.unitCost);
              },
            );

            if (compact) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: quantityField),
                      const SizedBox(width: 12),
                      Expanded(child: missingField),
                    ],
                  ),
                  const SizedBox(height: 12),
                  costField,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: quantityField),
                const SizedBox(width: 12),
                Expanded(child: missingField),
                const SizedBox(width: 12),
                Expanded(child: costField),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _InfoLine(
          label: 'Fecha vencimiento sugerida',
          value: SystemWFormatters.shortDate.format(state.expiryDate),
        ),
        _InfoLine(
          label: 'Conversion a unidades',
          value:
              '${state.quantity} x $unitsPerPackage = $totalUnits $unitLabel',
        ),
        _InfoLine(
          label: 'Faltantes actuales',
          value: '$currentMissingUnits u.',
        ),
        if (selectedProduct != null) ...[
          _InfoLine(
            label: 'Stock almacen actual',
            value: '${selectedProduct.stockWarehouse} u.',
          ),
          _InfoLine(
            label: 'Presentacion',
            value: '1 $packageLabel = $unitsPerPackage $unitLabel',
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
            state.quantity * state.unitCost,
          ),
          isStrong: true,
        ),
        if (_formError != null) ...[
          const SizedBox(height: 12),
          Text(
            _formError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFB91C1C),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                widget.currentUser == null || widget.onSubmitPurchase == null
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
    String? categoryNameForCreation;
    String? productNameForCreation;

    if (categoryValue == _newCategoryValue) {
      final newCategoryName = _newCategoryController.text.trim();
      if (newCategoryName.isEmpty) {
        setState(() {
          _formError = 'Ingresa el nombre de la nueva categoria.';
        });
        return;
      }
      categoryNameForCreation = newCategoryName;
    } else {
      final selectedCategory = widget.state.categories.firstWhere(
        (category) => category.id == categoryValue,
      );
      categoryNameForCreation = selectedCategory.name;
    }

    if (productValue == _newProductValue || categoryValue == _newCategoryValue) {
      final newProductName = _newProductController.text.trim();
      if (newProductName.isEmpty) {
        setState(() {
          _formError = 'Ingresa el nombre del producto.';
        });
        return;
      }
      productNameForCreation = newProductName;
    }

    final supplierName =
        supplierValue == _newSupplierValue
            ? _newSupplierController.text.trim()
            : supplierValue;
    if (supplierName.isEmpty) {
      setState(() {
        _formError = 'Selecciona o crea un proveedor.';
      });
      return;
    }

    setState(() {
      _formError = null;
    });

    await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .changeSupplier(supplierName);

    await widget.onSubmitPurchase!(
      categoryName: productNameForCreation == null ? null : categoryNameForCreation,
      productName: productNameForCreation,
    );
  }
}

class _MobileSectionHeading extends StatelessWidget {
  const _MobileSectionHeading({
    required this.title,
    required this.subtitle,
  });

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

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Text(message),
    );
  }
}

class _ProductInsightCard extends StatelessWidget {
  const _ProductInsightCard({
    required this.state,
    required this.product,
  });

  final AdminMobileDashboardState state;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final specsEntries = product.specs.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

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
            label: 'Presentacion',
            value:
                '1 ${product.packageName} = ${product.unitsPerPackage} ${product.unitName}',
          ),
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
  const _SpecPill({
    required this.label,
    required this.value,
  });

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
  });

  final String? productName;
  final String? supplierName;
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
          Text(
            'Resumen final',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
          if (!hasEnoughStock)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'La cantidad supera el stock disponible en almacen.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFB91C1C),
                ),
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
  });

  final String name;
  final int purchaseCount;
  final double total;
  final DateTime lastPurchaseAt;
  final String categoriesLabel;
}

class _CategoryDetailRow {
  const _CategoryDetailRow({
    required this.supplierName,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.salePrice,
  });

  final String supplierName;
  final String productName;
  final int quantity;
  final double costPrice;
  final double salePrice;
}

String _categoryNameForProduct(
  AdminMobileDashboardState state,
  Product product,
) {
  for (final category in state.categories) {
    if (category.id == product.categoryId) {
      return category.name;
    }
  }

  return 'Sin categoria';
}

int _missingUnits(Product product) {
  final missing = product.lowStockThreshold - product.stockWarehouse;
  return missing > 0 ? missing : 0;
}

String _formatSpecValue(dynamic value) {
  if (value == null) {
    return '-';
  }
  if (value is List) {
    return value.join(', ');
  }
  if (value is Map) {
    return value.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ');
  }
  return value.toString();
}

int _uniqueSupplierCount(AdminMobileDashboardState state) {
  final names = <String>{};

  for (final purchase in state.purchases) {
    final name = purchase.supplier.trim();
    if (name.isNotEmpty) {
      names.add(name);
    }
  }

  for (final entry in state.priceHistory) {
    final name = entry.supplier.trim();
    if (name.isNotEmpty) {
      names.add(name);
    }
  }

  return names.length;
}

List<String> _allSupplierOptions(AdminMobileDashboardState state) {
  final names = <String>{};

  for (final purchase in state.purchases) {
    final name = purchase.supplier.trim();
    if (name.isNotEmpty) {
      names.add(name);
    }
  }

  for (final entry in state.priceHistory) {
    final name = entry.supplier.trim();
    if (name.isNotEmpty) {
      names.add(name);
    }
  }

  final result = names.toList()
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
      if (name.isNotEmpty) {
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
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
  }

  final result = names.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}

List<_SupplierSummary> _buildSupplierSummaries(AdminMobileDashboardState state) {
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
            productName: item.productName,
            salePrice: product.salePrice,
          );
      existing.quantity += item.quantity * product.unitsPerPackage;
      existing.costPrice = item.unitCost;
      existing.salePrice = product.salePrice;
      grouped[key] = existing;
    }
  }

  final rows =
      grouped.values
          .map(
            (row) => _CategoryDetailRow(
              supplierName: row.supplierName,
              productName: row.productName,
              quantity: row.quantity,
              costPrice: row.costPrice,
              salePrice: row.salePrice,
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
    required this.productName,
    required this.salePrice,
    this.quantity = 0,
    this.costPrice = 0,
  });

  final String supplierName;
  final String productName;
  int quantity;
  double costPrice;
  double salePrice;
}

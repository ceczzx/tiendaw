import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/dashboard/presentation/admin_desktop_dashboard_view_model.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

enum AdminDesktopSection { sales, purchases, products, movements }

class AdminDesktopDashboardPage extends ConsumerWidget {
  const AdminDesktopDashboardPage({required this.activeSection, super.key});

  final AdminDesktopSection activeSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminDesktopDashboardViewModelProvider);

    return dashboard.when(
      data: (state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(activeSection),
            child: _DesktopSectionContent(
              activeSection: activeSection,
              state: state,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => Center(child: Text('Error cargando dashboard: $error')),
    );
  }
}

class _DesktopSectionContent extends ConsumerWidget {
  const _DesktopSectionContent({
    required this.activeSection,
    required this.state,
  });

  final AdminDesktopSection activeSection;
  final AdminDesktopDashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (activeSection) {
      AdminDesktopSection.sales => _SalesSection(
        state: state,
        onSellerChanged:
            (value) => ref
                .read(adminDesktopDashboardViewModelProvider.notifier)
                .setSellerFilter(value),
        onWindowChanged:
            (value) => ref
                .read(adminDesktopDashboardViewModelProvider.notifier)
                .setWindow(value),
      ),
      AdminDesktopSection.purchases => _PurchasesSection(
        state: state,
        onWindowChanged:
            (value) => ref
                .read(adminDesktopDashboardViewModelProvider.notifier)
                .setWindow(value),
      ),
      AdminDesktopSection.products => _ProductsSection(state: state),
      AdminDesktopSection.movements => _MovementsSection(
        state: state,
        onWindowChanged:
            (value) => ref
                .read(adminDesktopDashboardViewModelProvider.notifier)
                .setWindow(value),
      ),
    };
  }
}

class _SalesSection extends StatefulWidget {
  const _SalesSection({
    required this.state,
    required this.onSellerChanged,
    required this.onWindowChanged,
  });

  final AdminDesktopDashboardState state;
  final ValueChanged<String> onSellerChanged;
  final ValueChanged<DashboardWindow> onWindowChanged;

  @override
  State<_SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends State<_SalesSection> {
  String? _selectedShiftId;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final visibleShiftIds =
        state.filteredCashShifts.map((shift) => shift.id).toSet();
    final activeShiftId =
        _selectedShiftId != null && visibleShiftIds.contains(_selectedShiftId)
            ? _selectedShiftId
            : null;
    final selectedShift =
        activeShiftId == null
            ? null
            : state.filteredCashShifts.firstWhere(
              (shift) => shift.id == activeShiftId,
            );
    final salesRows =
        activeShiftId == null
            ? state.filteredSales
            : state.filteredSales
                .where((sale) => sale.cashShiftId == activeShiftId)
                .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Ventas',
            subtitle:
                'Revision comercial por periodo con foco en tickets, cobros y rendimiento del equipo.',
          ),
          const SizedBox(height: 20),
          _SalesFilters(
            state: state,
            onSellerChanged: widget.onSellerChanged,
            onWindowChanged: widget.onWindowChanged,
          ),
          const SizedBox(height: 20),
          _MetricRow(
            children: [
              MetricCard(
                label: 'Ventas del periodo',
                value: SystemWFormatters.currency.format(state.dailySalesTotal),
                detail: '${state.filteredSales.length} tickets',
                accent: const Color(0xFF0F766E),
              ),
              MetricCard(
                label: 'Mejor vendedor',
                value: state.topSeller,
                accent: const Color(0xFFEA580C),
              ),
              MetricCard(
                label: 'Mix de cobro',
                value:
                    '${SystemWFormatters.currency.format(state.cashSalesTotal)} cash',
                detail:
                    '${SystemWFormatters.currency.format(state.yapeSalesTotal)} yape/transfer',
                accent: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Turnos de caja',
            subtitle:
                'Selecciona un turno para revisar solo los tickets emitidos dentro de esa caja.',
            child: _DesktopTable(
              columns: const [
                'Inicio',
                'Cierre',
                'Vendedor',
                'Efectivo',
                'Digital',
                'Total',
                'Estado',
              ],
              rows:
                  state.filteredCashShifts.map((shift) {
                    final isSelected = shift.id == activeShiftId;
                    return _DesktopTableRow(
                      isSelected: isSelected,
                      onTap:
                          () => setState(() {
                            _selectedShiftId = isSelected ? null : shift.id;
                          }),
                      cells: [
                        Text(
                          SystemWFormatters.shortDateTime.format(
                            shift.openedAt,
                          ),
                        ),
                        Text(
                          shift.closedAt == null
                              ? 'Turno abierto'
                              : SystemWFormatters.shortDateTime.format(
                                shift.closedAt!,
                              ),
                        ),
                        Text(shift.sellerName ?? 'Vendedor'),
                        Text(
                          SystemWFormatters.currency.format(shift.cashSales),
                        ),
                        Text(
                          SystemWFormatters.currency.format(shift.yapeSales),
                        ),
                        Text(SystemWFormatters.currency.format(shift.total)),
                        StatusPill(
                          label: shift.closedAt == null ? 'Abierto' : 'Cerrado',
                          background:
                              shift.closedAt == null
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF1F5F9),
                          foreground:
                              shift.closedAt == null
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF334155),
                        ),
                      ],
                    );
                  }).toList(),
              emptyTitle: 'Sin turnos en este rango',
              emptyCaption:
                  'Abre una caja y registra ventas para ver los turnos aqui.',
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title:
                selectedShift == null
                    ? 'Tickets de venta'
                    : 'Tickets del turno seleccionado',
            subtitle:
                selectedShift == null
                    ? 'Tabla operativa para seguimiento rapido del periodo.'
                    : 'Detalle filtrado por la caja iniciada el ${SystemWFormatters.shortDateTime.format(selectedShift.openedAt)}.',
            trailing:
                selectedShift == null
                    ? null
                    : OutlinedButton.icon(
                      onPressed: () => setState(() => _selectedShiftId = null),
                      icon: const Icon(Icons.filter_alt_off_rounded),
                      label: const Text('Limpiar turno'),
                    ),
            child: _DesktopTable(
              columns: const [
                'Fecha',
                'Vendedor',
                'Pago',
                'Items',
                'Total',
                'Sync',
              ],
              rows:
                  salesRows
                      .map(
                        (sale) => _DesktopTableRow(
                          cells: [
                            Text(
                              SystemWFormatters.shortDateTime.format(
                                sale.createdAt,
                              ),
                            ),
                            Text(sale.sellerName),
                            Text(_paymentMethodLabel(sale.paymentMethod)),
                            Text('${sale.items.length}'),
                            Text(SystemWFormatters.currency.format(sale.total)),
                            Text(sale.syncStatus.name),
                          ],
                        ),
                      )
                      .toList(),
              emptyTitle:
                  selectedShift == null
                      ? 'Sin tickets en este rango'
                      : 'Este turno aun no tiene tickets',
              emptyCaption:
                  selectedShift == null
                      ? 'Ajusta el periodo o registra nuevas ventas.'
                      : 'Cuando se vendan productos en esta caja, apareceran aqui.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasesSection extends StatelessWidget {
  const _PurchasesSection({required this.state, required this.onWindowChanged});

  final AdminDesktopDashboardState state;
  final ValueChanged<DashboardWindow> onWindowChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Compras',
            subtitle:
                'Abastecimiento separado del dashboard general para revisar costo, proveedor y recepcion sin ruido.',
          ),
          const SizedBox(height: 20),
          _SectionToolbar(
            child: _WindowSelector(
              selectedWindow: state.window,
              onWindowChanged: onWindowChanged,
            ),
          ),
          const SizedBox(height: 20),
          _MetricRow(
            children: [
              MetricCard(
                label: 'Resumen del periodo',
                value: SystemWFormatters.currency.format(state.purchaseTotal),
                detail:
                    state.filteredPurchases.isEmpty
                        ? 'Sin compras registradas para este rango'
                        : 'Proveedor principal: ${state.topSupplier}',
                accent: const Color(0xFF0F766E),
                onTap: () => _showPurchaseOverviewDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Historial de compras',
            subtitle: 'Costo historico y trazabilidad de abastecimiento.',
            child: _DesktopTable(
              columns: const [
                'Fecha',
                'Proveedor',
                'Categorias',
                'Registrado por',
                'Total',
                'Sync',
              ],
              rows:
                  state.filteredPurchases
                      .map(
                        (purchase) => _DesktopTableRow(
                          cells: [
                            Text(
                              SystemWFormatters.shortDateTime.format(
                                purchase.receivedAt,
                              ),
                            ),
                            Text(purchase.supplier),
                            Text(_purchaseCategoriesLabel(state, purchase)),
                            Text(purchase.registeredBy),
                            Text(
                              SystemWFormatters.currency.format(purchase.total),
                            ),
                            Text(purchase.syncStatus.name),
                          ],
                        ),
                      )
                      .toList(),
              emptyTitle: 'Sin compras en este rango',
              emptyCaption:
                  'Cambia el periodo o registra nuevas compras para verlas aqui.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPurchaseOverviewDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PurchaseOverviewDialog(state: state),
    );
  }
}

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.state});

  final AdminDesktopDashboardState state;

  @override
  Widget build(BuildContext context) {
    final snapshots = _buildProductSnapshots(state);
    final storeUnits = state.products.fold<int>(
      0,
      (sum, product) => sum + product.stockStore,
    );
    final warehouseUnits = state.products.fold<int>(
      0,
      (sum, product) => sum + product.stockWarehouse,
    );
    final supplierTrackedCount =
        snapshots.where((snapshot) => snapshot.suppliers.isNotEmpty).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Productos',
            subtitle:
                'Mapa operativo del catalogo con stock actual, cajas, proveedores y ultima actividad por producto.',
          ),
          const SizedBox(height: 20),
          _MetricRow(
            children: [
              MetricCard(
                label: 'Catalogo activo',
                value: '${snapshots.length}',
                detail: '${state.categories.length} categorias',
                accent: const Color(0xFF0F766E),
              ),
              MetricCard(
                label: 'Stock actual',
                value: '$storeUnits u. tienda',
                detail: '$warehouseUnits u. en almacen',
                accent: const Color(0xFFEA580C),
              ),
              MetricCard(
                label: 'Productos con proveedor',
                value: '$supplierTrackedCount',
                detail:
                    '${snapshots.length - supplierTrackedCount} artesanales ',
                accent: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Vista producto por producto',
            subtitle:
                'Cada fila resume cantidad, cajas, costo, precio, hora de actividad y proveedores asociados.',
            child: _DesktopTable(
              columns: const [
                'Producto',
                'Categoria',
                'Tipo',
                'Mapa',
                'Cantidad',
                'Cajas / lote',
                'Ultima actividad',
                'Proveedores',
                'Precio / costo',
              ],
              rows:
                  snapshots
                      .map(
                        (snapshot) => _DesktopTableRow(
                          cells: [
                            _ProductNameCell(snapshot: snapshot),
                            Text(snapshot.categoryName),
                            _ProductTypeCell(product: snapshot.product),
                            _StockMapCell(product: snapshot.product),
                            _ProductQuantityCell(snapshot: snapshot),
                            SizedBox(
                              width: 190,
                              child: Text(snapshot.packageBreakdown),
                            ),
                            _ProductActivityCell(snapshot: snapshot),
                            SizedBox(
                              width: 220,
                              child: Text(
                                snapshot.suppliersLabel,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _ProductPricingCell(snapshot: snapshot),
                          ],
                        ),
                      )
                      .toList(),
              emptyTitle: 'Sin productos registrados',
              emptyCaption:
                  'Cuando cargues el catalogo, aqui aparecera la lectura completa de cada producto.',
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementsSection extends StatelessWidget {
  const _MovementsSection({required this.state, required this.onWindowChanged});

  final AdminDesktopDashboardState state;
  final ValueChanged<DashboardWindow> onWindowChanged;

  @override
  Widget build(BuildContext context) {
    final alertProducts = _collectAlertProducts(state);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Movimientos',
            subtitle:
                'Transferencias y alertas operativas separadas para monitorear stock y flujo entre almacen y tienda.',
          ),
          const SizedBox(height: 20),
          _SectionToolbar(
            child: _WindowSelector(
              selectedWindow: state.window,
              onWindowChanged: onWindowChanged,
            ),
          ),
          const SizedBox(height: 20),
          _MetricRow(
            children: [
              MetricCard(
                label: 'Movimientos del periodo | TIPO',
                value: '${state.filteredMovements.length}',
                detail:
                    'Compra ${state.purchaseMovementCount} | Venta ${state.saleMovementCount} | Transfer ${state.transferMovementCount}',
                accent: const Color(0xFF0F766E),
              ),
              MetricCard(
                label: 'Unidades movidas | CANTIDAD',
                value: '${state.movementUnitsTotal}',
                detail:
                    'Compra ${state.purchaseMovementUnits} u. | Venta ${state.saleMovementUnits} u. | Transfer ${state.transferMovementUnits} u.',
                accent: const Color(0xFFEA580C),
              ),
              MetricCard(
                label: 'Alertas activas',
                value: '${state.activeAlertCount}',
                detail: 'Stock bajo o vencimiento cercano',
                accent: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Alertas',
            subtitle:
                'Stock de tienda y almacen junto al motivo de alerta para reaccion rapida.',
            child: _DesktopTable(
              columns: const [
                'Producto',
                'Alerta',
                'Tienda',
                'Almacen',
                'Umbral',
                'Vence',
              ],
              rows:
                  alertProducts
                      .map(
                        (product) => _DesktopTableRow(
                          cells: [
                            Text(product.name),
                            Text(_alertReasonLabel(state, product)),
                            Text('${product.stockStore} u.'),
                            Text('${product.stockWarehouse} u.'),
                            Text('${product.lowStockThreshold} u.'),
                            Text(
                              product.nextExpiryDate == null
                                  ? '-'
                                  : SystemWFormatters.shortDate.format(
                                    product.nextExpiryDate!,
                                  ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
              emptyTitle: 'Sin alertas criticas',
              emptyCaption:
                  'No hay productos por vencer ni niveles de stock comprometidos.',
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Bitacora de movimientos',
            subtitle:
                'Lectura operativa separada por compra, venta y transferencia.',
            child: _DesktopTable(
              columns: const [
                'Fecha',
                'Producto',
                'Tipo',
                'Origen',
                'Destino',
                'Actor',
                'Cant.',
              ],
              rows:
                  state.filteredMovements
                      .map(
                        (movement) => _DesktopTableRow(
                          cells: [
                            Text(
                              SystemWFormatters.shortDateTime.format(
                                movement.occurredAt,
                              ),
                            ),
                            Text(movement.productName),
                            Text(_movementTypeLabel(movement)),
                            Text(_movementOriginLabel(movement)),
                            Text(_movementDestinationLabel(movement)),
                            Text(movement.actorName),
                            Text('${movement.quantity}'),
                          ],
                        ),
                      )
                      .toList(),
              emptyTitle: 'Sin movimientos en este rango',
              emptyCaption:
                  'Las compras, ventas y transferencias del periodo se listaran aqui.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _SalesFilters extends StatelessWidget {
  const _SalesFilters({
    required this.state,
    required this.onSellerChanged,
    required this.onWindowChanged,
  });

  final AdminDesktopDashboardState state;
  final ValueChanged<String> onSellerChanged;
  final ValueChanged<DashboardWindow> onWindowChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionToolbar(
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 250,
            child: DropdownButtonFormField<String>(
              value: state.sellerFilter,
              decoration: const InputDecoration(labelText: 'Filtro vendedor'),
              items: [
                ...state.sellerOptions.map(
                  (seller) => DropdownMenuItem(
                    value: seller['id'],
                    child: Text(seller['name']!),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onSellerChanged(value);
                }
              },
            ),
          ),
          _WindowSelector(
            selectedWindow: state.window,
            onWindowChanged: onWindowChanged,
          ),
        ],
      ),
    );
  }
}

class _SectionToolbar extends StatelessWidget {
  const _SectionToolbar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _WindowSelector extends StatelessWidget {
  const _WindowSelector({
    required this.selectedWindow,
    required this.onWindowChanged,
  });

  final DashboardWindow selectedWindow;
  final ValueChanged<DashboardWindow> onWindowChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DashboardWindow>(
      segments: const [
        ButtonSegment(value: DashboardWindow.today, label: Text('Hoy')),
        ButtonSegment(value: DashboardWindow.week, label: Text('7 dias')),
        ButtonSegment(value: DashboardWindow.month, label: Text('30 dias')),
      ],
      selected: {selectedWindow},
      onSelectionChanged: (value) => onWindowChanged(value.first),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _DesktopTableRow {
  const _DesktopTableRow({
    required this.cells,
    this.onTap,
    this.isSelected = false,
  });

  final List<Widget> cells;
  final VoidCallback? onTap;
  final bool isSelected;
}

class _DesktopTable extends StatefulWidget {
  const _DesktopTable({
    required this.columns,
    required this.rows,
    this.emptyTitle = 'Sin registros en este rango',
    this.emptyCaption = 'Ajusta el periodo o crea operaciones en Supabase.',
  });

  final List<String> columns;
  final List<_DesktopTableRow> rows;
  final String emptyTitle;
  final String emptyCaption;

  @override
  State<_DesktopTable> createState() => _DesktopTableState();
}

class _DesktopTableState extends State<_DesktopTable> {
  static const _pageSize = 10;
  int _pageIndex = 0;

  @override
  void didUpdateWidget(covariant _DesktopTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxPage = _maxPage;
    if (_pageIndex > maxPage) {
      _pageIndex = maxPage;
    }
  }

  int get _maxPage {
    if (widget.rows.isEmpty) {
      return 0;
    }
    return (widget.rows.length - 1) ~/ _pageSize;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return EmptyStateCard(
        title: widget.emptyTitle,
        caption: widget.emptyCaption,
      );
    }

    final start = _pageIndex * _pageSize;
    final pageRows = widget.rows.skip(start).take(_pageSize).toList();
    final end = start + pageRows.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            dataRowMinHeight: 56,
            dataRowMaxHeight: 110,
            columns:
                widget.columns
                    .map((label) => DataColumn(label: Text(label)))
                    .toList(),
            rows:
                pageRows
                    .map(
                      (row) => DataRow(
                        selected: row.isSelected,
                        onSelectChanged:
                            row.onTap == null ? null : (_) => row.onTap!(),
                        cells: row.cells.map((cell) => DataCell(cell)).toList(),
                      ),
                    )
                    .toList(),
          ),
        ),
        if (widget.rows.length > _pageSize) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${start + 1}-$end de ${widget.rows.length}',
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

class _DetailDialogShell extends StatelessWidget {
  const _DetailDialogShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PurchaseOverviewMode { purchases, suppliers }

class _PurchaseOverviewDialog extends StatefulWidget {
  const _PurchaseOverviewDialog({required this.state});

  final AdminDesktopDashboardState state;

  @override
  State<_PurchaseOverviewDialog> createState() =>
      _PurchaseOverviewDialogState();
}

class _PurchaseOverviewDialogState extends State<_PurchaseOverviewDialog> {
  String? _selectedCategoryId;
  _PurchaseOverviewMode _mode = _PurchaseOverviewMode.purchases;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final categoryOptions = state.categories;
    final summaries = _buildSupplierSummaries(
      state,
      categoryId: _selectedCategoryId,
    );
    final purchases =
        state.filteredPurchases
            .where(
              (purchase) => _purchaseMatchesCategory(
                state,
                purchase,
                _selectedCategoryId,
              ),
            )
            .toList();

    return _DetailDialogShell(
      title: 'Compras del periodo',
      subtitle:
          'Cambia la vista para separar el detalle de compras del resumen por proveedor sin mezclar ambas lecturas.',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<_PurchaseOverviewMode>(
                  segments: const [
                    ButtonSegment(
                      value: _PurchaseOverviewMode.purchases,
                      label: Text('Compras'),
                    ),
                    ButtonSegment(
                      value: _PurchaseOverviewMode.suppliers,
                      label: Text('Proveedores'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged:
                      (selection) => setState(() => _mode = selection.first),
                ),
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar categoria',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas las categorias'),
                      ),
                      ...categoryOptions.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged:
                        (value) => setState(() => _selectedCategoryId = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child:
                _mode == _PurchaseOverviewMode.purchases
                    ? _DesktopTable(
                      columns: const [
                        'Fecha',
                        'Proveedor',
                        'Categorias',
                        'Registrado por',
                        'Total',
                        'Sync',
                      ],
                      rows:
                          purchases
                              .map(
                                (purchase) => _DesktopTableRow(
                                  cells: [
                                    Text(
                                      SystemWFormatters.shortDateTime.format(
                                        purchase.receivedAt,
                                      ),
                                    ),
                                    Text(purchase.supplier),
                                    Text(
                                      _purchaseCategoriesLabel(state, purchase),
                                    ),
                                    Text(purchase.registeredBy),
                                    Text(
                                      SystemWFormatters.currency.format(
                                        purchase.total,
                                      ),
                                    ),
                                    Text(purchase.syncStatus.name),
                                  ],
                                ),
                              )
                              .toList(),
                      emptyTitle: 'Sin compras para este filtro',
                      emptyCaption:
                          'Selecciona otra categoria o amplia el rango del periodo.',
                    )
                    : _DesktopTable(
                      columns: const ['Proveedor', 'Categorias', 'Total'],
                      rows:
                          summaries
                              .map(
                                (summary) => _DesktopTableRow(
                                  cells: [
                                    Text(summary.supplier),
                                    Text(summary.categoriesLabel),
                                    Text(
                                      SystemWFormatters.currency.format(
                                        summary.total,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                      emptyTitle: 'Sin proveedores para este filtro',
                      emptyCaption:
                          'Cambia la categoria o registra compras en este periodo.',
                    ),
          ),
        ],
      ),
    );
  }
}

class _SupplierBreakdownDialog extends StatefulWidget {
  const _SupplierBreakdownDialog({required this.state});

  final AdminDesktopDashboardState state;

  @override
  State<_SupplierBreakdownDialog> createState() =>
      _SupplierBreakdownDialogState();
}

class _SupplierBreakdownDialogState extends State<_SupplierBreakdownDialog> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoryOptions = widget.state.categories;
    final summaries = _buildSupplierSummaries(
      widget.state,
      categoryId: _selectedCategoryId,
    );

    return _DetailDialogShell(
      title: 'Proveedores del periodo',
      subtitle:
          'Resumen agrupado por proveedor con filtro por categoria abastecida.',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 320,
              child: DropdownButtonFormField<String?>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Filtrar categoria',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las categorias'),
                  ),
                  ...categoryOptions.map(
                    (category) => DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged:
                    (value) => setState(() => _selectedCategoryId = value),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _DesktopTable(
              columns: const ['Proveedor', 'Categorias', 'Total'],
              rows:
                  summaries
                      .map(
                        (summary) => _DesktopTableRow(
                          cells: [
                            Text(summary.supplier),
                            Text(summary.categoriesLabel),
                            Text(
                              SystemWFormatters.currency.format(summary.total),
                            ),
                          ],
                        ),
                      )
                      .toList(),
              emptyTitle: 'Sin proveedores para este filtro',
              emptyCaption:
                  'Cambia la categoria o registra compras en este periodo.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseBreakdownDialog extends StatefulWidget {
  const _PurchaseBreakdownDialog({required this.state});

  final AdminDesktopDashboardState state;

  @override
  State<_PurchaseBreakdownDialog> createState() =>
      _PurchaseBreakdownDialogState();
}

class _PurchaseBreakdownDialogState extends State<_PurchaseBreakdownDialog> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoryOptions = widget.state.categories;
    final purchases =
        widget.state.filteredPurchases
            .where(
              (purchase) => _purchaseMatchesCategory(
                widget.state,
                purchase,
                _selectedCategoryId,
              ),
            )
            .toList();

    return _DetailDialogShell(
      title: 'Compras del periodo',
      subtitle:
          'Detalle completo con filtro por categoria comprada en el periodo.',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 320,
              child: DropdownButtonFormField<String?>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Filtrar categoria',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las categorias'),
                  ),
                  ...categoryOptions.map(
                    (category) => DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged:
                    (value) => setState(() => _selectedCategoryId = value),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _DesktopTable(
              columns: const [
                'Fecha',
                'Proveedor',
                'Categorias',
                'Registrado por',
                'Total',
                'Sync',
              ],
              rows:
                  purchases
                      .map(
                        (purchase) => _DesktopTableRow(
                          cells: [
                            Text(
                              SystemWFormatters.shortDateTime.format(
                                purchase.receivedAt,
                              ),
                            ),
                            Text(purchase.supplier),
                            Text(
                              _purchaseCategoriesLabel(widget.state, purchase),
                            ),
                            Text(purchase.registeredBy),
                            Text(
                              SystemWFormatters.currency.format(purchase.total),
                            ),
                            Text(purchase.syncStatus.name),
                          ],
                        ),
                      )
                      .toList(),
              emptyTitle: 'Sin compras para este filtro',
              emptyCaption:
                  'Selecciona otra categoria o amplia el rango del periodo.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSnapshot {
  const _ProductSnapshot({
    required this.product,
    required this.categoryName,
    required this.suppliers,
    required this.packageBreakdown,
    required this.lastPurchaseAt,
    required this.lastMovementAt,
    required this.latestUnitCost,
  });

  final Product product;
  final String categoryName;
  final List<String> suppliers;
  final String packageBreakdown;
  final DateTime? lastPurchaseAt;
  final DateTime? lastMovementAt;
  final double latestUnitCost;

  int get totalUnits => product.stockStore + product.stockWarehouse;

  String get suppliersLabel {
    if (suppliers.isEmpty) {
      return _isArtisanalProduct(product)
          ? 'Artesanal / sin proveedor'
          : 'Sin proveedor registrado';
    }
    return suppliers.join(', ');
  }
}

class _SupplierSummary {
  const _SupplierSummary({
    required this.supplier,
    required this.total,
    required this.categoriesLabel,
  });

  final String supplier;
  final double total;
  final String categoriesLabel;
}

class _ProductNameCell extends StatelessWidget {
  const _ProductNameCell({required this.snapshot});

  final _ProductSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.product.name,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${snapshot.totalUnits} ${snapshot.product.unitName} totales',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _ProductTypeCell extends StatelessWidget {
  const _ProductTypeCell({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final artisanal = _isArtisanalProduct(product);
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            label: product.productType,
            background:
                artisanal ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
            foreground:
                artisanal ? const Color(0xFF9A3412) : const Color(0xFF047857),
          ),
          const SizedBox(height: 6),
          Text(
            '${product.unitName} | ${product.packageName}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _StockMapCell extends StatelessWidget {
  const _StockMapCell({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final total = product.stockStore + product.stockWarehouse;

    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StockLane(
            label: 'Tienda',
            value: product.stockStore,
            total: total,
            color: const Color(0xFF0F766E),
          ),
          const SizedBox(height: 8),
          _StockLane(
            label: 'Almacen',
            value: product.stockWarehouse,
            total: total,
            color: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}

class _StockLane extends StatelessWidget {
  const _StockLane({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final widthFactor = total <= 0 ? 0.0 : value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Text('$value', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: const Color(0xFFE5E7EB),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(color: color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductQuantityCell extends StatelessWidget {
  const _ProductQuantityCell({required this.snapshot});

  final _ProductSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${snapshot.totalUnits} ${snapshot.product.unitName}'),
          const SizedBox(height: 4),
          Text(
            'Minimo ${snapshot.product.lowStockThreshold}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          Text(
            snapshot.product.nextExpiryDate == null
                ? 'Sin vencimiento'
                : 'Vence ${SystemWFormatters.shortDate.format(snapshot.product.nextExpiryDate!)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _ProductActivityCell extends StatelessWidget {
  const _ProductActivityCell({required this.snapshot});

  final _ProductSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.lastMovementAt == null
                ? 'Sin movimientos'
                : 'Mov. ${SystemWFormatters.shortDateTime.format(snapshot.lastMovementAt!)}',
          ),
          const SizedBox(height: 4),
          Text(
            snapshot.lastPurchaseAt == null
                ? 'Sin compra registrada'
                : 'Compra ${SystemWFormatters.shortDateTime.format(snapshot.lastPurchaseAt!)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _ProductPricingCell extends StatelessWidget {
  const _ProductPricingCell({required this.snapshot});

  final _ProductSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Venta ${SystemWFormatters.currency.format(snapshot.product.salePrice)}',
          ),
          const SizedBox(height: 4),
          Text(
            'Costo ${SystemWFormatters.currency.format(snapshot.latestUnitCost)} / ${snapshot.product.unitName}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

String _paymentMethodLabel(PaymentMethod method) {
  return switch (method) {
    PaymentMethod.cash => 'Efectivo',
    PaymentMethod.yape => 'Yape',
    PaymentMethod.transfer => 'Transferencia',
  };
}

String _purchaseCategoriesLabel(
  AdminDesktopDashboardState state,
  Purchase purchase,
) {
  final productById = {
    for (final product in state.products) product.id: product,
  };
  final categoryById = {
    for (final category in state.categories) category.id: category.name,
  };
  final categoryNames = <String>{};

  for (final item in purchase.items) {
    final categoryId = productById[item.productId]?.categoryId;
    if (categoryId == null) {
      continue;
    }
    final categoryName = categoryById[categoryId];
    if (categoryName != null) {
      categoryNames.add(categoryName);
    }
  }

  if (categoryNames.isEmpty) {
    return 'Sin categoria';
  }

  return categoryNames.join(', ');
}

bool _purchaseMatchesCategory(
  AdminDesktopDashboardState state,
  Purchase purchase,
  String? categoryId,
) {
  if (categoryId == null) {
    return true;
  }

  final productById = {
    for (final product in state.products) product.id: product,
  };
  return purchase.items.any(
    (item) => productById[item.productId]?.categoryId == categoryId,
  );
}

List<_SupplierSummary> _buildSupplierSummaries(
  AdminDesktopDashboardState state, {
  String? categoryId,
}) {
  final grouped = <String, List<Purchase>>{};

  for (final purchase in state.filteredPurchases) {
    if (!_purchaseMatchesCategory(state, purchase, categoryId)) {
      continue;
    }
    grouped.putIfAbsent(purchase.supplier, () => []).add(purchase);
  }

  final summaries =
      grouped.entries.map((entry) {
          final purchases = entry.value;
          final categories = <String>{};
          for (final purchase in purchases) {
            categories.addAll(
              _purchaseCategoriesLabel(state, purchase).split(', '),
            );
          }
          categories.removeWhere((label) => label.trim().isEmpty);

          return _SupplierSummary(
            supplier: entry.key,
            total: purchases.fold(0, (sum, purchase) => sum + purchase.total),
            categoriesLabel:
                categories.isEmpty ? 'Sin categoria' : categories.join(', '),
          );
        }).toList()
        ..sort((a, b) => b.total.compareTo(a.total));

  return summaries;
}

List<_ProductSnapshot> _buildProductSnapshots(
  AdminDesktopDashboardState state,
) {
  final categoryById = {
    for (final category in state.categories) category.id: category.name,
  };
  final purchasesByProduct = <String, List<Purchase>>{};
  for (final purchase in state.purchases) {
    final touchedProducts = <String>{};
    for (final item in purchase.items) {
      if (touchedProducts.add(item.productId)) {
        purchasesByProduct.putIfAbsent(item.productId, () => []).add(purchase);
      }
    }
  }

  final movementsByProduct = <String, List<InventoryMovement>>{};
  for (final movement in state.movements) {
    movementsByProduct.putIfAbsent(movement.productId, () => []).add(movement);
  }

  final snapshots =
      state.products.map((product) {
          final productPurchases = purchasesByProduct[product.id] ?? const [];
          final productMovements = movementsByProduct[product.id] ?? const [];
          final latestPurchase = _latestPurchaseForProduct(
            product.id,
            productPurchases,
          );
          final latestPurchaseLine =
              latestPurchase == null
                  ? null
                  : latestPurchase.items.firstWhere(
                    (item) => item.productId == product.id,
                  );
          final latestMovement =
              productMovements.isEmpty
                  ? null
                  : productMovements.reduce(
                    (current, next) =>
                        current.occurredAt.isAfter(next.occurredAt)
                            ? current
                            : next,
                  );
          final suppliers =
              productPurchases
                  .map((purchase) => purchase.supplier.trim())
                  .where(_hasOperationalSupplier)
                  .toSet()
                  .toList()
                ..sort();

          return _ProductSnapshot(
            product: product,
            categoryName: categoryById[product.categoryId] ?? 'Sin categoria',
            suppliers: suppliers,
            packageBreakdown: _packageBreakdownForProduct(product),
            lastPurchaseAt: latestPurchase?.receivedAt,
            lastMovementAt: latestMovement?.occurredAt,
            latestUnitCost:
                latestPurchaseLine?.unitCost ?? product.lastPurchaseCost,
          );
        }).toList()
        ..sort((a, b) {
          final categoryComparison = a.categoryName.toLowerCase().compareTo(
            b.categoryName.toLowerCase(),
          );
          if (categoryComparison != 0) {
            return categoryComparison;
          }
          return a.product.name.toLowerCase().compareTo(
            b.product.name.toLowerCase(),
          );
        });

  return snapshots;
}

Purchase? _latestPurchaseForProduct(
  String productId,
  List<Purchase> purchases,
) {
  if (purchases.isEmpty) {
    return null;
  }

  return purchases.reduce(
    (current, next) =>
        current.receivedAt.isAfter(next.receivedAt) ? current : next,
  );
}

List<Product> _collectAlertProducts(AdminDesktopDashboardState state) {
  final products = <String, Product>{};
  for (final product in state.lowStockProducts) {
    products[product.id] = product;
  }
  for (final product in state.expiringProducts) {
    products[product.id] = product;
  }

  final result =
      products.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
}

String _alertReasonLabel(AdminDesktopDashboardState state, Product product) {
  final reasons = <String>[];
  if (state.lowStockProducts.any((item) => item.id == product.id)) {
    reasons.add('Stock bajo');
  }
  if (state.expiringProducts.any((item) => item.id == product.id)) {
    reasons.add('Vence pronto');
  }
  return reasons.join(' / ');
}

bool _isArtisanalProduct(Product product) {
  return product.productType.trim().toLowerCase().contains('artesanal');
}

bool _hasOperationalSupplier(String value) {
  final normalized = value.trim();
  return normalized.isNotEmpty && normalized != 'Produccion artesanal';
}

String _packageBreakdownForProduct(Product product) {
  if (_isArtisanalProduct(product)) {
    return 'Artesanal | ${product.stockStore} ${product.unitName} tienda | ${product.stockWarehouse} ${product.unitName} almacen';
  }

  return 'Tienda ${_packageQuantityLabel(product, product.stockStore)} | Almacen ${_packageQuantityLabel(product, product.stockWarehouse)}';
}

String _packageQuantityLabel(Product product, int stockUnits) {
  final unitsPerPackage =
      product.unitsPerPackage <= 0 ? 1 : product.unitsPerPackage;
  final packages = stockUnits ~/ unitsPerPackage;
  final looseUnits = stockUnits % unitsPerPackage;
  final parts = <String>[];

  if (packages > 0) {
    parts.add('$packages ${product.packageName}');
  }
  if (looseUnits > 0 || parts.isEmpty) {
    parts.add('$looseUnits ${product.unitName}');
  }

  return parts.join(' + ');
}

String _movementTypeLabel(InventoryMovement movement) {
  final fromLocation = movement.fromLocation.toLowerCase();
  final toLocation = movement.toLocation.toLowerCase();
  if (fromLocation.contains('sin origen')) {
    return 'Compra';
  }
  if (toLocation.contains('sin destino')) {
    return 'Venta';
  }
  return 'Transferencia';
}

String _movementOriginLabel(InventoryMovement movement) {
  if (movement.fromLocation.toLowerCase().contains('sin origen')) {
    return 'Compra';
  }
  return movement.fromLocation;
}

String _movementDestinationLabel(InventoryMovement movement) {
  if (movement.toLocation.toLowerCase().contains('sin destino')) {
    return 'Venta';
  }
  return movement.toLocation;
}

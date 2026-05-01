import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/dashboard/presentation/admin_desktop_dashboard_view_model.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

enum AdminDesktopSection { sales, purchases, movements }

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
                label: 'Compras del periodo',
                value: SystemWFormatters.currency.format(state.purchaseTotal),
                detail: '${state.filteredPurchases.length} registros',
                accent: const Color(0xFF0F766E),
                onTap: () => _showPurchaseDialog(context),
              ),
              MetricCard(
                label: 'Proveedor principal',
                value: state.topSupplier,
                detail: 'Haz clic para ver proveedores por categoria',
                accent: const Color(0xFFEA580C),
                onTap: () => _showSupplierDialog(context),
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

  Future<void> _showSupplierDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SupplierBreakdownDialog(state: state),
    );
  }

  Future<void> _showPurchaseDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PurchaseBreakdownDialog(state: state),
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
              columns: const ['Proveedor', 'Categorias', 'Compras', 'Total'],
              rows:
                  summaries
                      .map(
                        (summary) => _DesktopTableRow(
                          cells: [
                            Text(summary.supplier),
                            Text(summary.categoriesLabel),
                            Text('${summary.purchaseCount}'),
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

class _SupplierSummary {
  const _SupplierSummary({
    required this.supplier,
    required this.purchaseCount,
    required this.total,
    required this.categoriesLabel,
  });

  final String supplier;
  final int purchaseCount;
  final double total;
  final String categoriesLabel;
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
            purchaseCount: purchases.length,
            total: purchases.fold(0, (sum, purchase) => sum + purchase.total),
            categoriesLabel:
                categories.isEmpty ? 'Sin categoria' : categories.join(', '),
          );
        }).toList()
        ..sort((a, b) => b.total.compareTo(a.total));

  return summaries;
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

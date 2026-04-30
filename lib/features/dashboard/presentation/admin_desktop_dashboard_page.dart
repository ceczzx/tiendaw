import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/dashboard/presentation/admin_desktop_dashboard_view_model.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

enum AdminDesktopSection { sales, purchases, movements }

class AdminDesktopDashboardPage extends ConsumerWidget {
  const AdminDesktopDashboardPage({
    required this.activeSection,
    super.key,
  });

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

class _SalesSection extends StatelessWidget {
  const _SalesSection({
    required this.state,
    required this.onSellerChanged,
    required this.onWindowChanged,
  });

  final AdminDesktopDashboardState state;
  final ValueChanged<String> onSellerChanged;
  final ValueChanged<DashboardWindow> onWindowChanged;

  @override
  Widget build(BuildContext context) {
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
            onSellerChanged: onSellerChanged,
            onWindowChanged: onWindowChanged,
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
            title: 'Tickets de venta',
            subtitle: 'Tabla operativa para seguimiento rapido del periodo.',
            child: _DesktopTable(
              columns: const ['Fecha', 'Vendedor', 'Pago', 'Total', 'Sync'],
              rows:
                  state.filteredSales
                      .map(
                        (sale) => [
                          SystemWFormatters.shortDateTime.format(sale.createdAt),
                          sale.sellerName,
                          switch (sale.paymentMethod) {
                            PaymentMethod.cash => 'Efectivo',
                            PaymentMethod.yape => 'Yape',
                            PaymentMethod.transfer => 'Transferencia',
                          },
                          SystemWFormatters.currency.format(sale.total),
                          sale.syncStatus.name,
                        ],
                      )
                      .toList(),
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
    required this.onWindowChanged,
  });

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
              ),
              MetricCard(
                label: 'Proveedor principal',
                value: state.topSupplier,
                accent: const Color(0xFFEA580C),
              ),
              MetricCard(
                label: 'Pendientes sync',
                value:
                    '${state.filteredPurchases.where((purchase) => purchase.syncStatus.name != 'synced').length}',
                detail: 'Compras aun no confirmadas',
                accent: const Color(0xFF2563EB),
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
                'Registrado por',
                'Total',
                'Sync',
              ],
              rows:
                  state.filteredPurchases
                      .map(
                        (purchase) => [
                          SystemWFormatters.shortDateTime.format(
                            purchase.receivedAt,
                          ),
                          purchase.supplier,
                          purchase.registeredBy,
                          SystemWFormatters.currency.format(purchase.total),
                          purchase.syncStatus.name,
                        ],
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementsSection extends StatelessWidget {
  const _MovementsSection({
    required this.state,
    required this.onWindowChanged,
  });

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
                label: 'Movimientos del periodo',
                value: '${state.filteredMovements.length}',
                detail: '${state.movementProductsCount} productos tocados',
                accent: const Color(0xFF0F766E),
              ),
              MetricCard(
                label: 'Unidades movidas',
                value: '${state.movementUnitsTotal}',
                detail: 'Transferencias y salidas registradas',
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
            subtitle: 'Productos por vencer y stock bajo para accion rapida.',
            child: Column(
              children: [
                ...state.expiringProducts.map(
                  (product) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name),
                    subtitle: const Text('Vencimiento dentro de 2 semanas'),
                    trailing: StatusPill(
                      label: SystemWFormatters.shortDate.format(
                        product.nextExpiryDate!,
                      ),
                      background: const Color(0xFFFFF7ED),
                      foreground: const Color(0xFF9A3412),
                    ),
                  ),
                ),
                ...state.lowStockProducts.map(
                  (product) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name),
                    subtitle: const Text('Stock bajo en tienda'),
                    trailing: StatusPill(
                      label: '${product.stockStore} u.',
                      background: const Color(0xFFFEF2F2),
                      foreground: const Color(0xFFB91C1C),
                    ),
                  ),
                ),
                if (state.expiringProducts.isEmpty &&
                    state.lowStockProducts.isEmpty)
                  const EmptyStateCard(
                    title: 'Sin alertas criticas',
                    caption: 'No hay productos por vencer ni stock bajo.',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Bitacora de movimientos',
            subtitle: 'Trazabilidad entre almacen y tienda.',
            child: _DesktopTable(
              columns: const [
                'Fecha',
                'Producto',
                'Tipo',
                'Origen',
                'Destino',
                'Cant.',
              ],
              rows:
                  state.filteredMovements
                      .map(
                        (movement) => [
                          SystemWFormatters.shortDateTime.format(
                            movement.occurredAt,
                          ),
                          movement.productName,
                          movement.type,
                          movement.fromLocation,
                          movement.toLocation,
                          '${movement.quantity}',
                        ],
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
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
      height: 190,
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

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const EmptyStateCard(
        title: 'Sin registros en este rango',
        caption: 'Ajusta el periodo o crea operaciones en Supabase.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns:
            columns.map((label) => DataColumn(label: Text(label))).toList(),
        rows:
            rows
                .map(
                  (cells) => DataRow(
                    cells: cells.map((cell) => DataCell(Text(cell))).toList(),
                  ),
                )
                .toList(),
      ),
    );
  }
}

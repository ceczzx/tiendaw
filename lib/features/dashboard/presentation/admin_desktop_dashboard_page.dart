import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/dashboard/presentation/admin_desktop_dashboard_view_model.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

class AdminDesktopDashboardPage extends ConsumerWidget {
  const AdminDesktopDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminDesktopDashboardViewModelProvider);

    return dashboard.when(
      data: (state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard administrativo',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Vista analitica para laptop con KPIs, alertas y tablas operativas.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: 250,
                    child: DropdownButtonFormField<String>(
                      value: state.sellerFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filtro vendedor',
                      ),
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
                          ref
                              .read(
                                adminDesktopDashboardViewModelProvider.notifier,
                              )
                              .setSellerFilter(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  SegmentedButton<DashboardWindow>(
                    segments: const [
                      ButtonSegment(
                        value: DashboardWindow.today,
                        label: Text('Hoy'),
                      ),
                      ButtonSegment(
                        value: DashboardWindow.week,
                        label: Text('7 dias'),
                      ),
                      ButtonSegment(
                        value: DashboardWindow.month,
                        label: Text('30 dias'),
                      ),
                    ],
                    selected: {state.window},
                    onSelectionChanged:
                        (value) => ref
                            .read(
                              adminDesktopDashboardViewModelProvider.notifier,
                            )
                            .setWindow(value.first),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 190,
                child: Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Ventas del periodo',
                        value: SystemWFormatters.currency.format(
                          state.dailySalesTotal,
                        ),
                        detail: '${state.filteredSales.length} tickets',
                        accent: const Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: MetricCard(
                        label: 'Mejor vendedor',
                        value: state.topSeller,
                        accent: const Color(0xFFEA580C),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: MetricCard(
                        label: 'Pendientes sync',
                        value: '${state.pendingSyncCount}',
                        detail: 'Se vacian al reconectar',
                        accent: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SectionCard(
                      title: 'Alertas',
                      subtitle: 'Productos por vencer y stock bajo.',
                      child: Column(
                        children: [
                          ...state.expiringProducts.map(
                            (product) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(product.name),
                              subtitle: const Text(
                                'Vencimiento dentro de 2 semanas',
                              ),
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
                              caption:
                                  'No hay productos por vencer ni stock bajo.',
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Ventas',
                subtitle: 'Tabla tipo Excel para revision rapida.',
                child: _DesktopTable(
                  columns: const ['Fecha', 'Vendedor', 'Pago', 'Total', 'Sync'],
                  rows:
                      state.filteredSales
                          .map(
                            (sale) => [
                              SystemWFormatters.shortDateTime.format(
                                sale.createdAt,
                              ),
                              sale.sellerName,
                              sale.paymentMethod == PaymentMethod.cash
                                  ? 'Efectivo'
                                  : 'Yape',
                              SystemWFormatters.currency.format(sale.total),
                              sale.syncStatus.name,
                            ],
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Compras',
                subtitle: 'Costo historico y abastecimiento.',
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
              const SizedBox(height: 16),
              SectionCard(
                title: 'Movimientos',
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => Center(child: Text('Error cargando dashboard: $error')),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/purchases/presentation/admin_mobile_dashboard_view_model.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

class AdminMobileDashboardPage extends ConsumerWidget {
  const AdminMobileDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminMobileDashboardViewModelProvider);
    final currentUser = ref.watch(sessionViewModelProvider).valueOrNull?.currentUser;

    return dashboard.when(
      data: (state) {
        final selectedProduct = state.selectedProduct;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operacion administrativa movil',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Compras, costos y movimientos conectados a tus tablas de Supabase.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              if (state.feedbackMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Text(state.feedbackMessage!),
                ),
                const SizedBox(height: 20),
              ],
              SectionCard(
                title: 'Registrar compra',
                subtitle: 'Producto, cantidad, costo, proveedor y vencimiento.',
                child:
                    state.products.isEmpty
                        ? const EmptyStateCard(
                          title: 'Sin productos registrados',
                          caption:
                              'Agrega productos y stock en Supabase para poder comprar.',
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: state.selectedProductId,
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
                                if (value != null) {
                                  ref
                                      .read(
                                        adminMobileDashboardViewModelProvider
                                            .notifier,
                                      )
                                      .selectProduct(value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 360;

                                if (compact) {
                                  return Column(
                                    children: [
                                      TextFormField(
                                        initialValue: '${state.quantity}',
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Cantidad',
                                        ),
                                        onChanged:
                                            (value) => ref
                                                .read(
                                                  adminMobileDashboardViewModelProvider
                                                      .notifier,
                                                )
                                                .changeQuantity(
                                                  int.tryParse(value) ??
                                                      state.quantity,
                                                ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        initialValue:
                                            state.unitCost.toStringAsFixed(2),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Costo unitario',
                                        ),
                                        onChanged:
                                            (value) => ref
                                                .read(
                                                  adminMobileDashboardViewModelProvider
                                                      .notifier,
                                                )
                                                .changeUnitCost(
                                                  double.tryParse(value) ??
                                                      state.unitCost,
                                                ),
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: '${state.quantity}',
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Cantidad',
                                        ),
                                        onChanged:
                                            (value) => ref
                                                .read(
                                                  adminMobileDashboardViewModelProvider
                                                      .notifier,
                                                )
                                                .changeQuantity(
                                                  int.tryParse(value) ??
                                                      state.quantity,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            state.unitCost.toStringAsFixed(2),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Costo unitario',
                                        ),
                                        onChanged:
                                            (value) => ref
                                                .read(
                                                  adminMobileDashboardViewModelProvider
                                                      .notifier,
                                                )
                                                .changeUnitCost(
                                                  double.tryParse(value) ??
                                                      state.unitCost,
                                                ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: state.supplier,
                              decoration: const InputDecoration(
                                labelText: 'Proveedor',
                              ),
                              onChanged:
                                  (value) => ref
                                      .read(
                                        adminMobileDashboardViewModelProvider
                                            .notifier,
                                      )
                                      .changeSupplier(value),
                            ),
                            const SizedBox(height: 16),
                            _InfoLine(
                              label: 'Fecha vencimiento sugerida',
                              value: SystemWFormatters.shortDate.format(
                                state.expiryDate,
                              ),
                            ),
                            _InfoLine(
                              label: 'Total compra',
                              value: SystemWFormatters.currency.format(
                                state.quantity * state.unitCost,
                              ),
                              isStrong: true,
                            ),
                            if (selectedProduct != null) ...[
                              const SizedBox(height: 6),
                              _InfoLine(
                                label: 'Stock almacen actual',
                                value: '${selectedProduct.stockWarehouse} u.',
                              ),
                            ],
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 360;

                                if (compact) {
                                  return Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed:
                                              currentUser == null
                                                  ? null
                                                  : () => ref
                                                      .read(
                                                        adminMobileDashboardViewModelProvider
                                                            .notifier,
                                                      )
                                                      .registerPurchase(
                                                        currentUser,
                                                      ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF0F766E,
                                            ),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Guardar compra'),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed:
                                              currentUser == null
                                                  ? null
                                                  : () => ref
                                                      .read(
                                                        adminMobileDashboardViewModelProvider
                                                            .notifier,
                                                      )
                                                      .transferToStore(
                                                        currentUser,
                                                      ),
                                          child: const Text('Mover a tienda'),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            currentUser == null
                                                ? null
                                                : () => ref
                                                    .read(
                                                      adminMobileDashboardViewModelProvider
                                                          .notifier,
                                                    )
                                                    .registerPurchase(
                                                      currentUser,
                                                    ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF0F766E,
                                          ),
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Guardar compra'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed:
                                            currentUser == null
                                                ? null
                                                : () => ref
                                                    .read(
                                                      adminMobileDashboardViewModelProvider
                                                          .notifier,
                                                    )
                                                    .transferToStore(
                                                      currentUser,
                                                    ),
                                        child: const Text('Mover a tienda'),
                                      ),
                                    ),
                                  ],
                                );
                              },
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
                        : Column(
                          children:
                              state.priceHistory.take(4).map((entry) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.productName),
                                  subtitle: Text(
                                    '${entry.supplier} - ${SystemWFormatters.shortDate.format(entry.registeredAt)}',
                                  ),
                                  trailing: Text(
                                    SystemWFormatters.currency.format(
                                      entry.unitCost,
                                    ),
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                );
                              }).toList(),
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
                        : Column(
                          children:
                              state.purchases.take(3).map((purchase) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(purchase.supplier),
                                  subtitle: Text(
                                    '${purchase.registeredBy} - ${SystemWFormatters.shortDateTime.format(purchase.receivedAt)}',
                                  ),
                                  trailing: Text(
                                    SystemWFormatters.currency.format(
                                      purchase.total,
                                    ),
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                );
                              }).toList(),
                        ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Movimientos',
                subtitle: 'Transferencias simples entre almacen y tienda.',
                child:
                    state.movements.isEmpty
                        ? const EmptyStateCard(
                          title: 'Sin movimientos registrados',
                          caption:
                              'Las compras, ventas y transferencias apareceran aqui.',
                        )
                        : Column(
                          children:
                              state.movements.take(4).map((movement) {
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
                              }).toList(),
                        ),
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
          Flexible(child: Text(value, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

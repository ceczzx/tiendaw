import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/features/sales/presentation/seller_dashboard_view_model.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

class SellerDashboardPage extends ConsumerWidget {
  const SellerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(sellerDashboardViewModelProvider);
    final session = ref.watch(sessionViewModelProvider).valueOrNull;
    final currentUser = session?.currentUser;

    return dashboard.when(
      data: (state) {
        final productsInCategory =
            state.selectedCategoryId == null
                ? const []
                : state.products
                    .where(
                      (product) => product.categoryId == state.selectedCategoryId,
                    )
                    .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Venta rapida para ${currentUser?.name ?? 'usuario'}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Flujo de 4 pasos conectado a Supabase para registrar ventas reales.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              if (state.feedbackMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: Text(state.feedbackMessage!),
                ),
                const SizedBox(height: 20),
              ],
              SectionCard(
                title: 'Paso 1. Categoria',
                subtitle: 'Selecciona una categoria existente en Supabase.',
                child:
                    state.categories.isEmpty
                        ? const EmptyStateCard(
                          title: 'Sin categorias registradas',
                          caption:
                              'Crea registros en public.categories para empezar a vender.',
                        )
                        : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children:
                              state.categories.map((category) {
                                final selected =
                                    category.id == state.selectedCategoryId;
                                return ChoiceChip(
                                  label: Text(category.name),
                                  selected: selected,
                                  onSelected:
                                      (_) => ref
                                          .read(
                                            sellerDashboardViewModelProvider
                                                .notifier,
                                          )
                                          .selectCategory(category.id),
                                );
                              }).toList(),
                        ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Paso 2. Producto',
                subtitle: 'Stock de tienda y almacen calculado desde Supabase.',
                child:
                    productsInCategory.isEmpty
                        ? const EmptyStateCard(
                          title: 'Sin productos disponibles',
                          caption:
                              'Agrega productos y stock para la categoria seleccionada.',
                        )
                        : Column(
                          children:
                              productsInCategory.map((product) {
                                final selected =
                                    product.id == state.selectedProductId;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap:
                                        () => ref
                                            .read(
                                              sellerDashboardViewModelProvider
                                                  .notifier,
                                            )
                                            .selectProduct(product.id),
                                    child: Ink(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color:
                                            selected
                                                ? const Color(0xFF0F766E)
                                                : const Color(0xFFFAFAF9),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              selected
                                                  ? const Color(0xFF0F766E)
                                                  : const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final compact = constraints.maxWidth < 340;

                                          if (compact) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color:
                                                            selected
                                                                ? Colors.white
                                                                : null,
                                                      ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Tienda: ${product.stockStore}  |  Almacen: ${product.stockWarehouse}',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            selected
                                                                ? Colors.white70
                                                                : const Color(
                                                                  0xFF4B5563,
                                                                ),
                                                      ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  SystemWFormatters.currency
                                                      .format(product.salePrice),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(
                                                        color:
                                                            selected
                                                                ? Colors.white
                                                                : const Color(
                                                                  0xFF0F766E,
                                                                ),
                                                      ),
                                                ),
                                              ],
                                            );
                                          }

                                          return Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      product.name,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            color:
                                                                selected
                                                                    ? Colors
                                                                        .white
                                                                    : null,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Stock tienda: ${product.stockStore}  |  Almacen: ${product.stockWarehouse}',
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color:
                                                                selected
                                                                    ? Colors
                                                                        .white70
                                                                    : const Color(
                                                                      0xFF4B5563,
                                                                    ),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                SystemWFormatters.currency.format(
                                                  product.salePrice,
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      color:
                                                          selected
                                                              ? Colors.white
                                                              : const Color(
                                                                0xFF0F766E,
                                                              ),
                                                    ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Paso 3. Cantidad y pago',
                subtitle: 'Controles adaptados para celular sin desbordamientos.',
                child:
                    state.selectedProduct == null
                        ? const EmptyStateCard(
                          title: 'Selecciona un producto',
                          caption:
                              'Primero elige una categoria y un producto disponible.',
                        )
                        : Column(
                          children: [
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
                                              () => ref
                                                  .read(
                                                    sellerDashboardViewModelProvider
                                                        .notifier,
                                                  )
                                                  .changeQuantity(
                                                    state.quantity - 1,
                                                  ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFF4F4F5,
                                            ),
                                            foregroundColor: const Color(
                                              0xFF111827,
                                            ),
                                          ),
                                          child: const Text('-1'),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child: Text(
                                          '${state.quantity} unidades',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed:
                                              () => ref
                                                  .read(
                                                    sellerDashboardViewModelProvider
                                                        .notifier,
                                                  )
                                                  .changeQuantity(
                                                    state.quantity + 1,
                                                  ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF0F766E,
                                            ),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('+1'),
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
                                            () => ref
                                                .read(
                                                  sellerDashboardViewModelProvider
                                                      .notifier,
                                                )
                                                .changeQuantity(
                                                  state.quantity - 1,
                                                ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFF4F4F5,
                                          ),
                                          foregroundColor: const Color(
                                            0xFF111827,
                                          ),
                                        ),
                                        child: const Text('-1'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        alignment: Alignment.center,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child: Text(
                                          '${state.quantity} unidades',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            () => ref
                                                .read(
                                                  sellerDashboardViewModelProvider
                                                      .notifier,
                                                )
                                                .changeQuantity(
                                                  state.quantity + 1,
                                                ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF0F766E,
                                          ),
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('+1'),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
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
                                selected: {state.paymentMethod},
                                onSelectionChanged:
                                    (selection) => ref
                                        .read(
                                          sellerDashboardViewModelProvider
                                              .notifier,
                                        )
                                        .setPaymentMethod(selection.first),
                              ),
                            ),
                          ],
                        ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Paso 4. Confirmacion',
                subtitle: 'Resumen final con total y caja abierta actual.',
                child:
                    state.selectedProduct == null
                        ? const EmptyStateCard(
                          title: 'Nada por confirmar',
                          caption:
                              'Selecciona un producto para ver el resumen de la venta.',
                        )
                        : Column(
                          children: [
                            _SummaryRow(
                              label: 'Producto',
                              value: state.selectedProduct!.name,
                            ),
                            _SummaryRow(
                              label: 'Cantidad',
                              value: '${state.quantity}',
                            ),
                            _SummaryRow(
                              label: 'Metodo',
                              value:
                                  state.paymentMethod == PaymentMethod.cash
                                      ? 'Efectivo'
                                      : 'Yape',
                            ),
                            _SummaryRow(
                              label: 'Total',
                              value: SystemWFormatters.currency.format(
                                state.selectedProduct!.salePrice * state.quantity,
                              ),
                              isStrong: true,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    currentUser == null
                                        ? null
                                        : () => ref
                                            .read(
                                              sellerDashboardViewModelProvider
                                                  .notifier,
                                            )
                                            .registerSale(currentUser),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEA580C),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Registrar venta'),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFFCD34D),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _SummaryRow(
                                    label: 'Caja efectivo',
                                    value: SystemWFormatters.currency.format(
                                      state.currentShift.cashSales,
                                    ),
                                  ),
                                  _SummaryRow(
                                    label: 'Caja Yape',
                                    value: SystemWFormatters.currency.format(
                                      state.currentShift.yapeSales,
                                    ),
                                  ),
                                  _SummaryRow(
                                    label: 'Total turno',
                                    value: SystemWFormatters.currency.format(
                                      state.currentShift.total,
                                    ),
                                    isStrong: true,
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
                                                    sellerDashboardViewModelProvider
                                                        .notifier,
                                                  )
                                                  .closeShift(currentUser),
                                      child: const Text('Cerrar caja del turno'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error cargando ventas: $error')),
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
          Flexible(child: Text(value, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

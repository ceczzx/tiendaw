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
            currentUser == null ? null : () => _handlePurchase(currentUser),
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

  Future<void> _handlePurchase(AppUser currentUser) async {
    final success = await ref
        .read(adminMobileDashboardViewModelProvider.notifier)
        .registerPurchase(currentUser);

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
}

class _HomeSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final supplierCount = _uniqueSupplierCount(state);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Inicio',
            subtitle:
                'Anade compra de productos de proveedores existentes o crea uno nuevo sin salir del flujo admin.',
          ),
          if (state.feedbackMessage != null) ...[
            const SizedBox(height: 16),
            _FeedbackBanner(message: state.feedbackMessage!),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title: 'Flujo rapido',
            subtitle:
                'Separo compras, proveedores y movimientos para que el admin no tenga todo mezclado en una sola pantalla.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuando registres una compra, si el proveedor no existe se crea con el mismo nombre al guardar en Supabase.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: onOpenPurchaseComposer,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('Anadir compra'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenSuppliers,
                      icon: const Icon(Icons.local_shipping_rounded),
                      label: const Text('Ver proveedores'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenMovements,
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
            title: 'Resumen actual',
            subtitle: 'Vista rapida de stock y ultimas operaciones cargadas.',
            child: Column(
              children: [
                _InfoLine(
                  label: 'Ultima compra',
                  value:
                      state.purchases.isEmpty
                          ? 'Sin compras'
                          : state.purchases.first.supplier,
                ),
                _InfoLine(
                  label: 'Ultimo proveedor',
                  value:
                      state.priceHistory.isEmpty
                          ? 'Sin historial'
                          : state.priceHistory.first.supplier,
                ),
                _InfoLine(
                  label: 'Ultimo movimiento',
                  value:
                      state.movements.isEmpty
                          ? 'Sin movimientos'
                          : state.movements.first.productName,
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
  final Future<void> Function()? onSubmitPurchase;

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
                'Historial de abastecimiento separado y boton para agregar nuevas compras cuando las necesites.',
          ),
          if (state.feedbackMessage != null) ...[
            const SizedBox(height: 16),
            _FeedbackBanner(message: state.feedbackMessage!),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title: 'Agregar cosas',
            subtitle:
                'Abre el formulario solo cuando quieras registrar producto, cantidad, costo y proveedor.',
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
                        'Usa "Agregar compra" para registrar un nuevo ingreso desde proveedores.',
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
                          state.priceHistory.take(6).map((entry) {
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
                                style: Theme.of(context).textTheme.titleMedium,
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
                          state.purchases.take(6).map((purchase) {
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
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            );
                          }).toList(),
                    ),
          ),
        ],
      ),
    );
  }
}

class _SuppliersSection extends StatelessWidget {
  const _SuppliersSection({required this.state});

  final AdminMobileDashboardState state;

  @override
  Widget build(BuildContext context) {
    final supplierSummaries = _buildSupplierSummaries(state);
    final categorySummaries = _buildCategorySummaries(state);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Proveedores',
            subtitle:
                'Aqui se ve el historial de proveedores, productos y categorias sin mezclarlo con el registro de compras.',
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
                detail: 'Unicos en compras e historial de costos',
                accent: const Color(0xFF0F766E),
              ),
              MetricCard(
                label: 'Productos',
                value: '${state.products.length}',
                detail: 'Disponibles en el catalogo actual',
                accent: const Color(0xFFEA580C),
              ),
              MetricCard(
                label: 'Categorias',
                value: '${state.categories.length}',
                detail: 'Clasificaciones del inventario',
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
                    : Column(
                      children:
                          supplierSummaries.map((summary) {
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
                                    SystemWFormatters.currency.format(
                                      summary.total,
                                    ),
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  Text(
                                    SystemWFormatters.shortDate.format(
                                      summary.lastPurchaseAt,
                                    ),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Productos',
            subtitle: 'Listado de productos con categoria y stock actual.',
            child:
                state.products.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin productos registrados',
                      caption: 'Agrega productos en Supabase para verlos aqui.',
                    )
                    : Column(
                      children: [
                        ...state.products.take(12).map((product) {
                          final categoryName = _categoryNameForProduct(
                            state,
                            product,
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(product.name),
                            subtitle: Text(
                              '$categoryName - Tienda ${product.stockStore} u. - Almacen ${product.stockWarehouse} u.',
                            ),
                            trailing: Text(
                              SystemWFormatters.currency.format(
                                product.lastPurchaseCost,
                              ),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          );
                        }),
                        if (state.products.length > 12)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Mostrando 12 de ${state.products.length} productos para mantener la vista movil ligera.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Categorias',
            subtitle: 'Cantidad de productos en ALMACEN por categoria.',
            child:
                categorySummaries.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin categorias registradas',
                      caption: 'Cuando existan categorias las veras aqui.',
                    )
                    : Column(
                      children:
                          categorySummaries.map((summary) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(summary.name),
                              subtitle: Text(
                                '${summary.productCount} productos asociados',
                              ),
                              trailing: Text(
                                '${summary.warehouseUnits} u.',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            );
                          }).toList(),
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
    required this.currentUser,
    required this.onTransfer,
  });

  final AdminMobileDashboardState state;
  final AppUser? currentUser;
  final Future<void> Function()? onTransfer;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileSectionHeading(
            title: 'Movimientos',
            subtitle:
                'Transferencias desde almacen a tienda con la bitacora operativa separada del resto.',
          ),
          if (state.feedbackMessage != null) ...[
            const SizedBox(height: 16),
            _FeedbackBanner(message: state.feedbackMessage!),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title: 'Mover de almacen a tienda',
            subtitle:
                'Usa el mismo producto seleccionado para registrar una transferencia simple.',
            child: _TransferForm(
              state: state,
              currentUser: currentUser,
              onTransfer: onTransfer,
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Movimientos recientes',
            subtitle: 'Compras, ventas y transferencias del inventario.',
            child:
                state.movements.isEmpty
                    ? const EmptyStateCard(
                      title: 'Sin movimientos registrados',
                      caption:
                          'Las compras, ventas y transferencias apareceran aqui.',
                    )
                    : Column(
                      children:
                          state.movements.take(8).map((movement) {
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
  }
}

class _PurchaseForm extends ConsumerWidget {
  const _PurchaseForm({
    required this.state,
    required this.currentUser,
    required this.onSubmitPurchase,
  });

  final AdminMobileDashboardState state;
  final AppUser? currentUser;
  final Future<void> Function()? onSubmitPurchase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProduct = state.selectedProduct;

    if (state.products.isEmpty) {
      return const EmptyStateCard(
        title: 'Sin productos registrados',
        caption: 'Agrega productos y stock en Supabase para poder comprar.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            if (value != null) {
              ref
                  .read(adminMobileDashboardViewModelProvider.notifier)
                  .selectProduct(value);
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: '${state.quantity}',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
                onChanged: (value) {
                  ref
                      .read(adminMobileDashboardViewModelProvider.notifier)
                      .changeQuantity(int.tryParse(value) ?? state.quantity);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
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
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: state.supplier,
          decoration: const InputDecoration(labelText: 'Proveedor'),
          onChanged: (value) {
            ref
                .read(adminMobileDashboardViewModelProvider.notifier)
                .changeSupplier(value);
          },
        ),
        const SizedBox(height: 16),
        _InfoLine(
          label: 'Fecha vencimiento sugerida',
          value: SystemWFormatters.shortDate.format(state.expiryDate),
        ),
        _InfoLine(
          label: 'Total compra',
          value: SystemWFormatters.currency.format(
            state.quantity * state.unitCost,
          ),
          isStrong: true,
        ),
        if (selectedProduct != null) ...[
          _InfoLine(
            label: 'Stock almacen actual',
            value: '${selectedProduct.stockWarehouse} u.',
          ),
          _InfoLine(
            label: 'Costo anterior',
            value: SystemWFormatters.currency.format(
              selectedProduct.lastPurchaseCost,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                currentUser == null || onSubmitPurchase == null
                    ? null
                    : () => onSubmitPurchase!(),
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
}

class _TransferForm extends ConsumerWidget {
  const _TransferForm({
    required this.state,
    required this.currentUser,
    required this.onTransfer,
  });

  final AdminMobileDashboardState state;
  final AppUser? currentUser;
  final Future<void> Function()? onTransfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProduct = state.selectedProduct;

    if (state.products.isEmpty) {
      return const EmptyStateCard(
        title: 'Sin productos registrados',
        caption: 'Agrega productos en Supabase para poder mover stock.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            if (value != null) {
              ref
                  .read(adminMobileDashboardViewModelProvider.notifier)
                  .selectProduct(value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: '${state.quantity}',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cantidad a mover'),
          onChanged: (value) {
            ref
                .read(adminMobileDashboardViewModelProvider.notifier)
                .changeQuantity(int.tryParse(value) ?? state.quantity);
          },
        ),
        const SizedBox(height: 16),
        if (selectedProduct != null) ...[
          _InfoLine(
            label: 'Stock en almacen',
            value: '${selectedProduct.stockWarehouse} u.',
          ),
          _InfoLine(
            label: 'Stock en tienda',
            value: '${selectedProduct.stockStore} u.',
          ),
          if (selectedProduct.nextExpiryDate != null)
            _InfoLine(
              label: 'Proximo vencimiento',
              value: SystemWFormatters.shortDate.format(
                selectedProduct.nextExpiryDate!,
              ),
            ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                currentUser == null || onTransfer == null
                    ? null
                    : () => onTransfer!(),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Mover a tienda'),
          ),
        ),
      ],
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

class _CategorySummary {
  const _CategorySummary({
    required this.name,
    required this.productCount,
    required this.warehouseUnits,
  });

  final String name;
  final int productCount;
  final int warehouseUnits;
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
          );
        }).toList()
        ..sort((a, b) => b.lastPurchaseAt.compareTo(a.lastPurchaseAt));

  return summaries;
}

List<_CategorySummary> _buildCategorySummaries(
  AdminMobileDashboardState state,
) {
  final productsByCategory = <String, List<Product>>{};

  for (final category in state.categories) {
    productsByCategory[category.id] = [];
  }

  for (final product in state.products) {
    productsByCategory.putIfAbsent(product.categoryId, () => []).add(product);
  }

  final summaries =
      productsByCategory.entries.map((entry) {
          var categoryName = 'Sin categoria';
          for (final category in state.categories) {
            if (category.id == entry.key) {
              categoryName = category.name;
              break;
            }
          }
          final products = entry.value;

          return _CategorySummary(
            name: categoryName,
            productCount: products.length,
            warehouseUnits: products.fold(
              0,
              (sum, product) => sum + product.stockWarehouse,
            ),
          );
        }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return summaries;
}

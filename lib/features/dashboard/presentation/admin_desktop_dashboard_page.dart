// ignore_for_file: unused_local_variable, unused_element, prefer_null_aware_operators

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/catalog/domain/catalog_entities.dart';
import 'package:tiendaw/features/catalog/domain/product_pricing_rules.dart';
import 'package:tiendaw/features/dashboard/presentation/admin_desktop_dashboard_view_model.dart';
import 'package:tiendaw/features/inventory/domain/inventory_entities.dart';
import 'package:tiendaw/features/purchases/presentation/admin_mobile_dashboard_page.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

enum AdminDesktopSection { sales, purchases, products, movements, operations }

class AdminDesktopDashboardPage extends ConsumerWidget {
  const AdminDesktopDashboardPage({required this.activeSection, super.key});

  final AdminDesktopSection activeSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activeSection == AdminDesktopSection.operations) {
      return const AdminMobileDashboardPage();
    }

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
        onPeriodChanged:
            (value) => ref
                .read(adminDesktopDashboardViewModelProvider.notifier)
                .setPeriod(value),
      ),
      AdminDesktopSection.purchases => _PurchasesSection(
        state: state,
        onPeriodChanged:
            (value) => ref
                .read(adminDesktopDashboardViewModelProvider.notifier)
                .setPeriod(value),
      ),
      AdminDesktopSection.products => _ProductsSection(state: state),
      AdminDesktopSection.movements => _MovementsSection(
        state: state,
        onPeriodChanged:
            (value) => ref
                .read(adminDesktopDashboardViewModelProvider.notifier)
                .setPeriod(value),
      ),
      AdminDesktopSection.operations => const AdminMobileDashboardPage(),
    };
  }
}

class _SalesSection extends StatefulWidget {
  const _SalesSection({
    required this.state,
    required this.onSellerChanged,
    required this.onPeriodChanged,
  });

  final AdminDesktopDashboardState state;
  final ValueChanged<String> onSellerChanged;
  final ValueChanged<DateTimeRange> onPeriodChanged;

  @override
  State<_SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends State<_SalesSection> {
  String? _selectedShiftId;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final productById = {
      for (final product in state.products) product.id: product,
    };
    final categoryById = {
      for (final category in state.categories) category.id: category.name,
    };
    final rejectedCashShifts =
        state.filteredCashShifts
            .where((shift) => shift.status == CashShiftStatus.rejected)
            .toList();
    final visibleCashShifts =
        state.filteredCashShifts
            .where((shift) => shift.status != CashShiftStatus.rejected)
            .toList();
    final rejectedSummaries = _buildRejectedShiftSummaries(rejectedCashShifts);
    final visibleShiftIds = visibleCashShifts.map((shift) => shift.id).toSet();
    final activeShiftId =
        _selectedShiftId != null && visibleShiftIds.contains(_selectedShiftId)
            ? _selectedShiftId
            : null;
    final selectedShift =
        activeShiftId == null
            ? null
            : visibleCashShifts.firstWhere(
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
            onPeriodChanged: widget.onPeriodChanged,
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
                'Inicial efectivo',
                'Inicial Yape',
                'Venta efectivo',
                'Venta digital',
                'Cierre efectivo',
                'Cierre Yape',
                'Total final',
                'Lugar inicio',
                'Lugar cierre',
                'Estado',
              ],
              rows:
                  visibleCashShifts.map((shift) {
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
                          SystemWFormatters.currency.format(shift.openingCash),
                        ),
                        Text(
                          SystemWFormatters.currency.format(shift.openingYape),
                        ),
                        Text(
                          SystemWFormatters.currency.format(shift.cashSales),
                        ),
                        Text(
                          SystemWFormatters.currency.format(shift.yapeSales),
                        ),
                        Text(_formatOptionalCurrency(shift.closingCash)),
                        Text(_formatOptionalCurrency(shift.closingYape)),
                        Text(
                          SystemWFormatters.currency.format(shift.finalAmount),
                        ),
                        SizedBox(
                          width: 260,
                          child: _MapsLinkCell(
                            label: _shiftOpeningPlace(shift),
                            latitude: shift.openingLatitude,
                            longitude: shift.openingLongitude,
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: _MapsLinkCell(
                            label: _shiftClosingPlace(shift),
                            latitude: shift.closingLatitude,
                            longitude: shift.closingLongitude,
                          ),
                        ),
                        StatusPill(
                          label: _cashShiftStatusLabel(shift),
                          background: _cashShiftStatusBackground(shift),
                          foreground: _cashShiftStatusForeground(shift),
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
                    ? 'Tabla operativa para seguimiento rapido del periodo con detalle de productos y categorias.'
                    : 'Detalle filtrado por la caja iniciada el ${SystemWFormatters.shortDateTime.format(selectedShift.openedAt)} con productos y categorias por ticket.',
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
                'Detalle',
                'Promocion',
                'Total',
                'Sync',
              ],
              rows:
                  salesRows.map((sale) {
                    final groupedItems = _groupSaleItems(sale);
                    return _DesktopTableRow(
                      cells: [
                        Text(
                          SystemWFormatters.shortDateTime.format(
                            sale.createdAt,
                          ),
                        ),
                        Text(sale.sellerName),
                        Text(_paymentMethodLabel(sale.paymentMethod)),
                        Text('${groupedItems.length}'),
                        _SaleItemsCell(
                          items: groupedItems,
                          productById: productById,
                          categoryById: categoryById,
                        ),
                        SizedBox(
                          width: 240,
                          child: Text(
                            groupedItems
                                .map((item) {
                                  if (!item.hasPromotion) {
                                    return '${item.productName}: No';
                                  }
                                  return '${item.productName}: Si | Promo ${SystemWFormatters.currency.format(item.baseUnitPrice)}';
                                })
                                .join('\n'),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(SystemWFormatters.currency.format(sale.total)),
                        Text(sale.syncStatus.name),
                      ],
                    );
                  }).toList(),
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
          const SizedBox(height: 20),
          SectionCard(
            title: 'Turnos rechazados',
            subtitle:
                rejectedCashShifts.isEmpty
                    ? 'No hay turnos rechazados en este periodo.'
                    : 'Resumen de ${rejectedCashShifts.length} rechazos agrupado por vendedor.',
            child: _DesktopTable(
              columns: const ['Vendedor', 'Rechazos', 'Ultimo rechazo'],
              rows:
                  rejectedSummaries.map((summary) {
                    return _DesktopTableRow(
                      cells: [
                        Text(summary.sellerName),
                        Text('${summary.rejectionCount}'),
                        Text(
                          SystemWFormatters.shortDateTime.format(
                            summary.lastRejectedAt,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
              emptyTitle: 'Sin turnos rechazados',
              emptyCaption: 'No hubo rechazos en el periodo seleccionado.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasesSection extends StatelessWidget {
  const _PurchasesSection({required this.state, required this.onPeriodChanged});

  final AdminDesktopDashboardState state;
  final ValueChanged<DateTimeRange> onPeriodChanged;

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
            child: _PeriodSelector(
              period: state.period,
              onPeriodChanged: onPeriodChanged,
            ),
          ),
          const SizedBox(height: 20),
          _MetricRow(
            children: [
              MetricCard(
                label: 'Resumen del periodo - Categorias',
                value: SystemWFormatters.currency.format(state.purchaseTotal),
                detail:
                    state.filteredPurchases.isEmpty
                        ? 'Sin compras registradas para este rango'
                        : _purchaseRelationSummary(state),
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
                'Relacion',
                'Productos',
                'Estado compra',
                'Costo / venta',
                'Ganancia',
                'Margen',
                'Total',
                'Registrado por',
                'Sync',
              ],
              rows:
                  state.filteredPurchases
                      .map(
                        (purchase) => _DesktopTableRow(
                          cells: _purchaseHistoryCells(state, purchase),
                          onTap:
                              () =>
                                  _showPurchaseDetailDialog(context, purchase),
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

  Future<void> _showPurchaseDetailDialog(
    BuildContext context,
    Purchase purchase,
  ) async {
    await showDialog<void>(
      context: context,
      builder:
          (context) => _PurchaseDetailDialog(state: state, purchase: purchase),
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
          const SizedBox(height: 20),
          SectionCard(
            title: 'Packs en tienda',
            subtitle:
                'Lectura de packs activos con stock disponible solo en tienda, precio, costo y margen.',
            child: _DesktopTable(
              columns: const [
                'Pack',
                'Productos',
                'Stock tienda',
                'Precio pack',
                'Costo',
                'Margen',
                'Estado',
              ],
              rows:
                  state.packs
                      .map(
                        (pack) => _DesktopTableRow(
                          cells: [
                            SizedBox(width: 220, child: Text(pack.name)),
                            SizedBox(
                              width: 320,
                              child: Text(
                                pack.items
                                    .map(
                                      (item) =>
                                          '${item.productName} x${item.quantity}',
                                    )
                                    .join('\n'),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${pack.availableForSale} disponibles\n${pack.packQuantityRemaining}/${pack.packQuantityTotal} activos',
                            ),
                            Text(
                              SystemWFormatters.currency.format(
                                pack.totalPackPrice,
                              ),
                            ),
                            Text(
                              SystemWFormatters.currency.format(pack.totalCost),
                            ),
                            Text(
                              SystemWFormatters.currency.format(pack.margin),
                            ),
                            StatusPill(
                              label: _packStatusLabel(pack),
                              background:
                                  pack.availableForSale > 0
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFF1F5F9),
                              foreground:
                                  pack.availableForSale > 0
                                      ? const Color(0xFF047857)
                                      : const Color(0xFF334155),
                            ),
                          ],
                        ),
                      )
                      .toList(),
              emptyTitle: 'Sin packs registrados',
              emptyCaption:
                  'Crea packs desde Operaciones en admin móvil para verlos aqui.',
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementsSection extends StatelessWidget {
  const _MovementsSection({required this.state, required this.onPeriodChanged});

  final AdminDesktopDashboardState state;
  final ValueChanged<DateTimeRange> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final supplierMovementSummaries = _buildMovementSupplierSummaries(state);
    final operationalAlertRows = _buildOperationalAlertRows(state);

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
            child: _PeriodSelector(
              period: state.period,
              onPeriodChanged: onPeriodChanged,
            ),
          ),
          const SizedBox(height: 20),
          _MetricRow(
            children: [
              MetricCard(
                label: 'Movimientos del periodo | TIPO',
                value: '${state.filteredMovements.length}',
                detail:
                    'Compras ${state.purchaseMovementCount} | Ventas ${state.saleMovementCount} | Traslados ${state.transferMovementCount} | Perdidas ${state.lossMovementCount}',
                accent: const Color(0xFF0F766E),
              ),
              MetricCard(
                label: 'Unidades movidas | CANTIDAD',
                value: '${state.movementUnitsTotal}',
                detail:
                    'Compras ${state.purchaseMovementUnits} u. | Ventas ${state.saleMovementUnits} u. | Traslados ${state.transferMovementUnits} u. | Perdidas ${state.lossMovementUnits} u.',
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
            title: 'Movimientos por proveedor',
            subtitle:
                'Resumen exclusivo de traslados de almacen a tienda para leer mejor el movimiento por proveedor.',
            child: _DesktopTable(
              columns: const [
                'Proveedor',
                'Productos',
                'Transfer',
                'Total',
                'Ultimo movimiento',
              ],
              rows:
                  supplierMovementSummaries
                      .map(
                        (summary) => _DesktopTableRow(
                          cells: [
                            Text(summary.supplierName),
                            Text('${summary.productCount}'),
                            Text('${summary.transferUnits} u.'),
                            Text('${summary.totalUnits} u.'),
                            Text(
                              SystemWFormatters.shortDateTime.format(
                                summary.lastMovementAt,
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
              emptyTitle: 'Sin proveedores vinculados a movimientos',
              emptyCaption:
                  'Cuando existan traslados de almacen a tienda con proveedor, apareceran agrupados aqui.',
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Alertas activas',
            subtitle:
                'Incluye stock bajo, lotes por vencer y lotes ya vencidos para que el contador coincida con la tabla.',
            child: _DesktopTable(
              columns: const [
                'Producto',
                'Proveedor',
                'Alerta',
                'Cantidad',
                'Ubicacion',
                'Fecha / referencia',
              ],
              rows:
                  operationalAlertRows
                      .map(
                        (alert) => _DesktopTableRow(
                          cells: [
                            Text(alert.productName),
                            Text(alert.supplierName),
                            Text(alert.alertLabel),
                            Text(alert.quantityLabel),
                            Text(alert.locationLabel),
                            Text(alert.referenceLabel),
                          ],
                        ),
                      )
                      .toList(),
              emptyTitle: 'Sin alertas operativas',
              emptyCaption:
                  'Cuando exista stock bajo o lotes por vencer apareceran aqui.',
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
                'Proveedor',
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
                            Text(_movementSupplierLabel(movement)),
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
    required this.onPeriodChanged,
  });

  final AdminDesktopDashboardState state;
  final ValueChanged<String> onSellerChanged;
  final ValueChanged<DateTimeRange> onPeriodChanged;

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
          _PeriodSelector(
            period: state.period,
            onPeriodChanged: onPeriodChanged,
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

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onPeriodChanged});

  final DateTimeRange period;
  final ValueChanged<DateTimeRange> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Periodo'),
            child: Text(
              '${SystemWFormatters.shortDate.format(period.start)} - ${SystemWFormatters.shortDate.format(period.end)}',
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => onPeriodChanged(_currentWeekRange()),
          icon: const Icon(Icons.calendar_view_week_rounded),
          label: const Text('Semana actual'),
        ),
        OutlinedButton.icon(
          onPressed: () => onPeriodChanged(_previousWeekRange()),
          icon: const Icon(Icons.history_rounded),
          label: const Text('Semana anterior'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final selected = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2024),
              lastDate: DateTime(2100),
              initialDateRange: period,
              locale: const Locale('es', 'PE'),
            );
            if (selected == null) {
              return;
            }
            onPeriodChanged(
              DateTimeRange(
                start: DateTime(
                  selected.start.year,
                  selected.start.month,
                  selected.start.day,
                ),
                end: DateTime(
                  selected.end.year,
                  selected.end.month,
                  selected.end.day,
                ),
              ),
            );
          },
          icon: const Icon(Icons.date_range_rounded),
          label: const Text('Elegir periodo'),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: children[i]),
        ],
      ],
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

class _DetailSummaryRow extends StatelessWidget {
  const _DetailSummaryRow({
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
          Flexible(
            child: Text(value, style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _MapsLinkCell extends StatelessWidget {
  const _MapsLinkCell({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final url = _mapsUrl(latitude: latitude, longitude: longitude);
    if (url == null) {
      return Text(label);
    }

    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Link de Google Maps copiado.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: Text(
        '$label\n$url',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF2563EB),
          decoration: TextDecoration.underline,
        ),
      ),
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

class _PurchaseDetailDialog extends StatelessWidget {
  const _PurchaseDetailDialog({required this.state, required this.purchase});

  final AdminDesktopDashboardState state;
  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    final supplierPurchases = _purchasesForSameSupplier(state, purchase)
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final analytics = _buildPurchaseAnalytics(state, purchase);
    final supplierTotal = supplierPurchases.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final productById = {
      for (final product in state.products) product.id: product,
    };

    return _DetailDialogShell(
      title: 'Detalle de compra',
      subtitle:
          'Compra registrada el ${SystemWFormatters.shortDateTime.format(purchase.receivedAt)} con historial separado por proveedor y detalle producto por producto.',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                MetricCard(
                  label: 'Proveedor',
                  value:
                      purchase.supplier.trim().isEmpty
                          ? 'Produccion artesanal'
                          : purchase.supplier,
                  detail:
                      purchase.supplierPhone?.trim().isNotEmpty == true
                          ? purchase.supplierPhone!
                          : 'Sin telefono',
                  accent: const Color(0xFF0F766E),
                ),
                MetricCard(
                  label: 'Total compra',
                  value: SystemWFormatters.currency.format(purchase.total),
                  detail: analytics.relationshipLabel,
                  accent: const Color(0xFFEA580C),
                ),
                MetricCard(
                  label: 'Historial proveedor',
                  value: '${supplierPurchases.length} compras',
                  detail: SystemWFormatters.currency.format(supplierTotal),
                  accent: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: 'Cabecera',
              subtitle:
                  'Resumen directo de la compra seleccionada con usuario, sincronizacion y rentabilidad proyectada.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailSummaryRow(
                    label: 'Registrado por',
                    value: purchase.registeredBy,
                  ),
                  _DetailSummaryRow(
                    label: 'Fecha',
                    value: SystemWFormatters.shortDateTime.format(
                      purchase.receivedAt,
                    ),
                  ),
                  _DetailSummaryRow(
                    label: 'Estado compra',
                    value: analytics.purchaseModeLabel,
                  ),
                  _DetailSummaryRow(
                    label: 'Referencia comercial',
                    value:
                        analytics.canSummarizeCommercialMetrics
                            ? '${SystemWFormatters.currency.format(analytics.referenceUnitCost)} costo | ${SystemWFormatters.currency.format(analytics.referenceSalePrice)} venta'
                            : 'Compra mixta: revisar lineas individuales',
                  ),
                  _DetailSummaryRow(
                    label: 'Ganancia proyectada',
                    value:
                        analytics.canSummarizeCommercialMetrics
                            ? '${SystemWFormatters.currency.format(analytics.projectedProfit)} | ${analytics.projectedMargin.toStringAsFixed(1)}%'
                            : 'No aplica a compras mixtas',
                  ),
                  _DetailSummaryRow(
                    label: 'Sync',
                    value: purchase.syncStatus.name,
                    isStrong: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: 'Lineas compradas',
              subtitle:
                  'Detalle producto por producto con conversion a unidades y vencimiento asociado.',
              child: _DesktopTable(
                columns: const [
                  'Producto',
                  'Tipo',
                  'Cantidad',
                  'Unidades',
                  'Costo u.',
                  'Subtotal',
                  'Vence',
                ],
                rows:
                    purchase.items.map((item) {
                      final product = productById[item.productId];
                      return _DesktopTableRow(
                        cells: [
                          Text(item.productName),
                          Text(product?.productType ?? 'Sin tipo'),
                          Text('${item.quantity} x ${item.unitsPerPackage}'),
                          Text('${item.totalUnits} u.'),
                          Text(
                            SystemWFormatters.currency.format(item.unitCost),
                          ),
                          Text(
                            SystemWFormatters.currency.format(item.subtotal),
                          ),
                          Text(
                            item.expiryDate == null
                                ? 'Sin fecha'
                                : SystemWFormatters.shortDate.format(
                                  item.expiryDate!,
                                ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: 'Compras a este proveedor',
              subtitle:
                  'Cada compra queda separada para ver cantidades, productos y total sin mezclar registros distintos.',
              child: _DesktopTable(
                columns: const [
                  'Fecha',
                  'Productos',
                  'Estado',
                  'Total',
                  'Registrado por',
                  'Detalle',
                ],
                rows:
                    supplierPurchases
                        .map(
                          (item) => _DesktopTableRow(
                            isSelected: item.id == purchase.id,
                            cells: [
                              Text(
                                SystemWFormatters.shortDateTime.format(
                                  item.receivedAt,
                                ),
                              ),
                              SizedBox(
                                width: 280,
                                child: Text(_purchaseItemsBreakdownLabel(item)),
                              ),
                              Text(
                                _buildPurchaseAnalytics(
                                  state,
                                  item,
                                ).purchaseModeLabel,
                              ),
                              Text(
                                SystemWFormatters.currency.format(item.total),
                              ),
                              Text(item.registeredBy),
                              SizedBox(
                                width: 220,
                                child: Text(
                                  _buildPurchaseAnalytics(
                                    state,
                                    item,
                                  ).relationshipLabel,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseOverviewDialog extends StatefulWidget {
  const _PurchaseOverviewDialog({required this.state});

  final AdminDesktopDashboardState state;

  @override
  State<_PurchaseOverviewDialog> createState() =>
      _PurchaseOverviewDialogState();
}

class _PurchaseOverviewDialogState extends State<_PurchaseOverviewDialog> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final categoryOptions = state.categories;
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
          'Detalle de compras con foco en la relacion proveedor-categoria para facilitar la lectura operativa.',
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _purchaseRelationSummary(state, categoryId: _selectedCategoryId),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _DesktopTable(
              columns: const [
                'Fecha',
                'Proveedor',
                'Relacion',
                'Productos',
                'Costo u.',
                'Venta u.',
                'Ganancia',
                'Margen',
                'Total',
                'Registrado por',
                'Sync',
              ],
              rows:
                  purchases
                      .map(
                        (purchase) => _DesktopTableRow(
                          cells: _purchaseHistoryCells(state, purchase),
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

class _PurchaseAnalytics {
  const _PurchaseAnalytics({
    required this.relationshipLabel,
    required this.purchaseModeLabel,
    required this.referenceUnitCost,
    required this.referenceSalePrice,
    required this.projectedProfit,
    required this.projectedMargin,
    required this.canSummarizeCommercialMetrics,
  });

  final String relationshipLabel;
  final String purchaseModeLabel;
  final double referenceUnitCost;
  final double referenceSalePrice;
  final double projectedProfit;
  final double projectedMargin;
  final bool canSummarizeCommercialMetrics;
}

class _MovementSupplierSummary {
  const _MovementSupplierSummary({
    required this.supplierName,
    required this.productCount,
    required this.transferUnits,
    required this.totalUnits,
    required this.lastMovementAt,
  });

  final String supplierName;
  final int productCount;
  final int transferUnits;
  final int totalUnits;
  final DateTime lastMovementAt;
}

class _RejectedShiftSummary {
  const _RejectedShiftSummary({
    required this.sellerName,
    required this.rejectionCount,
    required this.lastRejectedAt,
  });

  final String sellerName;
  final int rejectionCount;
  final DateTime lastRejectedAt;
}

class _OperationalAlertRow {
  const _OperationalAlertRow({
    required this.productName,
    required this.supplierName,
    required this.alertLabel,
    required this.quantityLabel,
    required this.locationLabel,
    required this.referenceLabel,
    required this.sortWeight,
    required this.sortDate,
  });

  final String productName;
  final String supplierName;
  final String alertLabel;
  final String quantityLabel;
  final String locationLabel;
  final String referenceLabel;
  final int sortWeight;
  final DateTime? sortDate;
}

class _SaleItemSummary {
  const _SaleItemSummary({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.isIced,
    required this.baseUnitPrice,
    required this.hasPromotion,
  });

  final String productId;
  final String productName;
  final num quantity;
  final bool isIced;
  final double baseUnitPrice;
  final bool hasPromotion;
}

class _SaleItemsCell extends StatelessWidget {
  const _SaleItemsCell({
    required this.items,
    required this.productById,
    required this.categoryById,
  });

  final List<_SaleItemSummary> items;
  final Map<String, Product> productById;
  final Map<String, String> categoryById;

  @override
  Widget build(BuildContext context) {
    final details =
        items.map((item) {
          final product = productById[item.productId];
          final categoryName =
              product == null
                  ? 'Sin categoria'
                  : categoryById[product.categoryId] ?? 'Sin categoria';
          final stockState = item.isIced ? 'Helada' : 'Normal';
          return '${item.quantity} x ${item.productName} | $categoryName | $stockState';
        }).toList();

    return SizedBox(
      width: 260,
      child: Text(
        details.join('\n'),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _PurchaseItemsCell extends StatelessWidget {
  const _PurchaseItemsCell({required this.items});

  final List<PurchaseLine> items;

  @override
  Widget build(BuildContext context) {
    final details =
        items
            .map(
              (item) =>
                  '${item.productName}: ${item.quantity} x ${item.unitsPerPackage} = ${item.totalUnits} u.',
            )
            .toList();

    return SizedBox(
      width: 270,
      child: Text(
        details.join('\n'),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

List<_SaleItemSummary> _groupSaleItems(Sale sale) {
  final grouped = <String, _SaleItemSummary>{};

  for (final item in sale.items) {
    final key =
        '${item.productId}::${item.isIced ? 'iced' : 'regular'}::${item.unitPrice.toStringAsFixed(2)}';
    final existing = grouped[key];
    if (existing == null) {
      grouped[key] = _SaleItemSummary(
        productId: item.productId,
        productName:
            item.isIced ? '${item.productName} (helada)' : item.productName,
        quantity: item.quantity,
        isIced: item.isIced,
        baseUnitPrice: item.baseUnitPrice ?? item.unitPrice,
        hasPromotion:
            item.usedPromotionalPrice ||
            (item.originalUnitPrice ?? item.baseUnitPrice ?? item.unitPrice) >
                (item.baseUnitPrice ?? item.unitPrice),
      );
      continue;
    }
    grouped[key] = _SaleItemSummary(
      productId: item.productId,
      productName: existing.productName,
      quantity: existing.quantity + item.quantity,
      isIced: existing.isIced,
      baseUnitPrice: existing.baseUnitPrice,
      hasPromotion: existing.hasPromotion,
    );
  }

  return grouped.values.toList();
}

String _purchaseItemsBreakdownLabel(Purchase purchase) {
  return purchase.items
      .map(
        (item) =>
            '${item.productName}: ${item.quantity} x ${item.unitsPerPackage} = ${item.totalUnits} u.',
      )
      .join('\n');
}

List<Purchase> _purchasesForSameSupplier(
  AdminDesktopDashboardState state,
  Purchase referencePurchase,
) {
  return state.filteredPurchases.where((purchase) {
    return _sameSupplierIdentity(purchase, referencePurchase);
  }).toList();
}

bool _sameSupplierIdentity(Purchase left, Purchase right) {
  final leftSupplierId = left.supplierId?.trim();
  final rightSupplierId = right.supplierId?.trim();
  if (leftSupplierId != null &&
      leftSupplierId.isNotEmpty &&
      rightSupplierId != null &&
      rightSupplierId.isNotEmpty) {
    return leftSupplierId == rightSupplierId;
  }

  return left.supplier.trim().toLowerCase() ==
      right.supplier.trim().toLowerCase();
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
          if (hasActivePromotion(snapshot.product)) ...[
            const SizedBox(height: 4),
            Text(
              'Promo activa',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFEA580C)),
            ),
          ],
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
          if (hasActivePromotion(snapshot.product)) ...[
            const SizedBox(height: 4),
            Text(
              'Promo ${SystemWFormatters.currency.format(bestPromotionalPrice(snapshot.product) ?? snapshot.product.salePrice)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFEA580C)),
            ),
          ],
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

String _purchaseRelationSummary(
  AdminDesktopDashboardState state, {
  String? categoryId,
}) {
  final filteredPurchases =
      state.filteredPurchases
          .where(
            (purchase) => _purchaseMatchesCategory(state, purchase, categoryId),
          )
          .toList();

  if (filteredPurchases.isEmpty) {
    return 'Sin relaciones proveedor-categoria para este rango.';
  }

  final relations = <String>{};
  final productById = {
    for (final product in state.products) product.id: product,
  };
  final categoryById = {
    for (final category in state.categories) category.id: category.name,
  };

  for (final purchase in filteredPurchases) {
    final supplierLabel =
        _hasOperationalSupplier(purchase.supplier)
            ? purchase.supplier.trim()
            : 'Artesanal';
    for (final item in purchase.items) {
      final product = productById[item.productId];
      final categoryName =
          product == null
              ? 'Sin categoria'
              : categoryById[product.categoryId] ?? 'Sin categoria';
      relations.add('$supplierLabel::$categoryName');
    }
  }

  return '${filteredPurchases.length} compras | ${relations.length} relaciones proveedor-categoria';
}

_PurchaseAnalytics _buildPurchaseAnalytics(
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
  final uniqueProductIds = <String>{};
  var totalUnits = 0;
  var projectedRevenue = 0.0;
  double? referenceUnitCost;
  double? referenceSalePrice;

  for (final item in purchase.items) {
    totalUnits += item.totalUnits;
    uniqueProductIds.add(item.productId);

    final product = productById[item.productId];
    final salePrice = product?.salePrice ?? 0;
    projectedRevenue += item.totalUnits * salePrice;
    referenceUnitCost ??= item.unitCost;
    referenceSalePrice ??= salePrice;

    final categoryId = product?.categoryId;
    final categoryName = categoryId == null ? null : categoryById[categoryId];
    if (categoryName != null && categoryName.trim().isNotEmpty) {
      categoryNames.add(categoryName);
    }
  }

  final canSummarizeCommercialMetrics = uniqueProductIds.length <= 1;
  final projectedProfit = projectedRevenue - purchase.total;
  final projectedMargin =
      projectedRevenue <= 0 ? 0.0 : (projectedProfit / projectedRevenue) * 100;
  final categoriesLabel =
      categoryNames.isEmpty ? 'Sin categoria' : categoryNames.join(', ');
  final supplierLabel =
      _hasOperationalSupplier(purchase.supplier)
          ? purchase.supplier.trim()
          : 'Artesanal';

  return _PurchaseAnalytics(
    relationshipLabel: '$supplierLabel -> $categoriesLabel',
    purchaseModeLabel:
        canSummarizeCommercialMetrics
            ? 'Compra simple'
            : 'Compra mixta (${uniqueProductIds.length} productos)',
    referenceUnitCost:
        canSummarizeCommercialMetrics ? referenceUnitCost ?? 0 : 0,
    referenceSalePrice:
        canSummarizeCommercialMetrics ? referenceSalePrice ?? 0 : 0,
    projectedProfit: canSummarizeCommercialMetrics ? projectedProfit : 0,
    projectedMargin: canSummarizeCommercialMetrics ? projectedMargin : 0,
    canSummarizeCommercialMetrics: canSummarizeCommercialMetrics,
  );
}

List<Widget> _purchaseHistoryCells(
  AdminDesktopDashboardState state,
  Purchase purchase,
) {
  final analytics = _buildPurchaseAnalytics(state, purchase);

  return [
    Text(SystemWFormatters.shortDateTime.format(purchase.receivedAt)),
    SizedBox(
      width: 180,
      child: Text(
        purchase.supplier.trim().isEmpty
            ? 'Produccion artesanal'
            : purchase.supplier,
      ),
    ),
    SizedBox(
      width: 250,
      child: Text(
        analytics.relationshipLabel,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    _PurchaseItemsCell(items: purchase.items),
    Text(analytics.purchaseModeLabel),
    Text(
      analytics.canSummarizeCommercialMetrics
          ? '${SystemWFormatters.currency.format(analytics.referenceUnitCost)} / ${SystemWFormatters.currency.format(analytics.referenceSalePrice)}'
          : 'Mixta',
    ),
    Text(
      analytics.canSummarizeCommercialMetrics
          ? SystemWFormatters.currency.format(analytics.projectedProfit)
          : 'No aplica',
    ),
    Text(
      analytics.canSummarizeCommercialMetrics
          ? '${analytics.projectedMargin.toStringAsFixed(1)}%'
          : 'No aplica',
    ),
    Text(SystemWFormatters.currency.format(purchase.total)),
    Text(purchase.registeredBy),
    Text(purchase.syncStatus.name),
  ];
}

List<_MovementSupplierSummary> _buildMovementSupplierSummaries(
  AdminDesktopDashboardState state,
) {
  final grouped = <String, List<InventoryMovement>>{};

  for (final movement in state.filteredMovements) {
    if (!_isWarehouseToStoreTransfer(movement)) {
      continue;
    }
    final supplierName = _movementSupplierLabel(movement);
    if (supplierName == 'No aplica' || supplierName == 'Sin proveedor') {
      continue;
    }
    grouped.putIfAbsent(supplierName, () => []).add(movement);
  }

  final summaries =
      grouped.entries.map((entry) {
          final transferUnits = entry.value
              .where(_isWarehouseToStoreTransfer)
              .fold(0, (sum, movement) => sum + movement.quantity);
          final lastMovementAt = entry.value
              .map((movement) => movement.occurredAt)
              .reduce(
                (current, next) => current.isAfter(next) ? current : next,
              );

          return _MovementSupplierSummary(
            supplierName: entry.key,
            productCount:
                entry.value
                    .map((movement) => movement.productId)
                    .toSet()
                    .length,
            transferUnits: transferUnits,
            totalUnits: entry.value.fold(
              0,
              (sum, movement) => sum + movement.quantity,
            ),
            lastMovementAt: lastMovementAt,
          );
        }).toList()
        ..sort((a, b) => b.lastMovementAt.compareTo(a.lastMovementAt));

  return summaries;
}

List<_RejectedShiftSummary> _buildRejectedShiftSummaries(
  List<CashShift> rejectedShifts,
) {
  final counts = <String, int>{};
  final lastDates = <String, DateTime>{};

  for (final shift in rejectedShifts) {
    final sellerName =
        shift.sellerName?.trim().isNotEmpty == true
            ? shift.sellerName!.trim()
            : 'Vendedor';
    counts[sellerName] = (counts[sellerName] ?? 0) + 1;
    final occurredAt = shift.closedAt ?? shift.openedAt;
    final existing = lastDates[sellerName];
    if (existing == null || occurredAt.isAfter(existing)) {
      lastDates[sellerName] = occurredAt;
    }
  }

  final summaries =
      counts.entries.map((entry) {
          return _RejectedShiftSummary(
            sellerName: entry.key,
            rejectionCount: entry.value,
            lastRejectedAt: lastDates[entry.key]!,
          );
        }).toList()
        ..sort((a, b) {
          final byCount = b.rejectionCount.compareTo(a.rejectionCount);
          if (byCount != 0) {
            return byCount;
          }
          return b.lastRejectedAt.compareTo(a.lastRejectedAt);
        });

  return summaries;
}

List<_OperationalAlertRow> _buildOperationalAlertRows(
  AdminDesktopDashboardState state,
) {
  final rows = <_OperationalAlertRow>[];
  // build purchases index to lookup suppliers for low-stock products
  final purchasesByProduct = <String, List<Purchase>>{};
  for (final purchase in state.purchases) {
    final touchedProducts = <String>{};
    for (final item in purchase.items) {
      if (touchedProducts.add(item.productId)) {
        purchasesByProduct.putIfAbsent(item.productId, () => []).add(purchase);
      }
    }
  }

  for (final product in state.lowStockProducts) {
    final productPurchases = purchasesByProduct[product.id] ?? const [];
    final suppliers =
        productPurchases
            .map((p) => p.supplier.trim())
            .where(_hasOperationalSupplier)
            .toSet()
            .toList()
          ..sort();
    final supplierLabel =
        suppliers.isEmpty
            ? (_isArtisanalProduct(product)
                ? 'Artesanal / sin proveedor'
                : 'Sin proveedor registrado')
            : suppliers.join(', ');

    rows.add(
      _OperationalAlertRow(
        productName: product.name,
        supplierName: supplierLabel,
        alertLabel: 'Stock bajo',
        quantityLabel: '${product.stockStore} u.',
        locationLabel: 'Tienda',
        referenceLabel: 'Minimo ${product.lowStockThreshold} u.',
        sortWeight: 2,
        sortDate: null,
      ),
    );
  }

  for (final alert in state.expiredLotAlerts) {
    rows.add(
      _OperationalAlertRow(
        productName: alert.productName,
        supplierName: alert.supplierName,
        alertLabel: 'Vencido',
        quantityLabel: '${alert.availableUnits} u.',
        locationLabel: 'Almacen',
        referenceLabel: SystemWFormatters.shortDate.format(alert.expiryDate),
        sortWeight: 0,
        sortDate: alert.expiryDate,
      ),
    );
  }

  for (final alert in state.expiringLotAlerts) {
    rows.add(
      _OperationalAlertRow(
        productName: alert.productName,
        supplierName: alert.supplierName,
        alertLabel: 'Vence pronto',
        quantityLabel: '${alert.availableUnits} u.',
        locationLabel: 'Almacen',
        referenceLabel: SystemWFormatters.shortDate.format(alert.expiryDate),
        sortWeight: 1,
        sortDate: alert.expiryDate,
      ),
    );
  }

  rows.sort((left, right) {
    final weightCompare = left.sortWeight.compareTo(right.sortWeight);
    if (weightCompare != 0) {
      return weightCompare;
    }

    final leftDate = left.sortDate;
    final rightDate = right.sortDate;
    if (leftDate != null && rightDate != null) {
      final dateCompare = leftDate.compareTo(rightDate);
      if (dateCompare != 0) {
        return dateCompare;
      }
    } else if (leftDate != null) {
      return -1;
    } else if (rightDate != null) {
      return 1;
    }

    return left.productName.toLowerCase().compareTo(
      right.productName.toLowerCase(),
    );
  });

  return rows;
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

String _cashShiftStatusLabel(CashShift shift) {
  if (shift.status == CashShiftStatus.rejected) {
    return 'Rechazado';
  }
  if (shift.status == CashShiftStatus.canceled) {
    return 'Cancelado';
  }
  if (shift.isClosed) {
    return 'Cerrado';
  }
  return switch (shift.status) {
    CashShiftStatus.pendingApproval => 'Pendiente',
    CashShiftStatus.approved => 'Aprobado',
    CashShiftStatus.closed => 'Cerrado',
    CashShiftStatus.open => 'Abierto',
    CashShiftStatus.rejected => 'Rechazado',
    CashShiftStatus.canceled => 'Cancelado',
  };
}

String _packStatusLabel(Pack pack) {
  if (pack.status == 'cancelled') {
    return 'Cancelado';
  }
  if (pack.status == 'exhausted' || pack.availableForSale <= 0) {
    return 'Agotado';
  }
  return 'Activo';
}

String _formatOptionalCurrency(double? value) {
  if (value == null) {
    return 'Pendiente';
  }
  return SystemWFormatters.currency.format(value);
}

Color _cashShiftStatusBackground(CashShift shift) {
  if (shift.status == CashShiftStatus.rejected) {
    return const Color(0xFFFEF2F2);
  }
  if (shift.status == CashShiftStatus.canceled) {
    return const Color(0xFFE2E8F0);
  }
  if (shift.isClosed) {
    return const Color(0xFFF1F5F9);
  }
  return switch (shift.status) {
    CashShiftStatus.pendingApproval => const Color(0xFFFFF7ED),
    CashShiftStatus.approved => const Color(0xFFE0F2FE),
    CashShiftStatus.closed => const Color(0xFFF1F5F9),
    CashShiftStatus.open => const Color(0xFFECFDF5),
    CashShiftStatus.rejected => const Color(0xFFFEF2F2),
    CashShiftStatus.canceled => const Color(0xFFE2E8F0),
  };
}

Color _cashShiftStatusForeground(CashShift shift) {
  if (shift.status == CashShiftStatus.rejected) {
    return const Color(0xFFB91C1C);
  }
  if (shift.status == CashShiftStatus.canceled) {
    return const Color(0xFF475569);
  }
  if (shift.isClosed) {
    return const Color(0xFF334155);
  }
  return switch (shift.status) {
    CashShiftStatus.pendingApproval => const Color(0xFF9A3412),
    CashShiftStatus.approved => const Color(0xFF075985),
    CashShiftStatus.closed => const Color(0xFF334155),
    CashShiftStatus.open => const Color(0xFF047857),
    CashShiftStatus.rejected => const Color(0xFFB91C1C),
    CashShiftStatus.canceled => const Color(0xFF475569),
  };
}

String _shiftOpeningPlace(CashShift shift) {
  return _shiftPlaceLabel(
    locationName: shift.locationName,
    latitude: shift.openingLatitude,
    longitude: shift.openingLongitude,
    fallback: 'Sin ubicacion de inicio',
  );
}

String _shiftClosingPlace(CashShift shift) {
  return _shiftPlaceLabel(
    locationName: shift.locationName,
    latitude: shift.closingLatitude,
    longitude: shift.closingLongitude,
    fallback: shift.isClosed ? 'Sin ubicacion de cierre' : 'Turno abierto',
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

String? _mapsUrl({required double? latitude, required double? longitude}) {
  if (latitude == null || longitude == null) {
    return null;
  }
  return 'https://www.google.com/maps?q=$latitude,$longitude';
}

String _movementTypeLabel(InventoryMovement movement) {
  if (movement.type.toLowerCase() == 'loss') {
    return 'Perdida';
  }
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
  if (movement.type.toLowerCase() == 'loss') {
    return 'Perdida';
  }
  if (movement.toLocation.toLowerCase().contains('sin destino')) {
    return 'Venta';
  }
  return movement.toLocation;
}

String _movementSupplierLabel(InventoryMovement movement) {
  final supplierName = movement.supplierName?.trim() ?? '';
  if (supplierName.isNotEmpty) {
    return supplierName;
  }

  return switch (_movementTypeLabel(movement)) {
    'Compra' => 'Sin proveedor',
    'Transferencia' => 'Sin proveedor',
    'Perdida' => 'Sin proveedor',
    _ => 'No aplica',
  };
}

String _lotAlertLocationLabel(InventoryLotAlert alert) {
  if (alert.availableUnits <= 0) {
    return 'Sin stock';
  }
  return 'Almacen';
}

bool _isWarehouseToStoreTransfer(InventoryMovement movement) {
  return _movementTypeLabel(movement) == 'Transferencia' &&
      movement.fromLocation.toLowerCase().contains('almacen') &&
      movement.toLocation.toLowerCase().contains('tienda');
}

DateTimeRange _currentWeekRange() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(
    Duration(days: today.weekday - DateTime.monday),
  );
  final sunday = monday.add(const Duration(days: 6));
  return DateTimeRange(start: monday, end: sunday);
}

DateTimeRange _previousWeekRange() {
  final currentWeek = _currentWeekRange();
  final monday = currentWeek.start.subtract(const Duration(days: 7));
  final sunday = currentWeek.end.subtract(const Duration(days: 7));
  return DateTimeRange(start: monday, end: sunday);
}

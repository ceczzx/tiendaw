import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/core/sync/realtime_refresh_stream.dart';
import 'package:tiendaw/core/sync/sync_status.dart';
import 'package:tiendaw/core/utils/postgrest_compat.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';

class SalesLocalDataSource {
  List<Sale> _sales = const [];
  List<CashShift> _cashShifts = const [];
  final Map<String, CashShift> _openShiftsBySeller = {};

  Future<void> upsertSale(Sale sale) async {
    final next = [..._sales];
    final index = next.indexWhere((item) => item.id == sale.id);
    if (index == -1) {
      next.add(sale);
    } else {
      next[index] = sale;
    }

    next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _sales = List<Sale>.unmodifiable(next);
  }

  Future<void> saveSales(List<Sale> sales) async {
    final next = [...sales]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _sales = List<Sale>.unmodifiable(next);
  }

  Future<List<Sale>> getSales() async => List.unmodifiable(_sales);

  Future<void> saveCashShifts(List<CashShift> shifts) async {
    final next = [...shifts]..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    _cashShifts = List<CashShift>.unmodifiable(next);
  }

  Future<List<CashShift>> getCashShifts() async =>
      List.unmodifiable(_cashShifts);

  Future<Sale?> findSale(String saleId) async {
    for (final sale in _sales) {
      if (sale.id == saleId) {
        return sale;
      }
    }
    return null;
  }

  Future<void> saveOpenShift(String sellerId, CashShift shift) async {
    _openShiftsBySeller[sellerId] = shift;
  }

  Future<CashShift?> getOpenShift(String sellerId) async {
    return _openShiftsBySeller[sellerId];
  }

  Future<void> clearOpenShift(String sellerId) async {
    _openShiftsBySeller.remove(sellerId);
  }
}

class SalesRemoteDataSource {
  SalesRemoteDataSource(this._client);

  final SupabaseClient _client;
  bool? _supportsSaleItemMeta;

  Future<List<Sale>> getSales() async {
    final rows = await _withSalesSelect(
      (selectClause) => _client
          .from('sales')
          .select(selectClause)
          .order('created_at', ascending: false),
    );

    return _mapRows(rows).map((row) {
      final seller = _mapNullable(row['seller']);
      final items =
          ((row['sale_items'] as List?) ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .map((item) {
                final product = _mapNullable(item['product']);
                final itemMeta =
                    item['item_meta'] is Map
                        ? Map<String, dynamic>.from(item['item_meta'] as Map)
                        : const <String, dynamic>{};
                final usedPromotionalPrice =
                    itemMeta['used_promotional_price'] == true;
                final usedLotPromotion =
                    itemMeta.containsKey('used_lot_promotion')
                        ? itemMeta['used_lot_promotion'] == true
                        : usedPromotionalPrice;
                return SaleLine(
                  productId: item['product_id'] as String,
                  productName: product['name']?.toString() ?? 'Producto',
                  quantity: (item['quantity'] as num).toInt(),
                  unitPrice: (item['unit_price'] as num).toDouble(),
                  baseUnitPrice:
                      (itemMeta['base_unit_price'] as num?)?.toDouble(),
                  originalUnitPrice:
                      (itemMeta['original_unit_price'] as num?)?.toDouble(),
                  priceAdjustment:
                      (itemMeta['price_adjustment'] as num?)?.toDouble() ?? 0,
                  isIced: itemMeta['is_iced'] == true,
                  usedPromotionalPrice: usedPromotionalPrice,
                  usedLotPromotion: usedLotPromotion,
                  packId: itemMeta['pack_id']?.toString(),
                  packName: itemMeta['pack_name']?.toString(),
                  batchId: itemMeta['batch_id']?.toString(),
                  packSaleQuantity:
                      (itemMeta['pack_sale_quantity'] as num?)?.toInt(),
                  packItemQuantity:
                      (itemMeta['pack_item_quantity'] as num?)?.toInt(),
                  stockReservedByPack:
                      itemMeta['stock_reserved_by_pack'] == true,
                );
              })
              .toList();

      return Sale(
        id: row['id'] as String,
        sellerId: row['seller_id'] as String,
        sellerName: seller['full_name']?.toString() ?? 'Usuario',
        cashShiftId: row['cash_shift_id'] as String?,
        items: items,
        paymentMethod: switch (row['payment_method']?.toString()) {
          'yape' => PaymentMethod.yape,
          'transfer' => PaymentMethod.transfer,
          _ => PaymentMethod.cash,
        },
        createdAt: _parseSupabaseDateTime(row['created_at'] as String),
        syncStatus: SyncStatus.synced,
        syncAttempts: 0,
      );
    }).toList();
  }

  Stream<List<Sale>> watchSales() {
    return createRealtimeRefreshStream(
      load: getSales,
      triggers: [
        _tableTrigger('sales', primaryKey: const ['id']),
        _tableTrigger('sale_items', primaryKey: const ['id']),
        _tableTrigger('products', primaryKey: const ['id']),
      ],
    );
  }

  Future<List<CashShift>> getCashShifts() async {
    final rows = await _client
        .from('cash_shifts')
        .select(
          'id, seller_id, opened_at, closed_at, opening_cash, opening_yape, closing_cash, closing_yape, '
          'location_id, opening_latitude, opening_longitude, closing_latitude, closing_longitude, '
          'status, approved_by, approved_at, rejection_reason, '
          'seller:profiles!cash_shifts_seller_id_fkey(full_name), '
          'location:locations!cash_shifts_location_id_fkey(name), '
          'sales(payment_method, total)',
        )
        .order('opened_at', ascending: false);

    return _mapRows(rows).map(_mapCashShift).toList();
  }

  Stream<List<CashShift>> watchCashShifts() {
    return createRealtimeRefreshStream(
      load: getCashShifts,
      triggers: [
        _tableTrigger('cash_shifts', primaryKey: const ['id']),
      ],
    );
  }

  Future<CashShift?> getOpenShift(String sellerId) {
    return _loadLatestShift(sellerId);
  }

  Stream<CashShift?> watchOpenShift(String sellerId) {
    return createRealtimeRefreshStream(
      load: () => _loadLatestShift(sellerId),
      triggers: [
        _client
            .from('cash_shifts')
            .stream(primaryKey: const ['id'])
            .eq('seller_id', sellerId)
            .skip(1),
      ],
    );
  }

  Future<CashShift> openShift({
    required String sellerId,
    required double openingCash,
    required double openingYape,
    required double openingLatitude,
    required double openingLongitude,
  }) async {
    final current = await _loadOpenShift(sellerId);
    if (current != null) {
      return current;
    }

    final openedAt = DateTime.now();
    final storeLocationId = await _resolveLocationId('store');
    final inserted =
        await _client
            .from('cash_shifts')
            .insert({
              'seller_id': sellerId,
              'opening_cash': openingCash,
              'opening_yape': openingYape,
              'location_id': storeLocationId,
              'opening_latitude': openingLatitude,
              'opening_longitude': openingLongitude,
              'opened_at': _toSupabaseDateTime(openedAt),
            })
            .select(
              'id, seller_id, opened_at, closed_at, opening_cash, opening_yape, closing_cash, closing_yape, '
              'location_id, opening_latitude, opening_longitude, closing_latitude, closing_longitude, '
              'status, approved_by, approved_at, rejection_reason, '
              'location:locations!cash_shifts_location_id_fkey(name), '
              'sales(payment_method, total)',
            )
            .maybeSingle();

    if (inserted == null) {
      throw StateError('No se pudo abrir la caja del turno.');
    }

    return _mapCashShift(Map<String, dynamic>.from(inserted));
  }

  Future<_PersistedSale> pushSale(Sale sale) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('No hay una sesion activa para registrar ventas.');
    }

    final openShift = await _loadOpenShift(currentUser.id);
    if (openShift == null) {
      throw StateError(
        'Inicia la caja antes de registrar ventas en la tienda.',
      );
    }
    if (!openShift.canSell) {
      throw StateError(
        openShift.isPendingApproval
            ? 'Solicitud enviada, esperando que el administrador apruebe el turno.'
            : 'Tu turno no esta habilitado para vender en este momento.',
      );
    }
    final storeLocationId = await _resolveLocationId('store');

    final inserted =
        await _client
            .from('sales')
            .insert({
              'id': sale.id,
              'seller_id': currentUser.id,
              'location_id': storeLocationId,
              'cash_shift_id': openShift.id,
              'payment_method': sale.paymentMethod.name,
              'total': sale.total,
              'created_at': _toSupabaseDateTime(sale.createdAt),
            })
            .select('id')
            .single();
    final saleId = inserted['id'] as String;

    final saleItemsPayload =
        sale.items
            .map(
              (item) => {
                'sale_id': saleId,
                'product_id': item.productId,
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
                'item_meta': item.toItemMeta(),
              },
            )
            .toList();

    await _insertSaleItems(saleItemsPayload);
    await _decrementSoldPacks(sale.items);

    return _PersistedSale(id: saleId, cashShiftId: openShift.id);
  }

  Future<void> _decrementSoldPacks(List<SaleLine> items) async {
    final soldByPack = <String, int>{};
    for (final item in items) {
      final packId = item.packId;
      final soldQuantity = item.packSaleQuantity ?? 0;
      if (packId == null || packId.isEmpty || soldQuantity <= 0) {
        continue;
      }
      final current = soldByPack[packId] ?? 0;
      if (soldQuantity > current) {
        soldByPack[packId] = soldQuantity;
      }
    }

    for (final entry in soldByPack.entries) {
      final row =
          await _client
              .from('packs')
              .select('pack_quantity_remaining')
              .eq('id', entry.key)
              .maybeSingle();
      final currentRemaining =
          (row?['pack_quantity_remaining'] as num?)?.toInt() ?? 0;
      final nextRemaining =
          currentRemaining - entry.value < 0
              ? 0
              : currentRemaining - entry.value;
      await _client
          .from('packs')
          .update({
            'pack_quantity_remaining': nextRemaining,
            'status': nextRemaining <= 0 ? 'exhausted' : 'active',
          })
          .eq('id', entry.key);
    }
  }

  Future<void> closeShift({
    required String sellerId,
    required double closingCash,
    required double closingYape,
    required double closingLatitude,
    required double closingLongitude,
  }) async {
    final current = await _loadOpenShift(sellerId);
    if (current != null) {
      await _client
          .from('cash_shifts')
          .update({
            'closed_at': _toSupabaseDateTime(DateTime.now()),
            'closing_cash': closingCash,
            'closing_yape': closingYape,
            'closing_latitude': closingLatitude,
            'closing_longitude': closingLongitude,
            'status': 'closed',
          })
          .eq('id', current.id);
    }
  }

  Future<void> approveShift({
    required String shiftId,
    required String adminId,
  }) async {
    await _client
        .from('cash_shifts')
        .update({
          'status': 'approved',
          'approved_by': adminId,
          'approved_at': _toSupabaseDateTime(DateTime.now()),
          'rejection_reason': null,
        })
        .eq('id', shiftId)
        .eq('status', 'pending_approval');
  }

  Future<void> rejectShift({
    required String shiftId,
    required String adminId,
    required String rejectionReason,
  }) async {
    await _client
        .from('cash_shifts')
        .update({
          'status': 'rejected',
          'approved_by': adminId,
          'approved_at': _toSupabaseDateTime(DateTime.now()),
          'rejection_reason': rejectionReason.trim(),
        })
        .eq('id', shiftId)
        .eq('status', 'pending_approval');
  }

  Future<void> deletePendingShiftRequest({
    required String sellerId,
    String? shiftId,
  }) async {
    var query = _client
        .from('cash_shifts')
        .delete()
        .eq('status', 'pending_approval')
        .eq('seller_id', sellerId);

    if (shiftId != null && shiftId.trim().isNotEmpty) {
      query = query.eq('id', shiftId);
    }

    await query;
  }

  Future<void> _insertSaleItems(
    List<Map<String, dynamic>> saleItemsPayload,
  ) async {
    if (_supportsSaleItemMeta == false) {
      await _client
          .from('sale_items')
          .insert(saleItemsPayload.map(_withoutItemMeta).toList());
      return;
    }

    try {
      await _client.from('sale_items').insert(saleItemsPayload);
      _supportsSaleItemMeta = true;
    } on PostgrestException catch (error) {
      if (!isMissingColumnError(
        error,
        column: 'item_meta',
        table: 'sale_items',
      )) {
        rethrow;
      }

      _supportsSaleItemMeta = false;
      await _client
          .from('sale_items')
          .insert(saleItemsPayload.map(_withoutItemMeta).toList());
    }
  }

  Future<T> _withSalesSelect<T>(
    Future<T> Function(String selectClause) run,
  ) async {
    if (_supportsSaleItemMeta == false) {
      return run(_legacySalesSelectClause);
    }

    try {
      final result = await run(_enhancedSalesSelectClause);
      _supportsSaleItemMeta = true;
      return result;
    } on PostgrestException catch (error) {
      if (!isMissingColumnError(
        error,
        column: 'item_meta',
        table: 'sale_items',
      )) {
        rethrow;
      }

      _supportsSaleItemMeta = false;
      return run(_legacySalesSelectClause);
    }
  }

  Future<CashShift?> _loadLatestShift(String sellerId) async {
    final rows = await _client
        .from('cash_shifts')
        .select(
          'id, seller_id, opened_at, closed_at, opening_cash, opening_yape, closing_cash, closing_yape, '
          'location_id, opening_latitude, opening_longitude, closing_latitude, closing_longitude, '
          'status, approved_by, approved_at, rejection_reason, '
          'location:locations!cash_shifts_location_id_fkey(name), '
          'sales(payment_method, total)',
        )
        .eq('seller_id', sellerId)
        .order('opened_at', ascending: false)
        .limit(1);

    final data = _mapRows(rows);
    if (data.isEmpty) {
      return null;
    }

    return _mapCashShift(data.first);
  }

  Future<CashShift?> _loadOpenShift(String sellerId) async {
    final rows = await _client
        .from('cash_shifts')
        .select(
          'id, seller_id, opened_at, closed_at, opening_cash, opening_yape, closing_cash, closing_yape, '
          'location_id, opening_latitude, opening_longitude, closing_latitude, closing_longitude, '
          'status, approved_by, approved_at, rejection_reason, '
          'location:locations!cash_shifts_location_id_fkey(name), '
          'sales(payment_method, total)',
        )
        .eq('seller_id', sellerId)
        .isFilter('closed_at', null)
        .inFilter('status', const ['open', 'approved', 'pending_approval'])
        .order('opened_at', ascending: false)
        .limit(1);

    final data = _mapRows(rows);
    if (data.isEmpty) {
      return null;
    }

    return _mapCashShift(data.first);
  }

  Future<String> _resolveLocationId(String locationType) async {
    final rows = await _client
        .from('locations')
        .select('id')
        .eq('location_type', locationType)
        .limit(1);

    final data = _mapRows(rows);
    if (data.isEmpty) {
      throw StateError(
        'No existe una ubicacion configurada para $locationType.',
      );
    }

    return data.first['id'] as String;
  }

  CashShift _mapCashShift(Map<String, dynamic> row) {
    final seller = _mapNullable(row['seller']);
    final location = _mapNullable(row['location']);
    final shiftSales = _mapShiftSales(row['sales']);
    return CashShift(
      id: row['id'] as String,
      sellerId: row['seller_id'] as String,
      sellerName: seller['full_name']?.toString(),
      openedAt: _parseSupabaseDateTime(row['opened_at'] as String),
      openingCash: (row['opening_cash'] as num?)?.toDouble() ?? 0,
      openingYape: (row['opening_yape'] as num?)?.toDouble() ?? 0,
      closedAt:
          row['closed_at'] == null
              ? null
              : _parseSupabaseDateTime(row['closed_at'] as String),
      closingCash: (row['closing_cash'] as num?)?.toDouble(),
      closingYape: (row['closing_yape'] as num?)?.toDouble(),
      cashSales: shiftSales.cash,
      yapeSales: shiftSales.yape,
      locationId: row['location_id']?.toString(),
      locationName: location['name']?.toString(),
      openingLatitude: (row['opening_latitude'] as num?)?.toDouble(),
      openingLongitude: (row['opening_longitude'] as num?)?.toDouble(),
      closingLatitude: (row['closing_latitude'] as num?)?.toDouble(),
      closingLongitude: (row['closing_longitude'] as num?)?.toDouble(),
      status: _mapShiftStatus(row['status']?.toString()),
      approvedBy: row['approved_by']?.toString(),
      approvedAt:
          row['approved_at'] == null
              ? null
              : _parseSupabaseDateTime(row['approved_at'] as String),
      rejectionReason: row['rejection_reason']?.toString(),
    );
  }

  List<Map<String, dynamic>> _mapRows(dynamic rows) {
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Map<String, dynamic> _mapNullable(dynamic value) {
    if (value == null) {
      return const {};
    }

    return Map<String, dynamic>.from(value as Map);
  }

  ({double cash, double yape}) _mapShiftSales(dynamic rawSales) {
    var cash = 0.0;
    var yape = 0.0;
    for (final item in (rawSales as List?) ?? const []) {
      final row = Map<String, dynamic>.from(item as Map);
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      if (row['payment_method'] == PaymentMethod.cash.name) {
        cash += total;
      } else {
        yape += total;
      }
    }
    return (cash: cash, yape: yape);
  }

  Stream<dynamic> _tableTrigger(
    String table, {
    required List<String> primaryKey,
  }) {
    return _client.from(table).stream(primaryKey: primaryKey).skip(1);
  }

  CashShiftStatus _mapShiftStatus(String? rawStatus) {
    return switch (rawStatus) {
      'pending_approval' => CashShiftStatus.pendingApproval,
      'approved' => CashShiftStatus.approved,
      'rejected' => CashShiftStatus.rejected,
      'canceled' => CashShiftStatus.canceled,
      'cancelled' => CashShiftStatus.canceled,
      'closed' => CashShiftStatus.closed,
      _ => CashShiftStatus.open,
    };
  }
}

class _PersistedSale {
  const _PersistedSale({required this.id, required this.cashShiftId});

  final String id;
  final String cashShiftId;
}

DateTime _parseSupabaseDateTime(String rawValue) {
  return DateTime.parse(rawValue).toLocal();
}

String _toSupabaseDateTime(DateTime value) {
  return value.toUtc().toIso8601String();
}

const String _enhancedSalesSelectClause =
    'id, seller_id, cash_shift_id, payment_method, created_at, '
    'seller:profiles(full_name), '
    'sale_items(product_id, quantity, unit_price, item_meta, product:products(name))';

const String _legacySalesSelectClause =
    'id, seller_id, cash_shift_id, payment_method, created_at, '
    'seller:profiles(full_name), '
    'sale_items(product_id, quantity, unit_price, product:products(name))';

Map<String, dynamic> _withoutItemMeta(Map<String, dynamic> row) {
  final next = Map<String, dynamic>.from(row);
  next.remove('item_meta');
  return next;
}

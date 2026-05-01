import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/core/sync/sync_status.dart';
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

  Future<List<CashShift>> getCashShifts() async => List.unmodifiable(_cashShifts);

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
}

class SalesRemoteDataSource {
  SalesRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Sale>> getSales() async {
    final rows = await _client
        .from('sales')
        .select(
          'id, seller_id, cash_shift_id, payment_method, created_at, seller:profiles(full_name), sale_items(product_id, quantity, unit_price, product:products(name))',
        )
        .order('created_at', ascending: false);

    return _mapRows(rows).map((row) {
      final seller = _mapNullable(row['seller']);
      final items =
          ((row['sale_items'] as List?) ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .map((item) {
                final product = _mapNullable(item['product']);
                return SaleLine(
                  productId: item['product_id'] as String,
                  productName: product['name']?.toString() ?? 'Producto',
                  quantity: item['quantity'] as int,
                  unitPrice: (item['unit_price'] as num).toDouble(),
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
        createdAt: DateTime.parse(row['created_at'] as String),
        syncStatus: SyncStatus.synced,
        syncAttempts: 0,
      );
    }).toList();
  }

  Future<List<CashShift>> getCashShifts() async {
    final rows = await _client
        .from('cash_shifts')
        .select(
          'id, seller_id, opened_at, closed_at, cash_total, yape_total, seller:profiles(full_name)',
        )
        .order('opened_at', ascending: false);

    return _mapRows(rows).map(_mapCashShift).toList();
  }

  Future<CashShift> getOpenShift(String sellerId) async {
    final current = await _loadOpenShift(sellerId);
    if (current != null) {
      return current;
    }

    final inserted =
        await _client
            .from('cash_shifts')
            .insert({
              'seller_id': sellerId,
              'opening_amount': 0,
              'cash_total': 0,
              'yape_total': 0,
            })
            .select(
              'id, seller_id, opened_at, closed_at, cash_total, yape_total',
            )
            .maybeSingle();

    if (inserted == null) {
      throw StateError('No se pudo abrir la caja del turno.');
    }

    return _mapCashShift(Map<String, dynamic>.from(inserted));
  }

  Future<String> pushSale(Sale sale) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('No hay una sesion activa para registrar ventas.');
    }

    final openShift = await getOpenShift(currentUser.id);
    final storeLocationId = await _resolveLocationId('store');

    await _client.from('sales').insert({
      'id': sale.id,
      'seller_id': currentUser.id,
      'location_id': storeLocationId,
      'cash_shift_id': openShift.id,
      'payment_method': sale.paymentMethod.name,
      'total': sale.total,
      'created_at': sale.createdAt.toIso8601String(),
    });

    await _client.from('sale_items').insert(
      sale.items
          .map(
            (item) => {
              'sale_id': sale.id,
              'product_id': item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
            },
          )
          .toList(),
    );

    final totalField =
      sale.paymentMethod == PaymentMethod.cash ? 'cash_total' : 'yape_total';
    final nextTotal =
      (sale.paymentMethod == PaymentMethod.cash
          ? openShift.cashSales
          : openShift.yapeSales) +
        sale.total;

    await _client
        .from('cash_shifts')
        .update({totalField: nextTotal})
        .eq('id', openShift.id);

    return openShift.id;
  }

  Future<void> closeShift(String sellerId) async {
    final current = await _loadOpenShift(sellerId);
    if (current != null) {
      await _client
          .from('cash_shifts')
          .update({'closed_at': DateTime.now().toIso8601String()})
          .eq('id', current.id);
    }

    await _client.from('cash_shifts').insert({
      'seller_id': sellerId,
      'opening_amount': 0,
      'cash_total': 0,
      'yape_total': 0,
    });
  }

  Future<CashShift?> _loadOpenShift(String sellerId) async {
    final rows = await _client
        .from('cash_shifts')
        .select('id, seller_id, opened_at, closed_at, cash_total, yape_total')
        .eq('seller_id', sellerId)
        .isFilter('closed_at', null)
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
      throw StateError('No existe una ubicacion configurada para $locationType.');
    }

    return data.first['id'] as String;
  }

  CashShift _mapCashShift(Map<String, dynamic> row) {
    final seller = _mapNullable(row['seller']);
    return CashShift(
      id: row['id'] as String,
      sellerId: row['seller_id'] as String,
      sellerName: seller['full_name']?.toString(),
      openedAt: DateTime.parse(row['opened_at'] as String),
      closedAt:
          row['closed_at'] == null
              ? null
              : DateTime.parse(row['closed_at'] as String),
      cashSales: (row['cash_total'] as num?)?.toDouble() ?? 0,
      yapeSales: (row['yape_total'] as num?)?.toDouble() ?? 0,
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
}

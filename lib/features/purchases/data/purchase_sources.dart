import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/core/sync/sync_status.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';

class PurchaseLocalDataSource {
  List<Purchase> _purchases = const [];

  Future<void> upsertPurchase(Purchase purchase) async {
    final next = [..._purchases];
    final index = next.indexWhere((item) => item.id == purchase.id);
    if (index == -1) {
      next.add(purchase);
    } else {
      next[index] = purchase;
    }

    next.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    _purchases = List<Purchase>.unmodifiable(next);
  }

  Future<void> savePurchases(List<Purchase> purchases) async {
    final next = [...purchases]
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    _purchases = List<Purchase>.unmodifiable(next);
  }

  Future<List<Purchase>> getPurchases() async => List.unmodifiable(_purchases);

  Future<Purchase?> findPurchase(String purchaseId) async {
    for (final purchase in _purchases) {
      if (purchase.id == purchaseId) {
        return purchase;
      }
    }
    return null;
  }
}

class PurchaseRemoteDataSource {
  PurchaseRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Purchase>> getPurchases() async {
    final rows = await _client
        .from('purchases')
        .select(
          'id, received_at, supplier:suppliers(name, phone), admin:profiles(full_name), purchase_items(product_id, quantity, unit_cost, expiry_date, product:products(name, units_per_package))',
        )
        .order('received_at', ascending: false);

    return _mapRows(rows).map((row) {
      final supplier = _mapNullable(row['supplier']);
      final admin = _mapNullable(row['admin']);
      final items =
          ((row['purchase_items'] as List?) ?? const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .map((item) {
                final product = _mapNullable(item['product']);
                return PurchaseLine(
                  productId: item['product_id'] as String,
                  productName: product['name']?.toString() ?? 'Producto',
                  quantity: item['quantity'] as int,
                  unitsPerPackage:
                      (product['units_per_package'] as num?)?.toInt() ?? 1,
                  unitCost: (item['unit_cost'] as num).toDouble(),
                  expiryDate:
                      item['expiry_date'] == null
                          ? null
                          : DateTime.parse(item['expiry_date'] as String),
                );
              })
              .toList();

      return Purchase(
        id: row['id'] as String,
        supplier: supplier['name']?.toString() ?? 'Produccion artesanal',
        supplierPhone: supplier['phone']?.toString(),
        registeredBy: admin['full_name']?.toString() ?? 'Administrador',
        items: items,
        receivedAt: _parseSupabaseDateTime(row['received_at'] as String),
        syncStatus: SyncStatus.synced,
        syncAttempts: 0,
      );
    }).toList();
  }

  Future<void> pushPurchase(Purchase purchase) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('No hay una sesion activa para registrar compras.');
    }

    final normalizedSupplier = purchase.supplier.trim();
    final supplierId =
        normalizedSupplier.isEmpty
            ? null
            : await _resolveSupplierId(
              normalizedSupplier,
              phone: purchase.supplierPhone,
            );
    final warehouseId = await _resolveLocationId('warehouse');

    await _client.from('purchases').insert({
      'id': purchase.id,
      'supplier_id': supplierId,
      'admin_id': currentUser.id,
      'warehouse_id': warehouseId,
      'total_price': purchase.total,
      'received_at': _toSupabaseDateTime(purchase.receivedAt),
    });

    await _client
        .from('purchase_items')
        .insert(
          purchase.items
              .map(
                (item) => {
                  'purchase_id': purchase.id,
                  'product_id': item.productId,
                  'quantity': item.quantity,
                  'unit_cost': item.unitCost,
                  'expiry_date': item.expiryDate?.toIso8601String(),
                },
              )
              .toList(),
        );

    if (supplierId != null) {
      await _client
          .from('product_prices')
          .insert(
            purchase.items
                .map(
                  (item) => {
                    'product_id': item.productId,
                    'supplier_id': supplierId,
                    'unit_cost': item.unitCost,
                    'effective_at': _toSupabaseDateTime(purchase.receivedAt),
                  },
                )
                .toList(),
          );
    }
  }

  Future<String> _resolveSupplierId(String supplierName, {String? phone}) async {
    final normalizedPhone = phone?.trim();
    final rows = await _client
        .from('suppliers')
        .select('id, phone')
        .eq('name', supplierName)
        .limit(1);

    final data = _mapRows(rows);
    if (data.isNotEmpty) {
      final supplier = data.first;
      final supplierId = supplier['id'] as String;
      final currentPhone = supplier['phone']?.toString().trim() ?? '';
      if (normalizedPhone != null &&
          normalizedPhone.isNotEmpty &&
          normalizedPhone != currentPhone) {
        await _client
            .from('suppliers')
            .update({'phone': normalizedPhone})
            .eq('id', supplierId);
      }
      return supplierId;
    }

    final inserted =
        await _client
            .from('suppliers')
            .insert({'name': supplierName, 'phone': normalizedPhone})
            .select('id')
            .maybeSingle();

    if (inserted == null) {
      throw StateError('No se pudo registrar el proveedor.');
    }

    return inserted['id'] as String;
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

DateTime _parseSupabaseDateTime(String rawValue) {
  return DateTime.parse(rawValue).toLocal();
}

String _toSupabaseDateTime(DateTime value) {
  return value.toUtc().toIso8601String();
}

// ignore_for_file: unused_catch_clause

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/core/sync/realtime_refresh_stream.dart';
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
          'id, received_at, supplier:suppliers!purchases_supplier_id_fkey(id, name, phone), admin:profiles!purchases_admin_id_fkey(full_name), purchase_items(id, product_id, quantity, unit_cost, expiry_date, product:products!purchase_items_product_id_fkey(name, units_per_package))',
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
        supplierId: supplier['id']?.toString(),
        supplierPhone: supplier['phone']?.toString(),
        registeredBy: admin['full_name']?.toString() ?? 'Administrador',
        items: items,
        receivedAt: _parseSupabaseDateTime(row['received_at'] as String),
        syncStatus: SyncStatus.synced,
        syncAttempts: 0,
      );
    }).toList();
  }

  Stream<List<Purchase>> watchPurchases() {
    return createRealtimeRefreshStream(
      load: getPurchases,
      triggers: [
        _tableTrigger('purchases', primaryKey: const ['id']),
        _tableTrigger('purchase_items', primaryKey: const ['id']),
        _tableTrigger('products', primaryKey: const ['id']),
        _tableTrigger('suppliers', primaryKey: const ['id']),
      ],
    );
  }

  Future<Purchase> pushPurchase(Purchase purchase) async {
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

    // La BD crea productos nuevos cuando product_id es null.
    final itemsPayload =
        purchase.items.map((item) {
          final isNewProduct = item.productId.trim().isEmpty;
          return {
            'product_id': isNewProduct ? null : item.productId,
            'quantity': item.quantity,
            'unit_cost': item.unitCost,
            'expiry_date': item.expiryDate?.toIso8601String(),
            'name': isNewProduct ? item.productName : null,
            'category_id': isNewProduct ? item.categoryId : null,
            'sku': isNewProduct ? item.sku : null,
            'sale_price': isNewProduct ? item.salePrice : null,
            'units_per_package': isNewProduct ? item.unitsPerPackage : 1,
          };
        }).toList();

    dynamic result;
    try {
      result = await _client.rpc(
        'registrar_compra', // Llama a la versión limpia y definitiva
        params: {
          'p_supplier_id': supplierId,
          'p_admin_id': currentUser.id,
          'p_warehouse_id': warehouseId,
          'p_total_price': purchase.total,
          'p_items': itemsPayload,
          // Omitimos p_received_at a propósito para que la BD use now() automático
        },
      );
    } on PostgrestException catch (error) {
      rethrow;
    } catch (e) {
      rethrow;
    }

    final response = Map<String, dynamic>.from(result as Map);
    final purchaseId = response['purchase_id']?.toString();

    if (purchaseId == null || purchaseId.isEmpty) {
      throw StateError(
        // Corregí el nombre de la función en tu mensaje de error para que no te confundas
        'La funcion registrar_compra no devolvio el id de la compra.',
      );
    }

    if (supplierId != null) {
      final priceItems =
          purchase.items
              .where((item) => item.productId.trim().isNotEmpty)
              .map(
                (item) => {
                  'product_id': item.productId,
                  'supplier_id': supplierId,
                  'unit_cost': item.unitCost,
                  'effective_at': _toSupabaseDateTime(purchase.receivedAt),
                },
              )
              .toList();
      if (priceItems.isNotEmpty) {
        await _client.from('product_prices').insert(priceItems);
      }
    }

    return purchase.copyWith(id: purchaseId, supplierId: supplierId);
  }

  Future<String> _resolveSupplierId(
    String supplierName, {
    String? phone,
  }) async {
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

  Stream<dynamic> _tableTrigger(
    String table, {
    required List<String> primaryKey,
  }) {
    return _client.from(table).stream(primaryKey: primaryKey).skip(1);
  }
}

DateTime _parseSupabaseDateTime(String rawValue) {
  return DateTime.parse(rawValue).toLocal();
}

String _toSupabaseDateTime(DateTime value) {
  return value.toUtc().toIso8601String();
}

import 'dart:async';

import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/shared/demo/system_w_store.dart';

class SalesLocalDataSource {
  SalesLocalDataSource(this._store);

  final SystemWStore _store;

  Future<void> saveSale(Sale sale) async => _store.saveSale(sale);
  Future<List<Sale>> getSales() async => _store.listSales();
  Future<CashShift> getOpenShift() async => _store.openShift;
  Future<void> closeShift(String sellerId) async {
    _store.closeShift();
    _store.reopenShiftForSeller(sellerId);
  }

  Future<void> markSaleSynced(String saleId) async =>
      _store.markSaleSynced(saleId);
  Future<void> increaseSyncAttempts(String saleId) async =>
      _store.increaseSaleSyncAttempts(saleId);
}

class SalesRemoteDataSource {
  SalesRemoteDataSource(this._store);

  final SystemWStore _store;

  Future<void> pushSale(Sale sale) async {
    if (!_store.isOnline) {
      throw StateError('No internet connection');
    }

    await Future<void>.delayed(const Duration(milliseconds: 220));
  }
}

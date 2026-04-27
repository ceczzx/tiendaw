import 'dart:async';

import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/shared/demo/system_w_store.dart';

class PurchaseLocalDataSource {
  PurchaseLocalDataSource(this._store);

  final SystemWStore _store;

  Future<void> savePurchase(Purchase purchase) async =>
      _store.savePurchase(purchase);
  Future<List<Purchase>> getPurchases() async => _store.listPurchases();
  Future<void> markPurchaseSynced(String purchaseId) async =>
      _store.markPurchaseSynced(purchaseId);
  Future<void> increaseSyncAttempts(String purchaseId) async =>
      _store.increasePurchaseSyncAttempts(purchaseId);
}

class PurchaseRemoteDataSource {
  PurchaseRemoteDataSource(this._store);

  final SystemWStore _store;

  Future<void> pushPurchase(Purchase purchase) async {
    if (!_store.isOnline) {
      throw StateError('No internet connection');
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

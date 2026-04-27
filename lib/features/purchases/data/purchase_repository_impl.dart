import 'package:tiendaw/features/purchases/data/purchase_sources.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_repository.dart';
import 'package:tiendaw/shared/demo/system_w_store.dart';

class PurchaseRepositoryImpl implements PurchaseRepository {
  PurchaseRepositoryImpl({
    required PurchaseLocalDataSource local,
    required PurchaseRemoteDataSource remote,
    required SystemWStore store,
  }) : _local = local,
       _remote = remote,
       _store = store;

  final PurchaseLocalDataSource _local;
  final PurchaseRemoteDataSource _remote;
  final SystemWStore _store;

  @override
  Future<List<Purchase>> getPurchases() {
    return _local.getPurchases();
  }

  @override
  Future<void> registerPurchase(Purchase purchase) async {
    await _local.savePurchase(purchase);

    if (!_store.isOnline) {
      return;
    }

    try {
      await _remote.pushPurchase(purchase);
      await _local.markPurchaseSynced(purchase.id);
    } catch (_) {
      await _local.increaseSyncAttempts(purchase.id);
    }
  }

  @override
  Future<void> syncPurchase(String purchaseId) async {
    final purchase = _store.listPurchases().firstWhere(
      (item) => item.id == purchaseId,
    );

    try {
      await _remote.pushPurchase(purchase);
      await _local.markPurchaseSynced(purchase.id);
    } catch (_) {
      await _local.increaseSyncAttempts(purchase.id);
    }
  }
}

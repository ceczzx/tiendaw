import 'package:tiendaw/core/sync/sync_status.dart';
import 'package:tiendaw/features/purchases/data/purchase_sources.dart';
import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_repository.dart';

class PurchaseRepositoryImpl implements PurchaseRepository {
  PurchaseRepositoryImpl({
    required PurchaseLocalDataSource local,
    required PurchaseRemoteDataSource remote,
  }) : _local = local,
       _remote = remote;

  final PurchaseLocalDataSource _local;
  final PurchaseRemoteDataSource _remote;

  @override
  Future<List<Purchase>> getPurchases() async {
    try {
      final purchases = await _remote.getPurchases();
      await _local.savePurchases(purchases);
      return purchases;
    } catch (_) {
      final cached = await _local.getPurchases();
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Future<void> registerPurchase(Purchase purchase) async {
    await _remote.pushPurchase(purchase);
    await _local.upsertPurchase(
      purchase.copyWith(syncStatus: SyncStatus.synced, syncAttempts: 0),
    );
  }

  @override
  Future<void> syncPurchase(String purchaseId) async {
    final purchase = await _local.findPurchase(purchaseId);
    if (purchase == null) {
      return;
    }

    await _remote.pushPurchase(purchase);
    await _local.upsertPurchase(
      purchase.copyWith(syncStatus: SyncStatus.synced, syncAttempts: 0),
    );
  }
}

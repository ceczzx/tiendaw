import 'dart:async';

import 'package:tiendaw/features/purchases/data/purchase_repository_impl.dart';
import 'package:tiendaw/features/sales/data/sales_repository_impl.dart';
import 'package:tiendaw/shared/demo/system_w_store.dart';

class SyncTask {
  SyncTask({required this.id, required this.productIds, required this.execute});

  final String id;
  final Set<String> productIds;
  final Future<void> Function() execute;
}

class SyncEngine {
  SyncEngine({
    required SystemWStore store,
    required SalesRepositoryImpl salesRepository,
    required PurchaseRepositoryImpl purchaseRepository,
  }) : _store = store,
       _salesRepository = salesRepository,
       _purchaseRepository = purchaseRepository;

  final SystemWStore _store;
  final SalesRepositoryImpl _salesRepository;
  final PurchaseRepositoryImpl _purchaseRepository;

  Future<void> syncPendingTransactions() async {
    if (!_store.isOnline) {
      return;
    }

    final tasks = <SyncTask>[
      ..._store.pendingSales.map(
        (sale) => SyncTask(
          id: sale.id,
          productIds: sale.items.map((item) => item.productId).toSet(),
          execute: () => _salesRepository.syncSale(sale.id),
        ),
      ),
      ..._store.pendingPurchases.map(
        (purchase) => SyncTask(
          id: purchase.id,
          productIds: purchase.items.map((item) => item.productId).toSet(),
          execute: () => _purchaseRepository.syncPurchase(purchase.id),
        ),
      ),
    ];

    final remainingTasks = [...tasks];

    while (remainingTasks.isNotEmpty) {
      final lockedProducts = <String>{};
      final currentBatch = <SyncTask>[];

      for (final task in List<SyncTask>.from(remainingTasks)) {
        final overlaps = task.productIds.any(lockedProducts.contains);
        if (overlaps) {
          continue;
        }

        currentBatch.add(task);
        lockedProducts.addAll(task.productIds);
      }

      await Future.wait(currentBatch.map((task) => task.execute()));
      remainingTasks.removeWhere(
        (task) => currentBatch.any((batchTask) => batchTask.id == task.id),
      );
    }
  }
}

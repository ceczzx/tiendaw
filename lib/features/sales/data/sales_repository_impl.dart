import 'package:tiendaw/core/sync/sync_status.dart';
import 'package:tiendaw/features/sales/data/sales_sources.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/features/sales/domain/sales_repository.dart';

class SalesRepositoryImpl implements SalesRepository {
  SalesRepositoryImpl({
    required SalesLocalDataSource local,
    required SalesRemoteDataSource remote,
  }) : _local = local,
       _remote = remote;

  final SalesLocalDataSource _local;
  final SalesRemoteDataSource _remote;

  @override
  Future<void> closeShift(String sellerId) async {
    await _remote.closeShift(sellerId);
    final reopenedShift = await _remote.getOpenShift(sellerId);
    await _local.saveOpenShift(sellerId, reopenedShift);
  }

  @override
  Future<CashShift> getOpenShift(String sellerId) async {
    try {
      final shift = await _remote.getOpenShift(sellerId);
      await _local.saveOpenShift(sellerId, shift);
      return shift;
    } catch (_) {
      final cached = await _local.getOpenShift(sellerId);
      if (cached == null) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Future<List<Sale>> getSales() async {
    try {
      final sales = await _remote.getSales();
      await _local.saveSales(sales);
      return sales;
    } catch (_) {
      final cached = await _local.getSales();
      if (cached.isEmpty) {
        rethrow;
      }
      return cached;
    }
  }

  @override
  Future<void> registerSale(Sale sale) async {
    await _remote.pushSale(sale);
    await _local.upsertSale(
      sale.copyWith(syncStatus: SyncStatus.synced, syncAttempts: 0),
    );
  }

  @override
  Future<void> syncSale(String saleId) async {
    final sale = await _local.findSale(saleId);
    if (sale == null) {
      return;
    }

    await _remote.pushSale(sale);
    await _local.upsertSale(
      sale.copyWith(syncStatus: SyncStatus.synced, syncAttempts: 0),
    );
  }
}

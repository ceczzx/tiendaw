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
    await _local.clearOpenShift(sellerId);
  }

  @override
  Future<CashShift?> getOpenShift(String sellerId) async {
    try {
      final shift = await _remote.getOpenShift(sellerId);
      if (shift == null) {
        await _local.clearOpenShift(sellerId);
      } else {
        await _local.saveOpenShift(sellerId, shift);
      }
      return shift;
    } catch (_) {
      return _local.getOpenShift(sellerId);
    }
  }

  @override
  Future<List<CashShift>> getCashShifts() async {
    try {
      final shifts = await _remote.getCashShifts();
      await _local.saveCashShifts(shifts);
      return shifts;
    } catch (_) {
      final cached = await _local.getCashShifts();
      if (cached.isEmpty) {
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
  Future<CashShift> openShift(String sellerId) async {
    final shift = await _remote.openShift(sellerId);
    await _local.saveOpenShift(sellerId, shift);
    return shift;
  }

  @override
  Future<void> registerSale(Sale sale) async {
    final persistedSale = await _remote.pushSale(sale);
    await _local.upsertSale(
      sale.copyWith(
        id: persistedSale.id,
        cashShiftId: persistedSale.cashShiftId,
        syncStatus: SyncStatus.synced,
        syncAttempts: 0,
      ),
    );
  }

  @override
  Future<void> syncSale(String saleId) async {
    final sale = await _local.findSale(saleId);
    if (sale == null) {
      return;
    }

    final persistedSale = await _remote.pushSale(sale);
    await _local.upsertSale(
      sale.copyWith(
        id: persistedSale.id,
        cashShiftId: persistedSale.cashShiftId,
        syncStatus: SyncStatus.synced,
        syncAttempts: 0,
      ),
    );
  }
}

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
  Future<void> closeShift({
    required String sellerId,
    required double closingCash,
    required double closingYape,
    required double closingLatitude,
    required double closingLongitude,
  }) async {
    await _remote.closeShift(
      sellerId: sellerId,
      closingCash: closingCash,
      closingYape: closingYape,
      closingLatitude: closingLatitude,
      closingLongitude: closingLongitude,
    );
    await _local.clearOpenShift(sellerId);
  }

  @override
  Future<void> approveShift({
    required String shiftId,
    required String adminId,
  }) async {
    await _remote.approveShift(shiftId: shiftId, adminId: adminId);
    final shifts = await _remote.getCashShifts();
    await _local.saveCashShifts(shifts);
  }

  @override
  Future<void> rejectShift({
    required String shiftId,
    required String adminId,
    required String rejectionReason,
  }) async {
    await _remote.rejectShift(
      shiftId: shiftId,
      adminId: adminId,
      rejectionReason: rejectionReason,
    );
    final shifts = await _remote.getCashShifts();
    await _local.saveCashShifts(shifts);
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
  Stream<List<CashShift>> watchCashShifts() async* {
    try {
      await for (final shifts in _remote.watchCashShifts()) {
        await _local.saveCashShifts(shifts);
        yield shifts;
      }
    } catch (_) {
      final cached = await _local.getCashShifts();
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
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
  Stream<List<Sale>> watchSales() async* {
    try {
      await for (final sales in _remote.watchSales()) {
        await _local.saveSales(sales);
        yield sales;
      }
    } catch (_) {
      final cached = await _local.getSales();
      if (cached.isNotEmpty) {
        yield cached;
      }
      rethrow;
    }
  }

  @override
  Future<CashShift> openShift({
    required String sellerId,
    required double openingCash,
    required double openingYape,
    required double openingLatitude,
    required double openingLongitude,
  }) async {
    final shift = await _remote.openShift(
      sellerId: sellerId,
      openingCash: openingCash,
      openingYape: openingYape,
      openingLatitude: openingLatitude,
      openingLongitude: openingLongitude,
    );
    await _local.saveOpenShift(sellerId, shift);
    return shift;
  }

  @override
  Stream<CashShift?> watchOpenShift(String sellerId) async* {
    try {
      await for (final shift in _remote.watchOpenShift(sellerId)) {
        if (shift == null) {
          await _local.clearOpenShift(sellerId);
        } else {
          await _local.saveOpenShift(sellerId, shift);
        }
        yield shift;
      }
    } catch (_) {
      yield await _local.getOpenShift(sellerId);
      rethrow;
    }
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

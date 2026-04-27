import 'package:tiendaw/features/sales/data/sales_sources.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/features/sales/domain/sales_repository.dart';
import 'package:tiendaw/shared/demo/system_w_store.dart';

class SalesRepositoryImpl implements SalesRepository {
  SalesRepositoryImpl({
    required SalesLocalDataSource local,
    required SalesRemoteDataSource remote,
    required SystemWStore store,
  }) : _local = local,
       _remote = remote,
       _store = store;

  final SalesLocalDataSource _local;
  final SalesRemoteDataSource _remote;
  final SystemWStore _store;

  @override
  Future<void> closeShift(String sellerId) {
    return _local.closeShift(sellerId);
  }

  @override
  Future<CashShift> getOpenShift() {
    return _local.getOpenShift();
  }

  @override
  Future<List<Sale>> getSales() {
    return _local.getSales();
  }

  @override
  Future<void> registerSale(Sale sale) async {
    await _local.saveSale(sale);

    if (!_store.isOnline) {
      return;
    }

    try {
      await _remote.pushSale(sale);
      await _local.markSaleSynced(sale.id);
    } catch (_) {
      await _local.increaseSyncAttempts(sale.id);
    }
  }

  @override
  Future<void> syncSale(String saleId) async {
    final sale = _store.listSales().firstWhere((item) => item.id == saleId);

    try {
      await _remote.pushSale(sale);
      await _local.markSaleSynced(sale.id);
    } catch (_) {
      await _local.increaseSyncAttempts(sale.id);
    }
  }
}

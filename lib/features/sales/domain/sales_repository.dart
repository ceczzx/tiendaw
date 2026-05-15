import 'package:tiendaw/features/sales/domain/sales_entities.dart';

abstract class SalesRepository {
  Future<void> registerSale(Sale sale);
  Future<List<Sale>> getSales();
  Stream<List<Sale>> watchSales();
  Future<List<CashShift>> getCashShifts();
  Stream<List<CashShift>> watchCashShifts();
  Future<CashShift?> getOpenShift(String sellerId);
  Stream<CashShift?> watchOpenShift(String sellerId);
  Future<CashShift> openShift(String sellerId);
  Future<void> closeShift(String sellerId);
  Future<void> syncSale(String saleId);
}

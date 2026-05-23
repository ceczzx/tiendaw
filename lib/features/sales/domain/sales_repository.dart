import 'package:tiendaw/features/sales/domain/sales_entities.dart';

abstract class SalesRepository {
  Future<void> registerSale(Sale sale);
  Future<List<Sale>> getSales();
  Stream<List<Sale>> watchSales();
  Future<List<CashShift>> getCashShifts();
  Stream<List<CashShift>> watchCashShifts();
  Future<CashShift?> getOpenShift(String sellerId);
  Stream<CashShift?> watchOpenShift(String sellerId);
  Future<CashShift> openShift({
    required String sellerId,
    required double openingAmount,
    required double openingLatitude,
    required double openingLongitude,
  });
  Future<void> closeShift({
    required String sellerId,
    required double cashTotal,
    required double yapeTotal,
    required double closingLatitude,
    required double closingLongitude,
  });
  Future<void> syncSale(String saleId);
}

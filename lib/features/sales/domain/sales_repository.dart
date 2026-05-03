import 'package:tiendaw/features/sales/domain/sales_entities.dart';

abstract class SalesRepository {
  Future<void> registerSale(Sale sale);
  Future<List<Sale>> getSales();
  Future<List<CashShift>> getCashShifts();
  Future<CashShift?> getOpenShift(String sellerId);
  Future<CashShift> openShift(String sellerId);
  Future<void> closeShift(String sellerId);
  Future<void> syncSale(String saleId);
}

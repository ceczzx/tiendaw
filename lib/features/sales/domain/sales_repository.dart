import 'package:tiendaw/features/sales/domain/sales_entities.dart';

abstract class SalesRepository {
  Future<void> registerSale(Sale sale);
  Future<List<Sale>> getSales();
  Future<CashShift> getOpenShift(String sellerId);
  Future<void> closeShift(String sellerId);
  Future<void> syncSale(String saleId);
}

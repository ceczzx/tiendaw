import 'package:tiendaw/features/sales/domain/sales_entities.dart';

abstract class SalesRepository {
  Future<void> registerSale(Sale sale);
  Future<List<Sale>> getSales();
  Stream<List<Sale>> watchSales();
  Future<List<CashShift>> getCashShifts();
  Stream<List<CashShift>> watchCashShifts();
  Future<CashShift?> getOpenShift(String sellerId);
  Stream<CashShift?> watchOpenShift(String sellerId);
  Future<void> deletePendingShiftRequest({
    required String sellerId,
    String? shiftId,
  });
  Future<CashShift> openShift({
    required String sellerId,
    required double openingCash,
    required double openingYape,
    required double openingLatitude,
    required double openingLongitude,
  });
  Future<void> closeShift({
    required String sellerId,
    required double closingCash,
    required double closingYape,
    required double closingLatitude,
    required double closingLongitude,
  });
  Future<void> approveShift({required String shiftId, required String adminId});
  Future<void> rejectShift({
    required String shiftId,
    required String adminId,
    required String rejectionReason,
  });
  Future<void> syncSale(String saleId);
}

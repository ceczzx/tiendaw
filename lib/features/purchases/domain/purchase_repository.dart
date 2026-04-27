import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';

abstract class PurchaseRepository {
  Future<void> registerPurchase(Purchase purchase);
  Future<List<Purchase>> getPurchases();
  Future<void> syncPurchase(String purchaseId);
}

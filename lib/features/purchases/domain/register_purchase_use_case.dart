import 'package:tiendaw/features/purchases/domain/purchase_entities.dart';
import 'package:tiendaw/features/purchases/domain/purchase_repository.dart';

class RegisterPurchaseUseCase {
  const RegisterPurchaseUseCase(this._repository);

  final PurchaseRepository _repository;

  Future<void> call(Purchase purchase) {
    return _repository.registerPurchase(purchase);
  }
}

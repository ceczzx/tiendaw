import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/features/sales/domain/sales_repository.dart';

class CreateSaleUseCase {
  const CreateSaleUseCase(this._repository);

  final SalesRepository _repository;

  Future<void> call(Sale sale) {
    return _repository.registerSale(sale);
  }
}

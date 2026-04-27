import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/domain/auth_repository.dart';

class LoadCurrentUserUseCase {
  const LoadCurrentUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<AppUser?> call() {
    return _repository.getCurrentUser();
  }
}

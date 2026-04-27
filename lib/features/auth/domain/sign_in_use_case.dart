import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/domain/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call({
    required String email,
    required String password,
  }) {
    return _repository.signIn(email: email, password: password);
  }
}

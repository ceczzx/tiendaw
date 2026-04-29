import 'package:tiendaw/features/auth/domain/auth_repository.dart';

class CompleteInvitedUserPasswordUseCase {
  const CompleteInvitedUserPasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String password}) {
    return _repository.updatePassword(password: password);
  }
}

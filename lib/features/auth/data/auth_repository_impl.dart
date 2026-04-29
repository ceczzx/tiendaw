import 'package:tiendaw/features/auth/data/auth_sources.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Future<AppUser?> getCurrentUser() {
    return _remote.getCurrentUser();
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) {
    return _remote.signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() {
    return _remote.signOut();
  }

  @override
  Future<void> updatePassword({required String password}) {
    return _remote.updatePassword(password: password);
  }

  @override
  String? getCurrentAuthEmail() {
    return _remote.getCurrentAuthEmail();
  }

  @override
  bool hasPendingInvitePasswordSetup() {
    return _remote.hasPendingInvitePasswordSetup();
  }
}

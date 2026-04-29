import 'package:tiendaw/features/auth/domain/app_user.dart';

abstract class AuthRepository {
  Future<AppUser?> getCurrentUser();
  Future<AppUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> updatePassword({required String password});
  String? getCurrentAuthEmail();
  bool hasPendingInvitePasswordSetup();
}

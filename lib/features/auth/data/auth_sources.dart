import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<AppUser?> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      return null;
    }

    final profile = await _ensureProfile(authUser);
    return _mapUser(profile);
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);

    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw StateError('Supabase no devolvio una sesion valida.');
    }

    final profile = await _ensureProfile(authUser);
    return _mapUser(profile);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<void> updatePassword({required String password}) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  String? getCurrentAuthEmail() {
    return _client.auth.currentUser?.email;
  }

  bool hasPendingInvitePasswordSetup() {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      return false;
    }

    // Mientras el correo invitado no confirme una contrasena propia,
    // seguimos enviandolo al onboarding separado.
    return authUser.invitedAt != null && authUser.emailConfirmedAt == null;
  }

  Future<Map<String, dynamic>> _ensureProfile(User authUser) async {
    try {
      final currentProfile =
          await _client
              .from('profiles')
              .select('id, full_name, role')
              .eq('id', authUser.id)
              .maybeSingle();

      if (currentProfile != null) {
        return Map<String, dynamic>.from(currentProfile);
      }

      final metadata = authUser.userMetadata ?? const <String, dynamic>{};
      final rawName = metadata['full_name']?.toString().trim();
      final rawRole = metadata['role']?.toString().trim().toLowerCase();

      final inserted =
          await _client
              .from('profiles')
              .upsert({
                'id': authUser.id,
                'full_name':
                    rawName != null && rawName.isNotEmpty
                        ? rawName
                        : _fallbackName(authUser.email),
                'role': rawRole == 'admin' ? 'admin' : 'seller',
              })
              .select('id, full_name, role')
              .maybeSingle();

      if (inserted == null) {
        throw StateError('No se pudo crear el perfil del usuario.');
      }

      return Map<String, dynamic>.from(inserted);
    } on PostgrestException catch (error) {
      throw StateError(_mapProfileError(error));
    }
  }

  AppUser _mapUser(Map<String, dynamic> profile) {
    final role = profile['role'] == 'admin' ? UserRole.admin : UserRole.seller;

    return AppUser(
      id: profile['id'] as String,
      name: profile['full_name'] as String,
      role: role,
    );
  }

  String _fallbackName(String? email) {
    if (email == null || email.isEmpty) {
      return 'Usuario';
    }

    return email.split('@').first.replaceAll('.', ' ').trim();
  }

  String _mapProfileError(PostgrestException error) {
    final rawMessage = error.message.toLowerCase();
    final rawDetails = error.details?.toString().toLowerCase() ?? '';

    if (error.code == '404' ||
        rawMessage.contains('invalid path specified in request url') ||
        rawDetails.contains('invalid path specified in request url')) {
      return 'La app si pudo conectarse a Supabase, pero no encontro la ruta REST de public.profiles. Revisa que SUPABASE_URL sea la URL base del proyecto y que las migraciones esten ejecutadas en ese mismo proyecto.';
    }

    return 'No se pudo leer o crear el perfil del usuario en Supabase: ${error.message}';
  }
}

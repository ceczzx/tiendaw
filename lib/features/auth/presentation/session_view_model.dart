import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiendaw/app/providers.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';

class SessionState {
  const SessionState({
    this.currentUser,
    this.isBusy = false,
    this.errorMessage,
    this.infoMessage,
    this.authEmail,
    this.isOfflineMode = false,
    this.isInviteFlow = false,
    this.isInviteSessionReady = false,
    this.inviteEmail,
  });

  final AppUser? currentUser;
  final bool isBusy;
  final String? errorMessage;
  final String? infoMessage;
  final String? authEmail;
  final bool isOfflineMode;
  final bool isInviteFlow;
  final bool isInviteSessionReady;
  final String? inviteEmail;

  bool get isAuthenticated => currentUser != null;

  SessionState copyWith({
    AppUser? currentUser,
    bool replaceCurrentUser = false,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfoMessage = false,
    String? authEmail,
    bool clearAuthEmail = false,
    bool? isOfflineMode,
    bool? isInviteFlow,
    bool? isInviteSessionReady,
    String? inviteEmail,
    bool clearInviteEmail = false,
  }) {
    return SessionState(
      currentUser:
          replaceCurrentUser ? currentUser : currentUser ?? this.currentUser,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      infoMessage: clearInfoMessage ? null : infoMessage ?? this.infoMessage,
      authEmail: clearAuthEmail ? null : authEmail ?? this.authEmail,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      isInviteFlow: isInviteFlow ?? this.isInviteFlow,
      isInviteSessionReady: isInviteSessionReady ?? this.isInviteSessionReady,
      inviteEmail: clearInviteEmail ? null : inviteEmail ?? this.inviteEmail,
    );
  }
}

final sessionViewModelProvider =
    AsyncNotifierProvider<SessionViewModel, SessionState>(SessionViewModel.new);

class SessionViewModel extends AsyncNotifier<SessionState> {
  static const _offlineSessionMessage =
      'Entraste sin internet. Reconocimos tu sesion guardada, pero necesitas conexion para cargar el sistema.';
  static const _offlineSignInMessage =
      'No pudimos conectarnos a internet. Revisa tu conexion e intenta nuevamente.';
  static const _invalidCredentialsMessage =
      'Correo o contrasena incorrectos. Verifica tus datos e intenta otra vez.';

  // Invitation link deshabilitado temporalmente.
  // static const _inviteCompletedMessage =
  //     'Tu cuenta ya quedo activada. Inicia sesion con tu correo y tu nueva contrasena.';

  StreamSubscription<AuthState>? _authSubscription;
  bool _isSigningOut = false;
  // Invitation link deshabilitado temporalmente.
  // StreamSubscription<Uri>? _inviteLinkSubscription;
  // bool _pendingInviteSuccessMessage = false;

  @override
  Future<SessionState> build() async {
    // Invitation link deshabilitado temporalmente.
    _listenToAuthStateChanges();
    try {
      final currentUser = await ref.read(loadCurrentUserUseCaseProvider)();
      return SessionState(
        currentUser: currentUser,
        authEmail: _resolveAuthEmail(),
      );
    } catch (error) {
      final fallbackUser = _resolveFallbackUser();
      if (fallbackUser != null && _isConnectivityError(error)) {
        return SessionState(
          currentUser: fallbackUser,
          authEmail: _resolveAuthEmail(),
          infoMessage: _offlineSessionMessage,
          isOfflineMode: true,
        );
      }

      return SessionState(errorMessage: _normalizeError(error));
    }
  }

  // Invitation link deshabilitado temporalmente.
  // void _initializeInviteLinkHandling() {
  //   _listenToAuthStateChanges();
  //   _listenToInviteLinks();
  // }

  Future<void> signIn({required String email, required String password}) async {
    final current = state.valueOrNull ?? const SessionState();
    state = AsyncData(
      current.copyWith(isBusy: true, clearError: true, clearInfoMessage: true),
    );

    try {
      final user = await ref
          .read(signInUseCaseProvider)
          .call(email: email, password: password);

      _invalidateFeatureState();
      state = AsyncData(
        SessionState(
          currentUser: user,
          authEmail: _resolveAuthEmail(),
          inviteEmail: ref.read(authRepositoryProvider).getCurrentAuthEmail(),
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          errorMessage: _normalizeError(error),
          replaceCurrentUser: true,
          currentUser: null,
          isOfflineMode: false,
          isInviteFlow: false,
          isInviteSessionReady: false,
          clearAuthEmail: true,
          clearInviteEmail: true,
        ),
      );
    }
  }

  Future<void> completeInvitePassword({required String password}) async {
    final current = state.valueOrNull ?? const SessionState();
    // Invitation link deshabilitado temporalmente.
    state = AsyncData(
      current.copyWith(
        isBusy: false,
        errorMessage:
            'El flujo de invitation link esta deshabilitado temporalmente.',
      ),
    );
  }

  Future<void> signOut() async {
    final current = state.valueOrNull ?? const SessionState();
    state = AsyncData(
      current.copyWith(isBusy: true, clearError: true, clearInfoMessage: true),
    );

    try {
      _isSigningOut = true;
      await ref.read(signOutUseCaseProvider)();
      _invalidateFeatureState();
      state = const AsyncData(SessionState());
    } catch (error) {
      _isSigningOut = false;
      state = AsyncData(
        current.copyWith(isBusy: false, errorMessage: _normalizeError(error)),
      );
    }
  }

  void _listenToAuthStateChanges() {
    _authSubscription?.cancel();
    _authSubscription = ref
        .read(supabaseClientProvider)
        .auth
        .onAuthStateChange
        .listen((data) {
          _debug(
            'Auth event=${data.event.name} sessionUser=${data.session?.user.id} email=${data.session?.user.email}',
          );
          unawaited(_handleAuthStateChange(data));
        });
    ref.onDispose(() => _authSubscription?.cancel());
  }

  // Invitation link deshabilitado temporalmente.
  // void _listenToInviteLinks() { ... }
  // Future<void> _consumeInviteLink(Uri uri) async { ... }

  Future<void> _handleAuthStateChange(AuthState authState) async {
    final current = state.valueOrNull ?? const SessionState();
    final event = authState.event;

    if (event == AuthChangeEvent.signedOut) {
      if (_isSigningOut) {
        _isSigningOut = false;
        _invalidateFeatureState();
        state = const AsyncData(SessionState());
        return;
      }

      final fallbackUser = _resolveFallbackUser(
        currentUser: current.currentUser,
        authUser: authState.session?.user,
      );
      if (fallbackUser != null) {
        state = AsyncData(
          current.copyWith(
            currentUser: fallbackUser,
            replaceCurrentUser: true,
            isBusy: false,
            clearError: true,
            authEmail: _resolveAuthEmail(
              currentAuthEmail: current.authEmail,
              authUser: authState.session?.user,
            ),
            infoMessage: _offlineSessionMessage,
            isOfflineMode: true,
            isInviteFlow: false,
            isInviteSessionReady: false,
            clearInviteEmail: true,
          ),
        );
        return;
      }

      _invalidateFeatureState();
      state = const AsyncData(SessionState());
      return;
    }

    if (!_shouldRefreshSession(event)) {
      _debug('Skipping refresh for event=${event.name}');
      return;
    }

    try {
      // Invitation link deshabilitado temporalmente.
      final currentUser = await ref.read(loadCurrentUserUseCaseProvider)();

      state = AsyncData(
        current.copyWith(
          currentUser: currentUser,
          replaceCurrentUser: true,
          isBusy: false,
          clearError: true,
          clearInfoMessage: true,
          authEmail: _resolveAuthEmail(),
          isOfflineMode: false,
          isInviteFlow: false,
          isInviteSessionReady: false,
          clearInviteEmail: true,
        ),
      );
      _debug('App user loaded after auth event currentUser=${currentUser?.id}');
    } catch (error) {
      _debug('Auth refresh error: $error');
      final fallbackUser = _resolveFallbackUser(
        currentUser: current.currentUser,
        authUser: authState.session?.user,
      );
      if (fallbackUser != null && _isConnectivityError(error)) {
        state = AsyncData(
          current.copyWith(
            currentUser: fallbackUser,
            replaceCurrentUser: true,
            isBusy: false,
            clearError: true,
            authEmail: _resolveAuthEmail(
              currentAuthEmail: current.authEmail,
              authUser: authState.session?.user,
            ),
            infoMessage: _offlineSessionMessage,
            isOfflineMode: true,
          ),
        );
        return;
      }

      state = AsyncData(
        current.copyWith(
          isBusy: false,
          clearInfoMessage: true,
          errorMessage: _normalizeError(error),
          isOfflineMode: false,
        ),
      );
    }
  }

  bool _shouldRefreshSession(AuthChangeEvent event) {
    return event == AuthChangeEvent.initialSession ||
        event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.tokenRefreshed ||
        event == AuthChangeEvent.userUpdated ||
        event == AuthChangeEvent.passwordRecovery;
  }

  // Invitation link deshabilitado temporalmente.
  // bool _hasPendingInvitePasswordSetup() {
  //   return ref.read(authRepositoryProvider).hasPendingInvitePasswordSetup();
  // }

  // bool _hasInviteSession() {
  //   final auth = ref.read(supabaseClientProvider).auth;
  //   return auth.currentSession != null;
  // }

  String _normalizeError(Object error) {
    if (_isInvalidCredentialsError(error)) {
      return _invalidCredentialsMessage;
    }

    if (_isConnectivityError(error)) {
      return _offlineSignInMessage;
    }

    final message = _extractErrorMessage(error);
    if (_looksLikeInvalidCredentialsMessage(message)) {
      return _invalidCredentialsMessage;
    }

    if (_looksLikeConnectivityMessage(message)) {
      return _offlineSignInMessage;
    }

    return message;
  }

  bool _isConnectivityError(Object error) {
    final raw = error.toString().toLowerCase();
    return raw.contains('socketexception') ||
        raw.contains('clientexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('connection closed before full header was received') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('no address associated with hostname');
  }

  bool _isInvalidCredentialsError(Object error) {
    if (error is AuthApiException) {
      final message = error.message.toLowerCase();
      final statusCode = error.statusCode?.toString();
      final code = error.code?.toLowerCase();
      return (statusCode == '400' || code == 'invalid_credentials') &&
          message.contains('invalid login credentials');
    }

    final raw = error.toString().toLowerCase();
    return _looksLikeInvalidCredentialsMessage(raw);
  }

  String _extractErrorMessage(Object error) {
    final message = error.toString().trim();
    final normalized = RegExp(
      r'message:\s*([^,\)]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (normalized != null) {
      return normalized.group(1)?.trim() ?? message;
    }

    return message
        .replaceFirst('AuthApiException(', '')
        .replaceFirst('AuthException(', '')
        .replaceFirst('StateError: ', '')
        .replaceAll(')', '')
        .trim();
  }

  bool _looksLikeConnectivityMessage(String rawMessage) {
    final raw = rawMessage.toLowerCase();
    return raw.contains('socketexception') ||
        raw.contains('clientexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('connection closed before full header was received') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('no address associated with hostname');
  }

  bool _looksLikeInvalidCredentialsMessage(String rawMessage) {
    final raw = rawMessage.toLowerCase();
    return raw.contains('invalid login credentials') ||
        raw.contains('invalid email or password') ||
        raw.contains('email not confirmed') && raw.contains('password');
  }

  AppUser? _resolveFallbackUser({AppUser? currentUser, User? authUser}) {
    return currentUser ?? _buildFallbackUserFromSession(authUser);
  }

  String? _resolveAuthEmail({String? currentAuthEmail, User? authUser}) {
    return currentAuthEmail ??
        authUser?.email?.trim() ??
        ref.read(authRepositoryProvider).getCurrentAuthEmail()?.trim();
  }

  AppUser? _buildFallbackUserFromSession([User? preferredUser]) {
    final auth = ref.read(supabaseClientProvider).auth;
    final authUser = preferredUser ?? auth.currentUser ?? auth.currentSession?.user;
    if (authUser == null) {
      return null;
    }

    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    final rawName = metadata['full_name']?.toString().trim();
    final rawRole =
        metadata['role']?.toString().trim().toLowerCase() ??
        authUser.appMetadata['role']?.toString().trim().toLowerCase();

    return AppUser(
      id: authUser.id,
      name:
          rawName != null && rawName.isNotEmpty
              ? rawName
              : _fallbackName(authUser.email),
      role: rawRole == 'admin' ? UserRole.admin : UserRole.seller,
    );
  }

  String _fallbackName(String? email) {
    if (email == null || email.isEmpty) {
      return 'Usuario';
    }

    return email.split('@').first.replaceAll('.', ' ').trim();
  }

  void _invalidateFeatureState() {
    ref.invalidate(catalogRepositoryProvider);
    ref.invalidate(salesRepositoryProvider);
    ref.invalidate(purchaseRepositoryProvider);
  }

  void _debug(String message) {
    debugPrint('[InviteFlow] $message');
  }
}

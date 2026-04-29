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
    this.isInviteFlow = false,
    this.isInviteSessionReady = false,
    this.inviteEmail,
  });

  final AppUser? currentUser;
  final bool isBusy;
  final String? errorMessage;
  final String? infoMessage;
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
      isInviteFlow: isInviteFlow ?? this.isInviteFlow,
      isInviteSessionReady: isInviteSessionReady ?? this.isInviteSessionReady,
      inviteEmail: clearInviteEmail ? null : inviteEmail ?? this.inviteEmail,
    );
  }
}

final sessionViewModelProvider =
    AsyncNotifierProvider<SessionViewModel, SessionState>(SessionViewModel.new);

class SessionViewModel extends AsyncNotifier<SessionState> {
  // Invitation link deshabilitado temporalmente.
  // static const _inviteCompletedMessage =
  //     'Tu cuenta ya quedo activada. Inicia sesion con tu correo y tu nueva contrasena.';

  StreamSubscription<AuthState>? _authSubscription;
  // Invitation link deshabilitado temporalmente.
  // StreamSubscription<Uri>? _inviteLinkSubscription;
  // bool _pendingInviteSuccessMessage = false;

  @override
  Future<SessionState> build() async {
    // Invitation link deshabilitado temporalmente.
    _listenToAuthStateChanges();
    try {
      final currentUser = await ref.read(loadCurrentUserUseCaseProvider)();
      return SessionState(currentUser: currentUser);
    } catch (error) {
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
          isInviteFlow: false,
          isInviteSessionReady: false,
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
      await ref.read(signOutUseCaseProvider)();
      _invalidateFeatureState();
      state = const AsyncData(SessionState());
    } catch (error) {
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
          unawaited(_handleAuthStateChange(data.event));
        });
    ref.onDispose(() => _authSubscription?.cancel());
  }

  // Invitation link deshabilitado temporalmente.
  // void _listenToInviteLinks() { ... }
  // Future<void> _consumeInviteLink(Uri uri) async { ... }

  Future<void> _handleAuthStateChange(AuthChangeEvent event) async {
    final current = state.valueOrNull ?? const SessionState();

    if (event == AuthChangeEvent.signedOut) {
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
          isInviteFlow: false,
          isInviteSessionReady: false,
          clearInviteEmail: true,
        ),
      );
      _debug('App user loaded after auth event currentUser=${currentUser?.id}');
    } catch (error) {
      _debug('Auth refresh error: $error');
      state = AsyncData(
        current.copyWith(isBusy: false, errorMessage: _normalizeError(error)),
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
    final message = error.toString().trim();
    return message
        .replaceFirst('AuthException(message: ', '')
        .replaceAll(')', '');
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

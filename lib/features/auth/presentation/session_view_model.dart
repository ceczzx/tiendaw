import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/providers.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';

class SessionState {
  const SessionState({
    this.currentUser,
    this.isBusy = false,
    this.errorMessage,
  });

  final AppUser? currentUser;
  final bool isBusy;
  final String? errorMessage;

  bool get isAuthenticated => currentUser != null;

  SessionState copyWith({
    AppUser? currentUser,
    bool replaceCurrentUser = false,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SessionState(
      currentUser:
          replaceCurrentUser ? currentUser : currentUser ?? this.currentUser,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final sessionViewModelProvider =
    AsyncNotifierProvider<SessionViewModel, SessionState>(SessionViewModel.new);

class SessionViewModel extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    try {
      final currentUser = await ref.read(loadCurrentUserUseCaseProvider)();
      return SessionState(currentUser: currentUser);
    } catch (error) {
      return SessionState(errorMessage: _normalizeError(error));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final current = state.valueOrNull ?? const SessionState();
    state = AsyncData(current.copyWith(isBusy: true, clearError: true));

    try {
      final user = await ref
          .read(signInUseCaseProvider)
          .call(email: email, password: password);

      _invalidateFeatureState();
      state = AsyncData(SessionState(currentUser: user));
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          errorMessage: _normalizeError(error),
          replaceCurrentUser: true,
          currentUser: null,
        ),
      );
    }
  }

  Future<void> signOut() async {
    final current = state.valueOrNull ?? const SessionState();
    state = AsyncData(current.copyWith(isBusy: true, clearError: true));

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

  String _normalizeError(Object error) {
    final message = error.toString().trim();
    return message.replaceFirst('AuthException(message: ', '').replaceAll(')', '');
  }

  void _invalidateFeatureState() {
    ref.invalidate(catalogRepositoryProvider);
    ref.invalidate(salesRepositoryProvider);
    ref.invalidate(purchaseRepositoryProvider);
  }
}

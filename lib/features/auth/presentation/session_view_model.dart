import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/providers.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';

class SessionState {
  const SessionState({
    required this.currentUser,
    required this.isOnline,
    required this.pendingSyncCount,
  });

  final AppUser currentUser;
  final bool isOnline;
  final int pendingSyncCount;

  SessionState copyWith({
    AppUser? currentUser,
    bool? isOnline,
    int? pendingSyncCount,
  }) {
    return SessionState(
      currentUser: currentUser ?? this.currentUser,
      isOnline: isOnline ?? this.isOnline,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
    );
  }
}

final sessionViewModelProvider =
    NotifierProvider<SessionViewModel, SessionState>(SessionViewModel.new);

class SessionViewModel extends Notifier<SessionState> {
  @override
  SessionState build() {
    final store = ref.read(systemWStoreProvider);
    return SessionState(
      currentUser: const AppUser(
        id: 'admin-1',
        name: 'Mariana Ruiz',
        role: UserRole.admin,
      ),
      isOnline: store.isOnline,
      pendingSyncCount: store.pendingTransactionsCount,
    );
  }

  Future<void> switchRole(UserRole role) async {
    final nextUser =
        role == UserRole.admin
            ? const AppUser(
              id: 'admin-1',
              name: 'Mariana Ruiz',
              role: UserRole.admin,
            )
            : const AppUser(
              id: 'seller-1',
              name: 'Luis Vega',
              role: UserRole.seller,
            );

    state = state.copyWith(currentUser: nextUser);
  }

  Future<void> toggleOnline(bool value) async {
    final store = ref.read(systemWStoreProvider);
    store.isOnline = value;

    if (value) {
      await ref.read(syncEngineProvider).syncPendingTransactions();
    }

    refreshStatus();
  }

  void refreshStatus() {
    final store = ref.read(systemWStoreProvider);
    state = state.copyWith(
      isOnline: store.isOnline,
      pendingSyncCount: store.pendingTransactionsCount,
    );
  }
}

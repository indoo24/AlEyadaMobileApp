import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_repository.dart';
import 'auth/session_expiry.dart';
import 'auth/token_store.dart';

/// The application's object graph.
///
/// Riverpod throughout — one state approach, as the architecture requires.
/// Overriding [apiClientProvider] or [tokenStoreProvider] is how tests swap in a
/// mock transport without any production code knowing tests exist.

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Depends on nothing, so both the transport and the session layer can hold it
/// without either depending on the other.
final sessionExpiryProvider = Provider<SessionExpiry>((ref) => SessionExpiry());

final apiClientProvider = Provider<ApiClient>((ref) {
  final expiry = ref.watch(sessionExpiryProvider);
  return ApiClient(
    tokens: ref.watch(tokenStoreProvider),
    // Raised only when a refresh was *rejected*. A network failure during refresh
    // is reported as a network error and leaves the session intact.
    onSessionExpired: expiry.signal,
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(
    repository: ref.watch(authRepositoryProvider),
    tokens: ref.watch(tokenStoreProvider),
  );

  final expiry = ref.watch(sessionExpiryProvider);
  void onExpired() => controller.onSessionExpired();
  expiry.addListener(onExpired);
  ref.onDispose(() => expiry.removeListener(onExpired));

  return controller;
});

/// The signed-in user, or null. Most screens want this rather than the whole
/// auth state.
final currentUserProvider = Provider((ref) => ref.watch(authControllerProvider).user);

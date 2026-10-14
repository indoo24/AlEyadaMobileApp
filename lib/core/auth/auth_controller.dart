import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import 'auth_repository.dart';
import 'models.dart';
import 'token_store.dart';

/// How far the app has got in working out who is using it.
enum AuthStatus {
  /// Still reading secure storage / asking `/auth/me/`. Show a splash, not a
  /// login screen: showing "sign in" to someone who is signed in is the most
  /// visible way to get this wrong.
  restoring,

  /// No usable session.
  signedOut,

  authenticated,

  /// A session exists but could not be confirmed because the network is down.
  ///
  /// Deliberately its own state. The user is *not* signed out — their tokens are
  /// intact and the app should let them retry rather than discarding a good
  /// session over a tunnel or a flaky café wifi.
  offlineWithSession,
}

class AuthState {
  const AuthState({required this.status, this.user, this.error});

  final AuthStatus status;
  final Me? user;

  /// Why the last restore/sign-in attempt failed, when it did.
  final ApiException? error;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isRestoring => status == AuthStatus.restoring;

  /// True while a real session exists, even if unconfirmed.
  bool get hasSession =>
      status == AuthStatus.authenticated || status == AuthStatus.offlineWithSession;

  UserRole get role => user?.role ?? UserRole.unknown;

  const AuthState.restoring() : this(status: AuthStatus.restoring);
  const AuthState.signedOut({ApiException? error})
    : this(status: AuthStatus.signedOut, error: error);

  AuthState copyWith({
    AuthStatus? status,
    Me? user,
    ApiException? error,
    bool clearError = false,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Owns the session: restores it at launch, signs in, signs out, and keeps the
/// current user fresh.
///
/// It is the single source of truth for "who is using the app" — every guard and
/// every role-dependent screen reads this rather than keeping its own copy.
class AuthController extends StateNotifier<AuthState> {
  AuthController({required AuthRepository repository, required TokenStore tokens})
    : _repo = repository,
      // A named formal cannot target a private field — named parameters may
      // not begin with an underscore.
      // ignore: prefer_initializing_formals
      _tokens = tokens,
      super(const AuthState.restoring());

  final AuthRepository _repo;
  final TokenStore _tokens;

  /// Whose session ended most recently on this device, until someone signs in
  /// again. The sign-in screens read it before signing in, to decide whether a
  /// `next` destination left behind by that session belongs to the person now
  /// signing in (see `resumeLocation`).
  String? get endedAccountId => _endedAccountId;
  String? _endedAccountId;

  /// Remember the current account as the one whose session is ending.
  void _ending() {
    final id = state.user?.id;
    if (id != null) _endedAccountId = id;
  }

  /// Cold start. Reads persisted tokens, then confirms them with one `/auth/me/`.
  ///
  /// The three outcomes are kept distinct on purpose:
  ///   * no token at all         → signed out
  ///   * token rejected (401)    → signed out, and the tokens are cleared
  ///   * token unverifiable      → offlineWithSession, tokens kept
  Future<void> restore() async {
    await _tokens.load();
    if (!_tokens.hasSession) {
      state = const AuthState.signedOut();
      return;
    }
    try {
      final user = await _repo.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException catch (e) {
      if (e.isAuthFailure) {
        await _tokens.clear();
        state = const AuthState.signedOut();
      } else {
        // Network, timeout or a 5xx. The session is probably fine; say so.
        state = AuthState(status: AuthStatus.offlineWithSession, error: e);
      }
    }
  }

  Future<void> signIn({String? phone, String? email, required String password}) async {
    final result = await _repo.login(phone: phone, email: email, password: password);
    await _tokens.save(access: result.tokens.access, refresh: result.tokens.refresh);
    _endedAccountId = null;
    state = AuthState(status: AuthStatus.authenticated, user: result.user);
  }

  /// Adopt a token pair obtained elsewhere — OTP verification after signup
  /// returns one, which is what makes "verify your phone" also sign you in.
  Future<void> adoptSession(AuthTokens tokens, {Me? user}) async {
    await _tokens.save(access: tokens.access, refresh: tokens.refresh);
    _endedAccountId = null;
    if (user != null) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } else {
      await refreshUser();
    }
  }

  /// Re-read `/auth/me/`. Called after anything that can change role or
  /// application status — notably an approval landing while the app is open.
  Future<void> refreshUser() async {
    if (!_tokens.hasSession) return;
    try {
      final user = await _repo.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException catch (e) {
      if (e.isAuthFailure) {
        await _tokens.clear();
        _ending();
        state = const AuthState.signedOut();
      } else if (state.user != null) {
        // Keep showing what we last knew rather than blanking the UI.
        state = state.copyWith(error: e);
      } else {
        state = AuthState(status: AuthStatus.offlineWithSession, error: e);
      }
    }
  }

  /// Sign out. Tells the backend to blacklist the refresh token, but clears
  /// locally regardless: if the network call fails, the user still expects to be
  /// signed out on this device.
  Future<void> signOut() async {
    final refresh = _tokens.refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _repo.logout(refresh);
      } on ApiException {
        // Already-blacklisted or unreachable. Local cleanup is what matters.
      }
    }
    await _tokens.clear();
    _ending();
    state = const AuthState.signedOut();
  }

  /// Called by the API client when a refresh was genuinely rejected.
  void onSessionExpired() {
    if (state.status == AuthStatus.signedOut) return;
    _ending();
    state = const AuthState.signedOut();
  }

  Future<void> acceptPolicies(List<String> versionIds) async {
    await _repo.acceptConsents(versionIds);
    await refreshUser();
  }

  Future<void> updateProfile(Map<String, dynamic> changes) async {
    final user = await _repo.updateMe(changes);
    state = state.copyWith(status: AuthStatus.authenticated, user: user, clearError: true);
  }
}

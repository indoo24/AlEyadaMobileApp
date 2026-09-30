import 'package:aleyada_mobile/core/api/api_client.dart';
import 'package:aleyada_mobile/core/auth/auth_controller.dart';
import 'package:aleyada_mobile/core/auth/auth_repository.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/auth/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../fixtures/api_fixtures.dart';

/// An in-memory stand-in for secure storage.
///
/// Keystore/Keychain are unavailable in a unit test, and the point under test is
/// the controller's behaviour, not the platform channel.
class FakeTokenStore extends TokenStore {
  FakeTokenStore({String? access, String? refresh}) : _access = access, _refresh = refresh, super();
  // ignore_for_file: prefer_initializing_formals

  String? _access;
  String? _refresh;
  bool cleared = false;

  @override
  String? get accessToken => _access;
  @override
  String? get refreshToken => _refresh;
  @override
  bool get hasSession => (_refresh ?? '').isNotEmpty;

  @override
  Future<void> load() async {}

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> updateTokens({required String access, String? refresh}) async {
    _access = access;
    if (refresh != null) _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    cleared = true;
  }
}

({AuthController controller, DioAdapter adapter, FakeTokenStore store}) _build({String? refresh}) {
  final store = FakeTokenStore(access: refresh == null ? null : 'a', refresh: refresh);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  final adapter = DioAdapter(dio: dio);
  final api = ApiClient(tokens: store, dio: dio);
  return (
    controller: AuthController(repository: AuthRepository(api), tokens: store),
    adapter: adapter,
    store: store,
  );
}

void main() {
  group('cold-start session restoration', () {
    test('no stored token means signed out', () async {
      final h = _build();

      await h.controller.restore();

      expect(h.controller.state.status, AuthStatus.signedOut);
      expect(h.controller.state.user, isNull);
    });

    test('a valid token is confirmed and the user is loaded', () async {
      final h = _build(refresh: 'r');
      h.adapter.onGet('/auth/me/', (s) => s.reply(200, meResponse));

      await h.controller.restore();

      expect(h.controller.state.status, AuthStatus.authenticated);
      expect(h.controller.state.user?.role, UserRole.patient);
      expect(h.controller.state.isAuthenticated, isTrue);
    });

    test('a rejected token signs out AND clears storage', () async {
      final h = _build(refresh: 'r');
      // The call 401s, and the refresh the client then attempts is refused too.
      // Both halves matter: a 401 alone triggers a refresh, and only a refresh
      // that is *rejected* ends the session.
      h.adapter.onGet('/auth/me/', (s) => s.reply(401, notAuthenticatedError));
      h.adapter.onPost(
        '/auth/token/refresh/',
        (s) => s.reply(401, notAuthenticatedError),
        data: Matchers.any,
      );

      await h.controller.restore();

      expect(h.controller.state.status, AuthStatus.signedOut);
      expect(
        h.store.cleared,
        isTrue,
        reason: 'a dead refresh token must not be left on the device',
      );
    });

    test('a network failure keeps the session and says so', () async {
      final h = _build(refresh: 'r');
      h.adapter.onGet(
        '/auth/me/',
        (s) => s.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/auth/me/'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      await h.controller.restore();

      // This is the case the whole distinction exists for: a tunnel is not a
      // logout, and the user must not be made to retype a password.
      expect(h.controller.state.status, AuthStatus.offlineWithSession);
      expect(h.controller.state.hasSession, isTrue);
      expect(h.store.cleared, isFalse, reason: 'the tokens are probably still good');
      expect(h.controller.state.error?.isNetworkFailure, isTrue);
    });
  });

  group('signing in', () {
    test('stores both tokens and adopts the user', () async {
      final h = _build();
      h.adapter.onPost('/auth/login/', (s) => s.reply(200, loginResponse), data: Matchers.any);

      await h.controller.signIn(phone: '01099990001', password: 'x');

      expect(h.controller.state.isAuthenticated, isTrue);
      expect(h.store.accessToken, isNotEmpty);
      expect(
        h.store.refreshToken,
        isNotEmpty,
        reason: 'without the refresh token the session dies in 15 minutes',
      );
    });

    test('adopting a session from OTP verification works without a user object', () async {
      final h = _build();
      h.adapter.onGet('/auth/me/', (s) => s.reply(200, meResponse));

      await h.controller.adoptSession(const AuthTokens(access: 'a', refresh: 'r'));

      expect(h.controller.state.isAuthenticated, isTrue);
      expect(h.store.refreshToken, 'r');
    });
  });

  group('signing out', () {
    test('clears locally even when the server call fails', () async {
      final h = _build(refresh: 'r');
      h.adapter.onPost(
        '/auth/logout/',
        (s) => s.reply(400, {'errors': <dynamic>[]}),
        data: Matchers.any,
      );

      await h.controller.signOut();

      // The user pressed sign out. Whatever the network did, this device is done.
      expect(h.controller.state.status, AuthStatus.signedOut);
      expect(h.store.cleared, isTrue);
    });
  });

  group('a session that expires mid-use', () {
    test('onSessionExpired moves to signed out', () {
      final h = _build(refresh: 'r');

      h.controller.onSessionExpired();

      expect(h.controller.state.status, AuthStatus.signedOut);
    });

    test('refreshUser keeps the last known user on a network blip', () async {
      final h = _build(refresh: 'r');
      h.adapter.onGet('/auth/me/', (s) => s.reply(200, meResponse));
      await h.controller.restore();
      expect(h.controller.state.user, isNotNull);

      // Now the network goes.
      final h2 = h.controller;
      h.adapter.onGet(
        '/auth/me/',
        (s) => s.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/auth/me/'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );
      await h2.refreshUser();

      // Blanking the screen because a refresh failed would be a regression.
      expect(h2.state.user, isNotNull);
      expect(h2.state.error?.isNetworkFailure, isTrue);
    });
  });

  group('role helpers', () {
    test('staff roles are recognised', () {
      expect(UserRole.doctor.isStaff, isTrue);
      expect(UserRole.assistant.isStaff, isTrue);
      expect(UserRole.admin.isStaff, isTrue);
      expect(UserRole.superAdmin.isStaff, isTrue);
      expect(UserRole.patient.isStaff, isFalse);
    });

    test('an applicant is not an active doctor', () {
      final me = Me.fromJson((meApplicantResponse['data'] as Map).cast<String, dynamic>());
      expect(me.isActiveDoctor, isFalse, reason: 'role is patient until an admin approves them');
      expect(me.hasOpenApplication, isTrue);
    });
  });
}

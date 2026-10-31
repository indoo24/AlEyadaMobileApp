import 'dart:async';

import 'package:aleyada_mobile/core/api/api_error.dart';
import 'package:aleyada_mobile/core/auth/auth_controller.dart';
import 'package:aleyada_mobile/core/auth/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/management_fixtures.dart' show envelope;
import '../widget/harness.dart';

/// A server whose access tokens rotate: only the newest one is accepted.
class _RotatingServer {
  _RotatingServer(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) async {
          Response<dynamic> reply(Object? body, [int status = 200]) =>
              Response(requestOptions: o, statusCode: status, data: body);
          calls.add(o.path);
          if (o.path == '/auth/token/refresh/') {
            refreshes.add((o.data as Map)['refresh'] as String);
            final gate = refreshGate;
            if (gate != null) await gate.future;
            final failure = refreshFailure;
            if (failure != null) return handler.reject(failure(o), true);
            final body = refreshBody;
            if (body != null) return handler.resolve(reply(body));
            generation++;
            return handler.resolve(
              reply(envelope({'access': 'access-$generation', 'refresh': 'refresh-$generation'})),
            );
          }
          final gate = gates[o.path];
          if (gate != null) await gate.future;
          final failure = pathFailures[o.path];
          if (failure != null) return handler.reject(failure(o), true);
          if (openReplies.containsKey(o.path)) {
            return handler.resolve(reply(envelope(openReplies[o.path])));
          }
          if (rejectAlways.contains(o.path) ||
              o.headers['Authorization'] != 'Bearer access-$generation') {
            return handler.reject(
              DioException.badResponse(
                statusCode: 401,
                requestOptions: o,
                response: reply({
                  'data': null,
                  'meta': {},
                  'errors': [
                    {'code': 'token_not_valid', 'detail': 'expired', 'field': null},
                  ],
                }, 401),
              ),
              true,
            );
          }
          return handler.resolve(reply(envelope({'path': o.path})));
        },
      ),
    );
  }

  /// The harness starts every session with the access token `access`.
  int generation = 0;
  final refreshes = <String>[];
  final calls = <String>[];
  final gates = <String, Completer<void>>{};

  /// Paths that answer 401 whatever token they carry.
  final rejectAlways = <String>{};

  /// Paths that answer this `data` whatever token they carry (sign-in, sign-out).
  final openReplies = <String, Object?>{};

  /// Paths that fail this way (a timeout, no connection) whatever they carry.
  final pathFailures = <String, DioException Function(RequestOptions o)>{};

  /// Held until completed, so a test can line requests up behind one refresh.
  Completer<void>? refreshGate;

  /// How the refresh fails, when it does.
  DioException Function(RequestOptions o)? refreshFailure;

  /// A 200 the refresh answers with instead of a token pair.
  Object? refreshBody;

  int callsTo(String path) => calls.where((p) => p == path).length;
}

/// The refresh endpoint answering [status], with the backend's [code] if given.
DioException Function(RequestOptions) _answers(
  int status, {
  String? code,
  Map<String, List<String>> headers = const {},
}) =>
    (o) => DioException.badResponse(
      statusCode: status,
      requestOptions: o,
      response: Response(
        requestOptions: o,
        statusCode: status,
        headers: Headers.fromMap(headers),
        data: {
          'data': null,
          'meta': <String, dynamic>{},
          'errors': [
            if (code != null) {'code': code, 'detail': 'refresh refused: $code', 'field': null},
          ],
        },
      ),
    );

/// The refresh never reaching the server.
DioException Function(RequestOptions) _transport(DioExceptionType type) =>
    (o) => DioException(requestOptions: o, type: type);

/// The [ApiException] [call] fails with. Fails the test if it succeeds.
Future<ApiException> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ApiException catch (e) {
    return e;
  }
  fail('expected the call to fail');
}

/// Let queued requests reach the refresh they are waiting on.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late TestHarness h;
  late _RotatingServer server;
  late int expired;
  late DateTime now;

  setUp(() {
    expired = 0;
    now = DateTime.utc(2026, 10, 26, 12);
    h = TestHarness(refreshToken: 'refresh-0', onSessionExpired: () => expired++, clock: () => now);
    server = _RotatingServer(h.dio);
    server.generation = -1; // nothing the harness holds is current: `access` is expired
  });

  test('one expired request refreshes once and is replayed', () async {
    final body = await h.client.get('/one/');
    expect(body, isNotNull);
    expect(server.refreshes, ['refresh-0']);
    expect(h.store.accessToken, 'access-0');
  });

  test('a request that was sent with a token an earlier refresh already replaced '
      'is replayed with the new one, without a second refresh', () async {
    // /late/ leaves with the old token but its 401 only comes back after /early/
    // has refreshed and been replayed.
    server.gates['/late/'] = Completer<void>();
    final late = h.client.get('/late/');
    await h.client.get('/early/');
    expect(server.refreshes, ['refresh-0']);

    server.gates['/late/']!.complete();
    await late;
    expect(server.refreshes, ['refresh-0'], reason: 'the session is not rotated twice');
    expect(h.store.refreshToken, 'refresh-0');
  });

  test('concurrent 401s still share one refresh', () async {
    await Future.wait([h.client.get('/a/'), h.client.get('/b/'), h.client.get('/c/')]);
    expect(server.refreshes, hasLength(1));
  });

  test('a token that is still the current one is refreshed as before', () async {
    await h.client.get('/one/');
    // The server moves on (another device, an admin revoking it…).
    server.generation = 5;
    await h.client.get('/two/');
    expect(server.refreshes, hasLength(2));
  });

  group('a refused refresh token ends the session', () {
    test('401 token_not_valid: cleared, reported once, the caller told to sign in', () async {
      server.refreshFailure = _answers(401, code: 'token_not_valid');

      final e = await _failureOf(h.client.get('/one/'));

      expect(e.isAuthFailure, isTrue);
      expect(h.store.hasSession, isFalse);
      expect(h.store.accessToken, isNull);
      expect(expired, 1);
      expect(server.refreshes, hasLength(1));
      expect(server.callsTo('/one/'), 1, reason: 'nothing is replayed without a token');
    });

    test(
      'a 401 without a code is a refusal too: the endpoint is sent no other credential',
      () async {
        server.refreshFailure = _answers(401);

        final e = await _failureOf(h.client.get('/one/'));

        expect(e.isAuthFailure, isTrue);
        expect(h.store.hasSession, isFalse);
        expect(expired, 1);
      },
    );

    test('token_not_valid on another 4xx is a refusal', () async {
      server.refreshFailure = _answers(400, code: 'token_not_valid');

      final e = await _failureOf(h.client.get('/one/'));

      expect(e.isAuthFailure, isTrue);
      expect(h.store.hasSession, isFalse);
      expect(expired, 1);
    });

    test('requests waiting on the refused refresh all fail, and the session ends once', () async {
      server.refreshFailure = _answers(401, code: 'token_not_valid');

      final failures = await Future.wait([
        _failureOf(h.client.get('/a/')),
        _failureOf(h.client.get('/b/')),
        _failureOf(h.client.get('/c/')),
      ]);

      expect(failures.every((e) => e.isAuthFailure), isTrue);
      expect(server.refreshes, hasLength(1));
      expect(expired, 1);
    });

    test('a sign-in made while the refresh was out is not cleared by its refusal', () async {
      server.refreshGate = Completer<void>();
      server.refreshFailure = _answers(401, code: 'token_not_valid');
      final pending = _failureOf(h.client.get('/one/'));
      await _settle();

      await h.store.save(access: 'access-new', refresh: 'refresh-new');
      server.refreshGate!.complete();
      final e = await pending;

      expect(e.failure, ApiFailure.sessionChanged, reason: 'that request was the old session\'s');
      expect(e.isAuthFailure, isFalse, reason: 'nothing may read it as the new session ending');
      expect(h.store.refreshToken, 'refresh-new');
      expect(expired, 0);
    });
  });

  group('a refresh that fails for any other reason keeps the session', () {
    void expectSessionKept() {
      expect(h.store.refreshToken, 'refresh-0');
      expect(h.store.accessToken, 'access', reason: 'nothing was overwritten either');
      expect(expired, 0);
    }

    for (final status in [500, 502, 503, 504]) {
      test('$status: a server failure, reported as one, and not retried', () async {
        server.refreshFailure = _answers(status);

        final e = await _failureOf(h.client.get('/one/'));

        expect(e.failure, ApiFailure.server);
        expect(e.isAuthFailure, isFalse);
        expectSessionKept();
        expect(server.refreshes, hasLength(1));
        expect(server.callsTo('/one/'), 1, reason: 'no replay without a new token');
      });
    }

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('${type.name}: a network failure, and the session survives it', () async {
        server.refreshFailure = _transport(type);

        final e = await _failureOf(h.client.get('/one/'));

        expect(e.isNetworkFailure, isTrue);
        expectSessionKept();
        expect(server.refreshes, hasLength(1));
      });
    }

    test('429 with Retry-After: throttled, and no refresh is sent until it has passed', () async {
      server.refreshFailure = _answers(
        429,
        code: 'throttled',
        headers: {
          'retry-after': ['30'],
        },
      );

      final first = await _failureOf(h.client.get('/one/'));
      expect(first.failure, ApiFailure.rateLimited);
      expectSessionKept();

      // Still inside the window: refused here, without asking the server again.
      now = now.add(const Duration(seconds: 29));
      final second = await _failureOf(h.client.get('/two/'));
      expect(second.failure, ApiFailure.rateLimited);
      expect(server.refreshes, hasLength(1));
      expectSessionKept();

      // The window has passed and the server has recovered.
      now = now.add(const Duration(seconds: 2));
      server.refreshFailure = null;
      await h.client.get('/three/');
      expect(server.refreshes, hasLength(2));
      expect(h.store.refreshToken, 'refresh-0');
      expect(h.store.accessToken, 'access-0');
    });

    test('429 without Retry-After: no wait is invented, the next request may try once', () async {
      server.refreshFailure = _answers(429, code: 'throttled');

      final first = await _failureOf(h.client.get('/one/'));
      final second = await _failureOf(h.client.get('/two/'));

      expect(first.failure, ApiFailure.rateLimited);
      expect(second.failure, ApiFailure.rateLimited);
      expect(server.refreshes, hasLength(2), reason: 'one attempt per request, never a loop');
      expectSessionKept();
    });

    test('a hold set for one session does not apply to the next one signed in', () async {
      server.refreshFailure = _answers(
        429,
        headers: {
          'retry-after': ['600'],
        },
      );
      await _failureOf(h.client.get('/one/'));

      await h.store.save(access: 'access', refresh: 'refresh-other');
      server.refreshFailure = null;
      await h.client.get('/two/');

      expect(server.refreshes, ['refresh-0', 'refresh-other']);
    });

    for (final status in [403, 404, 400]) {
      test('$status from in front of the endpoint: unexpected, without its prose', () async {
        server.refreshFailure = _answers(status, code: 'some_proxy_code');

        final e = await _failureOf(h.client.get('/one/'));

        expect(e.failure, ApiFailure.unexpected);
        expect(e.errors, isEmpty, reason: 'the refresh\'s message is not about this request');
        expectSessionKept();
      });
    }

    test('a 200 that is not a token pair (a captive portal) changes nothing', () async {
      server.refreshBody = '<html>Sign in to the Wi-Fi</html>';

      final e = await _failureOf(h.client.get('/one/'));

      expect(e.failure, ApiFailure.unexpected);
      expectSessionKept();
    });

    test('requests waiting on a failing refresh are all released, then the next one '
        'refreshes afresh', () async {
      server.refreshGate = Completer<void>();
      final pending = [
        _failureOf(h.client.get('/a/')),
        _failureOf(h.client.get('/b/')),
        _failureOf(h.client.get('/c/')),
      ];
      await _settle();
      expect(server.refreshes, hasLength(1), reason: 'three 401s, one refresh in flight');

      server.refreshFailure = _answers(503);
      server.refreshGate!.complete();
      final failures = await Future.wait(pending);
      expect(failures.every((e) => e.failure == ApiFailure.server), isTrue);
      expectSessionKept();

      // Nothing is left holding the failed refresh: a later request starts its own.
      server.refreshGate = null;
      server.refreshFailure = null;
      await h.client.get('/d/');
      expect(server.refreshes, hasLength(2));
    });
  });

  test(
    'a request still refused after a successful refresh is replayed once, never again',
    () async {
      server.rejectAlways.add('/stubborn/');

      final e = await _failureOf(h.client.get('/stubborn/'));

      expect(e.isAuthFailure, isTrue);
      expect(server.refreshes, hasLength(1));
      expect(server.callsTo('/stubborn/'), 2, reason: 'the original and one replay');
      expect(h.store.hasSession, isTrue, reason: 'the refresh itself was accepted');
      expect(expired, 0);
    },
  );

  group('a session that ends while its refresh is out', () {
    /// Starts [count] requests that 401 and wait on one held refresh.
    Future<List<Future<ApiException>>> waitingOnRefresh({int count = 1}) async {
      server.refreshGate = Completer<void>();
      final pending = [for (var i = 0; i < count; i++) _failureOf(h.client.get('/r$i/'))];
      await _settle();
      expect(server.refreshes, ['refresh-0'], reason: 'one refresh, in flight');
      return pending;
    }

    test('signed out, then the refresh succeeds: its tokens are dropped', () async {
      final pending = await waitingOnRefresh();

      await h.store.clear();
      server.refreshGate!.complete();
      final e = await pending.single;

      expect(e.failure, ApiFailure.sessionChanged);
      expect(h.store.refreshToken, isNull, reason: 'the signed-out session is not restored');
      expect(h.store.accessToken, isNull);
      expect(h.store.hasSession, isFalse);
      expect(server.callsTo('/r0/'), 1, reason: 'nothing is replayed after sign-out');
      expect(expired, 0, reason: 'sign-out already ended it; nothing more to report');
    });

    for (final (name, failure) in [
      ('a refusal', _answers(401, code: 'token_not_valid')),
      ('a 5xx', _answers(503)),
      ('a throttle', _answers(429)),
      ('no connection', _transport(DioExceptionType.connectionError)),
    ]) {
      test('signed out, then the refresh fails with $name: nothing is written', () async {
        final pending = await waitingOnRefresh();

        await h.store.clear();
        server.refreshFailure = failure;
        server.refreshGate!.complete();
        final e = await pending.single;

        expect(e.failure, ApiFailure.sessionChanged, reason: 'whatever the refresh said');
        expect(h.store.refreshToken, isNull);
        expect(h.store.accessToken, isNull);
        expect(server.callsTo('/r0/'), 1);
        expect(expired, 0);
      });
    }

    test('another account signs in, then the old refresh succeeds: the new account keeps '
        'its tokens and no request is replayed with them', () async {
      final pending = await waitingOnRefresh(count: 3);

      await h.store.save(access: 'access-b', refresh: 'refresh-b');
      server.refreshGate!.complete();
      final failures = await Future.wait(pending);

      expect(failures.every((e) => e.failure == ApiFailure.sessionChanged), isTrue);
      expect(h.store.accessToken, 'access-b');
      expect(h.store.refreshToken, 'refresh-b');
      for (var i = 0; i < 3; i++) {
        expect(server.callsTo('/r$i/'), 1, reason: 'the old account\'s request is not sent as B');
      }
      expect(expired, 0);

      // Nothing is left holding the dropped refresh: B's own refresh, when it
      // needs one, presents B's token.
      server.refreshGate = null;
      await h.client.get('/b/');
      expect(server.refreshes, ['refresh-0', 'refresh-b']);
      expect(h.store.refreshToken, isNot('refresh-0'));
    });

    test('another account signs in, then the old refresh fails with a 5xx: '
        'the new account is untouched', () async {
      final pending = await waitingOnRefresh();

      await h.store.save(access: 'access-b', refresh: 'refresh-b');
      server.refreshFailure = _answers(503);
      server.refreshGate!.complete();
      final e = await pending.single;

      expect(e.failure, ApiFailure.sessionChanged);
      expect(h.store.accessToken, 'access-b');
      expect(h.store.refreshToken, 'refresh-b');
      expect(expired, 0);
    });
  });

  group('a request is only ever replayed under the session that sent it', () {
    /// Account A's requests, held at the server so their 401s come back later.
    List<Future<ApiException>> sentByA(List<String> paths) {
      for (final p in paths) {
        server.gates[p] = Completer<void>();
      }
      return [for (final p in paths) _failureOf(h.client.get(p))];
    }

    void release(List<String> paths) {
      for (final p in paths) {
        server.gates[p]!.complete();
      }
    }

    test('A signs out and B signs in before A\'s 401 arrives: not refreshed, not replayed '
        'as B, and B untouched', () async {
      final pending = sentByA(['/a/']);
      await _settle();

      await h.store.clear();
      await h.store.save(access: 'access-b', refresh: 'refresh-b');
      release(['/a/']);
      final e = await pending.single;

      expect(e.failure, ApiFailure.sessionChanged);
      expect(e.isAuthFailure, isFalse);
      expect(server.callsTo('/a/'), 1, reason: 'never sent again, least of all with B\'s token');
      expect(server.refreshes, isEmpty, reason: 'B\'s refresh token is not spent on A');
      expect(h.store.accessToken, 'access-b');
      expect(h.store.refreshToken, 'refresh-b');
      expect(expired, 0);
    });

    test('A\'s 401 arrives while B\'s sign-in is still in progress: nothing is refreshed, '
        'replayed or written, and B\'s sign-in lands intact', () async {
      final pending = sentByA(['/a/']);
      await _settle();
      await h.store.clear(); // A signs out; B's sign-in has not answered yet.

      release(['/a/']);
      final e = await pending.single;
      await h.store.save(access: 'access-b', refresh: 'refresh-b'); // B's sign-in answers.

      expect(e.failure, ApiFailure.sessionChanged);
      expect(server.callsTo('/a/'), 1);
      expect(server.refreshes, isEmpty);
      expect(h.store.accessToken, 'access-b');
      expect(h.store.refreshToken, 'refresh-b');
      expect(expired, 0);
    });

    test('concurrent 401s for A and B: A\'s are refused, B\'s refreshes with B\'s own token '
        'and is replayed — no request ever carries the other account\'s credentials', () async {
      final a = sentByA(['/a0/', '/a1/', '/a2/']);
      await _settle();
      await h.store.clear();
      await h.store.save(access: 'access-b', refresh: 'refresh-b');
      server.generation = 10; // B's access token is already stale too.

      final b = h.client.get('/b/');
      release(['/a0/', '/a1/', '/a2/']);
      final failures = await Future.wait(a);
      await b;

      expect(failures.every((e) => e.failure == ApiFailure.sessionChanged), isTrue);
      for (final p in ['/a0/', '/a1/', '/a2/']) {
        expect(server.callsTo(p), 1);
      }
      expect(server.refreshes, ['refresh-b'], reason: 'one refresh, B\'s, for B\'s request');
      expect(server.callsTo('/b/'), 2, reason: 'B\'s own request: the original and one replay');
      expect(h.store.refreshToken, 'refresh-11');
      expect(h.store.accessToken, 'access-11');
      expect(expired, 0);
    });

    test('an unchanged session across two rotations still refreshes and replays: a request '
        'that left before the second rotation is replayed with the newest token', () async {
      await h.client.get('/one/'); // rotation 1
      server.generation = 5; // the server moves on

      server.gates['/late/'] = Completer<void>();
      final late = h.client.get('/late/');
      await _settle();
      await h.client.get('/early/'); // rotation 2
      server.gates['/late/']!.complete();
      await late;

      expect(server.refreshes, hasLength(2), reason: 'the late request needed no third');
      expect(server.callsTo('/late/'), 2, reason: 'the original and one replay');
      expect(h.store.accessToken, 'access-6');
    });

    group('through the session controller', () {
      late AuthController auth;

      setUp(() {
        auth = AuthController(repository: AuthRepository(h.client), tokens: h.store);
        server.openReplies['/auth/logout/'] = null;
        server.openReplies['/auth/login/'] = {
          'access': 'access-b',
          'refresh': 'refresh-b',
          'user': {'id': 'user-b', 'role': 'patient', 'phone': '+201000000002'},
        };
      });

      test('A\'s profile reload gets its 401 after B signed in: B stays signed in', () async {
        server.gates['/auth/me/'] = Completer<void>();
        final reloading = auth.refreshUser(); // A's, e.g. from opening the booking sheet
        await _settle();

        await auth.signOut();
        await auth.signIn(phone: '+201000000002', password: 'pw');
        server.gates['/auth/me/']!.complete();
        await reloading;

        expect(auth.state.status, AuthStatus.authenticated);
        expect(auth.state.user?.id, 'user-b');
        expect(h.store.accessToken, 'access-b');
        expect(h.store.refreshToken, 'refresh-b');
        expect(server.callsTo('/auth/me/'), 1, reason: 'not replayed with B\'s token');
        expect(server.refreshes, isEmpty);
      });

      test('A\'s profile reload gets its 401 while B is signing in: B\'s sign-in lands '
          'intact', () async {
        server.gates['/auth/me/'] = Completer<void>();
        final reloading = auth.refreshUser();
        await _settle();
        await auth.signOut();

        server.gates['/auth/login/'] = Completer<void>();
        final signingIn = auth.signIn(phone: '+201000000002', password: 'pw');
        await _settle();
        server.gates['/auth/me/']!.complete();
        await reloading;
        server.gates['/auth/login/']!.complete();
        await signingIn;

        expect(auth.state.status, AuthStatus.authenticated);
        expect(auth.state.user?.id, 'user-b');
        expect(h.store.accessToken, 'access-b');
        expect(h.store.refreshToken, 'refresh-b');
        expect(server.callsTo('/auth/me/'), 1);
        expect(server.refreshes, isEmpty);
      });
    });
  });

  group('a profile answer is only applied to the session that asked for it', () {
    late AuthController auth;
    const userA = {'id': 'user-a', 'role': 'patient', 'phone': '+201000000001'};
    const userB = {'id': 'user-b', 'role': 'patient', 'phone': '+201000000002'};

    Future<void> signInAs(Map<String, Object> user, String tag) async {
      server.openReplies['/auth/login/'] = {
        'access': 'access-$tag',
        'refresh': 'refresh-$tag',
        'user': user,
      };
      await auth.signIn(phone: user['phone']! as String, password: 'pw');
    }

    /// A's reload of `/auth/me/`, held at the server until [release].
    Future<void> reloadAsA() async {
      server.gates['/auth/me/'] = Completer<void>();
      final reloading = auth.refreshUser();
      await _settle();
      return reloading;
    }

    void release() => server.gates['/auth/me/']!.complete();

    void expectB() {
      expect(auth.state.status, AuthStatus.authenticated);
      expect(auth.state.user?.id, 'user-b');
      expect(auth.state.error, isNull, reason: 'A\'s outcome is not recorded on B\'s state');
      expect(h.store.accessToken, 'access-b');
      expect(h.store.refreshToken, 'refresh-b');
    }

    setUp(() async {
      auth = AuthController(repository: AuthRepository(h.client), tokens: h.store);
      server.openReplies['/auth/logout/'] = null;
      await signInAs(userA, 'a');
      expect(auth.state.user?.id, 'user-a');
    });

    test('A\'s reload succeeds after B signed in: B\'s profile stays', () async {
      server.openReplies['/auth/me/'] = {...userA, 'first_name': 'Late'};
      final reloading = reloadAsA();

      await auth.signOut();
      await signInAs(userB, 'b');
      release();
      await reloading;

      expectB();
    });

    test('A\'s reload fails on the network after B signed in: B stays authenticated', () async {
      server.pathFailures['/auth/me/'] = _transport(DioExceptionType.connectionError);
      final reloading = reloadAsA();

      await auth.signOut();
      await signInAs(userB, 'b');
      release();
      await reloading;

      expectB();
    });

    test('A\'s reload fails on the network after A signed out: still signed out, '
        'not "offline with a session"', () async {
      server.pathFailures['/auth/me/'] = _transport(DioExceptionType.receiveTimeout);
      final reloading = reloadAsA();

      await auth.signOut();
      release();
      await reloading;

      expect(auth.state.status, AuthStatus.signedOut);
      expect(auth.state.hasSession, isFalse);
      expect(auth.state.user, isNull);
    });

    for (final (name, arrange) in [
      ('succeeds', () => server.openReplies['/auth/me/'] = userA),
      (
        'fails on the network',
        () => server.pathFailures['/auth/me/'] = _transport(DioExceptionType.connectionError),
      ),
    ]) {
      test('A\'s reload $name while B is still signing in: nothing is shown for A, and B\'s '
          'sign-in lands intact', () async {
        arrange();
        final reloading = reloadAsA();
        await auth.signOut();

        server.gates['/auth/login/'] = Completer<void>();
        server.openReplies['/auth/login/'] = {
          'access': 'access-b',
          'refresh': 'refresh-b',
          'user': userB,
        };
        final signingIn = auth.signIn(phone: userB['phone']!, password: 'pw');
        await _settle();

        release();
        await reloading;
        expect(auth.state.status, AuthStatus.signedOut, reason: 'not A, and not offline');
        expect(auth.state.user, isNull);

        server.gates['/auth/login/']!.complete();
        await signingIn;
        expectB();
      });
    }

    test('A\'s profile save completes after B signed in: B\'s profile stays', () async {
      server.openReplies['/auth/me/'] = {...userA, 'first_name': 'Saved'};
      server.gates['/auth/me/'] = Completer<void>();
      final saving = auth.updateProfile({'first_name': 'Saved'});
      await _settle();

      await auth.signOut();
      await signInAs(userB, 'b');
      release();
      await saving;

      expectB();
    });

    group('the same session throughout', () {
      test('a reload\'s answer is applied', () async {
        server.openReplies['/auth/me/'] = {...userA, 'first_name': 'Ahmed'};

        await auth.refreshUser();

        expect(auth.state.status, AuthStatus.authenticated);
        expect(auth.state.user?.firstName, 'Ahmed');
      });

      test('a network failure keeps the user and records the error', () async {
        server.pathFailures['/auth/me/'] = _transport(DioExceptionType.connectionError);

        await auth.refreshUser();

        expect(auth.state.status, AuthStatus.authenticated);
        expect(auth.state.user?.id, 'user-a');
        expect(auth.state.error?.isNetworkFailure, isTrue);
        expect(h.store.refreshToken, 'refresh-a');
      });

      test('a token refresh in the middle of the reload is still the same session: '
          'the answer is applied', () async {
        // `/auth/me/` is not answered openly here: A's access token is stale, so
        // the call 401s, refreshes, and is replayed with the rotated token.
        await auth.refreshUser();

        expect(server.refreshes, ['refresh-a']);
        expect(server.callsTo('/auth/me/'), 2);
        expect(auth.state.status, AuthStatus.authenticated);
        expect(auth.state.user?.id, '', reason: 'the replayed answer, applied');
        expect(h.store.refreshToken, 'refresh-0');
      });

      test('a refused refresh during the reload still signs out', () async {
        server.refreshFailure = _answers(401, code: 'token_not_valid');

        await auth.refreshUser();

        expect(auth.state.status, AuthStatus.signedOut);
        expect(h.store.hasSession, isFalse);
        expect(expired, 1);
      });
    });
  });
}

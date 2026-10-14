import 'dart:async';

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
          if (o.path == '/auth/token/refresh/') {
            refreshes.add((o.data as Map)['refresh'] as String);
            generation++;
            return handler.resolve(
              reply(envelope({'access': 'access-$generation', 'refresh': 'refresh-$generation'})),
            );
          }
          final gate = gates[o.path];
          if (gate != null) await gate.future;
          if (o.headers['Authorization'] != 'Bearer access-$generation') {
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
  final gates = <String, Completer<void>>{};
}

void main() {
  late TestHarness h;
  late _RotatingServer server;

  setUp(() {
    h = TestHarness(refreshToken: 'refresh-0');
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
}

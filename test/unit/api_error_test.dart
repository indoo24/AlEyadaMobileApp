import 'package:aleyada_mobile/core/api/api_error.dart';
import 'package:aleyada_mobile/core/errors/error_messages.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_fixtures.dart';

DioException _http(int status, Object body) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: body,
  ),
  type: DioExceptionType.badResponse,
);

DioException _transport(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
);

void main() {
  group('classifying failures', () {
    test('401 is an auth failure', () {
      final e = ApiException.fromDio(_http(401, notAuthenticatedError));

      expect(e.failure, ApiFailure.unauthenticated);
      expect(e.isAuthFailure, isTrue);
      expect(e.code, 'not_authenticated');
    });

    test('403 is not an auth failure — signing in again would not help', () {
      final e = ApiException.fromDio(
        _http(403, {
          'data': null,
          'meta': <String, dynamic>{},
          'errors': [
            {'code': 'permission_denied', 'detail': 'no', 'field': null},
          ],
        }),
      );

      expect(e.failure, ApiFailure.forbidden);
      expect(e.isAuthFailure, isFalse);
    });

    test('a timeout is a network failure and NOT a logout', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.connectionError,
      ]) {
        final e = ApiException.fromDio(_transport(type));

        expect(e.isNetworkFailure, isTrue, reason: '$type');
        // This is the distinction that keeps a tunnel from signing people out.
        expect(e.isAuthFailure, isFalse, reason: '$type');
        expect(e.isRetryable, isTrue, reason: '$type');
      }
    });

    test('400 is a validation failure with field attribution', () {
      final e = ApiException.fromDio(_http(400, cityNotAllowedError));

      expect(e.failure, ApiFailure.validation);
      expect(e.fieldErrors.keys, containsAll(['city', 'password']));
      expect(e.fieldErrors['city'], contains('not registering doctors'));
      expect(e.generalErrors, isEmpty);
    });

    test('a non-field error lands in generalErrors', () {
      final e = ApiException.fromDio(_http(400, invalidCredentialsError));

      expect(e.fieldErrors, isEmpty);
      expect(e.generalErrors, hasLength(1));
      expect(e.code, 'invalid_credentials');
    });

    test('429 is rate limiting, and is not retried automatically', () {
      final e = ApiException.fromDio(_http(429, throttledError));

      expect(e.failure, ApiFailure.rateLimited);
      expect(e.isRetryable, isFalse, reason: 'hammering a throttle makes it worse');
    });

    test('5xx is a server failure and is retryable', () {
      final e = ApiException.fromDio(_http(503, {'errors': <dynamic>[]}));

      expect(e.failure, ApiFailure.server);
      expect(e.isRetryable, isTrue);
    });

    test('a body that is not an envelope does not crash the parser', () {
      final e = ApiException.fromDio(_http(502, '<html>bad gateway</html>'));

      expect(e.errors, isEmpty);
      expect(e.code, 'server_error');
    });

    test('hasCode finds a code anywhere in the list', () {
      final e = ApiException.fromDio(_http(400, cityNotAllowedError));
      expect(e.hasCode('required'), isTrue);
      expect(e.hasCode('nope'), isFalse);
    });
  });

  group('booking errors the user can recover from', () {
    test('a taken slot keeps the sheet open', () {
      final e = ApiException.fromDio(_http(409, slotTakenError));
      expect(isRecoverableBookingError(e), isTrue);
    });

    test('every slot/schedule conflict code is recoverable', () {
      for (final code in [
        'slot_not_bookable',
        'slot_unavailable',
        'doctor_busy',
        'booking_conflict',
        'outside_availability',
        'lead_time_too_short',
      ]) {
        final e = ApiException.fromDio(
          _http(400, {
            'errors': [
              {'code': code, 'detail': '', 'field': null},
            ],
          }),
        );
        expect(isRecoverableBookingError(e), isTrue, reason: code);
      }
    });

    test('a permission failure is not a "pick another time" problem', () {
      final e = ApiException.fromDio(
        _http(403, {
          'errors': [
            {'code': 'permission_denied', 'detail': '', 'field': null},
          ],
        }),
      );
      expect(isRecoverableBookingError(e), isFalse);
    });
  });
}

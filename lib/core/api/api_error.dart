import 'package:dio/dio.dart';

/// One entry from the backend's `errors` array.
///
/// The backend always sends `{code, detail, field}`. The **code** is the part
/// worth branching on: it is a stable contract, whereas `detail` is
/// human-readable prose that is sometimes Arabic, sometimes English, and always
/// free to be reworded. Nothing in this app makes a decision by matching on
/// `detail`.
class ApiError {
  const ApiError({required this.code, required this.detail, this.field});

  final String code;
  final String detail;

  /// The offending input, when the backend blamed one. Dotted for nested
  /// serializers (`profile.city`).
  final String? field;

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
    code: (json['code'] ?? 'unknown') as String,
    detail: (json['detail'] ?? '') as String,
    field: json['field'] as String?,
  );

  @override
  String toString() => 'ApiError($code${field != null ? ' on $field' : ''})';
}

/// How a request failed, in terms the UI can act on.
enum ApiFailure {
  /// No usable connection, DNS failure, or the request timed out. Crucially
  /// NOT the same as being signed out — see [ApiException.isAuthFailure].
  network,

  /// 400/422 — the backend rejected the input. [ApiException.fieldErrors] maps
  /// them back onto form fields.
  validation,

  /// 401 — no credentials, or they have expired and could not be refreshed.
  unauthenticated,

  /// The request was sent under a session that has since ended or been
  /// replaced (signed out, or someone else signed in). Its answer belongs to
  /// that old session: it is neither retried under the current one nor read
  /// as anything about it — in particular, not as a reason to sign out.
  sessionChanged,

  /// 403 — authenticated, but not allowed. A different screen from 401: asking
  /// this user to log in again would not help them.
  forbidden,

  /// 404. The backend returns this instead of 403 for records outside a user's
  /// scope, deliberately, so "not found" here does not always mean "absent".
  notFound,

  /// 409 and friends — a booking conflict, a slot taken, a duplicate account.
  conflict,

  /// 429 — throttled. The backend rate-limits login, OTP and registration.
  rateLimited,

  /// 5xx.
  server,

  /// A response that did not look like the envelope at all.
  unexpected,
}

/// A failed API call, already interpreted.
class ApiException implements Exception {
  ApiException({required this.failure, required this.errors, this.statusCode});

  final ApiFailure failure;
  final List<ApiError> errors;
  final int? statusCode;

  /// The first error's code, or a synthetic one for transport failures. This is
  /// what UI branches on.
  String get code => errors.isNotEmpty ? errors.first.code : _syntheticCode;

  String get _syntheticCode => switch (failure) {
    ApiFailure.network => 'network_error',
    ApiFailure.unauthenticated => 'not_authenticated',
    ApiFailure.sessionChanged => 'session_changed',
    ApiFailure.forbidden => 'permission_denied',
    ApiFailure.notFound => 'not_found',
    ApiFailure.rateLimited => 'throttled',
    ApiFailure.server => 'server_error',
    _ => 'unknown',
  };

  /// Errors the backend attributed to a field, keyed by field name, ready to
  /// hand straight to a form.
  Map<String, String> get fieldErrors {
    final out = <String, String>{};
    for (final e in errors) {
      final f = e.field;
      if (f != null && f.isNotEmpty) out.putIfAbsent(f, () => e.detail);
    }
    return out;
  }

  /// Errors with no field — the ones that belong at the top of a form.
  List<ApiError> get generalErrors =>
      errors.where((e) => e.field == null || e.field!.isEmpty).toList();

  /// True only when the *session* is the problem. A network outage must never
  /// be read as a logout, which is exactly the bug this getter exists to avoid.
  bool get isAuthFailure => failure == ApiFailure.unauthenticated;

  bool get isNetworkFailure => failure == ApiFailure.network;

  /// Whether retrying the identical request could plausibly succeed.
  bool get isRetryable => failure == ApiFailure.network || failure == ApiFailure.server;

  bool hasCode(String c) => errors.any((e) => e.code == c);

  /// Backend prose for display when the app has no better wording of its own.
  String? get firstDetail =>
      errors.isNotEmpty && errors.first.detail.isNotEmpty ? errors.first.detail : null;

  /// Build from whatever Dio surfaced.
  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;

    // Transport-level problems first: these have no envelope to read.
    final transport = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.unknown => e.response == null,
      _ => false,
    };
    if (transport) {
      return ApiException(failure: ApiFailure.network, errors: const [], statusCode: null);
    }

    if (e.type == DioExceptionType.cancel) {
      return ApiException(failure: ApiFailure.unexpected, errors: const [], statusCode: status);
    }

    return ApiException(
      failure: _failureFor(status),
      errors: _parseErrors(e.response?.data),
      statusCode: status,
    );
  }

  static ApiFailure _failureFor(int? status) => switch (status) {
    400 || 422 => ApiFailure.validation,
    401 => ApiFailure.unauthenticated,
    403 => ApiFailure.forbidden,
    404 => ApiFailure.notFound,
    409 => ApiFailure.conflict,
    429 => ApiFailure.rateLimited,
    _ when status != null && status >= 500 => ApiFailure.server,
    _ => ApiFailure.unexpected,
  };

  static List<ApiError> _parseErrors(dynamic data) {
    if (data is! Map) return const [];
    final raw = data['errors'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => ApiError.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  String toString() => 'ApiException($failure, status=$statusCode, errors=$errors)';
}

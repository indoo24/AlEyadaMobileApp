import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config/env.dart';
import 'api_error.dart';
import 'endpoints.dart';

/// The one place this app speaks HTTP.
///
/// It talks to Django directly with a Bearer token. It does **not** go through
/// the website's Next.js BFF: that layer exists to keep tokens out of browser
/// JavaScript, where an XSS could read them. A mobile app has Keystore/Keychain
/// for the same job, so routing through the BFF would add a hop, a cookie jar
/// and a CSRF dance to buy nothing. `/auth/login/` already returns the token
/// pair, and `EnvironmentAwareJWTAuthentication` is the backend's only
/// authentication class — so Bearer is not a mobile special case, it is the
/// native contract.
///
/// There is no CSRF handling here, and that is correct rather than an omission:
/// CSRF exists because browsers attach cookies automatically. Nothing attaches
/// an Authorization header on a user's behalf, so there is no cross-site request
/// to forge.
class ApiClient {
  ApiClient({
    required TokenStore tokens,
    Dio? dio,
    this.onSessionExpired,
    DateTime Function()? clock,
  })
    // A named parameter cannot be `this._tokens`: named formals may not
    // start with an underscore, so this assignment is the only form available.
    // ignore: prefer_initializing_formals
    : _tokens = tokens,
       _dio = dio ?? Dio(),
       _now = clock ?? DateTime.now {
    _dio.options
      ..baseUrl = Env.apiBaseUrl
      ..connectTimeout = Env.connectTimeout
      ..receiveTimeout = Env.receiveTimeout
      ..sendTimeout = Env.receiveTimeout
      ..headers['Accept'] = 'application/json'
      // Never throw on a status code; the interceptor below turns every failure
      // into an ApiException so callers have one thing to catch.
      ..validateStatus = (s) => s != null && s >= 200 && s < 300;

    _dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio _dio;
  final TokenStore _tokens;

  /// Called when the refresh token itself is dead and the user must sign in
  /// again. Deliberately *not* called for network failures.
  final void Function()? onSessionExpired;

  Dio get raw => _dio;

  /// Guards the refresh so that ten requests racing a just-expired access token
  /// produce one refresh call, not ten. Without this the backend's rotation
  /// (which blacklists the old refresh token) would invalidate the session: the
  /// first refresh would succeed and the other nine would present a token that
  /// had just been blacklisted.
  Future<void>? _refreshInFlight;

  /// Reads the time; a parameter so tests can move it past a `Retry-After`.
  final DateTime Function() _now;

  /// When the backend throttled a refresh and said when to come back: no
  /// refresh is sent for [_throttledRefresh] before [_refreshRetryAt]. A request
  /// that needs one in the meantime fails as throttled without asking again.
  DateTime? _refreshRetryAt;
  String? _throttledRefresh;

  /// The longest `Retry-After` honoured. A larger value is held to this, so a
  /// broken header cannot keep refreshes off for good.
  static const _maxRefreshHold = Duration(hours: 1);

  /// Which session sent a request: recorded in its `extra` when it leaves.
  ///
  /// A number, not a token — nothing secret travels with the request options.
  static const _kSession = 'aleyada.session';

  /// The current session's number, and the refresh token it was last seen with.
  ///
  /// A refresh token this client did not mint itself — a sign-in, of anyone —
  /// starts a new session; one it rotated (see [_doRefresh]) continues the old
  /// one. No refresh token at all is no session.
  int _sessions = 0;
  int? _sessionId;
  String? _sessionRefresh;

  int? _currentSession() {
    final refresh = _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;
    if (refresh != _sessionRefresh) {
      _sessionRefresh = refresh;
      _sessionId = ++_sessions;
    }
    return _sessionId;
  }

  /// The current session, as an opaque number: null when signed out, a new
  /// value after any sign-in, unchanged across this client's own refreshes.
  /// Callers that act on an answer after an `await` compare it before and after,
  /// and drop the answer when it moved.
  int? get session => _currentSession();

  /// Whether [options] was sent by a session other than the current one.
  bool _sessionChangedSince(RequestOptions options) =>
      options.extra[_kSession] != _currentSession();

  static ApiException _sessionChanged() =>
      ApiException(failure: ApiFailure.sessionChanged, errors: const [], statusCode: 401);

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['skipAuth'] != true) {
      if (options.extra['isRetry'] == true) {
        // A replay goes out under the session that sent the original, or not at
        // all — checked here, as it leaves, so no sign-in can slip in between.
        if (_sessionChangedSince(options)) {
          return handler.reject(DioException(requestOptions: options, error: _sessionChanged()));
        }
      } else {
        options.extra[_kSession] = _currentSession();
      }
      final token = _tokens.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    _log('→ ${options.method} ${options.path}');
    handler.next(options);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler handler) async {
    final status = e.response?.statusCode;
    final isRetry = e.requestOptions.extra['isRetry'] == true;
    final skipAuth = e.requestOptions.extra['skipAuth'] == true;

    // A 401 for a session that has ended since the request left — signed out,
    // or someone else signed in. It is the old session's answer: nothing is
    // refreshed or replayed under the session now current, nothing about that
    // session is touched, and the caller is told the session changed.
    if (status == 401 && !isRetry && !skipAuth && _sessionChangedSince(e.requestOptions)) {
      return handler.reject(
        DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          error: _sessionChanged(),
        ),
      );
    }

    // A 401 on a request we authenticated, that we have not already retried,
    // and for which we hold a refresh token: try once to refresh, then replay.
    if (status == 401 && !isRetry && !skipAuth && _tokens.hasSession) {
      try {
        // Sent before an earlier refresh finished, with the token that refresh
        // replaced: the new one is already here, so replay with it instead of
        // rotating the session a second time for nothing.
        if (!_sentWithReplacedToken(e.requestOptions)) await _refreshOnce();
      } on ApiException catch (refreshFailure) {
        // The refresh token was rejected. The refresh has already ended the
        // session (once, for every request that waited on it); the caller gets
        // its original 401, which reads as "sign in again".
        if (refreshFailure.isAuthFailure) return handler.next(e);
        // The session ended while the refresh was out: reported as such, below.
        // Anything else — no connection, a 5xx, a throttle, a reply that was not
        // the backend's — says nothing about the refresh token. The session is
        // kept and the caller gets that failure, to report and retry later.
        return handler.reject(
          DioException(
            requestOptions: e.requestOptions,
            type: refreshFailure.isNetworkFailure
                ? DioExceptionType.connectionError
                : DioExceptionType.unknown,
            error: refreshFailure,
          ),
        );
      }

      try {
        final opts = e.requestOptions;
        opts.extra['isRetry'] = true;
        opts.headers['Authorization'] = 'Bearer ${_tokens.accessToken}';
        final replayed = await _dio.fetch(opts);
        return handler.resolve(replayed);
      } on DioException catch (again) {
        return handler.next(again);
      }
    }

    _log(
      '← ${status ?? 'network'} ${e.requestOptions.method} ${e.requestOptions.path}${_codes(e)}',
    );
    handler.next(e);
  }

  /// Whether [options] carried an access token that has since been replaced.
  bool _sentWithReplacedToken(RequestOptions options) {
    final sent = options.headers['Authorization'];
    final current = _tokens.accessToken;
    if (sent is! String || current == null || current.isEmpty) return false;
    return sent != 'Bearer $current';
  }

  /// Refresh the access token, collapsing concurrent callers onto one request.
  Future<void> _refreshOnce() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  /// Refresh, and decide what a failure means for the session.
  ///
  /// Throws an [ApiException] for which [ApiException.isAuthFailure] is true
  /// only when the refresh token itself was refused — and the session has then
  /// already been ended — and [ApiFailure.sessionChanged] when the session it
  /// was refreshing ended while it was out. Every other failure leaves the
  /// tokens where they were.
  Future<void> _doRefresh() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      throw ApiException(failure: ApiFailure.unauthenticated, errors: const [], statusCode: 401);
    }
    final retryAt = _refreshRetryAt;
    if (retryAt != null && refresh == _throttledRefresh && _now().isBefore(retryAt)) {
      throw ApiException(failure: ApiFailure.rateLimited, errors: const [], statusCode: 429);
    }

    final Response<dynamic> res;
    try {
      // Sent through the same client, not a second Dio built on the side: one
      // transport means one place configuring timeouts, base URL and any future
      // interceptor — and it is the transport tests can substitute.
      //
      // `skipAuth` keeps the request interceptor from attaching the expired
      // access token, and it is also what stops the error interceptor treating a
      // failed refresh as a 401 worth refreshing: that would recurse.
      res = await _dio.post<dynamic>(
        Endpoints.tokenRefresh,
        data: {'refresh': refresh},
        options: Options(extra: const {'skipAuth': true, 'isRetry': true}),
      );
    } on DioException catch (e) {
      // Signed out, or someone else signed in, while this was out: whatever the
      // server said is about a session that has ended. It ends nothing, holds
      // nothing back, and touches nothing of the session now current.
      if (_tokens.refreshToken != refresh) throw _sessionChanged();
      final failure = ApiException.fromDio(e);
      if (_rejectsRefreshToken(failure)) {
        await _endSession(refresh);
        throw ApiException(
          failure: ApiFailure.unauthenticated,
          errors: failure.errors,
          statusCode: failure.statusCode,
        );
      }
      if (failure.failure == ApiFailure.rateLimited) _holdRefreshes(refresh, e.response);
      throw _temporary(failure);
    }

    if (_tokens.refreshToken != refresh) {
      // Signed out, or someone else signed in, while this was out. Its tokens
      // belong to a session that has ended: storing them would bring it back
      // after a sign-out, or overwrite the account now signed in. They are
      // dropped, and the requests that waited on them are not replayed.
      throw _sessionChanged();
    }
    final data = res.data is Map ? (res.data as Map)['data'] : null;
    final access = data is Map ? data['access'] : null;
    final rotated = data is Map ? data['refresh'] : null;
    if (access is! String || access.isEmpty) {
      // A 2xx that is not the backend's answer — a captive portal's sign-in
      // page, a proxy's. It says nothing about the token, so nothing is cleared.
      throw ApiException(
        failure: ApiFailure.unexpected,
        errors: const [],
        statusCode: res.statusCode,
      );
    }
    _refreshRetryAt = null;
    _throttledRefresh = null;
    // The same session, carried on to the rotated token — so a request this
    // session sent before the rotation can still be replayed with the new one.
    _currentSession();
    if (rotated is String && rotated.isNotEmpty) _sessionRefresh = rotated;
    // The backend rotates refresh tokens and blacklists the old one, so the
    // rotated value must be stored or the next refresh presents a dead token.
    await _tokens.updateTokens(access: access, refresh: rotated is String ? rotated : null);
    _log('session refreshed');
  }

  /// Whether the backend refused the refresh token itself.
  ///
  /// The refresh endpoint is public and is sent without an Authorization
  /// header, so a 401 from it can only be about the token in the body: the
  /// backend verifies its signature, expiry and blacklist entry and answers
  /// 401 `token_not_valid` when any fails. The code is honoured with any 4xx
  /// too, since codes are the contract. A 403, 404 or another 400 from this
  /// endpoint comes from somewhere in front of it, not from the token.
  static bool _rejectsRefreshToken(ApiException failure) {
    final status = failure.statusCode;
    if (status == 401) return true;
    return status != null && status >= 400 && status < 500 && failure.hasCode('token_not_valid');
  }

  /// Drop the session the refused token belonged to — once, however many
  /// requests were waiting on the refresh.
  Future<void> _endSession(String refused) async {
    // Checked by the caller already; kept so this can never clear a session
    // other than the refused one.
    if (_tokens.refreshToken != refused) return;
    await _tokens.clear();
    onSessionExpired?.call();
  }

  /// A refresh failure that leaves the session alone, as the caller should
  /// see it. No connection, a 5xx and a throttle are reported as themselves.
  /// Anything else is reported as unexpected, without the backend's prose: it
  /// describes the refresh, not the request the person made.
  static ApiException _temporary(ApiException failure) => switch (failure.failure) {
    ApiFailure.network || ApiFailure.server || ApiFailure.rateLimited => failure,
    _ => ApiException(
      failure: ApiFailure.unexpected,
      errors: const [],
      statusCode: failure.statusCode,
    ),
  };

  /// Honour a throttled refresh's `Retry-After`, in seconds — the form the
  /// backend's throttling sends. Without a usable value nothing is held: each
  /// later request may try once, as before.
  void _holdRefreshes(String refresh, Response<dynamic>? response) {
    final seconds = int.tryParse(response?.headers.value('retry-after')?.trim() ?? '');
    if (seconds == null || seconds <= 0) return;
    _throttledRefresh = refresh;
    _refreshRetryAt = _now().add(Duration(seconds: seconds.clamp(1, _maxRefreshHold.inSeconds)));
  }

  // --- verbs ---------------------------------------------------------------

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    bool skipAuth = false,
  }) => _send(
    () => _dio.get<dynamic>(
      path,
      queryParameters: _clean(query),
      cancelToken: cancelToken,
      options: Options(extra: {'skipAuth': skipAuth}),
    ),
  );

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    bool skipAuth = false,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: body,
      queryParameters: _clean(query),
      cancelToken: cancelToken,
      options: Options(extra: {'skipAuth': skipAuth}),
    ),
  );

  Future<dynamic> patch(String path, {Object? body, CancelToken? cancelToken}) =>
      _send(() => _dio.patch<dynamic>(path, data: body, cancelToken: cancelToken));

  Future<dynamic> put(String path, {Object? body, CancelToken? cancelToken}) =>
      _send(() => _dio.put<dynamic>(path, data: body, cancelToken: cancelToken));

  Future<dynamic> delete(String path, {Object? body, CancelToken? cancelToken}) =>
      _send(() => _dio.delete<dynamic>(path, data: body, cancelToken: cancelToken));

  /// Multipart upload with progress, for photos and licence documents.
  Future<dynamic> upload(
    String path, {
    required FormData form,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
    String method = 'POST',
  }) => _send(
    () => _dio.request<dynamic>(
      path,
      data: form,
      cancelToken: cancelToken,
      onSendProgress: onProgress,
      options: Options(method: method),
    ),
  );

  Future<dynamic> _send(Future<Response<dynamic>> Function() run) async {
    try {
      final res = await run();
      return res.data;
    } on DioException catch (e) {
      // A refresh that failed on the network is already an ApiException.
      final inner = e.error;
      if (inner is ApiException) throw inner;
      throw ApiException.fromDio(e);
    }
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v;
    });
    return out.isEmpty ? null : out;
  }

  /// The backend's error codes, e.g. ` [permission_denied]` — enough to tell one
  /// 403 from another. Codes are fixed identifiers, never user data; the
  /// human-readable details are left out.
  static String _codes(DioException e) {
    final data = e.response?.data;
    final errors = data is Map ? data['errors'] : null;
    if (errors is! List || errors.isEmpty) return '';
    final codes = errors.whereType<Map>().map((m) => '${m['code']}').toSet().join(', ');
    return ' [$codes]';
  }

  /// Logging that cannot leak a credential.
  ///
  /// Only the method, path, status and the backend's error codes are ever
  /// recorded — no headers, no bodies, no query strings. A password, an OTP code and a token all travel in exactly
  /// those places, and a log is the one component that reliably outlives the
  /// request it describes.
  void _log(String message) {
    if (!Env.verboseLogging) return;
    developer.log(message, name: 'aleyada.api');
  }
}

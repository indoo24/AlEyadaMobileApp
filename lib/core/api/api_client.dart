import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../config/env.dart';
import 'api_error.dart';

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
  ApiClient({required TokenStore tokens, Dio? dio, this.onSessionExpired})
    // A named parameter cannot be `this._tokens`: named formals may not
    // start with an underscore, so this assignment is the only form available.
    // ignore: prefer_initializing_formals
    : _tokens = tokens,
      _dio = dio ?? Dio() {
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

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.accessToken;
    if (token != null && token.isNotEmpty && options.extra['skipAuth'] != true) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    _log('→ ${options.method} ${options.path}');
    handler.next(options);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler handler) async {
    final status = e.response?.statusCode;
    final isRetry = e.requestOptions.extra['isRetry'] == true;
    final skipAuth = e.requestOptions.extra['skipAuth'] == true;

    // A 401 on a request we authenticated, that we have not already retried,
    // and for which we hold a refresh token: try once to refresh, then replay.
    if (status == 401 && !isRetry && !skipAuth && _tokens.hasSession) {
      try {
        await _refreshOnce();
      } on ApiException catch (refreshFailure) {
        // Distinguish carefully. If the refresh failed because the *network* is
        // down, this is not a logout — surface it as a network error and keep
        // the session. Only a real rejection ends the session.
        if (refreshFailure.isNetworkFailure) {
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              type: DioExceptionType.connectionError,
              error: refreshFailure,
            ),
          );
        }
        await _tokens.clear();
        onSessionExpired?.call();
        return handler.next(e);
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

    _log('← ${status ?? 'network'} ${e.requestOptions.path}');
    handler.next(e);
  }

  /// Refresh the access token, collapsing concurrent callers onto one request.
  Future<void> _refreshOnce() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<void> _doRefresh() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      throw ApiException(failure: ApiFailure.unauthenticated, errors: const [], statusCode: 401);
    }
    try {
      // Sent through the same client, not a second Dio built on the side: one
      // transport means one place configuring timeouts, base URL and any future
      // interceptor — and it is the transport tests can substitute.
      //
      // `skipAuth` keeps the request interceptor from attaching the expired
      // access token, and it is also what stops the error interceptor treating a
      // failed refresh as a 401 worth refreshing: that would recurse.
      final res = await _dio.post<dynamic>(
        '/auth/token/refresh/',
        data: {'refresh': refresh},
        options: Options(extra: const {'skipAuth': true, 'isRetry': true}),
      );
      final data = res.data is Map ? (res.data as Map)['data'] : null;
      final access = data is Map ? data['access'] as String? : null;
      final rotated = data is Map ? data['refresh'] as String? : null;
      if (access == null || access.isEmpty) {
        throw ApiException(failure: ApiFailure.unauthenticated, errors: const [], statusCode: 401);
      }
      // The backend rotates refresh tokens and blacklists the old one, so the
      // rotated value must be stored or the next refresh presents a dead token.
      await _tokens.updateTokens(access: access, refresh: rotated);
      _log('session refreshed');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
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

  /// Logging that cannot leak a credential.
  ///
  /// Only the method and path are ever recorded — no headers, no bodies, no
  /// query strings. A password, an OTP code and a token all travel in exactly
  /// those places, and a log is the one component that reliably outlives the
  /// request it describes.
  void _log(String message) {
    if (!Env.verboseLogging) return;
    developer.log(message, name: 'aleyada.api');
  }
}

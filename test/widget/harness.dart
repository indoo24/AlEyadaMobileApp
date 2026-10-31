import 'package:aleyada_mobile/core/api/api_client.dart';
import 'package:aleyada_mobile/core/auth/token_store.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Test scaffolding: a real widget tree, a real API client, a fake transport.
///
/// Widget tests go through the same `ApiClient` and the same providers as the
/// app — only the HTTP adapter is swapped. A test that mocks the repository
/// instead would pass while the envelope parsing was broken.
class TestHarness {
  TestHarness({
    String? refreshToken,
    void Function()? onSessionExpired,
    DateTime Function()? clock,
  }) {
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
    store = _InMemoryTokenStore(refresh: refreshToken);
    client = ApiClient(tokens: store, dio: dio, onSessionExpired: onSessionExpired, clock: clock);
  }

  late final Dio dio;
  late final DioAdapter adapter;
  late final TokenStore store;
  late final ApiClient client;

  List<Override> get overrides => [
    apiClientProvider.overrideWithValue(client),
    tokenStoreProvider.overrideWithValue(store),
  ];

  /// Wrap a widget in everything it needs: providers, the real theme, the real
  /// localizations, and a chosen locale so RTL can be asserted.
  Widget wrap(Widget child, {Locale locale = const Locale('ar')}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.light(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: child,
      ),
    );
  }
}

class _InMemoryTokenStore extends TokenStore {
  // ignore: prefer_initializing_formals
  _InMemoryTokenStore({String? refresh}) : _refresh = refresh, super();

  String? _access;
  String? _refresh;

  @override
  String? get accessToken => _access ?? (_refresh == null ? null : 'access');
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
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session lives between app launches.
///
/// Keystore on Android, Keychain on iOS — never SharedPreferences. The refresh
/// token is a seven-day bearer credential: on a rooted device, plaintext
/// preferences are readable by anything, and that token is enough to mint access
/// tokens for a week.
///
/// Passwords and OTP codes are never written here, or anywhere else. They are
/// used once, in memory, and discarded.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
          );

  final FlutterSecureStorage _storage;

  static const _kAccess = 'aleyada.access';
  static const _kRefresh = 'aleyada.refresh';

  /// Cached in memory so the hot path (one header per request) is not an async
  /// platform-channel call on every single call.
  String? _access;
  String? _refresh;
  bool _loaded = false;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => (_refresh ?? '').isNotEmpty;

  /// Read persisted tokens into memory. Called once at startup.
  ///
  /// A read failure is treated as "no session" rather than propagated: secure
  /// storage can genuinely fail (a restored backup on Android has, historically,
  /// produced undecryptable entries) and the right response is to ask the user
  /// to sign in, not to crash on launch.
  Future<void> load() async {
    if (_loaded) return;
    try {
      _access = await _storage.read(key: _kAccess);
      _refresh = await _storage.read(key: _kRefresh);
    } catch (_) {
      _access = null;
      _refresh = null;
      await _bestEffortClear();
    }
    _loaded = true;
  }

  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
    _loaded = true;
    try {
      await _storage.write(key: _kAccess, value: access);
      await _storage.write(key: _kRefresh, value: refresh);
    } catch (_) {
      // The session still works for this run; it just will not survive a
      // restart. Better than refusing to log the user in.
    }
  }

  /// After a refresh: the access token always changes, and the refresh token
  /// changes too because the backend rotates and blacklists the old one.
  Future<void> updateTokens({required String access, String? refresh}) =>
      save(access: access, refresh: refresh ?? _refresh ?? '');

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    await _bestEffortClear();
  }

  Future<void> _bestEffortClear() async {
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
    } catch (_) {
      // Nothing useful to do; the in-memory copy is already gone.
    }
  }
}

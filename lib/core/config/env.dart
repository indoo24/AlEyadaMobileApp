/// Build-time configuration.
///
/// Everything here is passed with `--dart-define` and is deliberately *not* a
/// secret. Anything compiled into a mobile binary can be read out of it, so the
/// only things that belong here are values a user could discover by watching
/// network traffic anyway: the API base URL and the environment name.
///
/// Real secrets stay on the server. The app authenticates with a token it is
/// given at login, which is why there is no API key in this file.
library;

enum AppEnvironment { development, production }

class Env {
  const Env._();

  /// Which backend this build talks to.
  ///
  /// Defaults to production so a release build cannot accidentally ship
  /// pointing at a developer's laptop. Development builds opt in explicitly.
  static const String _envName = String.fromEnvironment('ALEYADA_ENV', defaultValue: 'production');

  static AppEnvironment get environment =>
      _envName == 'development' ? AppEnvironment.development : AppEnvironment.production;

  static bool get isProduction => environment == AppEnvironment.production;

  /// The API root, including the `/api/v1` prefix the backend serves under.
  ///
  /// The default is the deployed host. For the Android emulator a developer
  /// passes `--dart-define=ALEYADA_API_BASE_URL=http://10.0.2.2:8000/api/v1`
  /// (10.0.2.2 is how the emulator reaches the host machine's localhost).
  static const String apiBaseUrl = String.fromEnvironment(
    'ALEYADA_API_BASE_URL',
    defaultValue: 'https://aleyada.scenariomnchnl.tech/api/v1',
  );

  /// Where the web management system lives: the address the doctor's
  /// "open the management system" button opens.
  ///
  /// The API does not report it (it is in neither `/auth/me/`, `/doctor/*` nor the
  /// public settings), so it is configuration — defaulted here, like the API
  /// address, and overridable per build with
  /// `--dart-define=ALEYADA_MANAGEMENT_URL=https://…`. Passing an empty value, or
  /// anything that is not an absolute http(s) address, removes the button; the
  /// Management screen never guesses one.
  static const String managementUrl = String.fromEnvironment(
    'ALEYADA_MANAGEMENT_URL',
    defaultValue: 'https://scenariomnchnl.tech/',
  );

  /// Verbose request logging. Never on in production: even with redaction, the
  /// safest log in a shipped binary is the one that does not exist.
  static bool get verboseLogging =>
      const bool.fromEnvironment('ALEYADA_VERBOSE_LOG', defaultValue: false) && !isProduction;

  static Duration get connectTimeout => const Duration(seconds: 15);
  static Duration get receiveTimeout => const Duration(seconds: 20);
}

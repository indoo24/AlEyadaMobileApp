import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The chosen display language.
///
/// Null means "follow the device", which for this product resolves to Arabic
/// unless the phone is set to English — Arabic is first in `supportedLocales`,
/// so it is also the fallback for every other language.
///
/// Stored in SharedPreferences and not secure storage on purpose: a language
/// choice is not a secret, and putting it in the Keychain would make the very
/// first frame wait on a platform channel.
///
/// `main` reads the saved value before the first frame and passes it in
/// ([LocaleController.preloaded]), so the first frame is already in the right
/// language. Without that preload (a test) the controller restores it itself.
class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _restore();
  }

  /// Starts from [initial] — already read from storage — with nothing to restore.
  LocaleController.preloaded(super.state);

  static const _key = 'aleyada.locale';

  /// The saved language, read once at launch; null when there is none (follow
  /// the device). Never throws.
  static Future<Locale?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      return code == null || code.isEmpty ? null : Locale(code);
    } catch (_) {
      return null;
    }
  }

  Future<void> _restore() async {
    final saved = await load();
    if (saved != null && mounted) state = saved;
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, locale.languageCode);
      }
    } catch (_) {
      // The choice applies to this run regardless.
    }
  }
}

/// Set by `main` when the saved language was read before the first frame.
final preloadedLocaleProvider = Provider<({Locale? locale})?>((ref) => null);

final localeControllerProvider = StateNotifierProvider<LocaleController, Locale?>((ref) {
  final preloaded = ref.watch(preloadedLocaleProvider);
  return preloaded == null ? LocaleController() : LocaleController.preloaded(preloaded.locale);
});

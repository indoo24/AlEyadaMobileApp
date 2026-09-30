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
class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _restore();
  }

  static const _key = 'aleyada.locale';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code != null && code.isNotEmpty) state = Locale(code);
    } catch (_) {
      // Keep following the device.
    }
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

final localeControllerProvider = StateNotifierProvider<LocaleController, Locale?>(
  (ref) => LocaleController(),
);

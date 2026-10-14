import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The chosen appearance: follow the device, or force light or dark.
///
/// Defaults to [ThemeMode.system]. Stored in SharedPreferences, like the
/// language, and for the same reason: a display choice is not a secret, and the
/// Keychain would make the first frame wait on a platform channel.
///
/// `main` reads the saved value before the first frame and hands it in, so a
/// person who chose dark never sees a light frame. Without that preload (a test,
/// or a preload that failed) the controller restores it itself, a moment later.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController({ThemeMode? initial}) : super(initial ?? ThemeMode.system) {
    if (initial == null) _restore();
  }

  static const storageKey = 'aleyada.theme_mode';

  /// Whether the person has chosen since launch. A late restore must never undo
  /// a choice made while the disk was still answering.
  bool _chosen = false;

  /// What [mode] is saved as. Stable strings, not enum indexes, so reordering the
  /// enum can never turn a saved "dark" into "light".
  static String encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  /// The mode saved as [raw]; anything unrecognised is "follow the device".
  static ThemeMode decode(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  /// The saved mode, read once at launch. Never throws.
  static Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return decode(prefs.getString(storageKey));
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> _restore() async {
    final saved = await load();
    if (mounted && !_chosen && saved != state) state = saved;
  }

  Future<void> setMode(ThemeMode mode) async {
    _chosen = true;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mode == ThemeMode.system) {
        await prefs.remove(storageKey);
      } else {
        await prefs.setString(storageKey, encode(mode));
      }
    } catch (_) {
      // The choice applies to this run regardless.
    }
  }
}

/// The mode read at launch, or null when nothing was preloaded.
final preloadedThemeModeProvider = Provider<ThemeMode?>((ref) => null);

final themeModeControllerProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(initial: ref.watch(preloadedThemeModeProvider)),
);

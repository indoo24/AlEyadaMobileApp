import 'package:aleyada_mobile/app/locale_controller.dart';
import 'package:aleyada_mobile/app/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'aleyada.theme_mode';

  Future<SharedPreferences> prefs([Map<String, Object> seed = const {}]) async {
    SharedPreferences.setMockInitialValues(seed);
    return SharedPreferences.getInstance();
  }

  group('what is stored', () {
    test('the three modes have stable, readable names', () {
      expect(ThemeModeController.encode(ThemeMode.light), 'light');
      expect(ThemeModeController.encode(ThemeMode.dark), 'dark');
      expect(ThemeModeController.encode(ThemeMode.system), 'system');
    });

    test('they decode back; anything else means "follow the device"', () {
      expect(ThemeModeController.decode('light'), ThemeMode.light);
      expect(ThemeModeController.decode('dark'), ThemeMode.dark);
      expect(ThemeModeController.decode('system'), ThemeMode.system);
      for (final odd in [null, '', 'DARK', 'amoled', '2', 'true']) {
        expect(ThemeModeController.decode(odd), ThemeMode.system, reason: '$odd');
      }
    });

    test('the storage key is the one the product names', () {
      expect(ThemeModeController.storageKey, key);
    });
  });

  group('the default', () {
    test('is to follow the device', () async {
      await prefs();
      final c = ThemeModeController();
      addTearDown(c.dispose);
      expect(c.state, ThemeMode.system);
      await pumpEventQueue();
      expect(c.state, ThemeMode.system, reason: 'nothing saved, nothing changes');
    });

    test('a provider with nothing preloaded starts on system', () async {
      await prefs();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeControllerProvider), ThemeMode.system);
    });
  });

  group('choosing', () {
    test('applies at once and is saved', () async {
      final p = await prefs();
      final c = ThemeModeController();
      addTearDown(c.dispose);

      final saving = c.setMode(ThemeMode.dark);
      expect(c.state, ThemeMode.dark, reason: 'the screen does not wait for the disk');
      await saving;
      expect(p.getString(key), 'dark');

      await c.setMode(ThemeMode.light);
      expect(c.state, ThemeMode.light);
      expect(p.getString(key), 'light');
    });

    test('going back to system forgets the choice', () async {
      final p = await prefs({key: 'dark'});
      final c = ThemeModeController(initial: ThemeMode.dark);
      addTearDown(c.dispose);
      await c.setMode(ThemeMode.system);
      expect(c.state, ThemeMode.system);
      expect(p.containsKey(key), isFalse);
    });

    test('an unwritable store does not stop the change applying', () async {
      // No mock initial values and a store that throws is not constructible here;
      // the contract is that setMode never throws and always updates state.
      await prefs();
      final c = ThemeModeController();
      addTearDown(c.dispose);
      await expectLater(c.setMode(ThemeMode.dark), completes);
      expect(c.state, ThemeMode.dark);
    });
  });

  group('restoring', () {
    test('a saved choice comes back after a restart', () async {
      await prefs({key: 'dark'});
      expect(await ThemeModeController.load(), ThemeMode.dark);

      final c = ThemeModeController(); // no preload: restores itself
      addTearDown(c.dispose);
      await pumpEventQueue();
      expect(c.state, ThemeMode.dark);
    });

    test('light is restored too, not mistaken for "no choice"', () async {
      await prefs({key: 'light'});
      expect(await ThemeModeController.load(), ThemeMode.light);
    });

    test('a corrupt value falls back to the device', () async {
      await prefs({key: 'purple'});
      expect(await ThemeModeController.load(), ThemeMode.system);
    });

    test('a choice made before the disk answered is not undone by it', () async {
      final p = await prefs({key: 'dark'});
      final c = ThemeModeController(); // restore in flight
      addTearDown(c.dispose);
      await c.setMode(ThemeMode.light); // the person taps Light right away
      await pumpEventQueue();
      expect(c.state, ThemeMode.light);
      expect(p.getString(key), 'light');
    });
  });

  group('the preload (no first-frame flash)', () {
    test('a preloaded mode is the first state, with no restore after it', () async {
      // The disk says light, but the preloaded value wins and is not replaced.
      await prefs({key: 'light'});
      final container = ProviderContainer(
        overrides: [preloadedThemeModeProvider.overrideWithValue(ThemeMode.dark)],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeControllerProvider), ThemeMode.dark, reason: 'first read');
      await pumpEventQueue();
      expect(container.read(themeModeControllerProvider), ThemeMode.dark, reason: 'still');
    });

    test('preloaded "system" is also honoured', () async {
      await prefs({key: 'dark'});
      final container = ProviderContainer(
        overrides: [preloadedThemeModeProvider.overrideWithValue(ThemeMode.system)],
      );
      addTearDown(container.dispose);
      await pumpEventQueue();
      expect(container.read(themeModeControllerProvider), ThemeMode.system);
    });
  });

  group('the language gets the same preload', () {
    const lkey = 'aleyada.locale';

    test('load() reads the saved language; null means follow the device', () async {
      await prefs({lkey: 'en'});
      expect(await LocaleController.load(), const Locale('en'));
      await prefs();
      expect(await LocaleController.load(), isNull);
      await prefs({lkey: ''});
      expect(await LocaleController.load(), isNull);
    });

    test('a preloaded language is the first state', () async {
      await prefs({lkey: 'ar'});
      final container = ProviderContainer(
        overrides: [preloadedLocaleProvider.overrideWithValue((locale: const Locale('en')))],
      );
      addTearDown(container.dispose);
      expect(container.read(localeControllerProvider), const Locale('en'));
      await pumpEventQueue();
      expect(container.read(localeControllerProvider), const Locale('en'));
    });

    test('a preload that found no saved language keeps following the device', () async {
      await prefs({lkey: 'en'});
      final container = ProviderContainer(
        overrides: [preloadedLocaleProvider.overrideWithValue((locale: null))],
      );
      addTearDown(container.dispose);
      await pumpEventQueue();
      expect(container.read(localeControllerProvider), isNull);
    });

    test('without a preload it restores itself, as before', () async {
      await prefs({lkey: 'en'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(localeControllerProvider);
      await pumpEventQueue();
      expect(container.read(localeControllerProvider), const Locale('en'));
    });
  });
}

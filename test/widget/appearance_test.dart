import 'dart:ui' as ui;

import 'package:aleyada_mobile/app/app.dart';
import 'package:aleyada_mobile/app/locale_controller.dart';
import 'package:aleyada_mobile/app/theme_mode_controller.dart';
import 'package:aleyada_mobile/core/theme/app_palette.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/profile/account_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

void main() {
  late TestHarness h;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The Account screen in an app wired like the real one: the theme mode and the
  /// language both come from their controllers.
  Future<void> pumpAccount(
    WidgetTester tester, {
    Locale locale = const Locale('ar'),
    ProviderContainer? using,
  }) async {
    tester.view
      ..physicalSize = const Size(390, 1000) * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: using ?? container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ref.watch(themeModeControllerProvider),
            locale: ref.watch(localeControllerProvider) ?? locale,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: const AccountScreen(),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester, 6);
  }

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(AccountScreen))).brightness;

  AppPalette palette(WidgetTester tester) => tester.element(find.byType(AccountScreen)).palette;

  Finder option(String label) => find.bySemanticsLabel(label);

  // ==========================================================================
  group('the Appearance row on the Account screen', () {
    testWidgets('sits in Settings under Language and says what is chosen — Arabic', (tester) async {
      await pumpAccount(tester);
      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('اللغة'), findsOneWidget);
      expect(find.text('المظهر'), findsOneWidget);
      expect(find.text('تلقائي'), findsOneWidget, reason: 'the default is to follow the device');

      final language = tester.getTopLeft(find.text('اللغة')).dy;
      final appearance = tester.getTopLeft(find.text('المظهر')).dy;
      expect(appearance, greaterThan(language), reason: 'below Language, in the same group');
    });

    testWidgets('and in English', (tester) async {
      await pumpAccount(tester, locale: const Locale('en'));
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('opens a sheet with the three choices, the current one marked', (tester) async {
      await pumpAccount(tester);
      await tap(tester, find.text('المظهر'));

      expect(find.text('اختر المظهر'), findsOneWidget);
      for (final label in ['تلقائي', 'فاتح', 'داكن']) {
        expect(
          find.descendant(of: find.byType(BottomSheet), matching: find.text(label)),
          findsOneWidget,
        );
      }
      final system = tester.getSemantics(option('تلقائي'));
      expect(system.flagsCollection.isSelected, ui.Tristate.isTrue);
      final dark = tester.getSemantics(option('داكن'));
      expect(dark.flagsCollection.isSelected, isNot(ui.Tristate.isTrue));
    });

    testWidgets('English labels in the sheet', (tester) async {
      await pumpAccount(tester, locale: const Locale('en'));
      await tap(tester, find.text('Appearance'));
      expect(find.text('Choose appearance'), findsOneWidget);
      for (final label in ['System', 'Light', 'Dark']) {
        expect(
          find.descendant(of: find.byType(BottomSheet), matching: find.text(label)),
          findsOneWidget,
        );
      }
    });
  });

  // ==========================================================================
  group('choosing', () {
    Future<void> choose(WidgetTester tester, String label) async {
      await tap(tester, find.text('المظهر'));
      await tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text(label)));
    }

    testWidgets('Dark switches the whole app, closes the sheet, and is saved', (tester) async {
      await pumpAccount(tester);
      expect(brightness(tester), Brightness.light, reason: 'the test device is light');

      await choose(tester, 'داكن');

      expect(find.byType(BottomSheet), findsNothing, reason: 'the sheet closes');
      expect(container.read(themeModeControllerProvider), ThemeMode.dark);
      expect(brightness(tester), Brightness.dark);
      expect(palette(tester).isDark, isTrue);
      expect(find.text('داكن'), findsOneWidget, reason: 'the row now says Dark');
      expect((await SharedPreferences.getInstance()).getString('aleyada.theme_mode'), 'dark');
    });

    testWidgets('Light is saved as light', (tester) async {
      await pumpAccount(tester);
      await choose(tester, 'داكن');
      await choose(tester, 'فاتح');
      expect(brightness(tester), Brightness.light);
      expect(find.text('فاتح'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('aleyada.theme_mode'), 'light');
    });

    testWidgets('System forgets the choice', (tester) async {
      await pumpAccount(tester);
      await choose(tester, 'داكن');
      await choose(tester, 'تلقائي');
      expect(container.read(themeModeControllerProvider), ThemeMode.system);
      expect((await SharedPreferences.getInstance()).containsKey('aleyada.theme_mode'), isFalse);
    });

    testWidgets('the sheet itself is dark in dark mode', (tester) async {
      await pumpAccount(tester);
      await choose(tester, 'داكن');
      await tap(tester, find.text('المظهر'));
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, AppPalette.dark.surfaceRaised);
    });

    testWidgets('the language picker, now on the shared sheet, still switches language', (
      tester,
    ) async {
      await pumpAccount(tester);
      await tap(tester, find.text('اللغة'));
      expect(find.text('اختر اللغة'), findsOneWidget);
      await tap(
        tester,
        find.descendant(of: find.byType(BottomSheet), matching: find.text('English')),
      );
      expect(container.read(localeControllerProvider), const Locale('en'));
      expect(find.text('Appearance'), findsOneWidget);
    });
  });

  // ==========================================================================
  group('System mode follows the device', () {
    testWidgets('dark device → dark, light device → light, live', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpAccount(tester);
      expect(container.read(themeModeControllerProvider), ThemeMode.system);
      expect(brightness(tester), Brightness.dark);
      expect(palette(tester).isDark, isTrue);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await settle(tester, 3);
      expect(brightness(tester), Brightness.light);
      expect(palette(tester).isDark, isFalse);
    });

    testWidgets('an explicit choice beats the device, both ways', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpAccount(tester);
      await tap(tester, find.text('المظهر'));
      await tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('فاتح')));
      expect(brightness(tester), Brightness.light, reason: 'Light on a dark phone');

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tap(tester, find.text('المظهر'));
      await tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('داكن')));
      expect(brightness(tester), Brightness.dark, reason: 'Dark on a light phone');
    });
  });

  // ==========================================================================
  group('the real app', () {
    Future<MaterialApp> pumpApp(WidgetTester tester, ProviderContainer c) async {
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const AlEyadaApp()));
      return tester.widget<MaterialApp>(find.byType(MaterialApp));
    }

    testWidgets('hands MaterialApp a light theme, a dark theme, and the chosen mode', (
      tester,
    ) async {
      final app = await pumpApp(tester, container);
      expect(app.themeMode, ThemeMode.system, reason: 'the default');
      expect(app.theme!.brightness, Brightness.light);
      expect(app.darkTheme!.brightness, Brightness.dark);
      expect(app.theme!.extension<AppPalette>()!.isDark, isFalse);
      expect(app.darkTheme!.extension<AppPalette>()!.isDark, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('dark mode asks for light status-bar icons; light mode asks for nothing', (
      tester,
    ) async {
      // The app-level overlay is the one that leaves the navigation bar colour
      // unset (the splash and the navy headers set their own, full styles).
      int appOverlays() => tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byWidgetPredicate((w) => w is AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .where(
            (r) =>
                r.value.systemNavigationBarColor == null &&
                r.value.statusBarIconBrightness == Brightness.light,
          )
          .length;

      final dark = ProviderContainer(
        overrides: [...h.overrides, preloadedThemeModeProvider.overrideWithValue(ThemeMode.dark)],
      );
      addTearDown(dark.dispose);
      await pumpApp(tester, dark);
      expect(appOverlays(), 1, reason: 'dark');
      await tester.pumpWidget(const SizedBox());

      final light = ProviderContainer(
        overrides: [...h.overrides, preloadedThemeModeProvider.overrideWithValue(ThemeMode.light)],
      );
      addTearDown(light.dispose);
      await pumpApp(tester, light);
      expect(appOverlays(), 0, reason: 'light adds no overlay of its own');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a preloaded choice is already in force on the very first frame', (tester) async {
      final preloaded = ProviderContainer(
        overrides: [
          ...h.overrides,
          preloadedThemeModeProvider.overrideWithValue(ThemeMode.dark),
          preloadedLocaleProvider.overrideWithValue((locale: const Locale('en'))),
        ],
      );
      addTearDown(preloaded.dispose);

      // One frame, no waiting on storage: nothing flashes light or Arabic.
      final app = await pumpApp(tester, preloaded);
      expect(app.themeMode, ThemeMode.dark);
      expect(app.locale, const Locale('en'));
      await tester.pumpWidget(const SizedBox());
    });
  });
}

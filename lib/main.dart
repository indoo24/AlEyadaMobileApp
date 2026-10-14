import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/locale_controller.dart';
import 'app/theme_mode_controller.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the saved appearance and language before the first frame, so a person
  // who chose dark mode or English never sees a flash of the other. Both reads
  // are a few milliseconds from SharedPreferences and cannot fail the launch.
  final (themeMode, locale) = await (ThemeModeController.load(), LocaleController.load()).wait;

  final container = ProviderContainer(
    overrides: [
      preloadedThemeModeProvider.overrideWithValue(themeMode),
      preloadedLocaleProvider.overrideWithValue((locale: locale)),
    ],
  );

  // Start restoring the session before the first frame. The router holds on the
  // splash until this settles, so nothing flashes a sign-in screen at a user who
  // is already signed in.
  container.read(authControllerProvider.notifier).restore();

  runApp(UncontrolledProviderScope(container: container, child: const AlEyadaApp()));
}

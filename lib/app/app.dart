import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'locale_controller.dart';
import 'router.dart';

class AlEyadaApp extends ConsumerWidget {
  const AlEyadaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      title: 'AlEyada',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),

      // Arabic first. `supportedLocales` order also decides what the app falls
      // back to for a device set to anything else — which for this product
      // should be Arabic, not English.
      locale: locale,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,

      // Directionality comes from the locale via Localizations, so no widget
      // reverses a Row by hand. Setting textDirection anywhere would break the
      // moment someone switched to English.
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          // Respect the reader's chosen size, but stop at a factor where the
          // layouts genuinely stop working. Clamping is honest about the limit;
          // ignoring the setting is not.
          minScaleFactor: 0.85,
          maxScaleFactor: 1.6,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

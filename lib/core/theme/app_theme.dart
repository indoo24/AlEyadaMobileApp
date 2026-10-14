import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'tokens.dart';

/// The Material theme built from the shared tokens.
///
/// Translated into Flutter widgets rather than transliterated from CSS: the
/// website's rounded-pill buttons and 16px cards become [ButtonStyle] and
/// [CardThemeData], so every screen inherits the look without repeating it.
class AppTheme {
  const AppTheme._();

  /// Cairo, bundled as an asset. Never a runtime download: an Arabic-first
  /// product must not render its first frame in a Latin fallback face.
  static const fontFamily = 'Cairo';

  static ThemeData light() => _build(AppPalette.light);

  static ThemeData dark() => _build(AppPalette.dark);

  /// Both themes come from here, so they cannot drift apart: a component styled
  /// in one is styled in the other, from the palette's roles.
  static ThemeData _build(AppPalette p) {
    final dark = p.isDark;
    var scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: p.brightness)
        .copyWith(
          // `primary` is the brand blue *as text and icons* — legible on the
          // surface. Filled buttons use `primaryFill` explicitly below.
          primary: p.primary,
          onPrimary: dark ? p.page : Colors.white,
          surface: p.surface,
          onSurface: p.body,
          error: p.danger,
          outline: p.border,
        );
    if (dark) {
      // Material 3 derives tinted container surfaces from the seed; pin them to
      // the palette so menus and pickers match the cards.
      scheme = scheme.copyWith(
        surfaceContainerLowest: p.page,
        surfaceContainerLow: p.surface,
        surfaceContainer: p.surfaceRaised,
        surfaceContainerHigh: p.surfaceRaised,
        surfaceContainerHighest: p.surfaceRaised,
        onSurfaceVariant: p.muted,
        outlineVariant: p.border,
      );
    }

    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: p.surface,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, p),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.heading,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: p.heading,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: _inputBorder(p.border),
        enabledBorder: _inputBorder(p.border),
        focusedBorder: _inputBorder(p.primary, width: 1.6),
        errorBorder: _inputBorder(p.danger),
        focusedErrorBorder: _inputBorder(p.danger, width: 1.6),
        labelStyle: TextStyle(color: p.muted, fontSize: 15),
        floatingLabelStyle: TextStyle(color: p.primary),
        hintStyle: TextStyle(color: p.muted, fontSize: 15),
        errorStyle: TextStyle(color: p.danger, fontSize: 13, height: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primaryFill,
          foregroundColor: p.onPrimaryFill,
          disabledBackgroundColor: p.primaryFill.withValues(alpha: 0.45),
          disabledForegroundColor: p.onPrimaryFill,
          // 48 is the accessible minimum for a primary action; the design's pill
          // shape keeps it from looking heavy.
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.pageSoft,
        selectedColor: p.primaryFill,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.heading,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.onPrimaryFill,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.pageSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? p.primary : p.muted,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        // Navy in light. In dark the heading colour is pale, so a pale bar with
        // white text would not read: use a lifted slate instead.
        backgroundColor: dark ? const Color(0xFF26364F) : p.heading,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.inputRadius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) => OutlineInputBorder(
    borderRadius: AppRadii.inputRadius,
    borderSide: BorderSide(color: color, width: width),
  );

  /// Sizes follow the tokens document's mobile column.
  ///
  /// Letter spacing is pinned to zero everywhere: Arabic glyphs join, and
  /// tracking breaks the joins. Material's defaults add tracking to several
  /// styles, so this is a correction, not a preference.
  static TextTheme _textTheme(TextTheme base, AppPalette p) {
    return base
        .copyWith(
          displayLarge: TextStyle(
            letterSpacing: 0,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: p.heading,
            height: 1.25,
          ),
          headlineLarge: TextStyle(
            letterSpacing: 0,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: p.heading,
            height: 1.25,
          ),
          headlineMedium: TextStyle(
            letterSpacing: 0,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: p.heading,
            height: 1.3,
          ),
          titleLarge: TextStyle(
            letterSpacing: 0,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: p.heading,
            height: 1.35,
          ),
          titleMedium: TextStyle(
            letterSpacing: 0,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: p.heading,
          ),
          titleSmall: TextStyle(
            letterSpacing: 0,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: p.heading,
          ),
          bodyLarge: TextStyle(
            letterSpacing: 0,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: p.body,
            height: 1.6,
          ),
          bodyMedium: TextStyle(
            letterSpacing: 0,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: p.body,
            height: 1.6,
          ),
          bodySmall: TextStyle(
            letterSpacing: 0,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: p.muted,
            height: 1.5,
          ),
          labelLarge: TextStyle(
            letterSpacing: 0,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: p.heading,
          ),
          labelMedium: TextStyle(
            letterSpacing: 0,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: p.muted,
          ),
        )
        // Arabic glyphs join, and tracking breaks the joins — so every style
        // above pins letterSpacing to 0 rather than inheriting Material's
        // defaults. `apply(letterSpacingFactor:)` cannot do this job: it asserts
        // the style already has a non-null letterSpacing.
        .apply(fontFamily: fontFamily);
  }
}

import 'package:flutter/material.dart';

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

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light)
        .copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          error: AppColors.danger,
          outline: AppColors.border,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.surface,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.6),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.6),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 15),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 15),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 13, height: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
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
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.border),
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
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgSoft,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.bgSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.inputRadius),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
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
  static TextTheme _textTheme(TextTheme base) {
    return base
        .copyWith(
          displayLarge: const TextStyle(
            letterSpacing: 0,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            height: 1.25,
          ),
          headlineLarge: const TextStyle(
            letterSpacing: 0,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
            height: 1.25,
          ),
          headlineMedium: const TextStyle(
            letterSpacing: 0,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
            height: 1.3,
          ),
          titleLarge: const TextStyle(
            letterSpacing: 0,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
            height: 1.35,
          ),
          titleMedium: const TextStyle(
            letterSpacing: 0,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
          titleSmall: const TextStyle(
            letterSpacing: 0,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
          bodyLarge: const TextStyle(
            letterSpacing: 0,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
            height: 1.6,
          ),
          bodyMedium: const TextStyle(
            letterSpacing: 0,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
            height: 1.6,
          ),
          bodySmall: const TextStyle(
            letterSpacing: 0,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.muted,
            height: 1.5,
          ),
          labelLarge: const TextStyle(
            letterSpacing: 0,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
          labelMedium: const TextStyle(
            letterSpacing: 0,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        )
        // Arabic glyphs join, and tracking breaks the joins — so every style
        // above pins letterSpacing to 0 rather than inheriting Material's
        // defaults. `apply(letterSpacingFactor:)` cannot do this job: it asserts
        // the style already has a non-null letterSpacing.
        .apply(fontFamily: fontFamily);
  }
}

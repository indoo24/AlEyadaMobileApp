import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps colour decisions in one place.
///
/// Dark mode only works while no widget hard-codes a light colour: a screen that
/// reaches for `AppColors.surface` or `Color(0xFFFFFFFF)` stays light in a dark
/// app. These tests fail the moment one is added, and say where.
void main() {
  final lib = Directory('lib');

  /// Every Dart file under lib/, as (relative path with `/`, text).
  List<(String, String)> sources() => [
    for (final f in lib.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart'))
        (
          f.path.replaceAll(r'\', '/').replaceFirst(RegExp(r'^.*?lib/'), 'lib/'),
          f.readAsStringSync(),
        ),
  ];

  bool inTheme(String path) => path.startsWith('lib/core/theme/');

  /// The text with `//` comments and `///` docs blanked, so prose may mention a
  /// token without tripping the guard.
  String code(String text) =>
      text.split('\n').map((l) => l.replaceFirst(RegExp(r'//.*$'), '')).join('\n');

  test('the source files are found (the guard is not vacuous)', () {
    final all = sources();
    expect(all.length, greaterThan(100));
    expect(
      all.where((s) => inTheme(s.$1)).map((s) => s.$1),
      contains('lib/core/theme/app_palette.dart'),
    );
  });

  test('AppColors is not referenced outside lib/core/theme/', () {
    final offenders = <String>[];
    for (final (path, text) in sources()) {
      if (inTheme(path)) continue;
      final lines = code(text).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('AppColors')) offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use context.palette.<role> (lib/core/theme/app_palette.dart) instead:\n${offenders.join('\n')}',
    );
  });

  test('the old static shadows and type styles are gone', () {
    final offenders = <String>[];
    for (final (path, text) in sources()) {
      if (inTheme(path)) continue;
      final c = code(text);
      if (RegExp(r'\bAppShadows\.').hasMatch(c)) {
        offenders.add('$path uses AppShadows.* (use context.palette.shadow*)');
      }
      if (RegExp(r'\bHomeType\.\w').hasMatch(c)) {
        offenders.add('$path uses HomeType.* (use context.homeType.*)');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('raw colour literals stay in the theme, the splash, and a short allowlist', () {
    // The splash is the brand's always-navy launch animation. The others sit on
    // the navy hero header, which is navy in both modes.
    const allowed = <String, int>{
      'lib/features/home/home_style.dart': 1, // hero tagline: 80% white
      'lib/features/profile/widgets/account_widgets.dart': 2, // pale chip text on the hero
    };
    final found = <String, int>{};
    for (final (path, text) in sources()) {
      if (inTheme(path) || path.startsWith('lib/features/splash/')) continue;
      final n = RegExp(r'\bColor\(0x[0-9A-Fa-f]{8}\)').allMatches(code(text)).length;
      if (n > 0) found[path] = n;
    }
    expect(found, allowed, reason: 'A new Color(0x…) needs a role in AppPalette, not a literal.');
  });

  test('widgets do not branch on the brightness to pick their own colours', () {
    // `context.palette.isDark` may select a *layout* detail (a hairline that only
    // dark needs); picking colours is the palette's job. This pins the places
    // that do it, so a new one is a conscious decision.
    const allowed = <String>{
      'lib/app/bottom_nav.dart', // the glass dock's border
      'lib/features/bookings/booking_detail_screen.dart', // hero card edge, timeline glyph
      'lib/features/doctors/widgets/doctor_profile_sections.dart', // hero edge
      'lib/features/home/widgets/home_hero.dart', // hero edge
      'lib/features/profile/account_screen.dart', // hero edge
    };
    final users = <String>{};
    for (final (path, text) in sources()) {
      if (inTheme(path)) continue;
      if (RegExp(r'\.isDark\b').hasMatch(code(text))) users.add(path);
    }
    expect(users, allowed);
  });
}

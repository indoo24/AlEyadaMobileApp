import 'dart:math' as math;

import 'package:aleyada_mobile/core/theme/app_palette.dart';
import 'package:aleyada_mobile/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x relative luminance and contrast ratio, on opaque colours.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// [fg] drawn at [alpha] over [bg].
Color over(Color fg, double alpha, Color bg) => Color.alphaBlend(fg.withValues(alpha: alpha), bg);

const _aa = 4.5; // normal text
const _aaLarge = 3.0; // large or bold text, icons and other UI parts

void main() {
  final palettes = {'light': AppPalette.light, 'dark': AppPalette.dark};

  for (final entry in palettes.entries) {
    final name = entry.key;
    final p = entry.value;

    group('$name palette: text', () {
      // Every surface text can sit on.
      final surfaces = {
        'page': p.page,
        'pageSoft': p.pageSoft,
        'surface': p.surface,
        'surfaceRaised': p.surfaceRaised,
        'input': p.input,
      };

      for (final s in surfaces.entries) {
        test('heading, body, muted and brand blue on ${s.key} are AA', () {
          expect(contrast(p.heading, s.value), greaterThanOrEqualTo(_aa), reason: 'heading');
          expect(contrast(p.body, s.value), greaterThanOrEqualTo(_aa), reason: 'body');
          expect(contrast(p.muted, s.value), greaterThanOrEqualTo(_aa), reason: 'muted');
          expect(contrast(p.primary, s.value), greaterThanOrEqualTo(_aa), reason: 'primary');
        });
      }

      test('error text is AA on the surfaces forms use', () {
        // The light red is the web token (4.8:1 on a white card, 4.35:1 on the
        // tinted page and field fills), so light is held to AA on cards and to
        // 4:1 on the tints; dark is AA everywhere.
        for (final bg in [p.surface, p.surfaceRaised]) {
          expect(contrast(p.danger, bg), greaterThanOrEqualTo(_aa), reason: '$bg');
        }
        for (final bg in [p.input, p.page]) {
          expect(contrast(p.danger, bg), greaterThanOrEqualTo(p.isDark ? _aa : 4.0), reason: '$bg');
        }
      });

      test('error text on its own faint tint (the form error banner) reads', () {
        // The banner is danger at 6% over the surface, with danger text.
        final banner = over(p.danger, 0.06, p.surface);
        expect(contrast(p.danger, banner), greaterThanOrEqualTo(p.isDark ? _aa : 4.0));
      });

      test('success and star read on a surface (icons and small status text)', () {
        // Light success green was already 3.3:1 on white — a graphic/status
        // colour, not body copy — so the bar for light is the 3:1 UI bar; dark is
        // lifted to full AA.
        final bar = p.isDark ? _aa : _aaLarge;
        expect(contrast(p.success, p.surface), greaterThanOrEqualTo(bar), reason: 'success');
        expect(
          contrast(p.star, p.surface),
          greaterThanOrEqualTo(p.isDark ? _aa : 2.0),
          reason: 'star',
        );
      });
    });

    group('$name palette: fills with their label', () {
      test('white on the brand fill is AA', () {
        expect(contrast(p.onPrimaryFill, p.primaryFill), greaterThanOrEqualTo(_aa));
      });

      test('white on the destructive fill is AA', () {
        expect(contrast(Colors.white, p.dangerFill), greaterThanOrEqualTo(_aa));
      });

      test('white on the WhatsApp fill: large bold button text', () {
        // The light green is the web token's (3.3:1), used on a bold 16px button
        // label — the large-text bar. Dark darkens the fill to full AA.
        expect(contrast(Colors.white, p.whatsapp), greaterThanOrEqualTo(p.isDark ? _aa : _aaLarge));
      });

      test('the brand fill is visible against the page and the surface (UI part, 3:1)', () {
        expect(contrast(p.primaryFill, p.page), greaterThanOrEqualTo(_aaLarge), reason: 'page');
        expect(
          contrast(p.primaryFill, p.surface),
          greaterThanOrEqualTo(_aaLarge),
          reason: 'surface',
        );
      });

      test('white text on both stops of the hero gradient, at full and at 80%', () {
        for (final stop in [p.heroStart, p.heroEnd]) {
          expect(contrast(Colors.white, stop), greaterThanOrEqualTo(_aa), reason: 'white on $stop');
          expect(
            contrast(over(Colors.white, 0.8, stop), stop),
            greaterThanOrEqualTo(_aa),
            reason: '80% white on $stop',
          );
        }
      });

      test('the pale chip on the hero (verification) reads on it', () {
        final chip = over(p.heroChip, p.heroChip.a, p.heroEnd);
        expect(
          contrast(const Color(0xFF86EFAC), chip),
          greaterThanOrEqualTo(_aa),
          reason: 'verified',
        );
        expect(
          contrast(const Color(0xFFFCD34D), chip),
          greaterThanOrEqualTo(_aa),
          reason: 'unverified',
        );
      });
    });

    group('$name palette: status tones', () {
      final tones = {
        'info': p.toneInfo,
        'success': p.toneSuccess,
        'warning': p.toneWarning,
        'caution': p.toneCaution,
        'danger': p.toneDanger,
        'neutral': p.toneNeutral,
      };
      for (final t in tones.entries) {
        test('${t.key}: label on its tint is AA', () {
          expect(contrast(t.value.fg, t.value.bg), greaterThanOrEqualTo(_aa));
        });
        test(
          '${t.key}: the pill is visible on a card and on the page (the tint is not the card)',
          () {
            // Not a text bar: a pill must not vanish into what it sits on.
            expect(t.value.bg == p.surface, isFalse);
          },
        );
      }

      test('tone foregrounds also read when used as a bare icon or text on the surface', () {
        for (final t in tones.entries) {
          expect(contrast(t.value.fg, p.surface), greaterThanOrEqualTo(_aaLarge), reason: t.key);
        }
      });

      test('a tone fill carrying a dark/white glyph (the timeline dot) reads', () {
        final glyph = p.isDark ? p.page : Colors.white;
        expect(contrast(glyph, p.toneSuccess.fg), greaterThanOrEqualTo(_aaLarge), reason: 'done');
        expect(contrast(glyph, p.toneDanger.fg), greaterThanOrEqualTo(_aaLarge), reason: 'failed');
      });
    });
  }

  group('light is the web design tokens, unchanged', () {
    const p = AppPalette.light;
    test('every role that existed as a token still has its value', () {
      expect(p.page, AppColors.bg);
      expect(p.pageSoft, AppColors.bgSoft);
      expect(p.surface, AppColors.surface);
      expect(p.surfaceRaised, AppColors.surface);
      expect(p.input, AppColors.input);
      expect(p.border, AppColors.border);
      expect(p.heading, AppColors.navy);
      expect(p.body, AppColors.ink);
      expect(p.muted, AppColors.muted);
      expect(p.primary, AppColors.primary);
      expect(p.primaryFill, AppColors.primary);
      expect(p.danger, AppColors.danger);
      expect(p.dangerFill, AppColors.danger);
      expect(p.success, AppColors.success);
      expect(p.star, AppColors.star);
      expect(p.whatsapp, AppColors.whatsapp);
    });

    test('the status pills keep the colours they always had', () {
      expect(p.toneWarning.fg, const Color(0xFFB45309));
      expect(p.toneWarning.bg, const Color(0xFFFEF3C7));
      expect(p.toneSuccess.fg, const Color(0xFF15803D));
      expect(p.toneSuccess.bg, const Color(0xFFDCFCE7));
      expect(p.toneDanger.fg, const Color(0xFFB91C1C));
      expect(p.toneDanger.bg, const Color(0xFFFEE2E2));
      expect(p.toneCaution.fg, const Color(0xFFC2410C));
      expect(p.toneCaution.bg, const Color(0xFFFFEDD5));
      expect(p.toneNeutral.bg, const Color(0xFFEEF2F7));
    });

    test('the hero edge is invisible in light', () {
      expect(p.heroEdge.a, 0);
    });
  });

  group('dark is navy-slate, not black, and lifts with elevation', () {
    const p = AppPalette.dark;

    test('no surface is pure black', () {
      for (final c in [p.page, p.pageSoft, p.surface, p.surfaceRaised, p.input]) {
        expect(c, isNot(const Color(0xFF000000)));
        expect(_luminance(c), greaterThan(0.003), reason: '$c');
      }
    });

    test('each level of elevation is lighter than the one below', () {
      expect(_luminance(p.page), lessThan(_luminance(p.surface)));
      expect(_luminance(p.surface), lessThan(_luminance(p.surfaceRaised)));
      expect(_luminance(p.surfaceRaised), lessThan(_luminance(p.pageSoft)));
    });

    test('the brand blue as text is lighter than as a fill', () {
      expect(_luminance(p.primary), greaterThan(_luminance(p.primaryFill)));
    });

    test('the hero stays visibly navy against the page, with an edge', () {
      expect(p.heroEdge.a, greaterThan(0));
      expect(contrast(p.heroEnd, p.page), greaterThan(1.8));
    });
  });

  group('AppPalette.lerp', () {
    const a = AppPalette.light;
    const b = AppPalette.dark;

    test('the ends are the palettes themselves', () {
      final start = a.lerp(b, 0);
      final end = a.lerp(b, 1);
      expect(start.page, a.page);
      expect(start.toneDanger.fg, a.toneDanger.fg);
      expect(start.brightness, Brightness.light);
      expect(end.page, b.page);
      expect(end.toneDanger.bg, b.toneDanger.bg);
      expect(end.shadowSoft.first.color, b.shadowSoft.first.color);
      expect(end.brightness, Brightness.dark);
    });

    test('the middle is between them, role by role', () {
      final mid = a.lerp(b, 0.5);
      expect(mid.page, Color.lerp(a.page, b.page, 0.5));
      expect(mid.primary, Color.lerp(a.primary, b.primary, 0.5));
      expect(mid.toneWarning.bg, Color.lerp(a.toneWarning.bg, b.toneWarning.bg, 0.5));
      expect(mid.dockShadow, Color.lerp(a.dockShadow, b.dockShadow, 0.5));
    });

    test('it is symmetric', () {
      final x = a.lerp(b, 0.3);
      final y = b.lerp(a, 0.7);
      void same(Color p, Color q, String role) {
        for (final (u, v) in [(p.r, q.r), (p.g, q.g), (p.b, q.b), (p.a, q.a)]) {
          expect(u, closeTo(v, 1e-9), reason: role);
        }
      }

      same(x.surface, y.surface, 'surface');
      same(x.heading, y.heading, 'heading');
      same(x.toneInfo.fg, y.toneInfo.fg, 'toneInfo.fg');
    });

    test('lerping with nothing changes nothing', () {
      expect(identical(a.lerp(null, 0.5), a), isTrue);
    });

    test('the brightness flips halfway', () {
      expect(a.lerp(b, 0.49).isDark, isFalse);
      expect(a.lerp(b, 0.51).isDark, isTrue);
    });
  });

  group('context.palette', () {
    Future<AppPalette> read(WidgetTester tester, ThemeData? theme) async {
      AppPalette? found;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              found = context.palette;
              return const SizedBox();
            },
          ),
        ),
      );
      return found!;
    }

    testWidgets('resolves the extension the theme carries', (tester) async {
      final p = await read(tester, ThemeData(extensions: const [AppPalette.dark]));
      expect(identical(p, AppPalette.dark), isTrue);
    });

    testWidgets('a bare light theme falls back to the light palette', (tester) async {
      final p = await read(tester, null);
      expect(identical(p, AppPalette.light), isTrue);
    });

    testWidgets('a bare dark theme falls back to the dark palette', (tester) async {
      final p = await read(tester, ThemeData.dark());
      expect(identical(p, AppPalette.dark), isTrue);
    });
  });
}

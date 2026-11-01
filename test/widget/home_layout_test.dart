import 'dart:math' as math;

import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/home/home_screen.dart';
import 'package:aleyada_mobile/features/home/widgets/quick_discovery.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_fixtures.dart';
import 'harness.dart';

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {
  'data': items,
  'meta': {
    'pagination': {'count': 35, 'page': 1, 'pages': 4, 'page_size': 8, 'next': null, 'previous': null},
  },
  'errors': <dynamic>[],
};

final _clinics = _page([
  {
    'id': 'c1',
    'slug': 'dar-al-fouad',
    'name_ar': 'مستشفى دار الفؤاد التخصصي للقلب والأوعية الدموية والقسطرة',
    'name_en': 'Dar Al Fouad',
    'city': {'id': '1', 'name_ar': 'مدينة 6 أكتوبر'},
    'area': {'id': '2', 'name_ar': 'الحي المتميز'},
    'address_ar': 'صرح طبي متكامل وطوارئ على مدار الساعة طوال أيام الأسبوع',
    'avg_rating': '4.60',
    'reviews_count': 12,
    'primary_image': null,
  },
  {
    'id': 'c2',
    'slug': 'x',
    'name_ar': 'عيادة',
    'address_ar': '',
    'avg_rating': '0.00',
    'reviews_count': 0,
    'primary_image': 'https://example.test/missing.png',
  },
]);

final _articles = _page([
  {
    'id': 'a1',
    'slug': 'diabetes',
    'title_ar': 'التغذية العلاجية لمرضى السكري: أسس عامة لضبط مستويات السكر في الدم',
    'excerpt':
        'تلعب التغذية العلاجية دوراً محورياً في خطة التحكم والوقاية من مضاعفات السكري إلى جانب الأدوية والنشاط الرياضي المنتظم.',
    'featured_image': 'https://example.test/missing.png',
    'category': {'id': 'k', 'name_ar': 'باطنة وتغذية', 'slug': 'k'},
    'is_certified': true,
  },
]);

final _cities = {
  'data': [
    {'id': '1', 'slug': 'cairo', 'name_ar': 'القاهرة', 'name_en': 'Cairo', 'areas': <dynamic>[]},
    {'id': '2', 'slug': 'giza', 'name_ar': 'الجيزة', 'name_en': 'Giza', 'areas': <dynamic>[]},
  ],
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

/// A quick action card's rect, its icon's, and its label's rect and paragraph.
typedef _Card = ({Rect card, Rect icon, Rect label, RenderParagraph text});

void main() {
  late TestHarness h;

  // Without this the test engine draws every glyph as a full-em square, which is
  // roughly twice as wide as Cairo and reports overflows that cannot happen.
  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  late ProviderContainer container;

  setUp(() {
    h = TestHarness();
    h.adapter
      ..onGet('/specializations/', (s) => s.reply(200, specializationsResponse))
      ..onGet('/doctors/', (s) => s.reply(200, doctorListResponse))
      ..onGet('/clinics/', (s) => s.reply(200, _clinics))
      ..onGet('/articles/', (s) => s.reply(200, _articles))
      ..onGet('/locations/cities/', (s) => s.reply(200, _cities));
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> pumpHome(
    WidgetTester tester, {
    required Size size,
    Locale locale = const Locale('ar'),
    double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final sizes = <String, Size>{
    'small phone': const Size(320, 568),
    'standard phone': const Size(360, 800),
    'mid phone': const Size(390, 844),
    'large phone': const Size(412, 915),
  };

  for (final entry in sizes.entries) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final scale in const [1.0, 1.6]) {
        testWidgets(
          'no layout errors: ${entry.key}, ${locale.languageCode}, text x$scale',
          (tester) async {
            await pumpHome(tester, size: entry.value, locale: locale, textScale: scale);

            // Scroll the whole feed so every section is laid out, not just the
            // ones that start on screen.
            final list = find.byType(Scrollable).first;
            for (var i = 0; i < 8; i++) {
              await tester.drag(list, const Offset(0, -600));
              await tester.pump(const Duration(milliseconds: 100));
            }

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  group('quick action cards', () {
    const labels = {
      'ar': ['كل الأطباء', 'التخصصات', 'حجز إلكتروني', 'الأقل سعرًا'],
      'en': ['All doctors', 'Specialties', 'Book online', 'Lowest fee'],
    };

    List<_Card> cards(WidgetTester tester, String lang) => [
      for (final label in labels[lang]!)
        () {
          final text = find.descendant(
            of: find.byType(QuickDiscovery),
            matching: find.text(label),
          );
          final card = find.ancestor(of: text, matching: find.byType(InkWell));
          final icon = find.descendant(of: card, matching: find.byType(Icon));
          return (
            card: tester.getRect(card.first),
            icon: tester.getRect(icon),
            label: tester.getRect(text),
            text: tester.renderObject<RenderParagraph>(text),
          );
        }(),
    ];

    for (final entry in sizes.entries) {
      for (final lang in labels.keys) {
        for (final scale in const [1.0, 1.1, 1.3]) {
          testWidgets('one height per row, icons and labels level: '
              '${entry.key}, $lang, text x$scale', (tester) async {
            final size = entry.value;
            await pumpHome(
              tester,
              size: size,
              locale: Locale(lang),
              textScale: scale,
            );

            // Four across, or two rows of two.
            final rows = <double, List<_Card>>{};
            for (final c in cards(tester, lang)) {
              rows.putIfAbsent(c.card.top, () => []).add(c);
            }
            for (final row in rows.values) {
              final first = row.first;
              for (final c in row) {
                expect(c.card.size, first.card.size, reason: 'same card size');
                expect(c.icon.top, first.icon.top, reason: 'icons level');
                expect(c.label.top, first.label.top, reason: 'labels level');
                // All of the label shows, inside its card, under its icon.
                expect(c.text.didExceedMaxLines, isFalse);
                expect(c.card.expandToInclude(c.label), c.card);
                expect(c.label.center.dx, closeTo(c.icon.center.dx, 0.5));
              }
              // The row is as tall as its longest label needs and no taller,
              // so a locale where nothing wraps keeps its single-line cards.
              final lowest = row.map((c) => c.label.bottom).reduce(math.max);
              const paddingAndBorder = 12 + 1;
              expect(
                first.card.bottom - lowest,
                closeTo(paddingAndBorder, 0.01),
              );
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('"حجز إلكتروني" wraps as two whole words; its row grows too', (
      tester,
    ) async {
      // Wide enough to stay four across, with text large enough that this
      // label, the longest, needs a second line while the others do not.
      await pumpHome(tester, size: const Size(412, 915), textScale: 1.3);
      final all = cards(tester, 'ar');
      final online = all[2];
      final oneLine = all[0].label.height;

      expect(all.map((c) => c.card.top).toSet(), hasLength(1));
      expect(online.label.height, closeTo(2 * oneLine, 0.5)); // حجز / إلكتروني
      for (final c in [all[0], all[1], all[3]]) {
        expect(c.label.height, oneLine);
        expect(c.card.height, online.card.height);
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('every section renders real data from the API', (tester) async {
    await pumpHome(tester, size: const Size(360, 800));

    expect(find.text('أسنان'), findsWidgets); // specialty tile
    expect(find.text('أطباء مقترحون'), findsOneWidget);
    expect(find.text('عرض الكل (+15)'), findsOneWidget); // 17 matches, 2 shown
    expect(find.text('احجز الآن'), findsWidgets);

    final feed = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.textContaining('دار الفؤاد'), 300, scrollable: feed);
    expect(find.textContaining('دار الفؤاد'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('باطنة وتغذية'), 300, scrollable: feed);
    expect(find.text('باطنة وتغذية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failing section says so and the rest of the screen still renders', (tester) async {
    // A fresh harness with no /clinics/ route: that request fails. (Articles are
    // a secondary section and simply step aside when they fail.)
    h = TestHarness();
    h.adapter
      ..onGet('/specializations/', (s) => s.reply(200, specializationsResponse))
      ..onGet('/doctors/', (s) => s.reply(200, doctorListResponse))
      ..onGet('/articles/', (s) => s.reply(200, _articles));
    container = ProviderContainer(overrides: h.overrides);
    await pumpHome(tester, size: const Size(360, 800));

    await tester.scrollUntilVisible(
      find.text('تعذّر تحميل هذا القسم.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('تعذّر تحميل هذا القسم.'), findsOneWidget);
    expect(find.text('أطباء مقترحون'), findsOneWidget);
  });

  testWidgets('choosing a city scopes the feed and is reflected in the header', (tester) async {
    await pumpHome(tester, size: const Size(360, 800));
    expect(find.text('كل المدن'), findsWidgets);

    await tester.tap(find.text('كل المدن').first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.text('الجيزة'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text('الجيزة'), findsWidgets);
    expect(find.text('كل المدن'), findsNothing);
  });
}

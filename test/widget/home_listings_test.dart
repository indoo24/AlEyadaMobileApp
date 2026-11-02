import 'dart:async';

import 'package:aleyada_mobile/app/bottom_nav.dart';
import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/app/shell.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/core/widgets/async_value_view.dart';
import 'package:aleyada_mobile/features/articles/article_detail_screen.dart';
import 'package:aleyada_mobile/features/articles/articles_screen.dart';
import 'package:aleyada_mobile/features/clinics/medical_centers_screen.dart';
import 'package:aleyada_mobile/features/doctors/providers.dart';
import 'package:aleyada_mobile/features/home/home_providers.dart';
import 'package:aleyada_mobile/features/home/home_screen.dart';
import 'package:aleyada_mobile/features/home/widgets/article_card.dart';
import 'package:aleyada_mobile/features/home/widgets/home_section_header.dart';
import 'package:aleyada_mobile/features/home/widgets/medical_center_card.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/api_fixtures.dart';
import '../fixtures/management_fixtures.dart' show envelope;
import 'harness.dart';

Map<String, dynamic> _clinic(int i) => {
  'id': 'clinic-$i',
  'slug': 'clinic-$i',
  'name_ar': 'عيادة $i',
  'name_en': 'Clinic $i',
  'city': {'id': '1', 'name_ar': 'الغربية'},
  'area': {'id': '2', 'name_ar': 'طنطا'},
  'address_ar': 'شارع البحر',
  'avg_rating': '4.60',
  'reviews_count': 12,
  'primary_image': null,
};

Map<String, dynamic> _article(int i) => {
  'id': 'article-$i',
  'slug': 'article-$i',
  'title_ar': 'مقال $i',
  'excerpt': 'ملخص المقال $i',
  'featured_image': null,
  'category': {'id': 'k', 'name_ar': 'تغذية', 'slug': 'k'},
  'reviewed_by_doctor': {
    'id': 'r',
    'slug': 'sara',
    'full_name_ar': 'سارة علي',
    'display_title': 'د.',
  },
  'is_certified': true,
  'published_at': '2026-03-14T09:00:00Z',
};

/// A long title and body, for the overflow checks.
const _longTitle =
    'التغذية العلاجية لمرضى السكري من النوع الثاني: أسس عامة لضبط مستويات '
    'السكر في الدم والوقاية من المضاعفات على المدى الطويل';

Map<String, dynamic> _detail(int i, {String? title, String? image}) => {
  ..._article(i),
  if (title != null) 'title_ar': title,
  'featured_image': image,
  'content':
      '<h2>مقدمة</h2><p>الفقرة الأولى من المقال $i.</p>'
      '<ul><li>شرب الماء</li><li>المشي يوميًا</li></ul>'
      '<p>${'جملة طويلة في نص المقال تتكرر لاختبار الالتفاف. ' * 12}</p>',
  'seo': <String, dynamic>{},
};

/// Answers `/clinics/` and `/articles/` a page at a time, as the backend does,
/// and an article by slug.
class _Server {
  _Server(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) async {
          Response<dynamic> reply(Object? body, [int status = 200]) =>
              Response(requestOptions: o, statusCode: status, data: body);
          void fail(int status) => handler.reject(
            DioException.badResponse(
              statusCode: status,
              requestOptions: o,
              response: reply(envelope(null), status),
            ),
            true,
          );
          Map<String, dynamic> pageOf(List<Map<String, dynamic>> all) {
            final q = o.queryParameters;
            final number = int.parse('${q['page'] ?? 1}');
            final size = int.parse('${q['page_size'] ?? 20}');
            final items = all.skip((number - 1) * size).take(size).toList();
            final pages = all.isEmpty ? 1 : (all.length / size).ceil();
            return envelope(
              items,
              meta: {
                'pagination': {
                  'count': all.length,
                  'page': number,
                  'pages': pages,
                  'page_size': size,
                  'next': null,
                  'previous': null,
                },
              },
            );
          }

          requests.add(o);
          final gate = gates[o.path];
          if (gate != null) await gate.future;
          if (failing.contains(o.path)) return fail(500);
          switch (o.path) {
            case '/specializations/':
              return handler.resolve(reply(specializationsResponse));
            case '/doctors/':
              return handler.resolve(reply(doctorListResponse));
            case '/locations/cities/':
              return handler.resolve(reply(citiesResponse));
            case '/clinics/':
              return handler.resolve(reply(pageOf(clinics)));
            case '/articles/':
              return handler.resolve(reply(pageOf(articles)));
          }
          final slug = RegExp(r'^/articles/([^/]+)/$').firstMatch(o.path)?[1];
          if (slug != null) {
            final d = details[slug];
            return d == null ? fail(404) : handler.resolve(reply(envelope(d)));
          }
          handler.next(o);
        },
      ),
    );
  }

  List<Map<String, dynamic>> clinics = [
    for (var i = 1; i <= 30; i++) _clinic(i),
  ];
  List<Map<String, dynamic>> articles = [
    for (var i = 1; i <= 25; i++) _article(i),
  ];
  Map<String, Map<String, dynamic>> details = {
    for (var i = 1; i <= 25; i++) 'article-$i': _detail(i),
  };
  final failing = <String>{};
  final gates = <String, Completer<void>>{};
  final requests = <RequestOptions>[];

  Iterable<Map<String, dynamic>> queriesTo(String path) =>
      requests.where((r) => r.path == path).map((r) => r.queryParameters);
}

void main() {
  late TestHarness h;
  late _Server server;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    server = _Server(h.dio);
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 10]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The real shell, Home and the new screens, at the app's own routes.
  Future<void> pumpApp(
    WidgetTester tester, {
    String start = Routes.home,
    Size size = const Size(390, 844),
    Locale locale = const Locale('ar'),
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    Widget stub(String name) => Scaffold(body: Text('page:$name'));
    final router = GoRouter(
      initialLocation: start,
      routes: [
        ShellRoute(
          builder: (_, __, child) => AppShell(child: child),
          routes: [
            GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
            GoRoute(path: Routes.doctors, builder: (_, __) => stub('doctors')),
            GoRoute(
              path: Routes.bookings,
              builder: (_, __) => stub('bookings'),
            ),
            GoRoute(
              path: Routes.favorites,
              builder: (_, __) => stub('favorites'),
            ),
            GoRoute(path: Routes.account, builder: (_, __) => stub('account')),
          ],
        ),
        GoRoute(
          path: Routes.clinics,
          builder: (_, __) => const MedicalCentersScreen(),
        ),
        GoRoute(
          path: Routes.articles,
          builder: (_, __) => const ArticlesScreen(),
        ),
        GoRoute(
          path: Routes.article,
          builder: (_, s) =>
              ArticleDetailScreen(slug: s.pathParameters['slug'] ?? ''),
        ),
        GoRoute(path: Routes.doctor, builder: (_, __) => stub('doctor')),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Finder feed() => find
      .descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await settle(tester);
  }

  /// Scrolls [scrollable] until [f] is on screen.
  Future<void> scrollTo(
    WidgetTester tester,
    Finder f,
    Finder scrollable,
  ) async {
    await tester.scrollUntilVisible(f, 300, scrollable: scrollable);
    await settle(tester, 4);
  }

  Finder listOf(Type screen) => find
      .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
      .first;

  /// The "see all" button in the Home section titled [title], if there is one.
  Finder seeAllOf(String title) => find.descendant(
    of: find.ancestor(
      of: find.text(title),
      matching: find.byType(HomeSectionHeader),
    ),
    matching: find.byType(TextButton),
  );

  group('medical centers', () {
    testWidgets('"see all" says how many more, and opens the full listing', (
      tester,
    ) async {
      await pumpApp(tester);
      // Home shows 8 of 30.
      final seeAll = find.text('عرض الكل (+22)');
      await scrollTo(tester, seeAll, feed());
      await tap(tester, seeAll);

      expect(find.byType(MedicalCentersScreen), findsOneWidget);
      expect(find.text('المراكز الطبية والعيادات'), findsOneWidget);
      expect(find.text('كل المدن'), findsOneWidget, reason: 'its city scope');
      expect(find.text('عيادة 1'), findsOneWidget);

      // Scrolling on reads the next page, until every clinic is there.
      await scrollTo(
        tester,
        find.text('عيادة 30'),
        listOf(MedicalCentersScreen),
      );
      expect(find.text('عيادة 30'), findsOneWidget);
      expect(server.queriesTo('/clinics/').map((q) => q['page']), [1, 1, 2]);
      expect(find.byType(MedicalCenterCard), findsWidgets);
      expect(tester.takeException(), isNull);

      await back(tester);
      expect(find.byType(MedicalCentersScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(GlassBottomNav), findsOneWidget);
    });

    testWidgets('scoped to the Home city, like the strip it continues', (
      tester,
    ) async {
      container.read(homeCitySlugProvider.notifier).state = 'giza';
      await pumpApp(tester, start: Routes.clinics);
      await settle(tester);
      expect(server.queriesTo('/clinics/').last['city'], 'giza');
      expect(find.text('الجيزة'), findsOneWidget);
    });

    testWidgets('a center opens its doctors, as on Home', (tester) async {
      await pumpApp(tester, start: Routes.clinics);
      await tap(tester, find.text('عيادة 2'));
      expect(container.read(doctorQueryProvider).clinic, 'clinic-2');
      expect(find.text('page:doctors'), findsOneWidget);
    });

    testWidgets('a few centers: "see all" without a count', (tester) async {
      server.clinics = [_clinic(1)];
      await pumpApp(tester);
      await scrollTo(tester, find.text('عيادة 1'), feed());
      expect(seeAllOf('المراكز الطبية والعيادات'), findsOneWidget);
      expect(
        find.descendant(
          of: seeAllOf('المراكز الطبية والعيادات'),
          matching: find.text('عرض الكل'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no centers: no "see all" on Home', (tester) async {
      server.clinics = [];
      await pumpApp(tester);
      await scrollTo(
        tester,
        find.text('لا توجد مراكز أو عيادات في هذه المدينة بعد.'),
        feed(),
      );
      expect(seeAllOf('المراكز الطبية والعيادات'), findsNothing);
    });

    testWidgets('listing: loading, then error with retry, then the list', (
      tester,
    ) async {
      server.failing.add('/clinics/');
      final gate = server.gates['/clinics/'] = Completer<void>();
      await pumpApp(tester, start: Routes.clinics);
      expect(find.byType(MedicalCenterSkeleton), findsWidgets);

      gate.complete();
      await settle(tester);
      expect(find.byType(AppErrorView), findsOneWidget);

      server.failing.clear();
      await tap(tester, find.text('إعادة المحاولة'));
      expect(find.byType(AppErrorView), findsNothing);
      expect(find.text('عيادة 1'), findsOneWidget);
    });

    testWidgets('listing: empty says so', (tester) async {
      server.clinics = [];
      await pumpApp(tester, start: Routes.clinics);
      expect(
        find.text('لا توجد مراكز أو عيادات في هذه المدينة بعد.'),
        findsOneWidget,
      );
    });

    testWidgets('listing: a failed next page keeps the list and offers retry', (
      tester,
    ) async {
      await pumpApp(tester, start: Routes.clinics);
      server.failing.add('/clinics/');
      await tester.drag(listOf(MedicalCentersScreen), const Offset(0, -6000));
      await settle(tester);
      expect(find.byType(MedicalCenterCard), findsWidgets);
      final retry = find.text('إعادة المحاولة');
      expect(retry, findsOneWidget);

      server.failing.clear();
      await tap(tester, retry);
      await scrollTo(
        tester,
        find.text('عيادة 30'),
        listOf(MedicalCentersScreen),
      );
      expect(find.text('عيادة 30'), findsOneWidget);
    });
  });

  group('articles', () {
    testWidgets('"see all" opens every article; one opens its page; back '
        'returns through both', (tester) async {
      await pumpApp(tester);
      final seeAll = find.text('عرض الكل (+21)'); // Home shows 4 of 25
      await scrollTo(tester, seeAll, feed());
      await tap(tester, seeAll);
      expect(find.byType(ArticlesScreen), findsOneWidget);
      expect(find.text('مقالات العيادة الطبية'), findsOneWidget);

      await scrollTo(tester, find.text('مقال 25'), listOf(ArticlesScreen));
      expect(server.queriesTo('/articles/').map((q) => q['page']), [1, 1, 2]);
      final listOffset = tester
          .state<ScrollableState>(listOf(ArticlesScreen))
          .position
          .pixels;

      await tap(tester, find.text('مقال 25'));
      expect(find.byType(ArticleDetailScreen), findsOneWidget);
      expect(find.text('مقال 25'), findsOneWidget);
      expect(find.text('الفقرة الأولى من المقال 25.'), findsOneWidget);

      await back(tester);
      expect(find.byType(ArticlesScreen), findsOneWidget);
      expect(
        tester.state<ScrollableState>(listOf(ArticlesScreen)).position.pixels,
        listOffset,
        reason: 'the listing is where it was left',
      );
      await back(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('an article on Home opens its page; back keeps Home\'s place', (
      tester,
    ) async {
      await pumpApp(tester);
      final card = find.text('مقال 2');
      await scrollTo(tester, card, feed());
      final homeOffset = tester.state<ScrollableState>(feed()).position.pixels;
      expect(homeOffset, greaterThan(0));

      await tap(
        tester,
        find.ancestor(of: card, matching: find.byType(ArticleCard)),
      );
      expect(find.byType(ArticleDetailScreen), findsOneWidget);
      expect(server.requests.last.path, '/articles/article-2/');

      await back(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.state<ScrollableState>(feed()).position.pixels, homeOffset);
    });

    testWidgets('the page shows what the API returns: category, date, '
        'reviewer and the body\'s blocks', (tester) async {
      await pumpApp(tester, start: Routes.articlePath('article-3'));
      expect(find.text('المقال'), findsOneWidget);
      expect(find.text('تغذية'), findsOneWidget);
      expect(find.text('مراجَع طبياً'), findsOneWidget);
      expect(find.text('مقال 3'), findsOneWidget);
      expect(find.text('14 مارس 2026'), findsOneWidget);
      expect(find.text('راجعه طبياً: د. سارة علي'), findsOneWidget);
      expect(find.text('مقدمة'), findsOneWidget);
      expect(find.text('شرب الماء'), findsOneWidget);
      expect(find.text('•'), findsNWidgets(2));
      // Not shown: anything the API did not send.
      expect(find.text('ملخص المقال 3'), findsNothing, reason: 'the body is');
    });

    testWidgets('no date, no reviewer, no body: only the excerpt, nothing '
        'invented', (tester) async {
      server.details['article-4'] = {
        ..._detail(4),
        'published_at': null,
        'reviewed_by_doctor': null,
        'is_certified': false,
        'content': '',
      };
      await pumpApp(tester, start: Routes.articlePath('article-4'));
      expect(find.text('ملخص المقال 4'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
      expect(find.textContaining('راجعه'), findsNothing);
      expect(find.text('مراجَع طبياً'), findsNothing);

      server.details['article-5'] = {
        ..._detail(5),
        'content': '',
        'excerpt': '',
      };
      await pumpApp(tester, start: Routes.articlePath('article-5'));
      expect(find.text('لا يتوفر نص لهذا المقال بعد.'), findsOneWidget);
    });

    testWidgets('a cover that fails to load leaves no gap or error', (
      tester,
    ) async {
      server.details['article-6'] = _detail(
        6,
        image: 'https://example.test/missing.png',
      );
      await pumpApp(tester, start: Routes.articlePath('article-6'));
      await settle(tester);
      expect(find.text('مقال 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading, then error with retry, then the article', (
      tester,
    ) async {
      server.failing.add('/articles/article-7/');
      final gate = server.gates['/articles/article-7/'] = Completer<void>();
      await pumpApp(tester, start: Routes.articlePath('article-7'));
      expect(find.byType(AppLoading), findsOneWidget);

      gate.complete();
      await settle(tester);
      expect(find.byType(AppErrorView), findsOneWidget);

      server.failing.clear();
      await tap(tester, find.text('إعادة المحاولة'));
      expect(find.text('مقال 7'), findsOneWidget);
    });

    testWidgets('an article that does not exist says so', (tester) async {
      await pumpApp(tester, start: Routes.articlePath('gone'));
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('مقدمة'), findsNothing);
    });

    testWidgets('listing: empty says so', (tester) async {
      server.articles = [];
      await pumpApp(tester, start: Routes.articles);
      expect(find.text('لا توجد مقالات منشورة حالياً.'), findsOneWidget);
    });

    testWidgets('listing: an error, and retry recovers', (tester) async {
      server.failing.add('/articles/');
      await pumpApp(tester, start: Routes.articles);
      expect(find.byType(AppErrorView), findsOneWidget);

      server.failing.clear();
      await tap(tester, find.text('إعادة المحاولة'));
      expect(find.byType(AppErrorView), findsNothing);
      expect(find.text('مقال 1'), findsOneWidget);
    });

    testWidgets('English: the screen reads left to right, the Arabic article '
        'right to left', (tester) async {
      await pumpApp(
        tester,
        start: Routes.articlePath('article-8'),
        locale: const Locale('en'),
      );
      expect(find.text('Article'), findsOneWidget);
      expect(find.text('Medically reviewed by د. سارة علي'), findsOneWidget);
      final title = tester.widget<Text>(find.text('مقال 8'));
      expect(title.textDirection, TextDirection.rtl);
      final paragraph = tester.getRect(find.text('الفقرة الأولى من المقال 8.'));
      // Right-aligned: it ends at the page's right gutter, not its left.
      expect(paragraph.right, closeTo(390 - 16, 1));
    });
  });

  group('no overflow', () {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final (width, scale) in const [(320.0, 1.6), (412.0, 1.0)]) {
        testWidgets(
          '${locale.languageCode}, ${width.toInt()}px, text x$scale',
          (tester) async {
            final size = Size(width, 700);
            server.details['article-1'] = _detail(1, title: _longTitle);
            for (final start in [
              Routes.articlePath('article-1'),
              Routes.articles,
              Routes.clinics,
            ]) {
              await pumpApp(
                tester,
                start: start,
                size: size,
                locale: locale,
                textScale: scale,
              );
              await tester.drag(
                find.byType(Scrollable).first,
                const Offset(0, -4000),
              );
              await settle(tester);
              expect(tester.takeException(), isNull, reason: start);
            }
          },
        );
      }
    }
  });
}

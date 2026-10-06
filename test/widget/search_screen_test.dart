import 'dart:async';

import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/api/envelope.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/doctors/doctors_screen.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:aleyada_mobile/features/doctors/providers.dart';
import 'package:aleyada_mobile/features/doctors/repository.dart';
import 'package:aleyada_mobile/features/doctors/search_state.dart';
import 'package:aleyada_mobile/features/doctors/widgets/search_filter_row.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/api_fixtures.dart';
import '../fixtures/search_fakes.dart';
import 'harness.dart';

final _cities = {
  'data': [
    {
      'id': '1',
      'slug': 'cairo',
      'name_ar': 'القاهرة',
      'name_en': 'Cairo',
      'areas': [
        {'id': 'a', 'slug': 'maadi', 'name_ar': 'المعادي', 'name_en': 'Maadi'},
      ],
    },
  ],
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

void main() {
  late TestHarness h;
  late FakeDirectory dir;
  late ProviderContainer container;

  // Real glyph widths, or the test engine's square glyphs report overflows that
  // cannot happen.
  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    h.adapter
      ..onGet('/specializations/', (s) => s.reply(200, specializationsResponse))
      ..onGet('/locations/cities/', (s) => s.reply(200, _cities))
      ..onGet(
        '/clinics/',
        (s) => s.reply(200, {
          'data': [
            {
              'id': 'c1',
              'slug': 'dar-al-fouad',
              'name_ar': 'مستشفى دار الفؤاد',
              'address_ar': 'أكتوبر',
              'avg_rating': '4.5',
              'reviews_count': 3,
            },
          ],
          'meta': {
            'pagination': {'count': 1, 'page': 1, 'pages': 1, 'page_size': 3},
          },
          'errors': <dynamic>[],
        }),
      );
    dir = FakeDirectory(h.client, handler: (q) async => pageOf(page: q.page));
    container = ProviderContainer(
      overrides: [...h.overrides, directoryRepositoryProvider.overrideWithValue(dir)],
    );
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpSearch(
    WidgetTester tester, {
    Locale locale = const Locale('ar'),
    Size size = const Size(360, 800),
    double textScale = 1.0,
    bool autofocus = false,
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
          home: DoctorsScreen(autofocus: autofocus),
        ),
      ),
    );
    await settle(tester);
  }

  DoctorQuery query() => container.read(doctorQueryProvider);
  void setQuery(DoctorQuery q) => container.read(doctorQueryProvider.notifier).state = q;
  Finder field() => find.byType(TextField);
  Finder feed() => find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable));

  group('instant search', () {
    testWidgets('typing searches by itself, after a pause, without a Search button', (tester) async {
      await pumpSearch(tester);
      expect(dir.calls, hasLength(1), reason: 'the initial, unfiltered list');

      await tester.enterText(field(), 'طبيب عيون');
      await tester.pump(const Duration(milliseconds: 200));
      expect(dir.calls, hasLength(1), reason: 'still inside the debounce window');

      await tester.pump(const Duration(milliseconds: 300));
      expect(dir.calls, hasLength(2));
      expect(dir.searches.last, 'طبيب عيون');
      await settle(tester, 3);
    });

    testWidgets('rapid typing makes one request, for the final text', (tester) async {
      await pumpSearch(tester);
      for (final text in ['ا', 'اح', 'احم', 'احمد', 'احمد ', 'احمد ج', 'احمد جمال']) {
        await tester.enterText(field(), text);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(dir.searches.where((s) => s != null), ['احمد جمال']);
      await settle(tester, 3);
    });

    testWidgets('a single character is not sent', (tester) async {
      await pumpSearch(tester);
      await tester.enterText(field(), 'ع');
      await tester.pump(const Duration(seconds: 1));
      expect(dir.calls, hasLength(1));
    });

    testWidgets('whitespace only is not a search', (tester) async {
      await pumpSearch(tester);
      await tester.enterText(field(), '      ');
      await tester.pump(const Duration(seconds: 1));
      expect(dir.calls, hasLength(1));
    });

    testWidgets('English and mixed Arabic/English text pass through', (tester) async {
      await pumpSearch(tester);
      await tester.enterText(field(), 'Dr أحمد');
      await tester.pump(const Duration(milliseconds: 500));
      expect(dir.searches.last, 'Dr أحمد');
      await settle(tester, 3);
    });

    testWidgets('the keyboard search key runs it immediately and remembers it', (tester) async {
      await pumpSearch(tester);
      await tester.enterText(field(), 'باطنة');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(dir.searches.last, 'باطنة', reason: 'no waiting for the pause');
      expect(container.read(recentSearchesProvider), ['باطنة']);
    });

    testWidgets('clearing the box returns to the unfiltered list', (tester) async {
      await pumpSearch(tester);
      await tester.enterText(field(), 'قلب');
      await tester.pump(const Duration(milliseconds: 500));
      expect(query().search, 'قلب');

      await tester.tap(find.byTooltip('مسح البحث'));
      await settle(tester, 3);
      expect(query().search, isNull);
      expect(dir.searches.last, isNull);
    });

    testWidgets('re-entering a previous query searches it again', (tester) async {
      await pumpSearch(tester);
      await tester.enterText(field(), 'قلب');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(field(), 'عيون');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(field(), 'قلب');
      await tester.pump(const Duration(milliseconds: 500));
      expect(dir.searches.where((s) => s != null), ['قلب', 'عيون', 'قلب']);
      await settle(tester, 3);
    });
  });

  group('results', () {
    testWidgets('the count comes from the response, not a constant', (tester) async {
      await pumpSearch(tester);
      expect(find.text('تم العثور على 17 طبيب'), findsOneWidget);
    });

    testWidgets('each card shows what the list provides', (tester) async {
      await pumpSearch(tester);
      expect(find.text('دكتور رقم 1'), findsOneWidget);
      expect(find.textContaining('300.00'), findsWidgets, reason: 'fee');
      expect(find.text('احجز موعد كشف'), findsWidgets);
      expect(find.text('الحجز الإلكتروني متاح'), findsWidgets);
    });

    testWidgets('a contact-only doctor offers the profile, not booking', (tester) async {
      dir.handler = (q) async => Paginated(
        items: [doctorNo(1, bookable: false)],
        pagination: const Pagination(count: 1, page: 1, pages: 1, pageSize: 20),
      );
      await pumpSearch(tester);
      expect(find.text('احجز موعد كشف'), findsNothing);
      expect(find.text('عرض الملف'), findsOneWidget);
    });

    testWidgets('while loading for the first time there are skeletons, not a spinner screen', (
      tester,
    ) async {
      final gate = Completer<Paginated<DoctorCard>>();
      dir.handler = (_) => gate.future;
      await pumpSearch(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('دكتور رقم 1'), findsNothing);
      gate.complete(pageOf());
      await settle(tester);
      expect(find.text('دكتور رقم 1'), findsOneWidget);
    });

    testWidgets('old results stay (dimmed) while a new search loads', (tester) async {
      await pumpSearch(tester);
      final gate = Completer<Paginated<DoctorCard>>();
      dir.handler = (_) => gate.future;

      await tester.enterText(field(), 'قلب');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('دكتور رقم 1'), findsOneWidget, reason: 'not blanked');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      gate.complete(pageOf(total: 1));
      await settle(tester);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('no results: a clear message and a way out that clears the filters', (tester) async {
      dir.handler = (q) async => q.hasFilters
          ? Paginated.emptyOf<DoctorCard>()
          : pageOf();
      setQuery(const DoctorQuery(city: 'cairo', minRating: 4.5));
      await pumpSearch(tester);

      expect(find.text('لم نجد أطباء مطابقين لبحثك'), findsOneWidget);
      expect(find.textContaining('جرّب تغيير التخصص'), findsOneWidget);

      await tester.tap(find.text('مسح الفلاتر'));
      await settle(tester);
      expect(query().activeFilterCount, 0);
      expect(find.text('دكتور رقم 1'), findsOneWidget);
    });

    testWidgets('no results and no filters: no pointless clear button', (tester) async {
      dir.handler = (q) async => Paginated.emptyOf<DoctorCard>();
      await pumpSearch(tester);
      expect(find.text('لم نجد أطباء مطابقين لبحثك'), findsOneWidget);
      expect(find.text('مسح الفلاتر'), findsNothing);
    });

    testWidgets('an API failure shows a message and retry, and keeps the query and filters', (
      tester,
    ) async {
      var fail = true;
      dir.handler = (q) async {
        if (fail) throw Exception('server exploded: 500 stacktrace');
        return pageOf();
      };
      setQuery(const DoctorQuery(search: 'قلب', city: 'cairo'));
      await pumpSearch(tester);

      expect(find.text('حدث خطأ'), findsOneWidget);
      expect(find.textContaining('stacktrace'), findsNothing, reason: 'no raw exception text');
      expect(query(), const DoctorQuery(search: 'قلب', city: 'cairo'));
      expect(tester.widget<TextField>(field()).controller!.text, 'قلب');

      fail = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(find.text('دكتور رقم 1'), findsOneWidget);
      expect(query().city, 'cairo');
    });
  });

  group('filters and chips', () {
    testWidgets('applied filters appear as chips and the button shows how many', (tester) async {
      setQuery(const DoctorQuery(specialization: 'cardiology', city: 'cairo', minRating: 4.5, maxFee: '300'));
      await pumpSearch(tester);

      Finder chip(String t) => find.descendant(of: find.byType(SearchFilterRow), matching: find.text(t));
      expect(chip('قلب'), findsOneWidget);
      expect(chip('القاهرة'), findsOneWidget);
      expect(find.text('تقييم 4.5+'), findsOneWidget);
      expect(find.text('حتى 300 ج.م'), findsOneWidget);
      expect(find.text('4'), findsOneWidget, reason: 'count on the filter button');
    });

    testWidgets('removing one chip reloads without a Search press', (tester) async {
      setQuery(const DoctorQuery(specialization: 'cardiology', minRating: 4.5));
      await pumpSearch(tester);
      final before = dir.calls.length;

      await tester.ensureVisible(find.text('تقييم 4.5+'));
      await tester.pump();
      await tester.tap(find.text('تقييم 4.5+'));
      await settle(tester, 3);

      expect(query(), const DoctorQuery(specialization: 'cardiology'));
      expect(dir.calls.length, before + 1);
      expect(find.text('تقييم 4.5+'), findsNothing);
    });

    testWidgets('removing the city also drops its area', (tester) async {
      setQuery(const DoctorQuery(city: 'cairo', area: 'maadi'));
      await pumpSearch(tester);
      expect(find.text('المعادي'), findsOneWidget);

      await tester.ensureVisible(find.text('القاهرة'));
      await tester.pump();
      await tester.tap(find.text('القاهرة'));
      await settle(tester, 3);
      expect(query().city, isNull);
      expect(query().area, isNull);
    });

    testWidgets('clear all removes every filter and keeps the search text', (tester) async {
      setQuery(const DoctorQuery(search: 'عيون', city: 'cairo', gender: 'female', bookingEnabled: true));
      await pumpSearch(tester);
      expect(find.text('طبيبة'), findsOneWidget);
      expect(find.text('حجز إلكتروني'), findsOneWidget);

      await tester.tap(find.text('مسح الكل'));
      await settle(tester, 3);
      expect(query(), const DoctorQuery(search: 'عيون'));
      expect(find.text('مسح الكل'), findsNothing);
    });

    testWidgets('the sheet applies several filters at once and chips follow', (tester) async {
      await pumpSearch(tester);
      await tester.tap(find.text('تصفية متقدمة'));
      await settle(tester);

      // The sheet is long; bring each control into view before tapping it.
      final sheet = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Scrollable),
      );
      for (final label in ['4.5+', '300 ج.م', 'طبيبة']) {
        await tester.scrollUntilVisible(find.text(label), 200, scrollable: sheet.first);
        await tester.tap(find.text(label));
        await tester.pump();
      }
      await tester.tap(find.text('تطبيق'));
      await settle(tester);

      expect(query().minRating, 4.5);
      expect(query().maxFee, '300');
      expect(query().gender, 'female');
      expect(query().activeFilterCount, 3);
      expect(find.text('تقييم 4.5+'), findsOneWidget);
      expect(find.text('حتى 300 ج.م'), findsOneWidget);
    });

    testWidgets('the sheet does not offer filters the backend cannot apply', (tester) async {
      await pumpSearch(tester);
      await tester.tap(find.text('تصفية متقدمة'));
      await settle(tester);
      expect(find.textContaining('متاح الآن'), findsNothing);
      expect(find.textContaining('مستشفى'), findsNothing, reason: 'no facility-type filter');
      expect(find.textContaining('أدنى'), findsNothing, reason: 'no minimum price');
    });
  });

  group('sorting', () {
    testWidgets('choosing a sort reloads with it and the control shows it', (tester) async {
      await pumpSearch(tester);
      await tester.tap(find.text('الأنسب'));
      await settle(tester, 3);
      await tester.tap(find.text('الأقل سعراً').last);
      await settle(tester, 8);

      expect(query().sort, DoctorSort.feeAsc);
      expect(dir.calls.last.toQuery()['sort'], 'fee_asc');
      expect(find.text('الأقل سعراً'), findsOneWidget);
    });

    testWidgets('going back to the default sort sends no sort', (tester) async {
      setQuery(const DoctorQuery(sort: DoctorSort.rating));
      await pumpSearch(tester);
      await tester.tap(find.text('الأعلى تقييماً'));
      await settle(tester, 3);
      await tester.tap(find.text('الأنسب').last);
      await settle(tester, 8);
      expect(query().sort, isNull);
      expect(dir.calls.last.toQuery().containsKey('sort'), isFalse);
    });
  });

  group('suggestions and recents', () {
    testWidgets('typing suggests a matching specialty, and tapping it filters by it', (tester) async {
      await pumpSearch(tester);
      await tester.tap(field());
      await tester.enterText(field(), 'قلب');
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester, 3);

      expect(find.text('تخصص'), findsOneWidget);
      await tester.tap(find.text('تخصص'));
      await settle(tester, 3);

      expect(query().specialization, 'cardiology');
      expect(query().search, isNull);
      expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
    });

    testWidgets('a clinic suggestion comes from the real clinics endpoint', (tester) async {
      await pumpSearch(tester);
      await tester.tap(field());
      await tester.enterText(field(), 'دار الفؤاد');
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester, 3);

      expect(find.text('مستشفى دار الفؤاد'), findsOneWidget);
      await tester.tap(find.text('مستشفى دار الفؤاد'));
      await settle(tester, 3);
      expect(query().clinic, 'dar-al-fouad');
      expect(find.text('مستشفى دار الفؤاد'), findsOneWidget, reason: 'now a chip');
    });

    testWidgets('no matching data, no suggestions', (tester) async {
      await pumpSearch(tester);
      await tester.tap(field());
      await tester.enterText(field(), 'zzzzzz');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('اقتراحات'), findsNothing);
    });

    testWidgets('an empty focused box shows recent searches; each can be removed or all cleared', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'recent_doctor_searches': ['عمليات العيون', 'دكتور أسنان', 'باطنة'],
      });
      container.dispose();
      container = ProviderContainer(
        overrides: [...h.overrides, directoryRepositoryProvider.overrideWithValue(dir)],
      );
      await pumpSearch(tester);
      await tester.tap(field());
      await settle(tester, 3);

      expect(find.text('عمليات البحث الأخيرة'), findsOneWidget);
      expect(find.text('عمليات العيون'), findsOneWidget);

      await tester.tap(find.byTooltip('إزالة من عمليات البحث الأخيرة').first);
      await settle(tester, 3);
      expect(find.text('عمليات العيون'), findsNothing);
      expect(find.text('باطنة'), findsOneWidget);

      await tester.tap(find.text('مسح الكل'));
      await settle(tester, 3);
      expect(find.text('عمليات البحث الأخيرة'), findsNothing);
    });

    testWidgets('tapping a recent search runs it', (tester) async {
      SharedPreferences.setMockInitialValues({
        'recent_doctor_searches': ['عمليات العيون'],
      });
      container.dispose();
      container = ProviderContainer(
        overrides: [...h.overrides, directoryRepositoryProvider.overrideWithValue(dir)],
      );
      await pumpSearch(tester);
      await tester.tap(field());
      await settle(tester, 3);
      await tester.tap(find.text('عمليات العيون'));
      await settle(tester, 3);
      expect(query().search, 'عمليات العيون');
      expect(dir.searches.last, 'عمليات العيون');
    });

    testWidgets('the idle panel offers real specialties, with no invented "popular" list', (
      tester,
    ) async {
      await pumpSearch(tester);
      await tester.tap(field());
      await settle(tester, 3);
      expect(find.text('تصفح حسب التخصص'), findsOneWidget);
      expect(find.text('أسنان'), findsOneWidget);
      expect(find.textContaining('الأكثر بحثاً'), findsNothing);
    });
  });

  group('pagination', () {
    testWidgets('scrolling near the end loads the next page and appends it', (tester) async {
      dir.handler = (q) async => pageOf(page: q.page, perPage: 6, total: 18);
      await pumpSearch(tester, size: const Size(360, 640));

      final list = feed();
      await tester.drag(list, const Offset(0, -1500));
      await settle(tester, 4);
      await tester.drag(list, const Offset(0, -1500));
      await settle(tester, 4);

      expect(dir.calls.where((q) => q.page == 2), hasLength(1), reason: 'once, not per scroll tick');
      final shown = container.read(doctorListProvider).valueOrNull!.items.map((d) => d.id).toList();
      expect(shown.take(12), [for (var i = 1; i <= 12; i++) 'doctor-$i'], reason: 'appended, in order');
      expect(shown.toSet(), hasLength(shown.length), reason: 'no doctor twice');
    });
  });

  group('layout', () {
    for (final entry in {
      'small phone': const Size(320, 568),
      'standard phone': const Size(360, 800),
      'large phone': const Size(412, 915),
    }.entries) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final scale in const [1.0, 1.6]) {
          testWidgets('no overflow: ${entry.key}, ${locale.languageCode}, text x$scale', (tester) async {
            setQuery(
              const DoctorQuery(
                specialization: 'cardiology',
                city: 'cairo',
                area: 'maadi',
                minRating: 4.5,
                maxFee: '500',
                gender: 'female',
                bookingEnabled: true,
              ),
            );
            await pumpSearch(tester, size: entry.value, locale: locale, textScale: scale);
            final list = feed();
            for (var i = 0; i < 3; i++) {
              await tester.drag(list, const Offset(0, -400));
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('the idle panel and suggestions fit a small phone at large text', (tester) async {
      await pumpSearch(tester, size: const Size(320, 568), textScale: 1.6);
      await tester.tap(field());
      await settle(tester, 3);
      expect(tester.takeException(), isNull);
      await tester.enterText(field(), 'قلب');
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester, 3);
      expect(tester.takeException(), isNull);
    });
  });

  group('navigation', () {
    testWidgets('tapping a result opens that doctor and remembers the search', (tester) async {
      setQuery(const DoctorQuery(search: 'قلب'));
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DoctorsScreen()),
          GoRoute(
            path: Routes.doctor,
            builder: (_, s) => Scaffold(body: Text('profile:${s.pathParameters['slug']}')),
          ),
        ],
      );
      tester.view
        ..physicalSize = const Size(720, 1600)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ar'),
            theme: AppTheme.light(),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('دكتور رقم 1'));
      await settle(tester, 3);
      expect(find.text('profile:doctor-1'), findsOneWidget);
      expect(container.read(recentSearchesProvider), ['قلب']);
    });

    testWidgets('arriving from Home with focus=1 puts the cursor in the box', (tester) async {
      await pumpSearch(tester, autofocus: true);
      expect(tester.widget<TextField>(field()).focusNode!.hasFocus, isTrue);
    });
  });
}

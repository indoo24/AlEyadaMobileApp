import 'package:aleyada_mobile/app/bottom_nav.dart';
import 'package:aleyada_mobile/app/shell.dart';
import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/core/widgets/async_value_view.dart';
import 'package:aleyada_mobile/features/doctors/doctors_screen.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:aleyada_mobile/features/doctors/widgets/doctor_rating.dart';
import 'package:aleyada_mobile/features/doctors/widgets/doctor_result_card.dart';
import 'package:aleyada_mobile/features/favorites/favorites_screen.dart';
import 'package:aleyada_mobile/features/favorites/providers.dart';
import 'package:aleyada_mobile/features/favorites/widgets/favorite_button.dart';
import 'package:aleyada_mobile/features/home/home_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/api_fixtures.dart';
import 'harness.dart';

Map<String, dynamic> _envelope(Object? data) => {
  'data': data,
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

/// `GET /doctors/<slug>/` for one of the fixture doctors.
Map<String, dynamic> _detail(Map<String, dynamic> card, {Object? avg, Object? count}) => _envelope({
  ...card,
  if (avg != null) 'avg_rating': avg,
  if (count != null) 'reviews_count': count,
  'clinics': <dynamic>[],
  'specializations': <dynamic>[],
  'services': <dynamic>[],
  'education': <dynamic>[],
  'certificates': <dynamic>[],
});

final _first = doctorCardData; // mohamed-ebrahim
final _second = doctorCardData2; // ahmed-reda
final String _firstId = _first['id'] as String;
final String _secondId = _second['id'] as String;
const _firstSlug = 'mohamed-ebrahim';
const _secondSlug = 'ahmed-reda';

String _row(String id, String slug) => '{"id":"$id","slug":"$slug"}';

void main() {
  late TestHarness h;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  void seed(List<String> rows, {String? user}) => SharedPreferences.setMockInitialValues({
    FavoritesController.storageKey(user): rows,
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    h.adapter
      ..onGet('/specializations/', (s) => s.reply(200, specializationsResponse))
      ..onGet('/doctors/', (s) => s.reply(200, doctorListResponse))
      ..onGet('/doctors/$_firstSlug/', (s) => s.reply(200, _detail(_first, avg: '4.95', count: 142)))
      ..onGet('/doctors/$_secondSlug/', (s) => s.reply(200, _detail(_second)));
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget app(Widget home, {Locale locale = const Locale('ar')}) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      theme: AppTheme.light(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: home,
    ),
  );

  Future<void> pumpIn(WidgetTester tester, Widget child, {Size size = const Size(360, 800)}) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(child));
    await settle(tester);
  }

  Finder heartOn([Finder? within]) => find.descendant(
    of: within ?? find.byType(FavoriteButton),
    matching: find.byIcon(Icons.favorite_rounded),
  );
  Finder heartOff([Finder? within]) => find.descendant(
    of: within ?? find.byType(FavoriteButton),
    matching: find.byIcon(Icons.favorite_border_rounded),
  );

  // ---------------------------------------------------------------- rating
  group('rating', () {
    Future<void> show(WidgetTester tester, {Object? avg, Object? count}) async {
      final d = DoctorCard.fromJson({..._first, 'avg_rating': avg, 'reviews_count': count});
      await pumpIn(tester, Scaffold(body: Center(child: DoctorRating(doctor: d))));
    }

    testWidgets('the real value and the real count', (tester) async {
      await show(tester, avg: '4.95', count: 142);
      expect(find.text('4.95'), findsOneWidget, reason: 'not rounded to 5.0');
      expect(find.text('(142 تقييم)'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('one review reads naturally', (tester) async {
      await show(tester, avg: '5.00', count: 1);
      expect(find.text('5.0'), findsOneWidget);
      expect(find.text('(تقييم واحد)'), findsOneWidget);
    });

    testWidgets('a rating with no count is shown without inventing one', (tester) async {
      await show(tester, avg: '4.50', count: 0);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.textContaining('تقييم'), findsNothing);
    });

    testWidgets('an unrated doctor says so instead of showing 0.0', (tester) async {
      await show(tester, avg: '0.00', count: 0);
      expect(find.text('لا توجد تقييمات'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('a missing rating is not 0.0 either', (tester) async {
      await show(tester, avg: null, count: null);
      expect(find.text('لا توجد تقييمات'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('the same in English', (tester) async {
      final d = DoctorCard.fromJson({..._first, 'avg_rating': '4.60', 'reviews_count': 12});
      tester.view
        ..physicalSize = const Size(720, 1600)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(Scaffold(body: Center(child: DoctorRating(doctor: d))), locale: const Locale('en')),
      );
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('(12 reviews)'), findsOneWidget);
    });

    testWidgets('every doctor view reads the same fields', (tester) async {
      // Search/Favorites card.
      final d = DoctorCard.fromJson({..._first, 'avg_rating': '4.95', 'reviews_count': 142});
      await pumpIn(tester, Scaffold(body: SingleChildScrollView(child: DoctorResultCard(doctor: d, onOpen: () {}))));
      expect(find.text('4.95'), findsOneWidget);
      expect(find.text('(142 تقييم)'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------- heart
  group('favourite button', () {
    Future<void> pumpHeart(WidgetTester tester) => pumpIn(
      tester,
      Scaffold(body: Center(child: FavoriteButton(doctorId: _firstId, slug: _firstSlug))),
    );

    testWidgets('outline when not a favourite, filled when it is — without leaving the screen', (
      tester,
    ) async {
      await pumpHeart(tester);
      expect(heartOff(), findsOneWidget);
      expect(heartOn(), findsNothing);

      await tester.tap(find.byType(FavoriteButton));
      await settle(tester, 4);
      expect(heartOn(), findsOneWidget);
      expect(heartOff(), findsNothing);
      expect(find.byType(FavoriteButton), findsOneWidget, reason: 'still on the same screen');

      await tester.tap(find.byType(FavoriteButton));
      await settle(tester, 4);
      expect(heartOff(), findsOneWidget);
    });

    testWidgets('it is a labelled toggle for screen readers', (tester) async {
      await pumpHeart(tester);
      expect(find.bySemanticsLabel('إضافة إلى المفضلة'), findsOneWidget);
      await tester.tap(find.byType(FavoriteButton));
      await settle(tester, 4);
      expect(find.bySemanticsLabel('إزالة من المفضلة'), findsOneWidget);
    });

    testWidgets('it is still a favourite after the app is closed and reopened', (tester) async {
      await pumpHeart(tester);
      await tester.tap(find.byType(FavoriteButton));
      await settle(tester, 4);

      // "Close" the app: throw away every provider. SharedPreferences stays.
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      container = ProviderContainer(overrides: h.overrides);

      await pumpHeart(tester);
      expect(heartOn(), findsOneWidget);
    });

    testWidgets('a save that fails puts the heart back and tells the person', (tester) async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          ...h.overrides,
          favoritesStoreProvider.overrideWithValue(_FailingStore()),
        ],
      );
      await pumpHeart(tester);
      await tester.tap(find.byType(FavoriteButton));
      await settle(tester, 4);
      expect(heartOff(), findsOneWidget);
      expect(find.text('تعذّر حفظ التغيير. حاول مرة أخرى.'), findsOneWidget);
    });

    testWidgets('tapping the heart does not open the doctor', (tester) async {
      var opened = 0;
      final d = DoctorCard.fromJson({..._first, 'avg_rating': '4.5', 'reviews_count': 3});
      await pumpIn(
        tester,
        Scaffold(body: SingleChildScrollView(child: DoctorResultCard(doctor: d, onOpen: () => opened++))),
      );
      await tester.tap(find.byType(FavoriteButton));
      await settle(tester, 4);
      expect(opened, 0);
      expect(heartOn(), findsOneWidget);
    });
  });

  // ------------------------------------------------------------ favourites
  group('favourites screen', () {
    GoRouter routerFor() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const FavoritesScreen()),
        GoRoute(path: Routes.doctor, builder: (_, s) => Scaffold(body: Text('profile:${s.pathParameters['slug']}'))),
        GoRoute(path: Routes.doctors, builder: (_, s) => Scaffold(body: Text('search:${s.uri.queryParameters['focus']}'))),
      ],
    );

    Future<void> pumpRouted(WidgetTester tester, GoRouter router) async {
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
    }

    testWidgets('lists the favourites with the shared card: rating, fee, booking, heart', (tester) async {
      seed([_row(_firstId, _firstSlug), _row(_secondId, _secondSlug)]);
      container.dispose();
      container = ProviderContainer(overrides: h.overrides);
      await pumpRouted(tester, routerFor());

      expect(find.text('الأطباء المفضلون'), findsOneWidget);
      expect(find.byType(DoctorResultCard), findsNWidgets(2));
      expect(find.text('محمد ابراهيم'), findsOneWidget);
      expect(find.text('4.95'), findsOneWidget, reason: 'live detail, not a saved copy');
      expect(find.text('(142 تقييم)'), findsOneWidget);
      expect(find.textContaining('300.00'), findsWidgets);
      expect(find.text('احجز موعد كشف'), findsWidgets);
      expect(heartOn(), findsNWidgets(2));
    });

    testWidgets('while details load there are skeleton cards, not a blank screen', (tester) async {
      seed([_row(_firstId, _firstSlug)]);
      container.dispose();
      container = ProviderContainer(overrides: h.overrides);
      h.adapter.onGet(
        '/doctors/$_firstSlug/',
        (s) => s.reply(200, _detail(_first), delay: const Duration(seconds: 2)),
      );
      await pumpRouted(tester, routerFor());
      expect(find.byType(DoctorResultCard), findsNothing);
      expect(find.byType(Skeleton), findsWidgets);

      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(find.byType(DoctorResultCard), findsOneWidget);
    });

    testWidgets('empty: a message, an explanation and a way to find doctors', (tester) async {
      final router = routerFor();
      await pumpRouted(tester, router);

      expect(find.text('لم تقم بإضافة أطباء للمفضلة بعد'), findsOneWidget);
      expect(find.text('أضف الأطباء الذين تفضلهم للوصول إليهم بسهولة لاحقًا.'), findsOneWidget);

      await tester.tap(find.text('البحث عن طبيب'));
      await settle(tester, 4);
      expect(find.text('search:1'), findsOneWidget, reason: 'opens Search with the cursor in the box');
    });

    testWidgets('removing a favourite slides it out, then the empty state appears', (tester) async {
      seed([_row(_firstId, _firstSlug), _row(_secondId, _secondSlug)]);
      container.dispose();
      container = ProviderContainer(overrides: h.overrides);
      await pumpRouted(tester, routerFor());
      expect(find.byType(DoctorResultCard), findsNWidgets(2));

      await tester.tap(find.byType(FavoriteButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DoctorResultCard), findsNWidgets(2), reason: 'still sliding out');

      await settle(tester, 5);
      expect(find.byType(DoctorResultCard), findsOneWidget);
      expect(container.read(favoritesProvider).entries, hasLength(1));
      expect(find.text('لم تقم بإضافة أطباء للمفضلة بعد'), findsNothing);

      await tester.tap(find.byType(FavoriteButton).first);
      await settle(tester, 8);
      expect(find.byType(DoctorResultCard), findsNothing);
      expect(find.text('لم تقم بإضافة أطباء للمفضلة بعد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a card opens that doctor', (tester) async {
      seed([_row(_firstId, _firstSlug)]);
      container.dispose();
      container = ProviderContainer(overrides: h.overrides);
      await pumpRouted(tester, routerFor());

      await tester.tap(find.text('محمد ابراهيم'));
      await settle(tester, 4);
      expect(find.text('profile:$_firstSlug'), findsOneWidget);
    });

    testWidgets('the booking button goes to the doctor, where booking starts', (tester) async {
      seed([_row(_firstId, _firstSlug)]);
      container.dispose();
      container = ProviderContainer(overrides: h.overrides);
      await pumpRouted(tester, routerFor());

      await tester.tap(find.text('احجز موعد كشف'));
      await settle(tester, 4);
      expect(find.text('profile:$_firstSlug'), findsOneWidget);
    });

    testWidgets('a favourite that cannot be loaded can be retried or removed', (tester) async {
      seed([_row(_firstId, _firstSlug)]);
      container.dispose();
      container = ProviderContainer(overrides: h.overrides);
      h.adapter.onGet('/doctors/$_firstSlug/', (s) => s.reply(500, _envelope(null)));
      await pumpRouted(tester, routerFor());
      expect(find.text('تعذّر تحميل بيانات هذا الطبيب.'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);

      // The server recovers.
      h.adapter.onGet('/doctors/$_firstSlug/', (s) => s.reply(200, _detail(_first)));
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(find.byType(DoctorResultCard), findsOneWidget);
    });

    testWidgets('an unreadable list shows an error with retry, not a blank screen', (tester) async {
      container.dispose();
      final store = _FlakyReadStore();
      container = ProviderContainer(
        overrides: [...h.overrides, favoritesStoreProvider.overrideWithValue(store)],
      );
      await pumpRouted(tester, routerFor());
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      store.fail = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(find.text('لم تقم بإضافة أطباء للمفضلة بعد'), findsOneWidget);
    });

    testWidgets('fits a small phone at large text', (tester) async {
      seed([_row(_firstId, _firstSlug), _row(_secondId, _secondSlug)]);
      container.dispose();
      container = ProviderContainer(overrides: h.overrides);
      tester.view
        ..physicalSize = const Size(640, 1136)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ar'),
            theme: AppTheme.light(),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const FavoritesScreen(),
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  // ------------------------------------------------------- across the app
  group('one source of truth across Home, Search and Favorites', () {
    testWidgets('favourite on Home → still a favourite in Search and Favorites → remove → gone everywhere', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: Routes.home,
        routes: [
          ShellRoute(
            builder: (_, __, child) => AppShell(child: child),
            routes: [
              GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
              GoRoute(path: Routes.doctors, builder: (_, __) => const DoctorsScreen()),
              GoRoute(path: Routes.bookings, builder: (_, __) => const Scaffold(body: Text('bookings'))),
              GoRoute(path: Routes.favorites, builder: (_, __) => const FavoritesScreen()),
              GoRoute(path: Routes.account, builder: (_, __) => const Scaffold(body: Text('account'))),
            ],
          ),
        ],
      );
      tester.view
        ..physicalSize = const Size(720, 1700)
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

      Future<void> openTab(String label) async {
        await tester.tap(
          find.descendant(of: find.byType(AppShell), matching: find.text(label)).last,
        );
        await settle(tester, 6);
      }

      Finder cardOf(String name) =>
          find.ancestor(of: find.text(name), matching: find.byType(DoctorResultCard)).first;

      // 1. Home: favourite the first recommended doctor.
      expect(container.read(favoritesProvider).contains(_firstId), isFalse);
      final homeCard = find.ancestor(of: find.text('محمد ابراهيم'), matching: find.byType(Container)).first;
      expect(homeCard, findsOneWidget);
      await tester.tap(find.byType(FavoriteButton).first);
      await settle(tester, 4);
      expect(container.read(favoritesProvider).contains(_firstId), isTrue);
      expect(heartOn(), findsOneWidget);

      // 2. Search: the same doctor is already a favourite there.
      await openTab('الأطباء');
      expect(find.byType(DoctorResultCard), findsNWidgets(2));
      expect(heartOn(cardOf('محمد ابراهيم')), findsOneWidget, reason: 'same doctor, same heart');
      expect(heartOn(cardOf('احمد رضا')), findsNothing);

      // 3. Favorites: the doctor is listed.
      await openTab('المفضلة');
      expect(find.byType(DoctorResultCard), findsOneWidget);
      expect(find.text('محمد ابراهيم'), findsOneWidget);

      // 4. Remove it there.
      await tester.tap(find.byType(FavoriteButton).first);
      await settle(tester, 8);
      expect(find.text('لم تقم بإضافة أطباء للمفضلة بعد'), findsOneWidget);

      // 5. Back to Search and Home: no longer a favourite anywhere.
      await openTab('الأطباء');
      expect(heartOn(), findsNothing);
      expect(heartOff(), findsWidgets);

      await openTab('الرئيسية');
      expect(heartOn(), findsNothing);
      expect(container.read(favoritesProvider).entries, isEmpty);
    });

    testWidgets(
      'under the floating dock, Search and Favorites scroll their last doctor clear of it',
      (tester) async {
        seed([_row(_firstId, _firstSlug), _row(_secondId, _secondSlug)]);
        Widget stub(String name) => Scaffold(body: Text(name));
        final router = GoRouter(
          initialLocation: Routes.doctors,
          routes: [
            ShellRoute(
              builder: (_, __, child) => AppShell(child: child),
              routes: [
                GoRoute(path: Routes.home, builder: (_, __) => stub('home')),
                GoRoute(path: Routes.doctors, builder: (_, __) => const DoctorsScreen()),
                GoRoute(path: Routes.bookings, builder: (_, __) => stub('bookings')),
                GoRoute(path: Routes.favorites, builder: (_, __) => const FavoritesScreen()),
                GoRoute(path: Routes.account, builder: (_, __) => stub('account')),
              ],
            ),
          ],
        );
        // A small phone with a gesture bar, so both lists are longer than the screen.
        tester.view
          ..physicalSize = const Size(720, 1120)
          ..devicePixelRatio = 2
          ..padding = const FakeViewPadding(bottom: 48)
          ..viewPadding = const FakeViewPadding(bottom: 48);
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

        final dockTop = tester
            .getRect(
              find.descendant(
                of: find.byType(GlassBottomNav),
                matching: find.byType(BackdropFilter),
              ),
            )
            .top;

        /// The tab's main list: the tallest vertical scrollable on screen.
        Finder mainList() {
          final vertical = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          );
          final all = vertical.evaluate().toList();
          all.sort((a, b) => b.size!.height.compareTo(a.size!.height));
          return find.byElementPredicate((e) => e == all.first);
        }

        for (final tab in ['الأطباء', 'المفضلة']) {
          await tester.tap(
            find.descendant(of: find.byType(GlassBottomNav), matching: find.text(tab)),
          );
          await settle(tester);
          expect(find.byType(DoctorResultCard), findsNWidgets(2), reason: tab);

          final list = mainList();
          expect(
            tester.state<ScrollableState>(list).position.maxScrollExtent,
            greaterThan(0),
            reason: '$tab: longer than the screen, so the check means something',
          );
          await tester.drag(list, const Offset(0, -3000));
          await settle(tester);
          expect(
            tester.getRect(find.byType(DoctorResultCard).last).bottom,
            lessThanOrEqualTo(dockTop),
            reason: '$tab: the last doctor ends above the dock, not under it',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _FailingStore implements FavoritesStore {
  @override
  Future<List<String>?> read(String key) async => null;

  @override
  Future<void> write(String key, List<String> value) async => throw StateError('disk full');
}

class _FlakyReadStore implements FavoritesStore {
  bool fail = true;

  @override
  Future<List<String>?> read(String key) async {
    if (fail) throw StateError('unreadable');
    return null;
  }

  @override
  Future<void> write(String key, List<String> value) async {}
}

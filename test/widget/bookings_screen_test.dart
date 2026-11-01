import 'dart:async';

import 'package:aleyada_mobile/app/bottom_nav.dart';
import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/app/shell.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/bookings/bookings_screen.dart';
import 'package:aleyada_mobile/features/bookings/providers.dart';
import 'package:aleyada_mobile/features/bookings/widgets/booking_tile.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/booking_fixtures.dart';
import '../fixtures/management_fixtures.dart';
import 'harness.dart';

void main() {
  late TestHarness h;
  late BookingsServer server;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    server = BookingsServer(h.dio);
    server.all = [
      patientBooking(id: 'next', start: DateTime.utc(2030, 1, 5, 7)),
      patientBooking(
        id: 'later',
        start: DateTime.utc(2030, 2, 1, 10),
        status: 'pending',
        doctorName: 'د. خالد',
      ),
      patientBooking(id: 'done', start: DateTime.utc(2029, 11, 3, 8), status: 'completed'),
      // Still "confirmed", but its time has passed: past, not upcoming.
      patientBooking(id: 'lapsed', start: DateTime.utc(2029, 12, 30, 8)),
      patientBooking(id: 'noshow', start: DateTime.utc(2029, 10, 3, 8), status: 'no_show'),
      patientBooking(
        id: 'cancelled',
        start: DateTime.utc(2030, 1, 9, 8),
        status: 'cancelled_by_clinic',
      ),
    ];
    // One container across pumps, so a remount sees the same section state the
    // app's long-lived ProviderScope would keep.
    container = ProviderContainer(
      overrides: [...h.overrides, bookingsClockProvider.overrideWithValue(() => testNow)],
    );
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(390, 2400),
    Locale locale = const Locale('ar'),
    double textScale = 1.0,
    bool signIn = true,
  }) async {
    if (signIn) {
      await container
          .read(authControllerProvider.notifier)
          .adoptSession(
            const AuthTokens(access: 'a', refresh: 'r'),
            user: Me.fromJson(patientUser()),
          );
    }
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: Routes.bookings,
      routes: [
        GoRoute(path: Routes.bookings, builder: (_, __) => const BookingsScreen()),
        GoRoute(
          path: Routes.doctors,
          builder: (_, __) => const Scaffold(body: Text('doctors page')),
        ),
        GoRoute(
          path: Routes.bookingDetail,
          builder: (_, s) => Scaffold(body: Text('detail ${s.pathParameters['id']}')),
        ),
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
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text).first;
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester, 5);
  }

  /// The segment for [label] (its accessible label carries the count too).
  Finder segment(String label) => find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}'));

  group('sections', () {
    testWidgets('upcoming: the soonest appointment is featured, the rest listed', (tester) async {
      await pumpScreen(tester);

      expect(find.text('حجوزاتي'), findsOneWidget);
      expect(find.text('تابع مواعيدك الطبية بسهولة'), findsOneWidget);
      expect(find.byType(NextBookingCard), findsOneWidget);
      expect(find.text('موعدك القادم'), findsOneWidget);
      expect(
        tester.widget<NextBookingCard>(find.byType(NextBookingCard)).booking.id,
        'next',
        reason: '5 Jan is sooner than 1 Feb',
      );
      expect(find.text('مواعيد قادمة أخرى'), findsOneWidget);
      expect(find.text('د. خالد'), findsOneWidget);
      expect(find.byType(BookingTile), findsOneWidget);
      // Exactly two upcoming: the lapsed "confirmed" one is not among them.
      expect(find.text('بانتظار التأكيد'), findsOneWidget);
    });

    testWidgets('past and cancelled come from the same single request', (tester) async {
      await pumpScreen(tester);

      await tapText(tester, 'السابقة');
      expect(container.read(bookingsTabProvider), BookingsTab.past);
      expect(find.byType(BookingTile), findsNWidgets(3));
      expect(find.byType(NextBookingCard), findsNothing);
      expect(find.text('تمت الزيارة'), findsOneWidget);
      expect(find.text('لم يتم الحضور'), findsOneWidget);
      expect(find.text('مؤكد'), findsOneWidget, reason: 'the lapsed one keeps its status');

      await tapText(tester, 'الملغاة');
      expect(find.byType(BookingTile), findsOneWidget);
      expect(find.text('ملغي'), findsOneWidget);

      expect(server.listRequests, hasLength(1));
      final q = server.listRequests.single.queryParameters;
      expect(q, {'page': 1, 'page_size': 50}, reason: 'only documented parameters');
    });

    testWidgets('past is most recent first', (tester) async {
      await pumpScreen(tester);
      await tapText(tester, 'السابقة');
      final ids = tester.widgetList<BookingTile>(find.byType(BookingTile)).map((t) => t.booking.id);
      expect(ids, ['lapsed', 'done', 'noshow']);
    });

    testWidgets('segments show their counts', (tester) async {
      await pumpScreen(tester);
      expect(segment('القادمة (2)'), findsOneWidget);
      expect(segment('السابقة (3)'), findsOneWidget);
      expect(segment('الملغاة (1)'), findsOneWidget);
    });

    testWidgets('every page is loaded', (tester) async {
      server.pageSize = 2;
      await pumpScreen(tester);
      expect(server.listRequests.map((r) => r.queryParameters['page']), [1, 2, 3]);
      expect(segment('السابقة (3)'), findsOneWidget);
    });
  });

  group('cards', () {
    testWidgets('date, day, time, clinic and address, from the booking', (tester) async {
      await pumpScreen(tester);
      // 2030-02-01 10:00 UTC is Friday 1 Feb, 12:00 in Cairo.
      final card = find.byType(BookingTile);
      expect(find.descendant(of: card, matching: find.text('الجمعة  •  12:00')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('فبراير')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('عيادة النخيل')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('شارع البحر')), findsOneWidget);
    });

    testWidgets('specialty comes from the doctor\'s profile, once per doctor', (tester) async {
      await pumpScreen(tester);
      expect(find.text('طب الأطفال'), findsNWidgets(2), reason: 'hero and card share a doctor');
      expect(server.requests.where((r) => r.path == '/doctors/dr-sample/'), hasLength(1));
    });

    testWidgets('the featured appointment counts down in exact time', (tester) async {
      await pumpScreen(tester);
      // 4 days 7 hours from the pinned clock.
      expect(find.text('بعد 4 أيام'), findsOneWidget);
    });

    testWidgets('tapping a card or the featured button opens that booking', (tester) async {
      await pumpScreen(tester);
      await tapText(tester, 'عرض تفاصيل الحجز');
      expect(find.text('detail next'), findsOneWidget);
    });

    testWidgets('a list card opens its own booking', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byType(BookingTile));
      await settle(tester);
      expect(find.text('detail later'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('loading shows card-shaped placeholders, then the list', (tester) async {
      server.listGate = Completer<void>();
      await pumpScreen(tester);
      expect(find.byType(BookingCardSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      server.listGate!.complete();
      await settle(tester);
      expect(find.byType(BookingCardSkeleton), findsNothing);
      expect(find.byType(NextBookingCard), findsOneWidget);
    });

    testWidgets('empty sections explain themselves and lead to search', (tester) async {
      server.all = [];
      await pumpScreen(tester);
      expect(find.text('لا توجد حجوزات قادمة'), findsOneWidget);
      expect(find.text('احجز موعدك الطبي بسهولة مع الطبيب المناسب.'), findsOneWidget);

      await tapText(tester, 'الملغاة');
      expect(find.text('لا توجد حجوزات ملغاة'), findsOneWidget);
      expect(find.text('ابحث عن طبيب'), findsNothing);

      await tapText(tester, 'القادمة');
      await tapText(tester, 'ابحث عن طبيب');
      expect(find.text('doctors page'), findsOneWidget);
    });

    testWidgets('a failure is a friendly message with retry — never server prose', (tester) async {
      server.failList = true;
      await pumpScreen(tester);
      expect(find.text('تعذّر تحميل حجوزاتك'), findsOneWidget);
      expect(find.text('حدث خطأ أثناء تحميل الحجوزات. حاول مرة أخرى.'), findsOneWidget);

      server.failList = false;
      await tapText(tester, 'إعادة المحاولة');
      expect(find.byType(NextBookingCard), findsOneWidget);
    });

    testWidgets('pull to refresh reloads once and keeps the section', (tester) async {
      await pumpScreen(tester, size: const Size(390, 844));
      await tapText(tester, 'السابقة');
      server.all = [
        ...server.all,
        patientBooking(id: 'new', start: DateTime.utc(2029, 12, 31, 8), status: 'completed'),
      ];

      await tester.fling(find.byType(BookingTile).first, const Offset(0, 400), 1000);
      await settle(tester, 12);

      expect(server.listRequests, hasLength(2));
      expect(container.read(bookingsTabProvider), BookingsTab.past);
      expect(segment('السابقة (4)'), findsOneWidget);
    });
  });

  group('section state', () {
    testWidgets('the selection survives leaving the screen and coming back', (tester) async {
      await pumpScreen(tester);
      await tapText(tester, 'الملغاة');

      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester, signIn: false);

      expect(container.read(bookingsTabProvider), BookingsTab.cancelled);
      expect(find.byType(BookingTile), findsOneWidget);
      expect(find.text('ملغي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the control follows the provider when something else moves it', (tester) async {
      await pumpScreen(tester);
      container.read(bookingsTabProvider.notifier).state = BookingsTab.past;
      await settle(tester);
      expect(find.byType(BookingTile), findsNWidgets(3));
      expect(tester.getSemantics(segment('السابقة (3)')), isSemantics(isSelected: true));
    });
  });

  group('layout', () {
    for (final width in const [320.0, 360.0, 390.0, 412.0]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final scale in const [1.0, 1.4]) {
          testWidgets('no overflow: ${width.toInt()}px, ${locale.languageCode}, text x$scale', (
            tester,
          ) async {
            await pumpScreen(tester, size: Size(width, 760), locale: locale, textScale: scale);
            for (final t in BookingsTab.values) {
              container.read(bookingsTabProvider.notifier).state = t;
              await settle(tester, 4);
              final lists = find.byType(Scrollable);
              if (lists.evaluate().isNotEmpty) {
                await tester.drag(lists.last, const Offset(0, -600));
                await settle(tester, 3);
              }
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  testWidgets('under the floating dock, the last booking scrolls clear of it', (tester) async {
    server.all = [
      for (var i = 0; i < 8; i++)
        patientBooking(id: 'b$i', start: DateTime.utc(2030, 1, 5 + i, 7), doctorName: 'د. $i'),
    ];
    await container
        .read(authControllerProvider.notifier)
        .adoptSession(
          const AuthTokens(access: 'a', refresh: 'r'),
          user: Me.fromJson(patientUser()),
        );
    Widget stub(String name) => Scaffold(body: Text(name));
    final router = GoRouter(
      initialLocation: Routes.bookings,
      routes: [
        ShellRoute(
          builder: (_, __, child) => AppShell(child: child),
          routes: [
            GoRoute(path: Routes.home, builder: (_, __) => stub('home')),
            GoRoute(path: Routes.doctors, builder: (_, __) => stub('doctors')),
            GoRoute(path: Routes.bookings, builder: (_, __) => const BookingsScreen()),
            GoRoute(path: Routes.favorites, builder: (_, __) => stub('favorites')),
            GoRoute(path: Routes.account, builder: (_, __) => stub('account')),
          ],
        ),
      ],
    );
    tester.view
      ..physicalSize = const Size(720, 1280)
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
          find.descendant(of: find.byType(GlassBottomNav), matching: find.byType(BackdropFilter)),
        )
        .top;
    final list = find.byType(ListView).last;
    expect(
      tester
          .state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)))
          .position
          .maxScrollExtent,
      greaterThan(0),
      reason: 'longer than the screen, so the check means something',
    );
    await tester.drag(list, const Offset(0, -4000));
    await settle(tester);

    expect(
      tester.getRect(find.byType(BookingTile).last).bottom,
      lessThanOrEqualTo(dockTop),
      reason: 'the last booking ends above the dock, not under it',
    );
    expect(tester.takeException(), isNull);
  });
}

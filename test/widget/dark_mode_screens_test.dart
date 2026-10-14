import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_palette.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/auth/sign_in_screen.dart';
import 'package:aleyada_mobile/features/bookings/booking_detail_screen.dart';
import 'package:aleyada_mobile/features/bookings/bookings_screen.dart';
import 'package:aleyada_mobile/features/bookings/models.dart';
import 'package:aleyada_mobile/features/bookings/providers.dart';
import 'package:aleyada_mobile/features/bookings/widgets/booking_tile.dart';
import 'package:aleyada_mobile/features/doctors/doctor_detail_screen.dart';
import 'package:aleyada_mobile/features/home/home_screen.dart';
import 'package:aleyada_mobile/features/notifications/notification_kinds.dart';
import 'package:aleyada_mobile/features/notifications/notifications_screen.dart';
import 'package:aleyada_mobile/features/profile/account_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/booking_fixtures.dart';
import '../fixtures/doctor_detail_fixtures.dart' as dd;
import '../fixtures/management_fixtures.dart';
import '../fixtures/notification_fixtures.dart';
import 'harness.dart';

/// Colours that only exist in the light palette — if one is *drawn* in dark mode,
/// a widget is still hard-coding light mode.
const _lightOnlyFills = <int>{
  0xFFEDF4FB, // page
  0xFFE8F0FB, // soft fill
  0xFFF8FBFF, // field fill
  0xFFDBE7F5, // border
  0xFFDCFCE7, // success tint
  0xFFFEF3C7, // warning tint
  0xFFFEE2E2, // danger tint
  0xFFFFEDD5, // caution tint
  0xFFEEF2F7, // neutral tint
};
const _lightOnlyText = <int>{
  0xFF0F172A, // heading
  0xFF1A2332, // body
  0xFF5B6B84, // muted
  0xFF0057B8, // brand blue
  0xFF15803D, // success text
  0xFFB45309, // warning text
  0xFFB91C1C, // danger text
  0xFFC2410C, // caution text
};

/// Every opaque fill and border drawn in the current tree, and every text colour.
({Set<int> fills, Set<int> text}) _colours(WidgetTester tester) {
  final fills = <int>{};
  final text = <int>{};
  void fill(Color? c) {
    if (c != null && c.a == 1) fills.add(c.toARGB32());
  }

  void walk(InlineSpan span) {
    if (span is TextSpan) {
      final c = span.style?.color;
      if (c != null && c.a == 1) text.add(c.toARGB32());
      span.children?.forEach(walk);
    }
  }

  for (final w in tester.allWidgets) {
    if (w is Material) fill(w.color);
    if (w is ColoredBox) fill(w.color);
    if (w is DecoratedBox && w.decoration is BoxDecoration) {
      final d = w.decoration as BoxDecoration;
      fill(d.color);
      if (d.border is Border) fill((d.border! as Border).top.color);
    }
    if (w is RichText) walk(w.text);
  }
  return (fills: fills, text: text);
}

void main() {
  late TestHarness h;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    BookingsServer(h.dio).all = [
      patientBooking(id: 'b1', start: DateTime.utc(2030, 1, 5, 7)),
      patientBooking(id: 'b2', start: DateTime.utc(2029, 12, 20, 7), status: 'completed'),
      patientBooking(
        id: 'b3',
        start: DateTime.utc(2029, 12, 22, 7),
        status: 'cancelled_by_patient',
      ),
      patientBooking(id: 'b4', start: DateTime.utc(2030, 1, 9, 7), status: 'pending'),
    ];
    AccountServer(h.dio).firstPage = [
      notificationJson('n1', type: 'booking_confirmed', title: 'تم تأكيد حجزك', booking: 'b1'),
      notificationJson(
        'n2',
        type: 'booking_cancelled',
        title: 'تم إلغاء الحجز',
        read: true,
        booking: 'b3',
      ),
      notificationJson(
        'n3',
        type: 'booking_pending',
        title: 'حجز قيد المراجعة',
        read: true,
        booking: 'b4',
      ),
    ];
    dd.DetailServer(h.dio);
    // Whatever nothing above answers: an empty page.
    h.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) =>
            handler.resolve(Response(requestOptions: o, statusCode: 200, data: paged(const []))),
      ),
    );
    container = ProviderContainer(
      overrides: [...h.overrides, bookingsClockProvider.overrideWithValue(() => testNow)],
    );
  });

  tearDown(() => container.dispose());

  Future<void> signIn() => container
      .read(authControllerProvider.notifier)
      .adoptSession(
        const AuthTokens(access: 'a', refresh: 'r'),
        user: Me.fromJson(patientUser()),
      );

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required ThemeMode mode,
    double width = 390,
    double height = 1600,
    double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = Size(width, height) * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => screen),
        GoRoute(path: Routes.bookingDetail, builder: (_, __) => const Scaffold()),
        GoRoute(path: Routes.doctor, builder: (_, __) => const Scaffold()),
        GoRoute(path: Routes.signIn, builder: (_, __) => const Scaffold()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // name -> (screen, signed in?)
  final screens = <String, (Widget, bool)>{
    'account': (const AccountScreen(), true),
    'my bookings': (const BookingsScreen(), true),
    'booking details': (const BookingDetailScreen(id: 'b1'), true),
    'notifications': (const NotificationsScreen(), true),
    'home': (const HomeScreen(), true),
    'doctor profile': (DoctorDetailScreen(slug: dd.slug), true),
    'sign in': (const SignInScreen(), false),
  };

  // ==========================================================================
  group('dark mode draws no light-only colour', () {
    for (final e in screens.entries) {
      testWidgets(e.key, (tester) async {
        if (e.value.$2) await signIn();
        await pumpScreen(tester, e.value.$1, mode: ThemeMode.dark);
        expect(tester.takeException(), isNull);

        final c = _colours(tester);
        expect(
          c.fills.intersection(_lightOnlyFills).map((v) => v.toRadixString(16)),
          isEmpty,
          reason: 'a light fill or border is still drawn',
        );
        expect(
          c.text.intersection(_lightOnlyText).map((v) => v.toRadixString(16)),
          isEmpty,
          reason: 'light-mode text colour (dark ink) is still used',
        );
      });
    }

    testWidgets('and the same scan does find them in light (the check is not vacuous)', (
      tester,
    ) async {
      final fills = <int>{};
      final text = <int>{};
      for (final e in screens.entries) {
        if (e.value.$2) await signIn();
        await pumpScreen(tester, e.value.$1, mode: ThemeMode.light);
        final c = _colours(tester);
        fills.addAll(c.fills);
        text.addAll(c.text);
        await tester.pumpWidget(const SizedBox());
      }
      expect(fills, contains(0xFFEDF4FB), reason: 'the page tint');
      expect(fills, contains(0xFFE8F0FB), reason: 'the soft fill');
      expect(fills, contains(0xFFDBE7F5), reason: 'the border');
      expect(text, contains(0xFF0F172A), reason: 'heading');
      expect(text, contains(0xFF5B6B84), reason: 'muted');
    });

    testWidgets('the page is the dark page, not white', (tester) async {
      await signIn();
      await pumpScreen(tester, const BookingsScreen(), mode: ThemeMode.dark);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppPalette.dark.page);
    });
  });

  // ==========================================================================
  group('dark mode keeps its layout', () {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.6]) {
        for (final name in ['account', 'my bookings', 'booking details', 'sign in']) {
          testWidgets('$name at ${width.toInt()}px, text x$scale', (tester) async {
            final e = screens[name]!;
            if (e.$2) await signIn();
            await pumpScreen(tester, e.$1, mode: ThemeMode.dark, width: width, textScale: scale);
            expect(tester.takeException(), isNull, reason: 'no overflow');
          });
        }
      }
    }
  });

  // ==========================================================================
  group('the booking sheet in dark', () {
    testWidgets('days, times and the confirm button use the dark palette', (tester) async {
      final h2 = TestHarness();
      dd.DetailServer(h2.dio);
      final c2 = ProviderContainer(overrides: h2.overrides);
      addTearDown(c2.dispose);
      await c2
          .read(authControllerProvider.notifier)
          .adoptSession(
            const AuthTokens(access: 'a', refresh: 'r'),
            user: Me.fromJson(patientUser()),
          );
      tester.view
        ..physicalSize = const Size(390, 1100) * 2
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c2,
          child: MaterialApp(
            locale: const Locale('ar'),
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: DoctorDetailScreen(slug: dd.slug),
          ),
        ),
      );
      Future<void> settle([int n = 10]) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settle();
      await tester.ensureVisible(find.text('احجز موعد').first);
      await tester.pump();
      await tester.tap(find.text('احجز موعد').first);
      await settle(12);
      await tester.tap(find.text('09:00').first);
      await settle(6);
      expect(tester.takeException(), isNull);

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, AppPalette.dark.surfaceRaised);

      final c = _colours(tester);
      expect(c.fills.intersection(_lightOnlyFills), isEmpty);
      expect(c.text.intersection(_lightOnlyText), isEmpty);
      // The chosen day and time are the dark brand fill, with white labels.
      expect(c.fills, contains(AppPalette.dark.primaryFill.toARGB32()));
    });
  });

  // ==========================================================================
  group('status colours', () {
    late L l;
    setUp(() async => l = await L.delegate.load(const Locale('ar')));

    for (final entry in {'light': AppPalette.light, 'dark': AppPalette.dark}.entries) {
      final p = entry.value;
      test('${entry.key}: every booking status takes its tone from the palette', () {
        StatusTone tone(BookingStatus s) {
          final st = statusStyle(l, p, s);
          return StatusTone(fg: st.fg, bg: st.bg);
        }

        bool same(StatusTone a, StatusTone b) => a.fg == b.fg && a.bg == b.bg;
        expect(same(tone(BookingStatus.pending), p.toneWarning), isTrue, reason: 'pending');
        expect(same(tone(BookingStatus.confirmed), p.toneSuccess), isTrue, reason: 'confirmed');
        expect(same(tone(BookingStatus.completed), p.toneInfo), isTrue, reason: 'completed');
        expect(
          same(tone(BookingStatus.cancelledByPatient), p.toneDanger),
          isTrue,
          reason: 'cancelled',
        );
        expect(
          same(tone(BookingStatus.cancelledByClinic), p.toneDanger),
          isTrue,
          reason: 'by clinic',
        );
        expect(same(tone(BookingStatus.noShow), p.toneCaution), isTrue, reason: 'no-show');
        for (final s in [BookingStatus.rescheduled, BookingStatus.expired, BookingStatus.unknown]) {
          expect(same(tone(s), p.toneNeutral), isTrue, reason: '$s');
        }
      });

      test('${entry.key}: every notification kind takes its tone from the palette', () {
        final confirmed = notificationStyle('booking_confirmed', palette: p);
        expect((confirmed.fg, confirmed.bg), (p.toneSuccess.fg, p.toneSuccess.bg));
        final cancelled = notificationStyle('booking_cancelled', palette: p);
        expect((cancelled.fg, cancelled.bg), (p.toneDanger.fg, p.toneDanger.bg));
        final pending = notificationStyle('booking_pending', palette: p);
        expect((pending.fg, pending.bg), (p.toneWarning.fg, p.toneWarning.bg));
        final reminder = notificationStyle('booking_reminder', palette: p);
        expect((reminder.fg, reminder.bg), (p.toneInfo.fg, p.toneInfo.bg));
        final noShow = notificationStyle('booking_no_show', palette: p);
        expect((noShow.fg, noShow.bg), (p.toneCaution.fg, p.toneCaution.bg));
      });
    }

    testWidgets('the pill on screen is the dark pair in dark and the light pair in light', (
      tester,
    ) async {
      Future<Color?> pillBackground(ThemeMode mode) async {
        await tester.pumpWidget(
          MaterialApp(
            themeMode: mode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            locale: const Locale('ar'),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: const Scaffold(body: BookingStatusChip(status: BookingStatus.pending)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
        return (box.decoration as BoxDecoration).color;
      }

      expect(await pillBackground(ThemeMode.light), AppPalette.light.toneWarning.bg);
      expect(await pillBackground(ThemeMode.dark), AppPalette.dark.toneWarning.bg);
    });
  });
}

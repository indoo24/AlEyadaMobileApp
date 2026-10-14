import 'dart:async';

import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/auth/otp_screen.dart';
import 'package:aleyada_mobile/features/auth/sign_in_screen.dart';
import 'package:aleyada_mobile/features/auth/widgets/auth_widgets.dart';
import 'package:aleyada_mobile/features/bookings/booking_detail_screen.dart';
import 'package:aleyada_mobile/features/bookings/models.dart';
import 'package:aleyada_mobile/features/bookings/providers.dart';
import 'package:aleyada_mobile/features/doctors/providers.dart';
import 'package:aleyada_mobile/features/doctors/repository.dart';
import 'package:aleyada_mobile/features/doctors/search_state.dart';
import 'package:aleyada_mobile/features/home/home_providers.dart';
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
import 'harness.dart';

/// Health information that belongs to account A only.
const _aNote = 'عندي حساسية من البنسلين';

/// A backend with two patients, A and B, who share one phone.
///
/// Like the real one, it decides by the bearer token whose data a request may
/// see: booking `b1` is A's, and B asking for it gets a 404.
class _TwoAccountServer {
  _TwoAccountServer(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) async {
          Response<dynamic> reply(Object? body, [int status = 200]) =>
              Response(requestOptions: o, statusCode: status, data: body);
          void fail(int status, Object body) => handler.reject(
            DioException.badResponse(
              statusCode: status,
              requestOptions: o,
              response: reply(body, status),
            ),
            true,
          );
          final who = switch (o.headers['Authorization']) {
            'Bearer access-A' => 'A',
            'Bearer access-B' => 'B',
            _ => null,
          };
          requests.add((o.path, who));

          Map<String, dynamic> session(String account) => envelope({
            'access': 'access-$account',
            'refresh': 'refresh-$account',
            'user': patientUser(id: 'user-$account'),
            'verified': true,
          });

          switch (o.path) {
            case '/auth/login/':
              final account = (o.data as Map)['phone'] == '0100000000B' ? 'B' : 'A';
              return handler.resolve(reply(session(account)));
            case '/auth/otp/verify/':
              return handler.resolve(reply(session(otpAccount)));
            case '/auth/logout/':
              return handler.resolve(reply(envelope(null)));
            case '/auth/me/':
              if (who == null) return fail(401, dd.errorBody('not_authenticated', 'No.'));
              return handler.resolve(reply(envelope(patientUser(id: 'user-$who'))));
            case '/bookings/b1/':
              final gate = bookingGate;
              if (gate != null) await gate.future;
              if (who != 'A') return fail(404, dd.errorBody('not_found', 'Not found.'));
              return handler.resolve(reply(envelope(aBooking)));
          }
          if (o.path.startsWith('/doctors/')) {
            return handler.resolve(reply(envelope(dd.publicDoctor())));
          }
          handler.next(o);
        },
      ),
    );
  }

  final aBooking = patientBooking(
    id: 'b1',
    start: DateTime.utc(2030, 1, 5, 7),
    overrides: {'notes_for_doctor': _aNote},
  );

  /// Who an OTP verification signs in as.
  String otpAccount = 'B';

  /// Holds `GET /bookings/b1/` until completed, to look at the screen meanwhile.
  Completer<void>? bookingGate;

  /// (path, account whose token it carried).
  final requests = <(String, String?)>[];
}

void main() {
  late TestHarness h;
  late _TwoAccountServer server;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    server = _TwoAccountServer(h.dio);
    container = ProviderContainer(
      overrides: [...h.overrides, bookingsClockProvider.overrideWithValue(() => testNow)],
    );
  });

  tearDown(() => container.dispose());

  Future<void> signInAs(String account) => container
      .read(authControllerProvider.notifier)
      .signIn(phone: account == 'B' ? '0100000000B' : '0100000000A', password: 'secret123');

  Future<void> signOut() => container.read(authControllerProvider.notifier).signOut();

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Start [call] and pump frames until it finishes: inside a widget test the
  /// requests it makes only progress while time is pumped.
  Future<void> run(WidgetTester tester, Future<void> Function() call) async {
    final pending = call();
    await settle(tester, 3);
    await pending;
  }

  // ==========================================================================
  group('booking details belong to one account', () {
    test('B never receives A\'s booking: it is asked again with B\'s token', () async {
      await signInAs('A');
      final sub = container.listen(bookingDetailProvider('b1'), (_, __) {});
      addTearDown(sub.close);
      final a = await container.read(bookingDetailProvider('b1').future);
      expect(a.notesForDoctor, _aNote);

      await signOut();
      await signInAs('B');
      await expectLater(container.read(bookingDetailProvider('b1').future), throwsA(anything));

      final state = container.read(bookingDetailProvider('b1'));
      expect(state.hasError, isTrue);
      expect(
        server.requests.where((r) => r.$1 == '/bookings/b1/').map((r) => r.$2).toList(),
        ['A', 'B'],
        reason: 'and nothing at all while nobody was signed in',
      );
    });

    test('it is dropped as soon as nothing shows it', () async {
      await signInAs('A');
      final sub = container.listen(bookingDetailProvider('b1'), (_, __) {});
      await container.read(bookingDetailProvider('b1').future);
      expect(container.exists(bookingDetailProvider('b1')), isTrue);

      sub.close();
      await Future<void>.delayed(Duration.zero);
      expect(container.exists(bookingDetailProvider('b1')), isFalse);
    });

    testWidgets('the open screen never draws A\'s booking for B, even while B\'s loads', (
      tester,
    ) async {
      await run(tester, () => signInAs('A'));
      tester.view
        ..physicalSize = const Size(390, 2400) * 2
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: Routes.bookingPath('b1'),
        routes: [
          GoRoute(
            path: Routes.bookingDetail,
            builder: (_, s) => BookingDetailScreen(id: s.pathParameters['id']!),
          ),
        ],
      );
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
      expect(find.text(_aNote), findsOneWidget, reason: 'A sees their own booking');
      expect(find.text('إلغاء الحجز'), findsWidgets);

      // Someone else takes the phone while the screen is open.
      server.bookingGate = Completer<void>();
      await run(tester, signOut);
      await run(tester, () => signInAs('B'));
      await settle(tester, 3);
      expect(find.text(_aNote), findsNothing, reason: 'not while B\'s request is in flight');
      expect(find.text('إلغاء الحجز'), findsNothing, reason: 'no action bar for A\'s booking');

      server.bookingGate!.complete();
      await settle(tester);
      expect(find.text(_aNote), findsNothing, reason: 'not after B\'s request is refused');
      expect(find.text('إلغاء الحجز'), findsNothing);
    });
  });

  // ==========================================================================
  group('search state belongs to one account', () {
    Future<void> settleRecents() => Future<void>.delayed(const Duration(milliseconds: 10));
    RecentSearchesController recents() => container.read(recentSearchesProvider.notifier);

    test('recent searches: A, the guest and B each have their own', () async {
      await signInAs('A');
      recents();
      await settleRecents();
      await recents().add('أمراض القلب');
      expect(container.read(recentSearchesProvider), ['أمراض القلب']);

      await signOut();
      recents();
      await settleRecents();
      expect(
        container.read(recentSearchesProvider),
        isEmpty,
        reason: 'the guest does not see A\'s',
      );
      await recents().add('عيون');

      await signInAs('B');
      recents();
      await settleRecents();
      expect(
        container.read(recentSearchesProvider),
        isEmpty,
        reason: 'B sees neither A\'s nor the guest\'s',
      );

      await signOut();
      await signInAs('A');
      recents();
      await settleRecents();
      expect(container.read(recentSearchesProvider), [
        'أمراض القلب',
      ], reason: 'A\'s own list is kept');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(RecentSearchesController.storageKey('user-A')), ['أمراض القلب']);
      expect(prefs.getStringList(RecentSearchesController.storageKey(null)), ['عيون']);
      expect(
        prefs.getStringList(RecentSearchesController.storageKey('user-B')),
        anyOf(isNull, isEmpty),
      );
    });

    test('the old device-wide list is deleted, not handed to whoever is signed in', () async {
      SharedPreferences.setMockInitialValues({
        RecentSearchesController.legacyStorageKey: ['بحث قديم'],
      });
      await signInAs('B');
      recents();
      await settleRecents();
      expect(container.read(recentSearchesProvider), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(RecentSearchesController.legacyStorageKey), isFalse);
    });

    test('filters and the home city start over for the next account', () async {
      await signInAs('A');
      container.read(doctorQueryProvider.notifier).state = const DoctorQuery(
        search: 'أحمد',
        gender: 'female',
        city: 'cairo',
        specialization: 'cardiology',
      );
      container.read(homeCitySlugProvider.notifier).state = 'cairo';

      await signOut();
      expect(container.read(doctorQueryProvider), const DoctorQuery());
      expect(container.read(homeCitySlugProvider), isNull);

      container.read(doctorQueryProvider.notifier).state = const DoctorQuery(gender: 'male');
      await signInAs('B');
      expect(container.read(doctorQueryProvider), const DoctorQuery(), reason: 'nor the guest\'s');
    });

    test('refreshing the same account keeps them', () async {
      await signInAs('A');
      container.read(doctorQueryProvider.notifier).state = const DoctorQuery(gender: 'female');
      await container.read(authControllerProvider.notifier).refreshUser();
      expect(container.read(doctorQueryProvider).gender, 'female');
    });
  });

  // ==========================================================================
  group('resuming `next` after signing in', () {
    Future<GoRouter> pumpAt(WidgetTester tester, String location) async {
      tester.view
        ..physicalSize = const Size(390, 1100) * 2
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home page')),
          ),
          GoRoute(
            path: Routes.signIn,
            builder: (_, s) => SignInScreen(next: s.uri.queryParameters['next']),
          ),
          GoRoute(
            path: Routes.otp,
            builder: (_, s) => OtpScreen(
              phone: s.uri.queryParameters['phone'] ?? '',
              purpose: s.uri.queryParameters['purpose'] ?? 'signup',
              next: s.uri.queryParameters['next'],
            ),
          ),
          GoRoute(
            path: Routes.bookingDetail,
            builder: (_, s) => Scaffold(body: Text('booking ${s.pathParameters['id']}')),
          ),
        ],
      );
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
      return router;
    }

    Finder field(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is AuthTextField && w.label == label),
      matching: find.byType(TextField),
    );

    Future<void> signInThroughForm(WidgetTester tester, String phone) async {
      await tester.enterText(field('رقم الهاتف'), phone);
      await tester.enterText(field('كلمة المرور'), 'secret123');
      final button = find.widgetWithText(FilledButton, 'تسجيل الدخول');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await settle(tester, 6);
    }

    testWidgets('A\'s session ended on A\'s booking: B signing in does not land there', (
      tester,
    ) async {
      await run(tester, () => signInAs('A'));
      await run(tester, signOut);
      final router = await pumpAt(tester, '${Routes.signIn}?next=%2Fbookings%2Fb1');
      await signInThroughForm(tester, '0100000000B');

      expect(container.read(authControllerProvider).user?.id, 'user-B');
      expect(find.text('booking b1'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        Routes.signIn,
        reason: 'the guards choose instead (home, in the app)',
      );
    });

    testWidgets('A signing back in resumes it', (tester) async {
      await run(tester, () => signInAs('A'));
      await run(tester, signOut);
      await pumpAt(tester, '${Routes.signIn}?next=%2Fbookings%2Fb1');
      await signInThroughForm(tester, '0100000000A');
      expect(find.text('booking b1'), findsOneWidget);
    });

    testWidgets('a guest who was never signed in resumes where they were going', (tester) async {
      await pumpAt(tester, '${Routes.signIn}?next=%2Fbookings%2Fb1');
      await signInThroughForm(tester, '0100000000B');
      expect(find.text('booking b1'), findsOneWidget);
    });

    testWidgets('an external or malformed `next` is ignored', (tester) async {
      for (final bad in ['https://evil.example/x', '//evil.example/x', r'/\evil.example']) {
        if (container.read(authControllerProvider).hasSession) await run(tester, signOut);
        final router = await pumpAt(tester, '${Routes.signIn}?next=${Uri.encodeComponent(bad)}');
        await signInThroughForm(tester, '0100000000A');
        expect(router.routerDelegate.currentConfiguration.uri.path, Routes.signIn, reason: bad);
        expect(find.text('home page'), findsNothing, reason: bad);
      }
    });

    testWidgets('OTP: a different account than the one that ended goes home', (tester) async {
      await run(tester, () => signInAs('A'));
      await run(tester, signOut);
      server.otpAccount = 'B';
      await pumpAt(tester, '${Routes.otp}?phone=0100000000B&purpose=signup&next=%2Fbookings%2Fb1');
      await tester.enterText(field('رمز التأكيد'), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
      await settle(tester, 6);
      expect(container.read(authControllerProvider).user?.id, 'user-B');
      expect(find.text('booking b1'), findsNothing);
      expect(find.text('home page'), findsOneWidget);
    });

    testWidgets('OTP: the same account continues to `next`', (tester) async {
      await run(tester, () => signInAs('A'));
      await run(tester, signOut);
      server.otpAccount = 'A';
      await pumpAt(tester, '${Routes.otp}?phone=0100000000A&purpose=signup&next=%2Fbookings%2Fb1');
      await tester.enterText(field('رمز التأكيد'), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'تأكيد'));
      await settle(tester, 6);
      expect(find.text('booking b1'), findsOneWidget);
    });
  });

  test('the booking model keeps the note the screen draws', () {
    // Guards the fixture the isolation tests rely on.
    expect(PatientBooking.fromJson(server.aBooking).notesForDoctor, _aNote);
  });
}

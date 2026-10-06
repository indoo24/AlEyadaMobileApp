import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/auth/auth_controller.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/management/clinics_screen.dart';
import 'package:aleyada_mobile/features/management/management_screen.dart';
import 'package:aleyada_mobile/features/management/providers.dart';
import 'package:aleyada_mobile/features/management/schedule_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/api_fixtures.dart';
import '../fixtures/management_fixtures.dart';
import 'harness.dart';

void main() {
  late TestHarness h;
  late RequestLog log;
  late ProviderContainer container;

  /// Whose data the fake API answers with. The mock adapter replies with fixed
  /// bodies, so a test that needs "doctor A, then doctor B" flips this.
  var servedDoctor = 'A';

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
    final poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
    await poppins.load();
  });

  setUp(() {
    servedDoctor = 'A';
    h = TestHarness();
    log = RequestLog(h.dio);
    mockDoctorApi(h.adapter);
    h.adapter
      ..onGet('/locations/cities/', (s) => s.reply(200, envelope(<dynamic>[])))
      ..onGet('/specializations/', (s) => s.reply(200, specializationsResponse))
      ..onGet('/doctors/', (s) => s.reply(200, doctorListResponse))
      ..onGet('/bookings/', (s) => s.reply(200, paged([])))
      ..onPost('/auth/logout/', (s) => s.reply(204, null));
    // Per-doctor answers for the endpoints the isolation tests look at.
    h.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (o, handler) {
          Response<dynamic> reply(Object body) =>
              Response(requestOptions: o, statusCode: 200, data: body);
          switch (o.path) {
            case '/doctor/stats/':
              log.calls.add(o);
              return handler.resolve(
                reply(envelope({...statsData, 'unique_patients': servedDoctor == 'A' ? 111 : 222})),
              );
            case '/doctor/clinics/':
              log.calls.add(o);
              return handler.resolve(
                reply(paged([
                  {...clinicOwned, 'name_ar': 'عيادة $servedDoctor'},
                ])),
              );
            case '/doctor/assistants/':
              log.calls.add(o);
              return handler.resolve(
                reply(paged([
                  {...assistantData, 'full_name': 'مساعد $servedDoctor'},
                ])),
              );
          }
          handler.next(o);
        },
      ),
    );
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> signIn(Map<String, dynamic> user) => container
      .read(authControllerProvider.notifier)
      .adoptSession(const AuthTokens(access: 'a', refresh: 'r'), user: Me.fromJson(user));

  Future<void> signOut(WidgetTester tester) async {
    final f = container.read(authControllerProvider.notifier).signOut();
    await settle(tester, 4);
    await f;
  }

  Future<void> pumpApp(WidgetTester tester, Widget home, {Size size = const Size(360, 900)}) async {
    tester.view
      ..physicalSize = size * 2
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
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text, {bool last = false}) async {
    final f = last ? find.text(text).last : find.text(text).first;
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester, 4);
  }

  // ===================================================== account isolation
  group('one doctor\'s data never reaches the next account', () {
    testWidgets('statistics', (tester) async {
      await signIn(doctorUser(id: 'doc-a'));
      await pumpApp(tester, const ManagementScreen());
      expect(find.text('111'), findsOneWidget);

      servedDoctor = 'B';
      await signIn(doctorUser(id: 'doc-b'));
      await settle(tester);
      expect(find.text('222'), findsOneWidget);
      expect(find.text('111'), findsNothing);
    });

    testWidgets('clinics', (tester) async {
      await signIn(doctorUser(id: 'doc-a'));
      await pumpApp(tester, const ClinicsScreen());
      expect(find.text('عيادة A'), findsOneWidget);

      servedDoctor = 'B';
      await signIn(doctorUser(id: 'doc-b'));
      await settle(tester);
      expect(find.text('عيادة B'), findsOneWidget);
      expect(find.text('عيادة A'), findsNothing);
    });

    testWidgets('appointments, and the filters the previous doctor chose', (tester) async {
      await signIn(doctorUser(id: 'doc-a'));
      await pumpApp(tester, const ScheduleScreen());
      await tapText(tester, 'الكل');
      await tapText(tester, 'كل الحالات');
      await tapText(tester, 'مؤكد', last: true);
      expect(container.read(scheduleFilterProvider).status, 'confirmed');
      expect(container.read(scheduleFilterProvider).upcoming, isFalse);

      await signIn(doctorUser(id: 'doc-b'));
      await settle(tester);
      expect(container.read(scheduleFilterProvider), const ScheduleFilter(), reason: 'back to the default');
      final last = log.last('GET', '/doctor/bookings/');
      expect(last.queryParameters['upcoming'], true);
      expect(last.queryParameters.containsKey('status'), isFalse);
    });

    testWidgets('after sign-out a doctor\'s list is not kept around', (tester) async {
      await signIn(doctorUser(id: 'doc-a'));
      await pumpApp(tester, const ScheduleScreen());
      expect(find.text('محمد جاد'), findsOneWidget);

      await pumpApp(tester, const SizedBox()); // the screen is left…
      await signOut(tester);
      await signIn(doctorUser(id: 'doc-b'));
      await pumpApp(tester, const ScheduleScreen());
      // …and the new doctor's first request is a fresh one, not A's cached page.
      expect(log.count('GET', '/doctor/bookings/'), 2);
    });
  });

  // ======================================================= freshness
  group('data is re-read when a screen is opened again', () {
    testWidgets('statistics and clinics', (tester) async {
      await signIn(doctorUser());
      await pumpApp(tester, const ManagementScreen());
      expect(log.count('GET', '/doctor/stats/'), 1);

      await pumpApp(tester, const SizedBox());
      await pumpApp(tester, const ManagementScreen());
      expect(log.count('GET', '/doctor/stats/'), 2);

      await pumpApp(tester, const SizedBox());
      await pumpApp(tester, const ClinicsScreen());
      await pumpApp(tester, const SizedBox());
      await pumpApp(tester, const ClinicsScreen());
      expect(log.count('GET', '/doctor/clinics/'), 2);
    });

    testWidgets('refreshing the profile does not refetch the statistics', (tester) async {
      await signIn(doctorUser());
      await pumpApp(tester, const ManagementScreen());
      h.adapter.onGet('/auth/me/', (s) => s.reply(200, envelope(doctorUser())));
      // A request on the fake clock: start it, pump, then collect the result.
      final refreshing = container.read(authControllerProvider.notifier).refreshUser();
      await settle(tester, 4);
      await refreshing;
      await signIn(doctorUser()); // the same account again
      await settle(tester);
      expect(log.count('GET', '/doctor/stats/'), 1);
    });
  });

  // ======================================================= route guards
  group('route guards', () {
    String where(GoRouter r) => r.routerDelegate.currentConfiguration.uri.path;

    Future<GoRouter> appRouter(WidgetTester tester) async {
      final router = container.read(routerProvider);
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
      return router;
    }

    testWidgets('signing out while on the hub leaves it for sign-in', (tester) async {
      await signIn(doctorUser());
      final r = await appRouter(tester);
      r.go(Routes.management);
      await settle(tester);
      expect(where(r), Routes.management);

      await signOut(tester);
      await settle(tester);
      expect(where(r), Routes.signIn);
      expect(find.byType(ManagementScreen), findsNothing);
    });

    testWidgets('signing out from a sub-screen leaves it too', (tester) async {
      await signIn(doctorUser());
      final r = await appRouter(tester);
      r.go(Routes.managementSchedule);
      await settle(tester);
      expect(where(r), Routes.managementSchedule);

      await signOut(tester);
      await settle(tester);
      expect(where(r), Routes.signIn);
    });

    testWidgets('a doctor with no approved profile cannot enter, hub or any area', (tester) async {
      await signIn({...doctorUser(), 'doctor_profile': null});
      final r = await appRouter(tester);
      for (final path in [
        Routes.management,
        Routes.managementClinics,
        Routes.managementAssistants,
        Routes.managementSchedule,
      ]) {
        r.go(path);
        await settle(tester, 3);
        expect(where(r), isNot(startsWith(Routes.management)), reason: path);
      }
      expect(log.count('GET', '/doctor/stats/'), 0, reason: 'nothing was even requested');
    });

    testWidgets('a role change to patient while on the hub moves the person away', (tester) async {
      await signIn(doctorUser());
      final r = await appRouter(tester);
      r.go(Routes.management);
      await settle(tester);

      await signIn(patientUser()); // the same session, now reported as a patient
      await settle(tester);
      expect(where(r), isNot(startsWith(Routes.management)));
    });

    testWidgets('a session that could not be confirmed (offline) is not let in', (tester) async {
      final offline = TestHarness(refreshToken: 'stored-refresh');
      offline.adapter.onGet('/auth/me/', (s) => s.reply(503, envelope(null)));
      container.dispose();
      container = ProviderContainer(overrides: offline.overrides);

      final restoring = container.read(authControllerProvider.notifier).restore();
      await settle(tester, 4);
      await restoring;
      expect(container.read(authControllerProvider).status, AuthStatus.offlineWithSession);

      final r = await appRouter(tester);
      r.go(Routes.management);
      await settle(tester);
      expect(where(r), isNot(startsWith(Routes.management)));
    });
  });

  // ================================================ duplicate requests
  group('a double tap sends one request', () {
    testWidgets('confirming an appointment', (tester) async {
      h.adapter.onPost(
        '/doctor/bookings/b1/confirm/',
        (s) => s.reply(200, envelope({'reason': ''}), delay: const Duration(seconds: 1)),
      );
      await signIn(doctorUser());
      await pumpApp(tester, const ScheduleScreen());

      final confirm = find.text('تأكيد').first;
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(confirm, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(log.count('POST', '/doctor/bookings/b1/confirm/'), 1);

      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
    });

    testWidgets('saving terms', (tester) async {
      h.adapter.onPatch(
        '/doctor/clinics/link-1/terms/',
        (s) => s.reply(200, envelope(clinicOwned), delay: const Duration(seconds: 1)),
      );
      await signIn(doctorUser());
      await pumpApp(tester, const ClinicsScreen());
      await tapText(tester, 'شروطي في هذه العيادة');
      final save = find.text('حفظ الشروط');
      await tester.ensureVisible(save);
      await tester.pump();
      final spot = tester.getCenter(save);
      await tester.tapAt(spot);
      await tester.pump(const Duration(milliseconds: 50));
      // The label is now a spinner: the button knows a request is on its way.
      expect(find.text('حفظ الشروط'), findsNothing);
      await tester.tapAt(spot);
      await tester.pump(const Duration(milliseconds: 50));
      expect(log.count('PATCH', '/doctor/clinics/link-1/terms/'), 1);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
    });

    testWidgets('switching an availability window', (tester) async {
      h.adapter.onPatch(
        '/doctor/availability-windows/win-1/',
        (s) => s.reply(200, envelope(windowData), delay: const Duration(seconds: 1)),
      );
      await signIn(doctorUser());
      await pumpApp(tester, const ScheduleScreen());
      await tapText(tester, 'أوقات التوفّر');
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(Switch), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(log.count('PATCH', '/doctor/availability-windows/win-1/'), 1);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
    });
  });

  // ============================================================ filters
  group('schedule filters', () {
    testWidgets('a chosen day replaces "upcoming" instead of combining with it', (tester) async {
      await signIn(doctorUser());
      await pumpApp(tester, const ScheduleScreen());
      expect(log.last('GET', '/doctor/bookings/').queryParameters['upcoming'], true);

      container.read(scheduleFilterProvider.notifier).state =
          container.read(scheduleFilterProvider).copyWith(date: '2026-10-01');
      await settle(tester);

      final q = log.last('GET', '/doctor/bookings/').queryParameters;
      expect(q['date'], '2026-10-01');
      expect(q.containsKey('upcoming'), isFalse, reason: 'a past day with "today onward" would be empty');

      container.read(scheduleFilterProvider.notifier).state =
          container.read(scheduleFilterProvider).copyWith(date: null);
      await settle(tester);
      expect(log.last('GET', '/doctor/bookings/').queryParameters['upcoming'], true);
    });

    testWidgets('changing a filter starts again from page 1', (tester) async {
      await signIn(doctorUser());
      await pumpApp(tester, const ScheduleScreen());
      container.read(scheduleFilterProvider.notifier).state =
          container.read(scheduleFilterProvider).copyWith(status: 'pending');
      await settle(tester);
      expect(log.last('GET', '/doctor/bookings/').queryParameters['page'], 1);
    });

    testWidgets('a failed load keeps the chosen filters, and retry uses them', (tester) async {
      await signIn(doctorUser());
      await pumpApp(tester, const ScheduleScreen());
      h.adapter.onGet('/doctor/bookings/', (s) => s.reply(500, envelope(null)));

      await tapText(tester, 'كل الحالات');
      await tapText(tester, 'مؤكد', last: true);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(container.read(scheduleFilterProvider).status, 'confirmed');

      final before = log.count('GET', '/doctor/bookings/');
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(log.count('GET', '/doctor/bookings/'), before + 1);
      expect(log.last('GET', '/doctor/bookings/').queryParameters['status'], 'confirmed');
      expect(log.last('GET', '/doctor/bookings/').queryParameters['upcoming'], true);
    });
  });

  // ======================================================== lifecycle
  group('lifecycle', () {
    testWidgets('typed edits survive collapsing a section', (tester) async {
      await signIn(doctorUser());
      await pumpApp(tester, const ClinicsScreen());
      await tapText(tester, 'شروطي في هذه العيادة');
      await tester.enterText(find.byType(TextField).at(0), '777');
      await tapText(tester, 'شروطي في هذه العيادة'); // collapse
      await tapText(tester, 'شروطي في هذه العيادة'); // expand again
      expect(find.text('777'), findsOneWidget);
    });

    testWidgets('leaving a screen while a request is in flight is harmless', (tester) async {
      h.adapter.onPost(
        '/doctor/bookings/b1/confirm/',
        (s) => s.reply(200, envelope({'reason': ''}), delay: const Duration(seconds: 1)),
      );
      await signIn(doctorUser());
      await pumpApp(tester, const ScheduleScreen());
      await tester.tap(find.text('تأكيد').first);
      await tester.pump(const Duration(milliseconds: 100));

      await pumpApp(tester, const Scaffold()); // the screen is gone
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the cancel dialog can be dismissed and reopened without a controller error', (tester) async {
      await signIn(doctorUser());
      await pumpApp(tester, const ScheduleScreen());
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('إلغاء').first);
        await settle(tester, 4);
        await tester.tap(find.text('إغلاق'));
        await settle(tester, 4);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new clinic sheet opened with the keyboard up fits a small phone', (tester) async {
      await signIn(doctorUser());
      await pumpApp(tester, const ClinicsScreen(), size: const Size(320, 568));
      await tapText(tester, 'إضافة عيادة');
      tester.view.viewInsets = const FakeViewPadding(bottom: 600); // an on-screen keyboard
      addTearDown(tester.view.resetViewInsets);
      await settle(tester, 3);
      expect(tester.takeException(), isNull);
    });
  });
}

import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/app/shell.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/config/env.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/core/widgets/async_value_view.dart';
import 'package:aleyada_mobile/features/management/management_screen.dart';
import 'package:aleyada_mobile/features/management/providers.dart';
import 'package:aleyada_mobile/features/practice/practice_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
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
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
    // The splash (the app's first screen) is in Poppins.
    final poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
    await poppins.load();
  });

  setUp(() {
    h = TestHarness();
    mockDoctorApi(h.adapter);
    h.adapter
      ..onGet('/specializations/', (s) => s.reply(200, specializationsResponse))
      ..onGet('/doctors/', (s) => s.reply(200, doctorListResponse))
      ..onGet('/bookings/', (s) => s.reply(200, paged([])))
      ..onPost('/auth/logout/', (s) => s.reply(204, null));
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> signInAs(Map<String, dynamic> user) => container
      .read(authControllerProvider.notifier)
      .adoptSession(
        const AuthTokens(access: 'a', refresh: 'r'),
        user: Me.fromJson(user),
      );

  Future<void> pumpRouter(WidgetTester tester, GoRouter router, {Locale locale = const Locale('ar')}) async {
    tester.view
      ..physicalSize = const Size(720, 1700)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
        ),
      ),
    );
    await settle(tester);
  }

  /// The real shell, with stand-in pages for everything but the management hub.
  GoRouter shellRouter({String start = Routes.home}) => GoRouter(
    initialLocation: start,
    routes: [
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const Scaffold(body: Text('home page'))),
          GoRoute(path: Routes.doctors, builder: (_, __) => const Scaffold(body: Text('search page'))),
          GoRoute(path: Routes.bookings, builder: (_, __) => const Scaffold(body: Text('bookings page'))),
          GoRoute(path: Routes.management, builder: (_, __) => const ManagementScreen()),
          GoRoute(path: Routes.favorites, builder: (_, __) => const Scaffold(body: Text('favorites page'))),
          GoRoute(path: Routes.account, builder: (_, __) => const Scaffold(body: Text('account page'))),
        ],
      ),
      GoRoute(path: Routes.managementClinics, builder: (_, __) => Scaffold(appBar: AppBar(), body: const Text('clinics page'))),
      GoRoute(path: Routes.managementAssistants, builder: (_, __) => Scaffold(appBar: AppBar(), body: const Text('assistants page'))),
      GoRoute(path: Routes.managementSchedule, builder: (_, __) => Scaffold(appBar: AppBar(), body: const Text('schedule page'))),
    ],
  );

  Finder inDock(String label) => find.descendant(of: find.byType(AppShell), matching: find.text(label));

  // ------------------------------------------------------------ navigation
  group('role-based navigation', () {
    testWidgets('a patient keeps "مواعيدي" and never sees "الإدارة"', (tester) async {
      await signInAs(patientUser());
      await pumpRouter(tester, shellRouter());

      expect(inDock('مواعيدي'), findsNothing, reason: 'the dock labels this tab "حجوزاتي"');
      expect(inDock('حجوزاتي'), findsOneWidget);
      expect(inDock('الإدارة'), findsNothing);
      expect(inDock('المفضلة'), findsOneWidget);
    });

    testWidgets('a doctor gets "الإدارة" in that position instead', (tester) async {
      await signInAs(doctorUser());
      await pumpRouter(tester, shellRouter());

      expect(inDock('الإدارة'), findsOneWidget);
      expect(inDock('حجوزاتي'), findsNothing);
      expect(inDock('الرئيسية'), findsOneWidget);
      expect(inDock('الأطباء'), findsOneWidget);
      expect(inDock('المفضلة'), findsOneWidget);
      expect(inDock('حسابي'), findsOneWidget);

      double x(String t) => tester.getCenter(inDock(t)).dx;
      // Right to left: home, search, management, favourites, account.
      expect(x('الرئيسية'), greaterThan(x('الأطباء')));
      expect(x('الأطباء'), greaterThan(x('الإدارة')));
      expect(x('الإدارة'), greaterThan(x('المفضلة')));
      expect(x('المفضلة'), greaterThan(x('حسابي')));
    });

    testWidgets('the management tab has its own dashboard icon, not the calendar', (tester) async {
      await signInAs(doctorUser());
      await pumpRouter(tester, shellRouter());

      final dock = find.byType(AppShell);
      expect(find.descendant(of: dock, matching: find.byIcon(Icons.space_dashboard_outlined)), findsOneWidget);
      expect(find.descendant(of: dock, matching: find.byIcon(Icons.calendar_today_outlined)), findsNothing);

      await tester.tap(inDock('الإدارة'));
      await settle(tester);
      expect(find.byType(ManagementScreen), findsOneWidget);
      expect(find.descendant(of: dock, matching: find.byIcon(Icons.space_dashboard_rounded)), findsWidgets,
          reason: 'filled when active');
    });

    testWidgets('switching account type updates the dock', (tester) async {
      final auth = container.read(authControllerProvider.notifier);
      await signInAs(patientUser());
      await pumpRouter(tester, shellRouter());
      expect(inDock('حجوزاتي'), findsOneWidget);

      await signInAs(doctorUser());
      await settle(tester, 4);
      expect(inDock('الإدارة'), findsOneWidget);
      expect(inDock('حجوزاتي'), findsNothing);

      // A mocked request completes on the fake clock: start it, pump, then collect.
      final signingOut = auth.signOut();
      await settle(tester, 4);
      await signingOut;
      expect(inDock('حجوزاتي'), findsOneWidget, reason: 'signed out: the patient dock');
      expect(inDock('الإدارة'), findsNothing);

      await signInAs(patientUser(id: 'other'));
      await settle(tester, 4);
      expect(inDock('الإدارة'), findsNothing);

      await signInAs(doctorUser(id: 'another-doctor'));
      await settle(tester, 4);
      expect(inDock('الإدارة'), findsOneWidget);
    });

    testWidgets('a doctor whose profile is not approved yet does not get management', (tester) async {
      await signInAs({...doctorUser(), 'doctor_profile': null});
      await pumpRouter(tester, shellRouter());
      expect(inDock('الإدارة'), findsNothing);
    });
  });

  group('who may open the management area', () {
    Future<GoRouter> appRouter(WidgetTester tester) async {
      final router = container.read(routerProvider);
      await pumpRouter(tester, router);
      return router;
    }

    String where(GoRouter r) => r.routerDelegate.currentConfiguration.uri.path;

    testWidgets('a doctor can', (tester) async {
      await signInAs(doctorUser());
      final r = await appRouter(tester);
      r.go(Routes.management);
      await settle(tester);
      expect(where(r), Routes.management);
      expect(find.byType(ManagementScreen), findsOneWidget);
    });

    testWidgets('a patient is sent home, from the hub and from each area', (tester) async {
      await signInAs(patientUser());
      final r = await appRouter(tester);
      for (final path in [
        Routes.management,
        Routes.managementClinics,
        Routes.managementAssistants,
        Routes.managementSchedule,
        Routes.practice,
      ]) {
        r.go(path);
        await settle(tester, 3);
        expect(where(r), isNot(startsWith(Routes.management)), reason: path);
        expect(find.byType(ManagementScreen), findsNothing, reason: path);
        expect(find.text('فتح نظام إدارة العيادة'), findsNothing, reason: 'patients never see it');
      }
    });

    testWidgets('a signed-out visitor is asked to sign in', (tester) async {
      await container.read(authControllerProvider.notifier).restore();
      final r = await appRouter(tester);
      r.go(Routes.management);
      await settle(tester);
      expect(where(r), Routes.signIn);
      expect(find.text('فتح نظام إدارة العيادة'), findsNothing, reason: 'visitors never see it');
    });

    testWidgets('the old practice address leads a doctor to management', (tester) async {
      await signInAs(doctorUser());
      final r = await appRouter(tester);
      r.go(Routes.practice);
      await settle(tester);
      expect(where(r), Routes.management);
    });
  });

  // ------------------------------------------------------------------- hub
  group('management hub', () {
    Future<GoRouter> pumpHub(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Uri? portal,
      bool noPortal = false,
      Size size = const Size(360, 850),
      double textScale = 1.0,
    }) async {
      tester.view
        ..physicalSize = size * 2
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      container.dispose();
      container = ProviderContainer(
        overrides: [
          ...h.overrides,
          if (portal != null) managementUrlProvider.overrideWithValue(portal),
          if (noPortal) managementUrlProvider.overrideWithValue(null),
        ],
      );
      await signInAs(doctorUser());
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const ManagementScreen()),
          GoRoute(path: Routes.managementClinics, builder: (_, __) => Scaffold(appBar: AppBar(), body: const Text('clinics page'))),
          GoRoute(path: Routes.managementAssistants, builder: (_, __) => Scaffold(appBar: AppBar(), body: const Text('assistants page'))),
          GoRoute(path: Routes.managementSchedule, builder: (_, __) => Scaffold(appBar: AppBar(), body: const Text('schedule page'))),
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
      return router;
    }

    testWidgets('shows the real statistics from the API', (tester) async {
      await pumpHub(tester);

      expect(find.text('إحصاءاتك'), findsOneWidget);
      expect(find.text('آخر 7 يوم'), findsOneWidget, reason: 'the period the server reports');
      // unique_patients, total_completed_visits, avg_rating, contact_rate,
      // profile_views, contacts, bookings_created, bookings_completed
      for (final v in ['9', '4', '4.6', '12.5%', '6', '3', '11', '8']) {
        expect(find.text(v), findsOneWidget, reason: v);
      }
      for (final label in [
        'عدد المرضى',
        'زيارات مكتملة',
        'متوسط التقييم',
        'معدل التواصل',
        'مشاهدات الصفحة',
        'مرات التواصل',
        'حجوزات',
        'تمت',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('5 تقييم'), findsOneWidget, reason: 'review count under the rating');
      expect(find.text('مشاهدات الصفحة: 6'), findsOneWidget);
    });

    testWidgets('an unrated doctor shows a dash, not 0.0', (tester) async {
      h.adapter.onGet(
        '/doctor/stats/',
        (s) => s.reply(200, envelope({...statsData, 'avg_rating': '0.00', 'reviews_count': 0})),
      );
      await pumpHub(tester);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('does not make statistics up', (tester) async {
      await pumpHub(tester);
      for (final invented in ['مرضى جدد', 'الإيرادات', 'نسبة الإلغاء']) {
        expect(find.text(invented), findsNothing);
      }
    });

    testWidgets('the management button is there by default and points at the configured address', (
      tester,
    ) async {
      await pumpHub(tester);
      expect(find.text('فتح نظام إدارة العيادة'), findsOneWidget);
      expect(container.read(managementUrlProvider), Uri.parse('https://scenariomnchnl.tech/'));
    });

    testWidgets('a build with no address has no button', (tester) async {
      await pumpHub(tester, noPortal: true);
      expect(find.text('فتح نظام إدارة العيادة'), findsNothing);
    });

    testWidgets('an address passed in the build configuration is the one used', (tester) async {
      await pumpHub(tester, portal: Uri.parse('https://clinic.example/dashboard'));
      expect(find.text('فتح نظام إدارة العيادة'), findsOneWidget);
      expect(container.read(managementUrlProvider)?.host, 'clinic.example');
    });

    group('opening it', () {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final launches = <Map<Object?, Object?>>[];
      var canOpen = true;

      setUp(() {
        launches.clear();
        canOpen = true;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'launch') {
              launches.add(Map<Object?, Object?>.from(call.arguments as Map));
            }
            return canOpen;
          },
        );
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      testWidgets('launches https://scenariomnchnl.tech/ in the browser, outside the app', (tester) async {
        await pumpHub(tester);
        await tester.ensureVisible(find.text('فتح نظام إدارة العيادة'));
        await tester.tap(find.text('فتح نظام إدارة العيادة'));
        await settle(tester, 3);

        expect(launches, hasLength(1));
        expect(launches.single['url'], 'https://scenariomnchnl.tech/');
        expect(launches.single['useSafariVC'], false, reason: 'an external browser, not an in-app view');
        expect(find.text('تعذّر فتح نظام الإدارة.'), findsNothing);
      });

      testWidgets('when nothing can open it, the doctor is told', (tester) async {
        canOpen = false;
        await pumpHub(tester);
        await tester.ensureVisible(find.text('فتح نظام إدارة العيادة'));
        await tester.tap(find.text('فتح نظام إدارة العيادة'));
        await settle(tester, 3);
        expect(find.text('تعذّر فتح نظام الإدارة.'), findsOneWidget);
      });
    });

    testWidgets('three modules, each opening its own screen', (tester) async {
      final router = await pumpHub(tester);
      expect(find.text('إدارة العيادة'), findsOneWidget);

      Future<void> open(String title, String page) async {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await settle(tester, 10);
        expect(find.text(page), findsOneWidget, reason: title);
        router.pop();
        await settle(tester, 10);
      }

      await open('العيادات', 'clinics page');
      await open('المساعدون', 'assistants page');
      await open('الجدول', 'schedule page');
    });

    testWidgets('skeletons while loading, nothing blank', (tester) async {
      h.adapter.onGet(
        '/doctor/stats/',
        (s) => s.reply(200, envelope(statsData), delay: const Duration(seconds: 2)),
      );
      await pumpHub(tester);
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.text('إدارة العيادة'), findsOneWidget, reason: 'modules do not wait for stats');

      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('a stats failure shows a retry; the modules stay usable', (tester) async {
      h.adapter.onGet('/doctor/stats/', (s) => s.reply(500, envelope(null)));
      await pumpHub(tester);

      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(find.text('إدارة العيادة'), findsOneWidget);

      h.adapter.onGet('/doctor/stats/', (s) => s.reply(200, envelope(statsData)));
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('an unpublished page says what is missing', (tester) async {
      h.adapter.onGet(
        '/doctor/activation/',
        (s) => s.reply(200, envelope({...activationData, 'is_published': false, 'is_complete': false, 'missing': ['photo']})),
      );
      await pumpHub(tester);
      expect(find.text('صفحتك غير منشورة بعد'), findsOneWidget);
      expect(find.text('اختر صورة'), findsOneWidget);
    });

    for (final entry in {
      'small phone': const Size(320, 568),
      'standard phone': const Size(360, 800),
      'large phone': const Size(412, 915),
    }.entries) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final scale in const [1.0, 1.6]) {
          testWidgets('no overflow: ${entry.key}, ${locale.languageCode}, text x$scale', (tester) async {
            await pumpHub(
              tester,
              size: entry.value,
              locale: locale,
              textScale: scale,
              portal: Uri.parse('https://clinic.example'),
            );
            final list = find.descendant(of: find.byType(RefreshIndicator), matching: find.byType(Scrollable));
            for (var i = 0; i < 3; i++) {
              await tester.drag(list.first, const Offset(0, -500));
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('management address', () {
    test('only an absolute http(s) address counts', () {
      expect(parseManagementUrl('https://clinic.example/admin')?.host, 'clinic.example');
      expect(parseManagementUrl(' http://localhost:3000 ')?.port, 3000);
      expect(parseManagementUrl(''), isNull);
      expect(parseManagementUrl('clinic.example'), isNull, reason: 'no scheme');
      expect(parseManagementUrl('javascript:alert(1)'), isNull);
      expect(parseManagementUrl('tel:+201000000000'), isNull);
      expect(parseManagementUrl('https://'), isNull);
    });

    test('the address the app ships with is a valid https address', () {
      final uri = parseManagementUrl(Env.managementUrl);
      expect(Env.managementUrl, 'https://scenariomnchnl.tech/');
      expect(uri?.scheme, 'https');
      expect(uri?.host, 'scenariomnchnl.tech');
    });

    test('the stats model reads the backend fields', () {
      final s = DoctorStats.fromJson(statsData);
      expect(
        (s.uniquePatients, s.completedVisits, s.avgRating, s.reviewsCount, s.profileViews, s.contacts,
            s.contactRate, s.bookingsCreated, s.bookingsCompleted, s.periodDays),
        (9, 4, '4.60', 5, 6, 3, 12.5, 11, 8, 7),
      );
      final empty = DoctorStats.fromJson(const {});
      expect(empty.uniquePatients, 0);
      expect(empty.contactRate, 0);
    });
  });
}

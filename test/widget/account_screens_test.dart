import 'dart:async';

import 'package:aleyada_mobile/app/locale_controller.dart';
import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/notifications/notification_kinds.dart';
import 'package:aleyada_mobile/features/notifications/notifications_screen.dart';
import 'package:aleyada_mobile/features/profile/account_screen.dart';
import 'package:aleyada_mobile/features/profile/edit_profile_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/management_fixtures.dart';
import '../fixtures/notification_fixtures.dart';
import 'harness.dart';

void main() {
  late TestHarness h;
  late AccountServer server;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    server = AccountServer(h.dio);
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> signIn(Map<String, dynamic> user) {
    server.me = user;
    return container
        .read(authControllerProvider.notifier)
        .adoptSession(
          const AuthTokens(access: 'a', refresh: 'r'),
          user: Me.fromJson(user),
        );
  }

  Future<void> pump(
    WidgetTester tester,
    String location, {
    Size size = const Size(390, 1400),
    Locale? locale = const Locale('ar'),
    double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    Widget page(String text) => Scaffold(body: Text(text));
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: Routes.account, builder: (_, __) => const AccountScreen()),
        GoRoute(path: Routes.editProfile, builder: (_, __) => const EditProfileScreen()),
        GoRoute(path: Routes.notifications, builder: (_, __) => const NotificationsScreen()),
        GoRoute(path: Routes.join, builder: (_, __) => page('join page')),
        GoRoute(path: Routes.signIn, builder: (_, __) => page('sign-in page')),
        GoRoute(path: Routes.signUp, builder: (_, __) => page('sign-up page')),
        GoRoute(path: Routes.otp, builder: (_, s) => page('otp ${s.uri}')),
        GoRoute(path: Routes.management, builder: (_, __) => page('management page')),
        GoRoute(path: Routes.managementSchedule, builder: (_, __) => page('schedule page')),
        GoRoute(
          path: Routes.bookingDetail,
          builder: (_, s) => page('booking ${s.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            routerConfig: router,
            locale: ref.watch(localeControllerProvider) ?? locale,
            theme: AppTheme.light(),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester, 6);
  }

  // ======================================================================
  group('My Account', () {
    testWidgets('a patient: name, phone, verified state, and their options', (tester) async {
      server.firstPage = [
        notificationJson('n1', type: 'booking_confirmed', title: 'تم تأكيد الحجز'),
      ];
      await signIn(patientUser());
      await pump(tester, Routes.account);

      final me = Me.fromJson(patientUser());
      expect(find.text('حسابي'), findsOneWidget);
      expect(find.text(me.displayName), findsOneWidget);
      expect(find.text(me.phone), findsOneWidget);
      expect(find.text('رقم الهاتف موثّق'), findsOneWidget);
      expect(find.text('تأكيد الرقم'), findsNothing, reason: 'already verified');
      expect(find.text('بياناتي'), findsOneWidget);
      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('1 جديد'), findsOneWidget, reason: 'the backend unread count');
      expect(find.text('لوحة التحكم'), findsNothing, reason: 'not a doctor');
      expect(find.text('انضم كطبيب'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });

    testWidgets('options open their screens', (tester) async {
      await signIn(patientUser());
      await pump(tester, Routes.account);
      await tap(tester, find.text('بياناتي'));
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tap(tester, find.byType(BackButton));
      await tap(tester, find.text('الإشعارات'));
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('joining as a doctor keeps its flow', (tester) async {
      await signIn(patientUser());
      await pump(tester, Routes.account);
      await tap(tester, find.text('انضم الآن'));
      expect(find.text('join page'), findsOneWidget);
    });

    testWidgets('an approved doctor gets the dashboard, not the join card', (tester) async {
      await signIn(doctorUser());
      await pump(tester, Routes.account);
      expect(find.text('انضم الآن'), findsNothing);
      await tap(tester, find.text('لوحة التحكم'));
      expect(find.text('management page'), findsOneWidget);
    });

    testWidgets('an unverified phone says so and can be verified from here', (tester) async {
      await signIn({...patientUser(), 'is_phone_verified': false});
      await pump(tester, Routes.account);
      expect(find.text('رقم الهاتف غير موثّق'), findsOneWidget);
      await tap(tester, find.text('تأكيد الرقم'));
      expect(server.where('POST', '/auth/otp/request/').single.data, {
        'phone': '+201099990001',
        'purpose': 'signup',
      });
      expect(
        find.textContaining('otp /verify?phone=%2B201099990001&purpose=signup&next=%2Faccount'),
        findsOneWidget,
      );
    });

    testWidgets('language: a sheet with both, the current one marked, and it switches', (
      tester,
    ) async {
      await signIn(patientUser());
      await pump(tester, Routes.account);
      await tap(tester, find.text('اللغة'));
      expect(find.text('اختر اللغة'), findsOneWidget);
      expect(find.bySemanticsLabel('English'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('العربية').last),
        isSemantics(isSelected: true),
      );

      await tap(tester, find.text('English'));
      expect(container.read(localeControllerProvider), const Locale('en'));
      expect(find.text('My account'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('logout asks first, then signs out', (tester) async {
      await signIn(patientUser());
      await pump(tester, Routes.account);
      await tap(tester, find.text('تسجيل الخروج'));
      expect(find.text('هل تريد تسجيل الخروج؟'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'تسجيل الخروج'));
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      expect(find.text('مرحباً بك'), findsOneWidget, reason: 'now a guest');
    });

    testWidgets('a guest: sign in or create an account, and the language', (tester) async {
      await pump(tester, Routes.account);
      expect(find.text('مرحباً بك'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsNothing);
      expect(find.text('بياناتي'), findsNothing);
      expect(find.text('اللغة'), findsOneWidget);
      await tap(tester, find.text('إنشاء حساب'));
      expect(find.text('sign-up page'), findsOneWidget);
    });
  });

  // ======================================================================
  group('Personal Information', () {
    testWidgets('shows the account, the phone read-only, and saving starts disabled', (
      tester,
    ) async {
      await signIn(patientUser());
      await pump(tester, Routes.editProfile);
      final me = Me.fromJson(patientUser());

      expect(find.text('بياناتي'), findsOneWidget);
      expect(find.text(me.displayName), findsOneWidget);
      expect(find.widgetWithText(TextField, me.firstName), findsOneWidget);
      expect(find.widgetWithText(TextField, me.lastName), findsOneWidget);
      expect(find.widgetWithText(TextField, me.email!), findsOneWidget);
      // The phone is not an input at all.
      expect(find.widgetWithText(TextField, me.phone), findsNothing);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(
        find.text('رقم الهاتف هو وسيلة تسجيل الدخول، ولا يمكن تغييره من هنا.'),
        findsOneWidget,
      );
      // The misplaced doctor-application line is gone from the phone field.
      expect(find.text('يمكنك استخدام حسابك كمريض بشكل طبيعي أثناء المراجعة.'), findsNothing);

      final save = find.widgetWithText(FilledButton, 'حفظ التغييرات');
      expect(tester.widget<FilledButton>(save).onPressed, isNull, reason: 'nothing changed yet');
    });

    testWidgets('editing enables save; saving sends the same fields as before', (tester) async {
      await signIn(patientUser());
      await pump(tester, Routes.account);
      await tap(tester, find.text('بياناتي'));
      final me = Me.fromJson(patientUser());

      await tester.enterText(find.widgetWithText(TextField, me.firstName), 'يوسف');
      await tester.pump();
      final save = find.widgetWithText(FilledButton, 'حفظ التغييرات');
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

      await tap(tester, save);
      expect(server.where('PATCH', '/auth/me/').single.data, {
        'first_name': 'يوسف',
        'last_name': me.lastName,
        'email': me.email,
      });
      expect(find.text('تم حفظ بياناتك.'), findsOneWidget);
      expect(find.byType(AccountScreen), findsOneWidget, reason: 'back where it came from');
      expect(container.read(currentUserProvider)!.firstName, 'يوسف');
    });

    testWidgets('a field error from the server sits under its field', (tester) async {
      server.patchError = {
        'data': null,
        'meta': <String, dynamic>{},
        'errors': [
          {'code': 'invalid', 'detail': 'أدخل بريدًا إلكترونيًا صحيحًا.', 'field': 'email'},
        ],
      };
      await signIn(patientUser());
      await pump(tester, Routes.editProfile);
      await tester.enterText(
        find.widgetWithText(TextField, Me.fromJson(patientUser()).email!),
        'x@',
      );
      await tester.pump();
      await tap(tester, find.widgetWithText(FilledButton, 'حفظ التغييرات'));

      expect(find.text('أدخل بريدًا إلكترونيًا صحيحًا.'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget, reason: 'stays open');
    });

    testWidgets('a general failure shows a banner, not raw server text', (tester) async {
      server.patchError = {
        'data': null,
        'meta': <String, dynamic>{},
        'errors': [
          {'code': 'throttled', 'detail': 'Request was throttled.', 'field': null},
        ],
      };
      await signIn(patientUser());
      await pump(tester, Routes.editProfile);
      await tester.enterText(
        find.widgetWithText(TextField, Me.fromJson(patientUser()).lastName),
        'قنديل',
      );
      await tester.pump();
      await tap(tester, find.widgetWithText(FilledButton, 'حفظ التغييرات'));
      expect(find.text('Request was throttled.'), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsWidgets);
    });

    testWidgets('an unverified phone can be verified from here too', (tester) async {
      await signIn({...patientUser(), 'is_phone_verified': false});
      await pump(tester, Routes.editProfile);
      expect(find.text('رقم الهاتف غير موثّق'), findsOneWidget);
      await tap(tester, find.text('تأكيد الرقم'));
      expect(find.textContaining('next=%2Faccount%2Fedit'), findsOneWidget);
    });
  });

  // ======================================================================
  group('Notifications', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final older = now.subtract(const Duration(days: 9));

    void seed() => server.firstPage = [
      notificationJson(
        'n1',
        type: 'booking_confirmed',
        title: 'تم تأكيد الحجز',
        body: 'تم تأكيد حجزك مع د. ريم الجيار',
        booking: 'b-1',
        createdAt: now.toUtc(),
      ),
      notificationJson(
        'n2',
        type: 'booking_cancelled',
        title: 'تم إلغاء الحجز',
        body: 'تم إلغاء حجزك',
        read: true,
        booking: 'b-2',
        createdAt: yesterday.toUtc(),
      ),
      notificationJson(
        'n3',
        type: 'review_approved',
        title: 'تم نشر تقييمك',
        createdAt: older.toUtc(),
      ),
    ];

    testWidgets('grouped by day, with type icons and times', (tester) async {
      seed();
      await signIn(patientUser());
      await pump(tester, Routes.notifications);

      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('أمس'), findsOneWidget);
      expect(find.text('أقدم'), findsOneWidget);
      expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);
      expect(find.byIcon(Icons.event_busy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.rate_review_outlined), findsOneWidget);
      String two(int v) => v.toString().padLeft(2, '0');
      expect(find.text('${two(now.hour)}:${two(now.minute)}'), findsOneWidget);
      expect(find.text('إشعاران غير مقروءين'), findsOneWidget, reason: 'n1 and n3');
    });

    testWidgets('unread: bolder, a dot, and spoken — not colour alone', (tester) async {
      seed();
      await signIn(patientUser());
      await pump(tester, Routes.notifications);
      final unread = tester.widget<Text>(find.text('تم تأكيد الحجز'));
      final read = tester.widget<Text>(find.text('تم إلغاء الحجز'));
      expect(unread.style!.fontWeight, FontWeight.w800);
      expect(read.style!.fontWeight, FontWeight.w600);
      expect(find.bySemanticsLabel(RegExp('^غير مقروء، تم تأكيد الحجز')), findsOneWidget);
    });

    testWidgets('a booking notification opens that booking and is marked read', (tester) async {
      seed();
      await signIn(patientUser());
      await pump(tester, Routes.notifications);
      await tap(tester, find.text('تم تأكيد الحجز'));
      expect(server.where('POST', '/notifications/n1/read/'), hasLength(1));
      expect(find.text('booking b-1'), findsOneWidget);
      expect(server.where('GET', '/notifications/'), hasLength(1), reason: 'not refetched');
    });

    testWidgets('a notification with no destination just marks itself read', (tester) async {
      seed();
      await signIn(patientUser());
      await pump(tester, Routes.notifications);
      await tap(tester, find.text('تم نشر تقييمك'));
      expect(server.where('POST', '/notifications/n3/read/'), hasLength(1));
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('mark all read: everything un-bolds; a failure puts it back', (tester) async {
      seed();
      await signIn(patientUser());
      await pump(tester, Routes.notifications);
      server.failMark = true;
      await tap(tester, find.text('تعليم الكل كمقروء'));
      expect(find.text('تعذّر تحديث الإشعارات. حاول مرة أخرى.'), findsOneWidget);
      expect(tester.widget<Text>(find.text('تم تأكيد الحجز')).style!.fontWeight, FontWeight.w800);

      server.failMark = false;
      await tap(tester, find.text('تعليم الكل كمقروء'));
      expect(server.where('POST', '/notifications/read-all/'), hasLength(2));
      expect(tester.widget<Text>(find.text('تم تأكيد الحجز')).style!.fontWeight, FontWeight.w600);
      expect(find.text('تعليم الكل كمقروء'), findsNothing);
    });

    testWidgets('loading shows item-shaped placeholders, not a spinner', (tester) async {
      seed();
      server.listGate = Completer<void>();
      await signIn(patientUser());
      await pump(tester, Routes.notifications);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('تم تأكيد الحجز'), findsNothing);
      server.listGate!.complete();
      await settle(tester);
      expect(find.text('تم تأكيد الحجز'), findsOneWidget);
    });

    testWidgets('empty: a proper empty state', (tester) async {
      await signIn(patientUser());
      await pump(tester, Routes.notifications);
      expect(find.text('لا توجد إشعارات'), findsOneWidget);
      expect(find.text('سنخبرك هنا بكل جديد يتعلق بحجوزاتك.'), findsOneWidget);
    });

    testWidgets('error: friendly text and retry', (tester) async {
      server.failList = true;
      await signIn(patientUser());
      await pump(tester, Routes.notifications);
      expect(find.text('تعذّر تحميل الإشعارات'), findsOneWidget);
      seed();
      server.failList = false;
      await tap(tester, find.text('إعادة المحاولة'));
      expect(find.text('تم تأكيد الحجز'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads once and keeps the list', (tester) async {
      seed();
      await signIn(patientUser());
      await pump(tester, Routes.notifications, size: const Size(390, 844));
      await tester.fling(find.text('تم تأكيد الحجز'), const Offset(0, 400), 1000);
      await settle(tester, 12);
      expect(server.where('GET', '/notifications/'), hasLength(2));
      expect(find.text('تم تأكيد الحجز'), findsOneWidget);
    });

    testWidgets('older pages load on request', (tester) async {
      seed();
      server.pages[2] = [
        notificationJson(
          'n9',
          type: 'booking_reminder',
          title: 'تذكير بموعدك',
          read: true,
          createdAt: older.toUtc(),
        ),
      ];
      await signIn(patientUser());
      await pump(tester, Routes.notifications);
      await tap(tester, find.text('عرض الإشعارات الأقدم'));
      expect(find.text('تذكير بموعدك'), findsOneWidget);
      expect(find.text('عرض الإشعارات الأقدم'), findsNothing);
    });

    testWidgets('long text wraps without breaking the layout', (tester) async {
      server.firstPage = [
        notificationJson(
          'n1',
          type: 'booking_pending',
          title: 'عنوان طويل جدًا ' * 6,
          body: 'نص الإشعار الطويل الذي يشرح التفاصيل ' * 10,
        ),
      ];
      await signIn(patientUser());
      await pump(tester, Routes.notifications, size: const Size(320, 700), textScale: 1.4);
      expect(tester.takeException(), isNull);
    });
  });

  group('notification destinations', () {
    AppNotification n(String type, {String? booking}) =>
        AppNotification.fromJson(notificationJson('x', type: type, title: 't', booking: booking));
    final patient = Me.fromJson(patientUser());
    final doctor = Me.fromJson(doctorUser());

    test('patient booking events open the booking — only with a booking id', () {
      for (final t in patientBookingEvents) {
        expect(notificationDestination(n(t, booking: 'b'), patient), '/bookings/b', reason: t);
        expect(notificationDestination(n(t), patient), isNull, reason: t);
      }
    });

    test('staff events go to the schedule, and only for a doctor', () {
      for (final t in staffBookingEvents) {
        expect(notificationDestination(n(t, booking: 'b'), doctor), Routes.managementSchedule);
        expect(notificationDestination(n(t, booking: 'b'), patient), isNull);
      }
    });

    test('everything else opens nothing it cannot honour', () {
      for (final t in [
        'review_approved',
        'feedback_request',
        'clinic_invitation_received',
        'something_new',
      ]) {
        expect(notificationDestination(n(t), doctor), isNull, reason: t);
      }
      expect(
        notificationDestination(n('clinic_invitation_accepted'), doctor),
        Routes.managementClinics,
      );
      expect(notificationDestination(n('doctor_verified'), patient), Routes.account);
    });

    test('every backend type has a style; unknown types get the bell', () {
      expect(notificationStyle('booking_reminder').icon, Icons.alarm_rounded);
      expect(notificationStyle('something_new').icon, Icons.notifications_none_rounded);
    });
  });

  // ======================================================================
  group('layout', () {
    for (final width in const [320.0, 360.0, 390.0, 412.0]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final scale in const [1.0, 1.5]) {
          testWidgets('no overflow: ${width.toInt()}px, ${locale.languageCode}, text x$scale', (
            tester,
          ) async {
            server.firstPage = [
              notificationJson(
                'n1',
                type: 'booking_confirmed',
                title: 'تم تأكيد الحجز',
                body: 'تفاصيل ' * 12,
              ),
            ];
            await signIn({
              ...doctorUser(),
              'full_name': 'اسم طويل جدًا لطبيب يحمل أكثر من كلمة واحدة في الاسم',
              'is_phone_verified': false,
            });
            for (final route in [Routes.account, Routes.editProfile, Routes.notifications]) {
              await pump(tester, route, size: Size(width, 720), locale: locale, textScale: scale);
              final scroll = find.byType(Scrollable).first;
              await tester.drag(scroll, const Offset(0, -900));
              await settle(tester, 3);
              expect(tester.takeException(), isNull, reason: route);
            }
          });
        }
      }
    }
  });
}

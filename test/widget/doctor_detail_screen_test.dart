import 'dart:async';

import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/bookings/providers.dart';
import 'package:aleyada_mobile/features/doctors/doctor_detail_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/doctor_detail_fixtures.dart';
import '../fixtures/management_fixtures.dart';
import 'harness.dart';

void main() {
  late TestHarness h;
  late DetailServer server;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    server = DetailServer(h.dio);
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

  Future<void> signInPatient() => signInAs(patientUser());

  final unverified = <String, dynamic>{...patientUser(), 'is_phone_verified': false};

  Future<void> pumpDetail(
    WidgetTester tester, {
    // Tall, so every section is built; the layout group uses real phone sizes.
    Size size = const Size(390, 5200),
    Locale locale = const Locale('ar'),
    double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/d',
      routes: [
        GoRoute(
          path: '/d',
          builder: (_, __) => const DoctorDetailScreen(slug: slug),
        ),
        GoRoute(
          path: Routes.signIn,
          builder: (_, s) => Scaffold(body: Text('sign-in ${s.uri}')),
        ),
        GoRoute(
          path: Routes.otp,
          builder: (_, s) => Scaffold(body: Text('otp ${s.uri}')),
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

  Finder inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester, 5);
  }

  List<String> captureLaunches() {
    final launched = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') launched.add((call.arguments as Map)['url'] as String);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return launched;
  }

  Future<void> openGenericBooking(WidgetTester tester) => tap(tester, find.text('احجز موعدًا'));

  /// A button of type [T] (or a subclass — `FilledButton.icon` is one) labelled
  /// [text].
  Finder button<T>(String text) =>
      find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is T)).first;

  // =============================================================== the profile
  group('the profile shows what the API returns', () {
    testWidgets('hero, stats and every section with data', (tester) async {
      await pumpDetail(tester);

      // In the hero, and in the bar title (hidden until the hero scrolls away).
      expect(find.text('د. سارة محمود'), findsNWidgets(2));
      expect(find.text('استشاري طب الأطفال'), findsOneWidget);
      expect(find.text('طنطا، الغربية'), findsWidgets);
      expect(find.text('4.5'), findsWidgets);
      expect(find.text('12 سنة'), findsOneWidget);
      expect(find.text('150.00 ج.م'), findsWidgets);

      expect(find.text('نبذة قصيرة عن الطبيبة.'), findsOneWidget);
      expect(find.text('رعاية آمنة لكل طفل.'), findsOneWidget);
      expect(find.text('دكتوراه طب الأطفال'), findsOneWidget);
      expect(find.text('استشاري بمستشفى الجامعة'), findsOneWidget);
      // Multi-line text (sent with \r\n) becomes one bullet per line.
      expect(find.text('مستشفى أ'), findsOneWidget);
      expect(find.text('مستشفى ب'), findsOneWidget);
      expect(find.text('زمالة طب الأطفال'), findsOneWidget);
      // An empty field is not a section with nothing in it.
      expect(find.text('الزمالات والدبلومات'), findsNothing);

      expect(find.text('حديثي الولادة'), findsOneWidget);
      expect(find.text('متابعة النمو  ·  250.00 ج.م'), findsOneWidget);
      expect(
        find.text('تطعيمات'),
        findsOneWidget,
        reason: 'a service with no price shows no price',
      );

      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('clinics: primary first, both fees, hours grouped by day, a book button each', (
      tester,
    ) async {
      await pumpDetail(tester);

      final a = tester.getTopLeft(find.text('عيادة النخيل').first).dy;
      final b = tester.getTopLeft(find.text('مركز الشفاء').first).dy;
      expect(a, lessThan(b));
      expect(find.text('العيادة الرئيسية'), findsOneWidget);
      expect(find.text('شارع البحر — أمام البنك'), findsNWidgets(2));
      expect(find.text('100.00 ج.م'), findsOneWidget, reason: 'clinic B sends no follow-up fee');
      expect(find.text('300.00 ج.م'), findsOneWidget);
      // Two Saturday shifts are one line; Saturday is listed before Monday.
      expect(find.text('09:00 – 13:00  ،  17:00 – 21:00'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('السبت').first).dy,
        lessThan(tester.getTopLeft(find.text('الاثنين').first).dy),
      );
      expect(find.text('احجز موعد'), findsNWidgets(2));
    });

    testWidgets('the website is the doctor\'s `website` — never the booking or maps link', (
      tester,
    ) async {
      final launched = captureLaunches();
      await pumpDetail(tester);

      expect(find.text('dr-sample.example'), findsOneWidget);
      expect(find.textContaining('external-booking'), findsNothing);

      await tap(tester, find.text('الموقع الإلكتروني'));
      expect(launched.last, 'https://dr-sample.example/');

      await tap(tester, find.text('الموقع على الخريطة'));
      expect(launched.last, 'https://maps.app.goo.gl/sample');

      // Only clinic B has its own map link, so only it gets a map button.
      expect(
        find.ancestor(
          of: find.text('فتح الموقع'),
          matching: find.byWidgetPredicate((w) => w is TextButton),
        ),
        findsOneWidget,
      );
      await tap(tester, button<TextButton>('فتح الموقع'));
      expect(launched.last, 'https://maps.app.goo.gl/clinicB');
    });

    testWidgets('social links: only networks with a valid web address', (tester) async {
      final launched = captureLaunches();
      await pumpDetail(tester);
      expect(find.text('فيسبوك'), findsOneWidget);
      expect(find.text('إنستجرام'), findsNothing, reason: 'empty');
      expect(find.text('لينكد إن'), findsNothing, reason: 'not a URL');
      await tap(tester, find.widgetWithText(ActionChip, 'فيسبوك'));
      expect(launched.single, 'https://facebook.com/drsample');
    });

    testWidgets('a sparse profile hides every section it has no data for', (tester) async {
      server.doctor = publicDoctor(
        overrides: {
          'years_of_experience': null,
          'min_fee': null,
          'avg_rating': '0.00',
          'reviews_count': 0,
          'bio_ar': '',
          'vision_ar': null,
          'academic_degree_ar': '',
          'current_positions_ar': '',
          'past_positions_ar': '',
          'certifications_ar': '',
          'website': '',
          'google_maps_url': '',
          'social_links': null,
          'specializations': <dynamic>[],
          'services': <dynamic>[],
        },
      );
      server.reviewPages = {1: reviewsPage(const [], page: 1, pages: 1)};
      await pumpDetail(tester);

      for (final absent in [
        'نبذة عن الطبيب',
        'المعلومات المهنية',
        'الخدمات',
        'التخصصات',
        'الموقع والروابط',
      ]) {
        expect(find.text(absent), findsNothing, reason: absent);
      }
      // Unrated is "no reviews", never ★ 0.0.
      expect(find.text('لا توجد تقييمات'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
      expect(find.text('لا توجد تقييمات بعد.'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('next available time comes from the primary clinic\'s availability', (
      tester,
    ) async {
      await pumpDetail(tester);
      expect(find.text('أقرب موعد متاح'), findsOneWidget);
      expect(find.text('السبت 5 يناير  •  09:00'), findsOneWidget);
      expect(server.availabilityFor(clinicA), hasLength(1));
      expect(server.availabilityFor(clinicB), isEmpty, reason: 'not fetched until chosen');
    });

    testWidgets('a contact-only doctor: call and WhatsApp, no booking, no availability calls', (
      tester,
    ) async {
      server.doctor = publicDoctor(
        overrides: {
          'booking_enabled': false,
          'clinics': [
            clinicLink(clinicA, name: 'عيادة النخيل', isPrimary: true, bookingEnabled: false),
          ],
        },
      );
      await pumpDetail(tester, size: const Size(390, 800));

      expect(find.text('احجز موعدًا'), findsNothing);
      expect(button<FilledButton>('اتصال'), findsOneWidget);
      expect(button<FilledButton>('واتساب'), findsOneWidget);
      expect(
        find.text('الحجز الإلكتروني غير متاح لهذا الطبيب — تواصل مع العيادة مباشرة.'),
        findsOneWidget,
      );
      expect(server.requests.where((r) => r.path.endsWith('/availability/')), isEmpty);
    });
  });

  // =============================================================== reviews
  group('reviews', () {
    testWidgets('first names, verified badge, and pages loaded on demand', (tester) async {
      await pumpDetail(tester);

      expect(find.text('أحمد'), findsOneWidget);
      expect(find.text('منى'), findsOneWidget);
      expect(find.text('تعليق r1'), findsOneWidget);
      expect(find.text('زيارة مؤكدة'), findsOneWidget, reason: 'only r1 is a verified visit');
      expect(find.text('خالد'), findsNothing);

      final more = find.text('عرض المزيد من التقييمات');
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pump();
      // While the page loads the button is a spinner, so it cannot be pressed again.
      expect(find.text('عرض المزيد من التقييمات'), findsNothing);
      await settle(tester);

      expect(find.text('خالد'), findsOneWidget);
      expect(find.text('عرض المزيد من التقييمات'), findsNothing, reason: 'that was the last page');
      expect(
        server.reviewRequests.where((r) => '${r.queryParameters['page']}' == '2'),
        hasLength(1),
      );
    });

    testWidgets('a failed load says so and retries', (tester) async {
      server.failReviewPages.add(1);
      await pumpDetail(tester);
      expect(find.text('تعذّر تحميل التقييمات.'), findsOneWidget);

      server.failReviewPages.clear();
      await tap(tester, find.text('إعادة المحاولة'));
      expect(find.text('أحمد'), findsOneWidget);
    });
  });

  // =============================================================== booking sheet
  group('booking sheet', () {
    testWidgets('several clinics: the patient chooses one first', (tester) async {
      await signInPatient();
      await pumpDetail(tester, size: const Size(390, 820));
      await openGenericBooking(tester);

      expect(inSheet(find.text('اختر العيادة')), findsOneWidget);
      expect(server.availabilityFor(clinicB), isEmpty);

      await tap(tester, inSheet(find.text('مركز الشفاء')));
      expect(server.availabilityFor(clinicB), hasLength(1));
      expect(inSheet(find.text('12:00')), findsOneWidget);

      await tap(tester, inSheet(find.text('تغيير')));
      expect(inSheet(find.text('اختر العيادة')), findsOneWidget);
    });

    testWidgets('a clinic card\'s button opens straight on that clinic', (tester) async {
      await signInPatient();
      await pumpDetail(tester);
      await tap(tester, find.text('احجز موعد').last);

      expect(inSheet(find.text('اختر العيادة')), findsNothing);
      expect(inSheet(find.text('مركز الشفاء')), findsOneWidget);
      expect(inSheet(find.text('12:00')), findsOneWidget);
    });

    testWidgets('switching clinics: a late answer for the old clinic never shows', (tester) async {
      await signInPatient();
      final slowB = Completer<void>();
      server.availabilityGates[clinicB] = slowB;
      await pumpDetail(tester, size: const Size(390, 820));
      await openGenericBooking(tester);

      await tap(tester, inSheet(find.text('مركز الشفاء')));
      await tap(tester, inSheet(find.text('تغيير')));
      await tap(tester, inSheet(find.text('عيادة النخيل')));
      expect(inSheet(find.text('09:00')), findsOneWidget);

      slowB.complete();
      await settle(tester);
      expect(inSheet(find.text('09:00')), findsOneWidget);
      expect(inSheet(find.text('12:00')), findsNothing);
    });

    testWidgets('choose a day and time, confirm, and see what the server confirmed', (
      tester,
    ) async {
      await signInPatient();
      await pumpDetail(tester, size: const Size(390, 820));
      await tap(tester, find.text('احجز موعد').first); // clinic A

      final confirm = inSheet(find.widgetWithText(FilledButton, 'تأكيد الحجز'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull, reason: 'no time chosen');

      // The second day, then its only time.
      await tap(tester, inSheet(find.text('7')));
      await tap(tester, inSheet(find.text('10:00')));
      expect(inSheet(find.text('ملخص الحجز')), findsOneWidget);
      expect(inSheet(find.text('الاثنين 7 يناير')), findsOneWidget);

      // Back to the first day, a different time, and a follow-up visit.
      await tap(tester, inSheet(find.text('5')));
      await tap(tester, inSheet(find.text('09:00')));
      await tap(tester, inSheet(find.text('متابعة')));
      expect(
        inSheet(find.text('100.00 ج.م')),
        findsOneWidget,
        reason: 'the clinic\'s follow-up fee',
      );

      await tap(tester, confirm);
      final body = Map<String, dynamic>.from(server.bookings.single.data as Map);
      expect(body, {'slot': '$clinicA-s1', 'clinic': clinicA, 'visit_type': 'follow_up'});

      expect(inSheet(find.text('تم تأكيد حجزك')), findsOneWidget);
      expect(inSheet(find.text('السبت 5 يناير')), findsOneWidget);
      // The API issues no booking reference; its internal id is not shown as one.
      expect(find.textContaining('booking-123'), findsNothing);

      await tap(tester, inSheet(find.text('عرض تفاصيل الحجز')));
      expect(find.text('booking booking-123'), findsOneWidget);
    });

    testWidgets('one confirm, one request — however many taps', (tester) async {
      await signInPatient();
      server.bookGate = Completer<void>();
      await pumpDetail(tester, size: const Size(390, 820));
      await tap(tester, find.text('احجز موعد').first);
      await tap(tester, inSheet(find.text('09:00')));

      final confirm = inSheet(find.widgetWithText(FilledButton, 'تأكيد الحجز'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.tap(inSheet(find.byType(FilledButton)).last, warnIfMissed: false);
      await tester.pump();
      expect(inSheet(find.byType(CircularProgressIndicator)), findsOneWidget);

      server.bookGate!.complete();
      await settle(tester);
      expect(server.bookings, hasLength(1));
      expect(inSheet(find.text('تم تأكيد حجزك')), findsOneWidget);
    });

    testWidgets(
      'a slot taken meanwhile: localized error, fresh times, the slot marked unavailable',
      (tester) async {
        await signInPatient();
        server.bookError = errorBody('slot_unavailable', 'Slot is gone');
        await pumpDetail(tester, size: const Size(390, 820));
        await tap(tester, find.text('احجز موعد').first);
        final before = server.availabilityFor(clinicA).length;

        await tap(tester, inSheet(find.text('09:00')));
        await tap(tester, inSheet(find.widgetWithText(FilledButton, 'تأكيد الحجز')));

        expect(inSheet(find.text('هذا الموعد لم يعد متاحًا. اختر موعدًا آخر.')), findsOneWidget);
        expect(find.text('Slot is gone'), findsNothing);
        expect(server.availabilityFor(clinicA).length, before + 1, reason: 'refetched');
        // The refused time is struck through and cannot be chosen again.
        await tap(tester, inSheet(find.text('09:00')));
        final confirm = inSheet(find.widgetWithText(FilledButton, 'تأكيد الحجز'));
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        expect(inSheet(find.text('تم تأكيد حجزك')), findsNothing);
      },
    );

    testWidgets('a time already in the past cannot be chosen', (tester) async {
      await signInPatient();
      server.availabilityByClinic[clinicA] = availability(
        clinicA,
        days: [
          {
            'date': '2030-01-05',
            'slots': [
              slot('old', '2020-01-05T07:00:00Z', '08:00'),
              slot('new', '2030-01-05T07:00:00Z', '09:00'),
            ],
          },
        ],
      );
      await pumpDetail(tester, size: const Size(390, 820));
      await tap(tester, find.text('احجز موعد').first);

      await tap(tester, inSheet(find.text('08:00')));
      final confirm = inSheet(find.widgetWithText(FilledButton, 'تأكيد الحجز'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tap(tester, inSheet(find.text('09:00')));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    });

    testWidgets('a guest is sent to sign in, and nothing is booked', (tester) async {
      await pumpDetail(tester, size: const Size(390, 820));
      await tap(tester, find.text('احجز موعد').first);
      await tap(tester, inSheet(find.text('09:00')));
      await tap(tester, inSheet(find.text('سجّل الدخول لتأكيد الحجز')));

      expect(find.textContaining('sign-in /sign-in?next=%2Fdoctors%2F$slug'), findsOneWidget);
      expect(server.bookings, isEmpty);
    });

    testWidgets('phone-only at this clinic: the server\'s message and contact buttons', (
      tester,
    ) async {
      await signInPatient();
      server.availabilityByClinic[clinicB] = contactOnlyAvailability;
      await pumpDetail(tester);
      await tap(tester, find.text('احجز موعد').last);

      expect(inSheet(find.text('هذا الطبيب يستقبل الحجوزات عبر الهاتف فقط.')), findsOneWidget);
      expect(inSheet(button<FilledButton>('اتصال')), findsOneWidget);
      expect(inSheet(find.text('تأكيد الحجز')), findsNothing);
    });

    testWidgets('availability that fails to load can be retried', (tester) async {
      await signInPatient();
      server.availabilityByClinic.remove(clinicB);
      await pumpDetail(tester);
      await tap(tester, find.text('احجز موعد').last);
      expect(inSheet(find.text('إعادة المحاولة')), findsOneWidget);

      server.availabilityByClinic[clinicB] = availability(
        clinicB,
        days: [
          {
            'date': '2030-02-01',
            'slots': [slot('b1', '2030-02-01T10:00:00Z', '12:00')],
          },
        ],
      );
      await tap(tester, inSheet(find.text('إعادة المحاولة')));
      expect(inSheet(find.text('12:00')), findsOneWidget);
    });
  });

  // ==================================================== account state and errors
  group('booking: account state and server errors', () {
    Future<void> openOnClinicA(WidgetTester tester) async {
      await pumpDetail(tester, size: const Size(390, 820));
      await tap(tester, find.text('احجز موعد').first);
    }

    Future<void> pickAndConfirm(WidgetTester tester) async {
      await tap(tester, inSheet(find.text('09:00')));
      await tap(tester, inSheet(find.widgetWithText(FilledButton, 'تأكيد الحجز')));
    }

    const noPermission = 'لا تملك صلاحية لهذا الإجراء.';

    testWidgets('a verified patient books: token attached, clinic id sent, booking listed', (
      tester,
    ) async {
      await signInPatient();
      await openOnClinicA(tester);
      expect(server.meRequests, isNotEmpty, reason: 'the account is re-read when the sheet opens');
      await pickAndConfirm(tester);

      final request = server.bookings.single;
      expect(request.method, 'POST');
      expect(request.path, '/doctors/$slug/book/');
      expect(request.headers['Authorization'], 'Bearer a');
      expect(request.data, {'slot': '$clinicA-s1', 'clinic': clinicA, 'visit_type': 'first_visit'});
      expect(inSheet(find.text('تم تأكيد حجزك')), findsOneWidget);

      // Started, pumped, then awaited: a mocked request needs frames to complete.
      final pending = container.read(myBookingsProvider.future);
      await settle(tester, 3);
      final mine = await pending;
      expect(mine.map((b) => b.id), ['booking-123']);
    });

    testWidgets('an unverified phone: verification is offered instead, and nothing is booked', (
      tester,
    ) async {
      server.me = unverified;
      await signInAs(unverified);
      await openOnClinicA(tester);

      expect(inSheet(find.text('أكّد رقم هاتفك لإتمام الحجز')), findsOneWidget);
      expect(inSheet(find.text('تأكيد الحجز')), findsNothing);
      await tap(tester, inSheet(find.widgetWithText(FilledButton, 'تأكيد رقم الهاتف')));

      expect(server.otpRequests.single.data, {'phone': '+201099990001', 'purpose': 'signup'});
      expect(server.bookings, isEmpty);
      expect(
        find.text('otp /verify?phone=%2B201099990001&purpose=signup&next=%2Fdoctors%2F$slug'),
        findsOneWidget,
      );
    });

    testWidgets('a code that cannot be sent says why, and the sheet stays open', (tester) async {
      server.me = unverified;
      server.otpError = errorBody('throttled', 'too many');
      await signInAs(unverified);
      await openOnClinicA(tester);
      await tap(tester, inSheet(find.widgetWithText(FilledButton, 'تأكيد رقم الهاتف')));
      expect(inSheet(find.text('أكّد رقم هاتفك لإتمام الحجز')), findsOneWidget);
      expect(find.textContaining('otp '), findsNothing);
      expect(server.bookings, isEmpty);
    });

    testWidgets('verified elsewhere since sign-in: the fresh account is used, not the stale one', (
      tester,
    ) async {
      await signInAs(unverified); // what the app loaded at launch
      server.me = patientUser(); // verified since, e.g. on the website
      await openOnClinicA(tester);
      expect(inSheet(find.text('أكّد رقم هاتفك لإتمام الحجز')), findsNothing);
      await pickAndConfirm(tester);
      expect(server.bookings, hasLength(1));
      expect(inSheet(find.text('تم تأكيد حجزك')), findsOneWidget);
    });

    testWidgets('a 403 caused by the account shows the way forward, not "no permission"', (
      tester,
    ) async {
      await signInPatient();
      server.bookError = errorBody('permission_denied', 'ليس لديك صلاحية للقيام بهذا الإجراء.');
      server.bookErrorStatus = 403;
      // The server's view changed after the sheet opened.
      server.onBook = () => server.me = unverified;
      await openOnClinicA(tester);
      await pickAndConfirm(tester);

      expect(find.text(noPermission), findsNothing);
      expect(inSheet(find.text('أكّد رقم هاتفك لإتمام الحجز')), findsOneWidget);
      expect(inSheet(find.widgetWithText(FilledButton, 'تأكيد رقم الهاتف')), findsOneWidget);
    });

    testWidgets('a 403 for an account in good standing is reported as a permission error', (
      tester,
    ) async {
      await signInPatient();
      server.bookError = errorBody('permission_denied', 'ليس لديك صلاحية للقيام بهذا الإجراء.');
      server.bookErrorStatus = 403;
      await openOnClinicA(tester);
      final before = server.meRequests.length;
      await pickAndConfirm(tester);

      expect(inSheet(find.text(noPermission)), findsOneWidget);
      expect(server.meRequests.length, before + 1, reason: 'the account was re-checked');
      expect(inSheet(find.text('تم تأكيد حجزك')), findsNothing);
    });

    testWidgets('an expired session (401): one refresh attempt, then "sign in" — no token prose', (
      tester,
    ) async {
      await signInPatient();
      server.bookError = errorBody('token_not_valid', 'Given token not valid for any token type');
      server.bookErrorStatus = 401;
      await openOnClinicA(tester);
      await pickAndConfirm(tester);

      expect(server.refreshes, hasLength(1));
      expect(inSheet(find.text('من فضلك سجّل الدخول للمتابعة.')), findsOneWidget);
      expect(find.textContaining('token'), findsNothing);
      expect(find.text(noPermission), findsNothing);
      // The dead session is dropped. (In the app the client's onSessionExpired then
      // signs the user out; the harness client is built without that callback.)
      expect(h.store.hasSession, isFalse);
    });

    for (final status in [400, 422]) {
      testWidgets('an invalid clinic ($status) is a validation error, not a permission error', (
        tester,
      ) async {
        await signInPatient();
        server.bookError = {
          'data': null,
          'meta': <String, dynamic>{},
          'errors': [
            {'code': 'does_not_exist', 'detail': 'العيادة المختارة غير موجودة.', 'field': 'clinic'},
          ],
        };
        server.bookErrorStatus = status;
        await openOnClinicA(tester);
        await pickAndConfirm(tester);

        expect(inSheet(find.text('العيادة المختارة غير موجودة.')), findsOneWidget);
        expect(find.text(noPermission), findsNothing);
        expect(server.refreshes, isEmpty);
      });
    }

    testWidgets('the doctor is busy (409): its own message, and the times are refreshed', (
      tester,
    ) async {
      await signInPatient();
      server.bookError = errorBody('doctor_busy', 'busy');
      await openOnClinicA(tester);
      final before = server.availabilityFor(clinicA).length;
      await pickAndConfirm(tester);

      expect(inSheet(find.text('الطبيب محجوز في هذا الوقت. اختر موعدًا آخر.')), findsOneWidget);
      expect(find.text(noPermission), findsNothing);
      expect(server.availabilityFor(clinicA).length, before + 1);
    });

    testWidgets('a doctor account books like anyone else — the app adds no role rule', (
      tester,
    ) async {
      server.me = doctorUser();
      await signInAs(doctorUser());
      await openOnClinicA(tester);
      await pickAndConfirm(tester);
      expect(server.bookings, hasLength(1));
    });

    testWidgets('no clinic chosen yet: nothing can be confirmed, nothing is sent', (tester) async {
      await signInPatient();
      await pumpDetail(tester, size: const Size(390, 820));
      await openGenericBooking(tester);
      expect(inSheet(find.text('اختر العيادة')), findsOneWidget);
      expect(inSheet(find.text('تأكيد الحجز')), findsNothing);
      expect(server.bookings, isEmpty);
    });
  });

  // =============================================================== layout
  group('layout', () {
    for (final (name, size) in [('small phone', Size(320, 568)), ('large phone', Size(430, 932))]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final scale in const [1.0, 1.3]) {
          testWidgets('no overflow: $name, ${locale.languageCode}, text x$scale', (tester) async {
            await signInPatient();
            await pumpDetail(tester, size: size, locale: locale, textScale: scale);
            final scroll = find
                .descendant(of: find.byType(RefreshIndicator), matching: find.byType(Scrollable))
                .first;
            for (var i = 0; i < 14; i++) {
              await tester.drag(scroll, const Offset(0, -400));
              await settle(tester, 2);
            }
            expect(tester.takeException(), isNull);

            await tester.drag(scroll, const Offset(0, 8000));
            await settle(tester, 3);
            // The sticky "book" button (its icon is unique on the page).
            await tester.tap(find.byIcon(Icons.calendar_month_rounded));
            await settle(tester, 6);
            await tap(tester, inSheet(find.text('مركز الشفاء')));
            await tap(tester, inSheet(find.text('12:00')));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}

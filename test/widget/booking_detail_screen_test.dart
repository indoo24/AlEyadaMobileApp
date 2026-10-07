import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/bookings/booking_detail_screen.dart';
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
import '../fixtures/doctor_detail_fixtures.dart' as dd;
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

  Future<void> pumpDetail(
    WidgetTester tester,
    Map<String, dynamic> booking, {
    Size size = const Size(390, 2400),
    Locale locale = const Locale('ar'),
    double textScale = 1.0,
    String? routeId,
  }) async {
    server.all = [booking];
    await container
        .read(authControllerProvider.notifier)
        .adoptSession(
          const AuthTokens(access: 'a', refresh: 'r'),
          user: Me.fromJson(patientUser()),
        );
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: Routes.bookingPath(routeId ?? booking['id'] as String),
      routes: [
        GoRoute(
          path: Routes.bookingDetail,
          builder: (_, s) => BookingDetailScreen(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: Routes.doctor,
          builder: (_, s) => Scaffold(body: Text('doctor ${s.pathParameters['slug']}')),
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

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester, 6);
  }

  Finder button<T>(String text) =>
      find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is T)).first;

  // 5 Jan 2030 07:00 UTC = Saturday 09:00 in Cairo, 4 days 7 hours away.
  Map<String, dynamic> upcoming({Map<String, dynamic> overrides = const {}}) => patientBooking(
    id: 'b1',
    start: DateTime.utc(2030, 1, 5, 7),
    overrides: {'notes_for_doctor': 'عندي حساسية من البنسلين', ...overrides},
  );

  group('an upcoming booking', () {
    testWidgets('doctor, appointment, information — all from real data', (tester) async {
      await pumpDetail(tester, upcoming());

      expect(find.text('تفاصيل الحجز'), findsOneWidget);
      // Doctor header: from the booking, plus specialty and rating from the profile.
      expect(find.text('د. سارة محمود'), findsWidgets);
      expect(find.text('طب الأطفال'), findsWidgets);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('مؤكد'), findsOneWidget);

      // The appointment card.
      expect(find.text('موعدك'), findsOneWidget);
      expect(find.text('السبت'), findsOneWidget);
      expect(find.text('5 يناير 2030'), findsOneWidget);
      expect(find.text('09:00'), findsWidgets);
      expect(find.text('بعد 4 أيام'), findsOneWidget);
      expect(find.text('30 دقيقة'), findsWidgets);

      // Booking information.
      expect(find.text('معلومات الحجز'), findsOneWidget);
      expect(find.text('السبت 5 يناير'), findsWidgets);
      expect(find.text('زيارة أولى'), findsOneWidget);
      expect(find.text('300.00 ج.م'), findsOneWidget);
      expect(find.text('عندي حساسية من البنسلين'), findsOneWidget);

      // Cancellation window, relative to the appointment (6 hours before).
      expect(find.text('يمكنك إلغاء الحجز حتى قبل موعدك بـ6 ساعات.'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('clinic card: address and area, and the clinic\'s own actions', (tester) async {
      final launched = captureLaunches();
      // Give the matched clinic (عيادة النخيل) a map link of its own.
      final doctor = dd.publicDoctor();
      (doctor['clinics'] as List)[0] = dd.clinicLink(
        dd.clinicA,
        name: 'عيادة النخيل',
        isPrimary: true,
        mapsUrl: 'https://maps.app.goo.gl/nakheel',
      );
      server.doctors[dd.slug] = doctor;
      await pumpDetail(tester, upcoming());

      expect(find.text('العيادة والموقع'), findsOneWidget);
      expect(find.text('طنطا، الغربية'), findsOneWidget);
      expect(find.text('شارع البحر — أمام البنك'), findsOneWidget);

      await tap(tester, button<OutlinedButton>('فتح الموقع'));
      expect(launched.last, 'https://maps.app.goo.gl/nakheel');
      await tap(tester, button<OutlinedButton>('اتصال'));
      expect(launched.last, 'tel:+201000000001');
      expect(
        server.requests.where((r) => r.path == '/tracking/contact-click/'),
        hasLength(1),
        reason: 'contact clicks are tracked as on the doctor page',
      );
    });

    testWidgets('sticky bar: cancel (the server allows it) and call the clinic', (tester) async {
      await pumpDetail(tester, upcoming(), size: const Size(390, 844));
      expect(button<OutlinedButton>('إلغاء الحجز'), findsOneWidget);
      expect(button<FilledButton>('اتصال بالعيادة'), findsOneWidget);
      expect(find.text('احجز موعدًا آخر'), findsNothing);
    });

    testWidgets('cancelling: confirm with a reason, the server answers, the page updates', (
      tester,
    ) async {
      await pumpDetail(tester, upcoming(), size: const Size(390, 844));
      await tap(tester, button<OutlinedButton>('إلغاء الحجز'));
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ظرف طارئ');
      await tap(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'إلغاء الحجز'),
        ),
      );

      expect(server.cancels.single.data, {'reason': 'ظرف طارئ'});
      expect(find.text('تم إلغاء الحجز.'), findsOneWidget);
      // Re-read from the server: now cancelled, no cancel button, book-again offered.
      expect(find.text('ملغي'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('ألغيتَ هذا الحجز'),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      expect(find.text('ألغيتَ هذا الحجز'), findsOneWidget);
      expect(find.text('احجز موعدًا جديدًا'), findsOneWidget);
      expect(find.text('إلغاء الحجز'), findsNothing);
    });

    testWidgets('dismissing the dialog cancels nothing', (tester) async {
      await pumpDetail(tester, upcoming(), size: const Size(390, 844));
      await tap(tester, button<OutlinedButton>('إلغاء الحجز'));
      await tap(tester, find.text('تراجع'));
      expect(server.cancels, isEmpty);
      expect(find.text('مؤكد'), findsOneWidget);
    });

    testWidgets('a refused cancellation (422) shows the server\'s reason, nothing breaks', (
      tester,
    ) async {
      server.cancelError = dd.errorBody(
        'cancellation_too_late',
        'لم يعد الإلغاء متاحًا إلكترونيًا.',
      );
      await pumpDetail(tester, upcoming(), size: const Size(390, 844));
      await tap(tester, button<OutlinedButton>('إلغاء الحجز'));
      await tap(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'إلغاء الحجز'),
        ),
      );

      expect(find.text('لم يعد الإلغاء متاحًا إلكترونيًا.'), findsOneWidget);
      expect(find.text('مؤكد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('past the cutoff: no cancel button, and the reason why', (tester) async {
      await pumpDetail(tester, upcoming(overrides: {'can_cancel': false}));
      expect(find.text('إلغاء الحجز'), findsNothing);
      expect(find.text('انتهت مهلة الإلغاء الإلكتروني. للإلغاء تواصل مع العيادة.'), findsOneWidget);
      expect(find.text('اتصال بالعيادة'), findsOneWidget, reason: 'the way to cancel instead');
    });

    testWidgets('a pending booking shows it is awaiting the clinic', (tester) async {
      await pumpDetail(tester, upcoming(overrides: {'status': 'pending'}));
      expect(find.text('بانتظار التأكيد'), findsOneWidget);
      expect(find.text('بانتظار تأكيد العيادة'), findsOneWidget);
      expect(find.text('تم تأكيد الحجز'), findsNothing);
    });

    testWidgets('payment status appears only when payment is required', (tester) async {
      await pumpDetail(
        tester,
        upcoming(overrides: {'payment_required': true, 'payment_status': 'proof_pending'}),
      );
      expect(find.text('الدفع'), findsOneWidget);
      expect(find.text('بانتظار إثبات الدفع'), findsOneWidget);
    });
  });

  group('a finished booking', () {
    testWidgets('completed: no countdown, full timeline, book again', (tester) async {
      await pumpDetail(
        tester,
        patientBooking(id: 'b2', start: DateTime.utc(2029, 11, 3, 8), status: 'completed'),
        size: const Size(390, 2000),
      );
      expect(find.text('تمت الزيارة'), findsWidgets);
      expect(find.textContaining('بعد '), findsNothing);
      expect(find.text('تم الحجز'), findsOneWidget);
      expect(find.text('20 ديسمبر 2029'), findsOneWidget, reason: 'created_at, its only timestamp');
      expect(find.text('موعد الكشف'), findsOneWidget);
      expect(find.text('إلغاء الحجز'), findsNothing);

      await tap(tester, find.text('احجز موعدًا آخر'));
      expect(find.text('doctor ${dd.slug}'), findsOneWidget);
    });

    testWidgets('cancelled by the clinic: its reason, the outcome, book a new one', (tester) async {
      await pumpDetail(
        tester,
        patientBooking(
          id: 'b3',
          start: DateTime.utc(2030, 1, 9, 8),
          status: 'cancelled_by_clinic',
          canCancel: false,
          overrides: {'cancellation_reason': 'سفر الطبيب'},
        ),
      );
      expect(find.text('ملغي'), findsOneWidget);
      expect(find.text('سبب الإلغاء'), findsOneWidget);
      expect(find.text('سفر الطبيب'), findsOneWidget);
      expect(find.text('ألغت العيادة هذا الحجز'), findsOneWidget);
      expect(find.text('احجز موعدًا جديدًا'), findsOneWidget);
      expect(
        find.textContaining('بعد '),
        findsNothing,
        reason: 'no countdown for a cancelled visit',
      );
      expect(find.text('اتصال بالعيادة'), findsNothing);
    });
  });

  group('missing data', () {
    testWidgets('no doctor slug, no address, no fee, no notes: nothing invented', (tester) async {
      await pumpDetail(
        tester,
        patientBooking(
          id: 'b4',
          start: DateTime.utc(2030, 1, 5, 7),
          doctorSlug: '',
          clinicAddress: null,
          canCancel: false,
          overrides: {'fee_snapshot': null, 'notes_for_doctor': '', 'reason_for_visit': ''},
        ),
        size: const Size(390, 844),
      );
      expect(server.requests.where((r) => r.path.startsWith('/doctors/')), isEmpty);
      expect(find.text('التخصص'), findsNothing);
      expect(find.text('رسوم الزيارة'), findsNothing);
      expect(find.text('ملاحظاتك للطبيب'), findsNothing);
      expect(find.text('فتح الموقع'), findsNothing);
      expect(find.text('اتصال'), findsNothing);
      // Nothing it could honestly offer: no bar at all.
      expect(find.text('اتصال بالعيادة'), findsNothing);
      expect(find.text('إلغاء الحجز'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('a clinic not found on the profile borrows no map or phone', (tester) async {
      await pumpDetail(
        tester,
        patientBooking(id: 'b5', start: DateTime.utc(2030, 1, 5, 7), clinicName: 'عيادة أخرى'),
      );
      expect(find.text('عيادة أخرى'), findsWidgets);
      expect(find.text('فتح الموقع'), findsNothing);
      expect(find.text('اتصال'), findsNothing);
      expect(find.text('اتصال بالعيادة'), findsNothing);
      expect(find.text('طب الأطفال'), findsWidgets, reason: 'the doctor is still known');
    });

    testWidgets('a profile that fails to load leaves the booking fully usable', (tester) async {
      server.doctors.clear();
      await pumpDetail(tester, upcoming(), size: const Size(390, 844));
      expect(find.text('5 يناير 2030'), findsOneWidget);
      expect(find.text('التخصص'), findsNothing);
      expect(button<OutlinedButton>('إلغاء الحجز'), findsOneWidget);
    });

    testWidgets('a booking the server does not have is an error state, not a crash', (
      tester,
    ) async {
      await pumpDetail(tester, upcoming(), routeId: 'someone-elses');
      expect(find.text('العنصر المطلوب غير موجود.'), findsOneWidget);
      expect(find.byType(BookingStatusChip), findsNothing);
      expect(find.text('إلغاء الحجز'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('layout', () {
    for (final width in const [320.0, 360.0, 390.0, 412.0]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final scale in const [1.0, 1.4]) {
          testWidgets('no overflow: ${width.toInt()}px, ${locale.languageCode}, text x$scale', (
            tester,
          ) async {
            await pumpDetail(
              tester,
              upcoming(overrides: {'payment_required': true, 'payment_status': 'accepted'}),
              size: Size(width, 760),
              locale: locale,
              textScale: scale,
            );
            final list = find.byType(Scrollable).first;
            for (var i = 0; i < 6; i++) {
              await tester.drag(list, const Offset(0, -500));
              await settle(tester, 2);
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}

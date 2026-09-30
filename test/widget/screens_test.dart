import 'package:aleyada_mobile/core/widgets/async_value_view.dart';
import 'package:aleyada_mobile/core/widgets/form_fields.dart';
import 'package:aleyada_mobile/features/bookings/models.dart';
import 'package:aleyada_mobile/features/bookings/widgets/booking_tile.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:aleyada_mobile/features/doctors/widgets/doctor_card_tile.dart';
import 'package:aleyada_mobile/features/home/home_screen.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/api/api_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_fixtures.dart';
import 'harness.dart';

void main() {
  late TestHarness h;
  setUp(() => h = TestHarness());

  group('right-to-left layout', () {
    testWidgets('Arabic renders RTL without any widget reversing a Row', (tester) async {
      await tester.pumpWidget(
        h.wrap(Builder(builder: (context) => Text('اتجاه', key: const Key('probe')))),
      );

      final direction = Directionality.of(tester.element(find.byKey(const Key('probe'))));
      // Comes from the locale via Localizations. Nothing sets textDirection by
      // hand, which is why switching to English below just works.
      expect(direction, TextDirection.rtl);
    });

    testWidgets('English renders LTR from the same widget tree', (tester) async {
      await tester.pumpWidget(
        h.wrap(
          Builder(builder: (context) => Text('direction', key: const Key('probe'))),
          locale: const Locale('en'),
        ),
      );

      expect(Directionality.of(tester.element(find.byKey(const Key('probe')))), TextDirection.ltr);
    });

    testWidgets('a phone number stays LTR inside an RTL form', (tester) async {
      await tester.pumpWidget(
        h.wrap(const Scaffold(body: AppTextField(label: 'الهاتف', forceLtr: true))),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      // 01012345678 must not read backwards as it is typed.
      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, TextAlign.start);
    });
  });

  group('doctor card', () {
    testWidgets('shows name, specialty, location and fee', (tester) async {
      final doctor = DoctorCard.fromJson(doctorCardData2);
      await tester.pumpWidget(h.wrap(Scaffold(body: DoctorCardTile(doctor: doctor))));

      expect(find.text('احمد رضا'), findsOneWidget);
      expect(find.text('قلب وأوعية دموية'), findsOneWidget);
      expect(find.textContaining('طنطا'), findsOneWidget);
      expect(find.textContaining('300.00'), findsOneWidget);
    });

    testWidgets('falls back to an initial when there is no photo', (tester) async {
      final doctor = DoctorCard.fromJson({...doctorCardData, 'photo': null});
      await tester.pumpWidget(h.wrap(Scaffold(body: DoctorCardTile(doctor: doctor))));

      // A broken-image glyph on a medical directory looks like a broken product.
      expect(find.byType(Image), findsNothing);
      expect(find.text('م'), findsOneWidget);
    });

    testWidgets('a rating is announced, not only coloured', (tester) async {
      final doctor = DoctorCard.fromJson(doctorCardData2);
      await tester.pumpWidget(h.wrap(Scaffold(body: DoctorCardTile(doctor: doctor))));

      final semantics = tester.getSemantics(find.byType(RatingBadge));
      expect(semantics.label, contains('4.5'));
    });

    testWidgets('is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        h.wrap(
          Scaffold(
            body: DoctorCardTile(
              doctor: DoctorCard.fromJson(doctorCardData),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DoctorCardTile));
      expect(tapped, isTrue);
    });
  });

  group('booking tile', () {
    testWidgets('shows the server-formatted date and time', (tester) async {
      final booking = PatientBooking.fromJson(bookingData);
      await tester.pumpWidget(h.wrap(Scaffold(body: BookingTile(booking: booking))));

      expect(find.text('احمد رضا'), findsOneWidget);
      expect(find.text('2026-10-01'), findsOneWidget);
      // 13:00 is the clinic's wall clock, not a conversion of 10:00 UTC into the
      // test machine's zone.
      expect(find.text('13:00'), findsOneWidget);
    });

    testWidgets('each status gets its own label, not just a colour', (tester) async {
      for (final status in ['pending', 'confirmed', 'cancelled_by_patient', 'completed']) {
        await tester.pumpWidget(
          h.wrap(
            Scaffold(
              body: BookingTile(
                booking: PatientBooking.fromJson({...bookingData, 'status': status}),
              ),
            ),
          ),
        );
        expect(find.byType(BookingStatusChip), findsOneWidget, reason: status);
        final chip = tester.widget<BookingStatusChip>(find.byType(BookingStatusChip));
        expect(chip.status, BookingStatus.parse(status));
      }
    });
  });

  group('application status card', () {
    DoctorApplication app(Map<String, dynamic> over) => DoctorApplication.fromJson({
      'kind': 'application',
      'status': 'pending',
      'is_open': true,
      'needs_doctor_action': false,
      'rejection_reason': '',
      'doctor_name': 'سارة علي',
      ...over,
    });

    testWidgets('a new application and a claim say different things', (tester) async {
      await tester.pumpWidget(h.wrap(Scaffold(body: ApplicationStatusCard(application: app({})))));
      final applicationTitle = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();

      await tester.pumpWidget(
        h.wrap(Scaffold(body: ApplicationStatusCard(application: app({'kind': 'claim'})))),
      );
      final claimTitle = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();

      // The two must not collapse into one vague "under review".
      expect(applicationTitle.first, isNot(claimTitle.first));
      expect(
        claimTitle.join(),
        contains('سارة علي'),
        reason: 'a claim names the page being claimed',
      );
    });

    testWidgets('changes-requested shows the reviewer note', (tester) async {
      await tester.pumpWidget(
        h.wrap(
          Scaffold(
            body: ApplicationStatusCard(
              application: app({
                'status': 'changes_requested',
                'needs_doctor_action': true,
                'rejection_reason': 'صورة الترخيص غير واضحة',
              }),
            ),
          ),
        ),
      );

      // Rendered as a RichText (bold label + the note), so read the composed
      // plain text rather than looking for a Text widget.
      final rich = tester.widgetList<RichText>(find.byType(RichText));
      final composed = rich.map((r) => r.text.toPlainText()).join(' ');
      expect(composed, contains('صورة الترخيص غير واضحة'));
      expect(composed, contains('ملاحظة المراجع'));
    });

    testWidgets('an approved doctor sees nothing here', (tester) async {
      await tester.pumpWidget(
        h.wrap(
          Scaffold(
            body: ApplicationStatusCard(application: app({'status': 'approved', 'is_open': false})),
          ),
        ),
      );

      // They have a practice dashboard; a status card would be noise.
      expect(find.byType(Card), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('async states', () {
    testWidgets('a network error offers a retry and says it is the connection', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        h.wrap(
          Scaffold(
            body: AppErrorView(error: _networkError(), onRetry: () => retried = true),
          ),
        ),
      );

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton));
      expect(retried, isTrue);
    });

    testWidgets('an empty view explains itself rather than showing a blank screen', (tester) async {
      await tester.pumpWidget(
        h.wrap(
          const Scaffold(
            body: AppEmptyView(title: 'لا نتائج', hint: 'جرّب بحثًا آخر'),
          ),
        ),
      );

      expect(find.text('لا نتائج'), findsOneWidget);
      expect(find.text('جرّب بحثًا آخر'), findsOneWidget);
    });

    testWidgets('a loading state is announced to a screen reader', (tester) async {
      await tester.pumpWidget(h.wrap(const Scaffold(body: AppLoading())));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // A spinner with no label tells a screen-reader user nothing at all.
      final semantics = tester.widget<Semantics>(
        find.descendant(of: find.byType(AppLoading), matching: find.byType(Semantics)).first,
      );
      expect(semantics.properties.label, isNotNull);
      expect(semantics.properties.label, isNotEmpty);
    });
  });

  group('form error banner', () {
    testWidgets('renders nothing when there is no message', (tester) async {
      await tester.pumpWidget(h.wrap(const Scaffold(body: FormErrorBanner())));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('announces the message when there is one', (tester) async {
      await tester.pumpWidget(
        h.wrap(const Scaffold(body: FormErrorBanner(message: 'خطأ في البيانات'))),
      );

      expect(find.text('خطأ في البيانات'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });
}

/// Built through the production classifier, so the test exercises the real
/// mapping rather than a stand-in that happens to look similar.
ApiException _networkError() => ApiException.fromDio(
  DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: DioExceptionType.connectionError,
  ),
);

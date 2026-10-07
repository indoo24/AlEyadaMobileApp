import 'package:aleyada_mobile/features/bookings/models.dart';
import 'package:aleyada_mobile/features/doctors/doctor_detail_logic.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:aleyada_mobile/features/doctors/providers.dart';
import 'package:aleyada_mobile/features/doctors/repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fixtures/doctor_detail_fixtures.dart';
import '../widget/harness.dart';

void main() {
  DoctorDetail doctor([Map<String, dynamic> overrides = const {}]) =>
      DoctorDetail.fromJson(publicDoctor(overrides: overrides));

  setUpAll(() => initializeDateFormatting('ar'));

  group('parsing the public profile', () {
    test('the fields the live endpoint returns beyond the spec', () {
      final d = doctor();
      expect(d.academicDegreeAr, 'دكتوراه طب الأطفال');
      expect(d.currentPositionsAr, 'استشاري بمستشفى الجامعة');
      expect(d.pastPositionsAr, 'مستشفى أ\nمستشفى ب', reason: '\\r\\n normalised');
      expect(d.certificationsAr, 'زمالة طب الأطفال');
      expect(d.fellowshipsAr, '');
      expect(d.visionAr, 'رعاية آمنة لكل طفل.');
    });

    test('website is `website` — not the external booking link or the map link', () {
      final d = doctor();
      expect(d.website.toString(), 'https://dr-sample.example/');
      expect(d.googleMapsUrl.toString(), 'https://maps.app.goo.gl/sample');
      expect(doctor({'website': ''}).website, isNull);
      expect(doctor({'website': null}).website, isNull, reason: 'no fallback to another link');
    });

    test('only safe, absolute web links are kept', () {
      expect(webUri('https://a.example/x'), isNotNull);
      expect(webUri('http://a.example'), isNotNull);
      for (final bad in [
        '',
        '   ',
        'a.example',
        '/relative',
        'javascript:alert(1)',
        'tel:+20100',
        5,
        null,
      ]) {
        expect(webUri(bad), isNull, reason: '$bad');
      }
    });

    test('social links: known networks with a valid address, in a fixed order', () {
      expect(doctor().socialLinks.keys, ['facebook']);
      expect(doctor({'social_links': 'x'}).socialLinks, isEmpty);
      expect(doctor({'social_links': null}).socialLinks, isEmpty);
      final d = doctor({
        'social_links': {
          'tiktok': 'https://tiktok.com/@a',
          'myspace': 'https://myspace.com/a',
          'facebook': 'https://facebook.com/a',
        },
      });
      expect(d.socialLinks.keys, ['facebook', 'tiktok']);
    });

    test('an older server that omits the extra fields still parses', () {
      final raw = publicDoctor()
        ..removeWhere(
          (k, _) => {
            'academic_degree_ar',
            'current_positions_ar',
            'past_positions_ar',
            'certifications_ar',
            'fellowships_ar',
            'vision_ar',
            'website',
            'google_maps_url',
            'social_links',
          }.contains(k),
        );
      final d = DoctorDetail.fromJson(raw);
      expect(d.academicDegreeAr, '');
      expect(d.website, isNull);
      expect(d.socialLinks, isEmpty);
    });

    test('working hours keep the backend\'s day label; clinic map link is validated', () {
      final link = doctor().clinics.last;
      expect(link.clinic.workingHours.first.weekdayLabel, 'السبت');
      expect(link.clinic.mapsUri.toString(), 'https://maps.app.goo.gl/clinicB');
      expect(doctor().clinics.first.clinic.mapsUri, isNull, reason: 'empty string');
    });

    test('certificates read `issuer`, education reads `institution_ar`', () {
      final cert = DoctorCredential.fromJson({
        'id': 'c',
        'title_ar': 'زمالة',
        'issuer': 'المجلس',
        'year': 2018,
      });
      expect((cert.titleAr, cert.subtitle, cert.year), ('زمالة', 'المجلس', '2018'));
      final edu = DoctorCredential.fromJson({
        'id': 'e',
        'degree_ar': 'بكالوريوس',
        'institution_ar': 'جامعة بنها',
      });
      expect((edu.titleAr, edu.subtitle, edu.year), ('بكالوريوس', 'جامعة بنها', null));
    });
  });

  group('reviews and availability parsing', () {
    test('a review is the spec\'s PublicReview: patient_name and verified_visit', () {
      final r = PublicReview.fromJson(review('r1', name: ' منى ', rating: 4, verified: true));
      expect(r.reviewerName, 'منى');
      expect(r.rating, 4);
      expect(r.verifiedVisit, isTrue);
      expect(r.createdAt, DateTime.utc(2026, 9, 1, 10));
      expect(PublicReview.fromJson({'id': 'x', 'rating': 9}).rating, 5, reason: 'clamped');
      expect(PublicReview.fromJson({'id': 'x'}).reviewerName, '');
    });

    test('the contact-only availability answer keeps its message and links', () {
      final a = DoctorAvailability.fromJson(contactOnlyAvailability);
      expect(a.bookingEnabled, isFalse);
      expect(a.hasAnySlot, isFalse);
      expect(a.message, 'هذا الطبيب يستقبل الحجوزات عبر الهاتف فقط.');
      expect(a.contact.telUrl, 'tel:+201000000009');
      expect(a.contact.canWhatsapp, isTrue);
    });

    test('the first free slot is the earliest day that has one', () {
      final a = DoctorAvailability.fromJson(
        availability(
          clinicA,
          days: [
            {'date': '2030-01-04', 'slots': <dynamic>[]},
            {
              'date': '2030-01-05',
              'slots': [slot('s', '2030-01-05T07:00:00Z', '09:00')],
            },
          ],
        ),
      );
      final first = firstFreeSlot(a)!;
      expect((first.date, first.slot.displayTime), ('2030-01-05', '09:00'));
      expect(firstFreeSlot(DoctorAvailability.empty), isNull);
    });
  });

  group('which clinic the booking sheet opens on', () {
    test('only clinics that take online bookings, and only if the doctor does', () {
      expect(bookableClinics(doctor()).map((c) => c.clinic.id), [clinicA, clinicB]);
      final mixed = doctor({
        'clinics': [clinicLink(clinicA, bookingEnabled: false), clinicLink(clinicB)],
      });
      expect(bookableClinics(mixed).map((c) => c.clinic.id), [clinicB]);
      expect(bookableClinics(doctor({'booking_enabled': false})), isEmpty);
    });

    test('a requested clinic wins; one clinic needs no choice; several do', () {
      expect(initialBookingClinic(doctor(), requested: clinicB), clinicB);
      expect(initialBookingClinic(doctor()), isNull, reason: 'the patient chooses');
      final single = doctor({
        'clinics': [clinicLink(clinicA, bookingEnabled: false), clinicLink(clinicB)],
      });
      expect(initialBookingClinic(single), clinicB);
      expect(
        initialBookingClinic(single, requested: clinicA),
        clinicB,
        reason: 'A is not bookable',
      );
    });

    test('the profile\'s availability hint uses the primary bookable clinic', () {
      expect(availabilityHintClinic(doctor())!.clinic.id, clinicA);
      final noPrimary = doctor({
        'clinics': [
          clinicLink(clinicA, isPrimary: true, bookingEnabled: false),
          clinicLink(clinicB),
        ],
      });
      expect(availabilityHintClinic(noPrimary)!.clinic.id, clinicB);
      expect(availabilityHintClinic(doctor({'booking_enabled': false})), isNull);
    });
  });

  group('formatting', () {
    test('working hours are grouped by day, Saturday first, shifts in order', () {
      final days = groupWorkingHours(const [
        ClinicWorkingHour(weekday: 1, openTime: '10:00:00', closeTime: '14:00:00'),
        ClinicWorkingHour(
          weekday: 6,
          openTime: '17:00:00',
          closeTime: '21:00:00',
          weekdayLabel: 'السبت',
        ),
        ClinicWorkingHour(weekday: 6, openTime: '09:00:00', closeTime: '13:00:00'),
        ClinicWorkingHour(weekday: 9, openTime: '09:00', closeTime: '10:00'),
      ]);
      expect(days.map((d) => d.weekday), [6, 1]);
      expect(days.first.label, 'السبت');
      expect(days.first.ranges, ['09:00 – 13:00', '17:00 – 21:00']);
      expect(days.last.label, '', reason: 'no label sent; the screen names the day itself');
    });

    test('times drop their seconds; anything else is left alone', () {
      expect(shortTime('09:00:00'), '09:00');
      expect(shortTime('9:30'), '9:30');
      expect(shortTime('صباحًا'), 'صباحًا');
    });

    test('a clinic-local date is labelled without timezone arithmetic', () {
      expect(longDayLabel('2030-01-05', 'ar'), 'السبت 5 يناير');
      expect(longDayLabel('not a date', 'ar'), 'not a date');
      final p = calendarParts('2030-01-07', 'ar')!;
      expect((p.weekday, p.day, p.month), ('الاثنين', '7', 'يناير'));
    });

    test('the fee shown matches the visit type, and is never invented', () {
      final link = doctor().clinics.first; // consultation 150, follow-up 100
      final a = DoctorAvailability.fromJson(availability(clinicA, fee: '150.00'));
      expect(feeFor(visitType: VisitType.firstVisit, clinic: link, availability: a), '150.00');
      expect(feeFor(visitType: VisitType.followUp, clinic: link, availability: a), '100.00');
      final noFollowup = doctor().clinics.last;
      expect(feeFor(visitType: VisitType.followUp, clinic: noFollowup, availability: a), '150.00');
      expect(feeFor(visitType: VisitType.firstVisit, clinic: link), '150.00');
      expect(feeFor(visitType: VisitType.firstVisit), isNull);
    });
  });

  group('the reviews controller', () {
    late TestHarness h;
    late DetailServer server;
    late ProviderContainer container;

    setUp(() {
      h = TestHarness();
      server = DetailServer(h.dio);
      container = ProviderContainer(overrides: h.overrides);
    });
    tearDown(() => container.dispose());

    Future<ReviewsState> loaded() async {
      final sub = container.listen(doctorReviewsProvider(slug), (_, __) {});
      addTearDown(sub.close);
      while (container.read(doctorReviewsProvider(slug)).loading) {
        await Future<void>.delayed(Duration.zero);
      }
      return container.read(doctorReviewsProvider(slug));
    }

    test('pages append, the total is the server\'s count, and the last page ends it', () async {
      final first = await loaded();
      expect(first.items.map((r) => r.id), ['r1', 'r2']);
      expect((first.total, first.hasMore), (3, true));

      final notifier = container.read(doctorReviewsProvider(slug).notifier);
      // Two calls at once are one request.
      await Future.wait([notifier.loadMore(), notifier.loadMore()]);
      final s = container.read(doctorReviewsProvider(slug));
      expect(s.items.map((r) => r.id), ['r1', 'r2', 'r3']);
      expect(s.hasMore, isFalse);
      expect(
        server.reviewRequests.where((r) => '${r.queryParameters['page']}' == '2'),
        hasLength(1),
      );
    });

    test('a review repeated across pages is listed once', () async {
      server.reviewPages[2] = reviewsPage(
        [review('r2'), review('r3')],
        page: 2,
        pages: 2,
        count: 3,
      );
      await loaded();
      await container.read(doctorReviewsProvider(slug).notifier).loadMore();
      expect(container.read(doctorReviewsProvider(slug)).items.map((r) => r.id), [
        'r1',
        'r2',
        'r3',
      ]);
    });

    test('a failed further page keeps what is loaded and can be retried', () async {
      server.failReviewPages.add(2);
      await loaded();
      final notifier = container.read(doctorReviewsProvider(slug).notifier);
      await notifier.loadMore();
      var s = container.read(doctorReviewsProvider(slug));
      expect(s.items, hasLength(2));
      expect(s.moreError, isNotNull);
      expect(s.hasMore, isTrue);

      server.failReviewPages.clear();
      await notifier.loadMore();
      s = container.read(doctorReviewsProvider(slug));
      expect(s.items, hasLength(3));
      expect(s.moreError, isNull);
    });
  });
}

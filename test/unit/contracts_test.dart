import 'package:aleyada_mobile/core/api/envelope.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/features/bookings/models.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_fixtures.dart';

/// Contract tests: every DTO is parsed from a body captured off the real API.
///
/// The point is not that the parsers run — it is that they agree with the server
/// about field names, nullability, the money-as-string convention, and the
/// envelope. A DTO that quietly drops a required field passes a hand-written test
/// and fails in production; these fixtures make that impossible.
void main() {
  group('envelope', () {
    test('unwraps an object', () {
      expect(unwrapObject(meResponse)['role'], 'patient');
    });

    test('reads meta.pagination from a list response', () {
      final page = unwrapPaginated(doctorListResponse, DoctorCard.fromJson);

      expect(page.items, hasLength(2));
      expect(page.pagination.count, 17);
      expect(page.pagination.pages, 9);
      expect(page.pagination.page, 1);
      expect(page.hasMore, isTrue, reason: 'page 1 of 9');
    });

    test('an un-paginated list still yields one usable page', () {
      final page = unwrapPaginated(citiesResponse, City.fromJson);

      expect(page.items, hasLength(3));
      expect(page.pagination.pages, 1);
      expect(page.hasMore, isFalse);
    });

    test('appending a page keeps earlier items', () {
      final first = unwrapPaginated(doctorListResponse, DoctorCard.fromJson);
      final combined = first.append(first);

      expect(combined.items, hasLength(4));
    });

    test('money stays a string — never a double', () {
      // 300.00 through a binary float and back is how you end up displaying
      // 299.99999. The backend uses DecimalField; so do we.
      expect(parseMoney('300.00'), '300.00');
      expect(parseMoney(null), isNull);
    });

    test('timestamps are normalised to UTC', () {
      final t = parseUtc('2026-10-01T10:00:00Z');
      expect(t, isNotNull);
      expect(t!.isUtc, isTrue);
    });
  });

  group('Me', () {
    test('parses the login payload', () {
      final me = Me.fromJson(unwrapObject(loginResponse)['user'] as Map<String, dynamic>);

      expect(me.role, UserRole.patient);
      expect(me.phone, '+201099990001');
      expect(me.isPhoneVerified, isTrue);
      expect(me.patientProfile?.fullName, 'مريض الاختبار');
      expect(me.doctorProfile, isNull);
      expect(me.doctorApplication, isNull);
    });

    test('surfaces outstanding policy re-acceptance', () {
      final me = Me.fromJson(unwrapObject(meResponse));

      expect(me.requiresReacceptance, containsAll(['privacy', 'terms']));
      expect(me.mustReacceptPolicies, isTrue);
    });

    test('an unknown role degrades instead of throwing', () {
      final me = Me.fromJson({...meResponseData, 'role': 'chief_wizard'});

      expect(me.role, UserRole.unknown);
      expect(me.role.isStaff, isFalse, reason: 'an unknown role grants nothing');
    });

    test('tokens are only usable when both halves are present', () {
      expect(AuthTokens.fromJson(unwrapObject(loginResponse)).isUsable, isTrue);
      expect(const AuthTokens(access: 'a', refresh: '').isUsable, isFalse);
    });

    group('an applicant', () {
      late Me me;
      setUp(() => me = Me.fromJson(unwrapObject(meApplicantResponse)));

      test('is still a patient while under review', () {
        expect(me.role, UserRole.patient);
        expect(me.isActiveDoctor, isFalse);
      });

      test('holds a draft profile, which is exactly why kind must be read', () {
        expect(me.doctorProfile, isNotNull);
        expect(me.doctorProfile!.isApproved, isFalse);
        expect(me.doctorApplication!.kind, ApplicationKind.application);
      });

      test('has an open application', () {
        expect(me.hasOpenApplication, isTrue);
        expect(me.doctorApplication!.status, ApplicationStatus.pending);
        expect(me.doctorApplication!.needsDoctorAction, isFalse);
      });
    });

    test('a claimant holds no profile at all', () {
      final me = Me.fromJson(unwrapObject(meClaimantResponse));

      expect(
        me.doctorProfile,
        isNull,
        reason: 'which is why the claim cannot be inferred from a profile',
      );
      expect(me.doctorApplication!.kind, ApplicationKind.claim);
      expect(me.doctorApplication!.doctorName, 'د. سارة علي');
    });

    test('display and short names degrade through the available fields', () {
      final me = Me.fromJson(unwrapObject(meResponse));
      expect(me.displayName, 'مريض الاختبار');
      expect(me.shortName.split(' '), hasLength(2));

      final bare = Me.fromJson({
        ...meResponseData,
        'patient_profile': null,
        'full_name': '',
        'first_name': '',
      });
      expect(bare.displayName, bare.phone, reason: 'falls back to the login identifier');
    });
  });

  group('DoctorCard', () {
    late DoctorCard doctor;
    setUp(() => doctor = DoctorCard.fromJson(doctorCardData));

    test('parses the captured card', () {
      expect(doctor.slug, 'mohamed-ebrahim');
      expect(doctor.displayName, 'محمد ابراهيم');
      expect(doctor.yearsOfExperience, 45);
      expect(doctor.primarySpecialization?.slug, 'cardiology');
      expect(doctor.bookingEnabled, isTrue);
    });

    test('keeps the fee as the server sent it', () {
      expect(doctor.minFee, '300.00');
    });

    test('uses the pre-built contact URLs rather than rebuilding them', () {
      expect(doctor.contact.telUrl, 'tel:+201014253965');
      expect(doctor.contact.canCall, isTrue);
      expect(doctor.contact.whatsappUrl, startsWith('https://wa.me/'));
      expect(doctor.contact.canWhatsapp, isTrue);
    });

    test('joins area and city for display', () {
      expect(doctor.locationLabel, 'طنطا، الغربية');
    });

    test('an empty contact block does not claim it can call', () {
      final d = DoctorCard.fromJson({...doctorCardData, 'contact': <String, dynamic>{}});
      expect(d.contact.canCall, isFalse);
      expect(d.contact.canWhatsapp, isFalse);
    });

    test('rating parses from its decimal string', () {
      expect(DoctorCard.fromJson(doctorCardData2).rating, 4.5);
      expect(doctor.rating, 0);
    });
  });

  group('Specialization tree', () {
    test('flattens parents with their children', () {
      final tree = unwrapList(specializationsResponse).map(Specialization.fromJson).toList();
      final flat = tree.expand((s) => s.flattened).toList();

      expect(tree, hasLength(2));
      expect(flat.map((s) => s.slug), containsAll(['dentistry', 'orthodontics', 'cardiology']));
    });
  });

  group('locations', () {
    test('the search list and the onboarding list are genuinely different', () {
      final all = unwrapList(citiesResponse).map(City.fromJson).toList();
      final onboarding = unwrapList(onboardingCitiesResponse).map(City.fromJson).toList();

      // Patients must be able to search every city the directory serves…
      expect(all.map((c) => c.slug), containsAll(['cairo', 'giza', 'gharbia']));
      // …while doctor registration is narrower. Merging these would either
      // restrict patient search or let a doctor apply where we do not operate.
      expect(onboarding.map((c) => c.slug), ['gharbia']);
      expect(onboarding.single.areas.map((a) => a.slug), ['tanta']);
    });

    test('areas nest under their city', () {
      final cities = unwrapList(citiesResponse).map(City.fromJson).toList();
      final giza = cities.firstWhere((c) => c.slug == 'giza');
      expect(giza.areas.map((a) => a.slug), ['dokki', 'mohandessin']);
    });
  });

  group('availability', () {
    late DoctorAvailability availability;
    setUp(() => availability = DoctorAvailability.fromJson(unwrapObject(availabilityResponse)));

    test('parses the captured response', () {
      expect(availability.bookingEnabled, isTrue);
      expect(availability.timezone, 'Africa/Cairo');
      expect(availability.fee, '300.00');
      expect(availability.days, hasLength(2));
    });

    test('days with no slots are excluded from the picker source', () {
      expect(availability.daysWithSlots, hasLength(1));
      expect(availability.daysWithSlots.single.date, '2026-10-01');
      expect(availability.hasAnySlot, isTrue);
    });

    test('a slot keeps UTC for the wire and the server label for display', () {
      final slot = availability.daysWithSlots.single.slots.first;

      expect(slot.startAt.isUtc, isTrue);
      expect(slot.startAt.hour, 10, reason: 'UTC, as sent');
      // Africa/Cairo is UTC+3 here, and this is the label the *server* formatted.
      // Deriving it locally would use the phone's zone and mislead a patient
      // booking from abroad.
      expect(slot.displayTime, '13:00');
      expect(slot.durationMinutes, 30);
    });

    test('an empty body yields an unbookable, empty availability', () {
      expect(DoctorAvailability.empty.hasAnySlot, isFalse);
      expect(DoctorAvailability.empty.bookingEnabled, isFalse);
    });
  });

  group('PatientBooking', () {
    late PatientBooking booking;
    setUp(() => booking = PatientBooking.fromJson(bookingData));

    test('parses the captured booking', () {
      expect(booking.doctorName, 'احمد رضا');
      expect(booking.clinicName, 'طنطا');
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.visitType, VisitType.firstVisit);
      expect(booking.feeSnapshot, '300.00');
      expect(booking.durationMinutes, 30);
    });

    test('shows the server-formatted date and time', () {
      expect(booking.displayDate, '2026-10-01');
      expect(booking.displayTime, '13:00');
      expect(booking.startAt.isUtc, isTrue);
    });

    test('takes can_cancel from the server rather than computing a cutoff', () {
      expect(booking.canCancel, isTrue);
      expect(booking.cancellationCutoffAt, isNotNull);

      final locked = PatientBooking.fromJson({...bookingData, 'can_cancel': false});
      expect(locked.canCancel, isFalse);
    });

    test('status groups behave as the lifecycle implies', () {
      expect(BookingStatus.pending.isActive, isTrue);
      expect(BookingStatus.confirmed.isActive, isTrue);
      expect(BookingStatus.completed.isFinished, isTrue);
      expect(BookingStatus.cancelledByPatient.isCancelled, isTrue);
      expect(BookingStatus.cancelledByClinic.isCancelled, isTrue);
      expect(BookingStatus.noShow.isActive, isFalse);
    });

    test('every backend status value is recognised', () {
      // Taken from BookingStatusEnum in the OpenAPI schema.
      const wire = [
        'pending',
        'confirmed',
        'cancelled_by_patient',
        'cancelled_by_clinic',
        'completed',
        'no_show',
        'rescheduled',
        'expired',
      ];
      for (final w in wire) {
        expect(BookingStatus.parse(w), isNot(BookingStatus.unknown), reason: w);
      }
      expect(BookingStatus.parse('something_new'), BookingStatus.unknown);
    });

    test('visit types round-trip to the wire values the backend expects', () {
      expect(VisitType.firstVisit.wire, 'first_visit');
      expect(VisitType.followUp.wire, 'follow_up');
      expect(VisitType.parse('follow_up'), VisitType.followUp);
      // An unknown value must not crash a booking list.
      expect(VisitType.parse('nonsense'), VisitType.firstVisit);
    });
  });
}

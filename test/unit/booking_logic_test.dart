import 'package:aleyada_mobile/features/bookings/booking_logic.dart';
import 'package:aleyada_mobile/features/bookings/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_fixtures.dart';
import '../fixtures/booking_fixtures.dart';

void main() {
  PatientBooking b(String id, DateTime start, {String status = 'confirmed'}) =>
      PatientBooking.fromJson(patientBooking(id: id, start: start, status: status));

  group('sections', () {
    test('status decides first; time only separates active bookings', () {
      final now = testNow;
      expect(sectionFor(b('a', DateTime.utc(2030, 1, 2)), now), BookingsTab.upcoming);
      expect(
        sectionFor(b('a', DateTime.utc(2030, 1, 2), status: 'pending'), now),
        BookingsTab.upcoming,
      );
      expect(
        sectionFor(b('a', DateTime.utc(2029, 12, 2)), now),
        BookingsTab.past,
        reason: 'lapsed',
      );
      expect(
        sectionFor(b('a', DateTime.utc(2030, 2, 2), status: 'completed'), now),
        BookingsTab.past,
      );
      for (final s in ['no_show', 'expired', 'rescheduled']) {
        expect(
          sectionFor(b('a', DateTime.utc(2030, 2, 2), status: s), now),
          BookingsTab.past,
          reason: s,
        );
      }
      for (final s in ['cancelled_by_patient', 'cancelled_by_clinic']) {
        expect(
          sectionFor(b('a', DateTime.utc(2030, 2, 2), status: s), now),
          BookingsTab.cancelled,
          reason: s,
        );
      }
    });

    test('an appointment in progress is still upcoming until it ends', () {
      // Starts 10 minutes ago, 30 minutes long.
      final started = b('a', testNow.subtract(const Duration(minutes: 10)));
      expect(sectionFor(started, testNow), BookingsTab.upcoming);
    });

    test('upcoming soonest first; past and cancelled most recent first', () {
      final g = groupBookings([
        b('u2', DateTime.utc(2030, 3, 1)),
        b('p1', DateTime.utc(2029, 1, 1), status: 'completed'),
        b('u1', DateTime.utc(2030, 1, 5)),
        b('p2', DateTime.utc(2029, 6, 1), status: 'completed'),
        b('c1', DateTime.utc(2029, 6, 1), status: 'cancelled_by_patient'),
        b('c2', DateTime.utc(2030, 6, 1), status: 'cancelled_by_clinic'),
      ], testNow);
      expect(g.upcoming.map((x) => x.id), ['u1', 'u2']);
      expect(g.next?.id, 'u1');
      expect(g.past.map((x) => x.id), ['p2', 'p1']);
      expect(g.cancelled.map((x) => x.id), ['c2', 'c1']);
      expect(BookingGroups.empty.next, isNull);
    });
  });

  group('countdown', () {
    final start = DateTime.utc(2030, 1, 5, 7);
    final end = start.add(const Duration(minutes: 30));

    test('one honest unit, from two UTC instants', () {
      expect(countdownTo(start, end, testNow), (unit: CountdownUnit.days, value: 4));
      expect(countdownTo(start, end, start.subtract(const Duration(hours: 5, minutes: 59))), (
        unit: CountdownUnit.hours,
        value: 5,
      ));
      expect(countdownTo(start, end, start.subtract(const Duration(minutes: 42))), (
        unit: CountdownUnit.minutes,
        value: 42,
      ));
      expect(
        countdownTo(start, end, start.subtract(const Duration(seconds: 20))),
        (unit: CountdownUnit.minutes, value: 1),
        reason: 'never "in 0 minutes"',
      );
      expect(countdownTo(start, end, start.add(const Duration(minutes: 5))), (
        unit: CountdownUnit.now,
        value: 0,
      ));
      expect(countdownTo(start, end, end), isNull, reason: 'over');
    });
  });

  group('timeline', () {
    List<(TimelineStepKind, TimelineState)> steps(String status, DateTime start) => [
      for (final s in timelineFor(b('a', start, status: status), testNow)) (s.kind, s.state),
    ];

    test('confirmed and ahead', () {
      expect(steps('confirmed', DateTime.utc(2030, 2, 1)), [
        (TimelineStepKind.booked, TimelineState.done),
        (TimelineStepKind.confirmed, TimelineState.done),
        (TimelineStepKind.appointment, TimelineState.upcoming),
      ]);
    });

    test('pending shows the wait', () {
      expect(steps('pending', DateTime.utc(2030, 2, 1))[1], (
        TimelineStepKind.awaiting,
        TimelineState.current,
      ));
    });

    test('completed, no-show and cancelled end in their outcome', () {
      expect(steps('completed', DateTime.utc(2029, 2, 1)).last, (
        TimelineStepKind.outcome,
        TimelineState.done,
      ));
      expect(steps('no_show', DateTime.utc(2029, 2, 1)).last, (
        TimelineStepKind.outcome,
        TimelineState.failed,
      ));
      expect(steps('cancelled_by_clinic', DateTime.utc(2030, 2, 1)), [
        (TimelineStepKind.booked, TimelineState.done),
        (TimelineStepKind.outcome, TimelineState.failed),
      ]);
    });
  });

  group('matching the booking\'s clinic on the doctor\'s profile', () {
    final clinics = [('1', 'عيادة أ'), ('2', 'عيادة ب'), ('3', 'عيادة ب')];
    (String, String)? match({String? id, required String name}) => matchClinic<(String, String)>(
      clinics,
      idOf: (c) => c.$1,
      nameOf: (c) => c.$2,
      clinicId: id,
      clinicName: name,
    );

    test('by id first, then by exact name', () {
      expect(match(id: '2', name: 'anything'), ('2', 'عيادة ب'));
      expect(match(name: ' عيادة أ '), ('1', 'عيادة أ'));
    });

    test('ambiguous or absent: no match — nothing is borrowed', () {
      expect(match(name: 'عيادة ب'), isNull, reason: 'two clinics share the name');
      expect(match(name: 'غير موجودة'), isNull);
      expect(match(name: ''), isNull);
      expect(match(id: 'x', name: 'غير موجودة'), isNull);
    });
  });

  group('parsing', () {
    test('payment status', () {
      expect(PaymentState.parse('proof_pending'), PaymentState.proofPending);
      expect(PaymentState.parse('accepted'), PaymentState.accepted);
      expect(PaymentState.parse('something_new'), PaymentState.unknown);
    });

    test('the clinic id is read when the booking carries one', () {
      expect(
        PatientBooking.fromJson(bookingData).clinicId,
        isNull,
        reason: 'the captured one has none',
      );
      final withId = PatientBooking.fromJson({
        ...bookingData,
        'clinic': {'id': 'c-9', 'name_ar': 'طنطا'},
      });
      expect(withId.clinicId, 'c-9');
    });
  });
}

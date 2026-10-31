import '../../core/api/api_error.dart';
import 'models.dart';

/// Decisions My Bookings and Booking Details share, kept free of widgets.

/// The sections of My Bookings.
enum BookingsTab { upcoming, past, cancelled }

/// The patient's bookings, split and sorted for reading.
class BookingGroups {
  const BookingGroups({required this.upcoming, required this.past, required this.cancelled});

  /// Soonest first.
  final List<PatientBooking> upcoming;

  /// Most recent first.
  final List<PatientBooking> past;

  /// Most recent first.
  final List<PatientBooking> cancelled;

  List<PatientBooking> of(BookingsTab tab) => switch (tab) {
    BookingsTab.upcoming => upcoming,
    BookingsTab.past => past,
    BookingsTab.cancelled => cancelled,
  };

  /// The appointment to feature at the top of the upcoming section.
  PatientBooking? get next => upcoming.firstOrNull;

  static const empty = BookingGroups(upcoming: [], past: [], cancelled: []);
}

/// Which section a booking belongs in.
///
/// Decided by the server's `status` first. Time only separates an active
/// booking that is still ahead from one whose slot has passed without the clinic
/// closing it yet — and that comparison is between two UTC instants (`end_at`
/// from the server, the device clock in UTC), so it does not depend on the
/// phone's timezone.
BookingsTab sectionFor(PatientBooking b, DateTime nowUtc) {
  if (b.status.isCancelled) return BookingsTab.cancelled;
  if (b.status.isActive && b.endAt.isAfter(nowUtc)) return BookingsTab.upcoming;
  return BookingsTab.past;
}

BookingGroups groupBookings(List<PatientBooking> all, DateTime nowUtc) {
  final upcoming = <PatientBooking>[];
  final past = <PatientBooking>[];
  final cancelled = <PatientBooking>[];
  for (final b in all) {
    switch (sectionFor(b, nowUtc)) {
      case BookingsTab.upcoming:
        upcoming.add(b);
      case BookingsTab.past:
        past.add(b);
      case BookingsTab.cancelled:
        cancelled.add(b);
    }
  }
  upcoming.sort((a, b) => a.startAt.compareTo(b.startAt));
  past.sort((a, b) => b.startAt.compareTo(a.startAt));
  cancelled.sort((a, b) => b.startAt.compareTo(a.startAt));
  return BookingGroups(upcoming: upcoming, past: past, cancelled: cancelled);
}

/// How far away an appointment is, as one unit.
enum CountdownUnit { now, minutes, hours, days }

/// The time until [startUtc], or null when it is over.
///
/// A duration between two UTC instants — exact whatever the phone's timezone.
/// Deliberately never "today" or "tomorrow": those depend on *whose* calendar
/// day it is, and the clinic's and the patient's can differ.
({CountdownUnit unit, int value})? countdownTo(
  DateTime startUtc,
  DateTime endUtc,
  DateTime nowUtc,
) {
  if (!endUtc.isAfter(nowUtc)) return null;
  final left = startUtc.difference(nowUtc);
  if (left <= Duration.zero) return (unit: CountdownUnit.now, value: 0);
  if (left < const Duration(hours: 1)) {
    return (unit: CountdownUnit.minutes, value: left.inMinutes < 1 ? 1 : left.inMinutes);
  }
  if (left < const Duration(days: 1)) return (unit: CountdownUnit.hours, value: left.inHours);
  return (unit: CountdownUnit.days, value: left.inDays);
}

/// The steps of a booking's life the API can actually vouch for.
///
/// Only two timestamps exist — `created_at` and the appointment itself — so no
/// step invents a time for "confirmed" or "completed"; those show the state
/// alone.
enum TimelineStepKind { booked, awaiting, confirmed, appointment, outcome }

enum TimelineState { done, current, upcoming, failed }

class TimelineStep {
  const TimelineStep(this.kind, this.state);

  final TimelineStepKind kind;
  final TimelineState state;
}

List<TimelineStep> timelineFor(PatientBooking b, DateTime nowUtc) {
  final s = b.status;
  if (s.isCancelled || s == BookingStatus.expired || s == BookingStatus.rescheduled) {
    return const [
      TimelineStep(TimelineStepKind.booked, TimelineState.done),
      TimelineStep(TimelineStepKind.outcome, TimelineState.failed),
    ];
  }
  if (s == BookingStatus.completed) {
    return const [
      TimelineStep(TimelineStepKind.booked, TimelineState.done),
      TimelineStep(TimelineStepKind.confirmed, TimelineState.done),
      TimelineStep(TimelineStepKind.appointment, TimelineState.done),
      TimelineStep(TimelineStepKind.outcome, TimelineState.done),
    ];
  }
  if (s == BookingStatus.noShow) {
    return const [
      TimelineStep(TimelineStepKind.booked, TimelineState.done),
      TimelineStep(TimelineStepKind.confirmed, TimelineState.done),
      TimelineStep(TimelineStepKind.outcome, TimelineState.failed),
    ];
  }
  final passed = !b.startAt.isAfter(nowUtc);
  if (s == BookingStatus.pending) {
    return [
      const TimelineStep(TimelineStepKind.booked, TimelineState.done),
      const TimelineStep(TimelineStepKind.awaiting, TimelineState.current),
      TimelineStep(
        TimelineStepKind.appointment,
        passed ? TimelineState.current : TimelineState.upcoming,
      ),
    ];
  }
  // Confirmed (and anything unrecognised that is still active).
  return [
    const TimelineStep(TimelineStepKind.booked, TimelineState.done),
    const TimelineStep(TimelineStepKind.confirmed, TimelineState.done),
    TimelineStep(
      TimelineStepKind.appointment,
      passed ? TimelineState.current : TimelineState.upcoming,
    ),
  ];
}

/// `PaymentStatusEnum`, parsed permissively.
enum PaymentState {
  notRequired,
  proofPending,
  proofUploaded,
  accepted,
  rejected,
  unknown;

  static PaymentState parse(String raw) => switch (raw) {
    'not_required' => notRequired,
    'proof_pending' => proofPending,
    'proof_uploaded' => proofUploaded,
    'accepted' => accepted,
    'rejected' => rejected,
    _ => unknown,
  };
}

/// Whether a booking request that failed may nonetheless have created the
/// booking.
///
/// The booking endpoint takes no idempotency key, so the answer is the only
/// proof of what happened. An answer the server sent and the app read — a
/// validation error, 401, 403, 404, 409, 429 — is a refusal: nothing was made.
/// Without one the request may still have been carried out:
///
///  * no answer at all — a timeout or a connection lost once the request may
///    already be on its way (a failure to connect at all cannot be told apart);
///  * a 5xx — the server, or a gateway in front of it, failed, possibly after
///    the booking was saved;
///  * a 2xx that could not be read, which almost certainly means it was made.
bool bookingOutcomeUncertain(Object error) {
  if (error is! ApiException) return true;
  return switch (error.failure) {
    ApiFailure.network || ApiFailure.server => true,
    // No status means no answer (a failed handshake, for instance).
    ApiFailure.unexpected => error.statusCode == null,
    _ => false,
  };
}

/// The patient's active booking for this doctor at [startAt] (a UTC instant),
/// and at [clinicId] when both sides name one — the booking a submission whose
/// answer was lost would have made. Null when there is none in [bookings].
///
/// The API returns no slot id on a booking and no request reference, so the
/// doctor, the time and the clinic are what identify it. A patient cannot hold
/// two active bookings with one doctor at one time, so at most one matches.
PatientBooking? findSubmittedBooking(
  List<PatientBooking> bookings, {
  required String doctorSlug,
  required DateTime startAt,
  String? clinicId,
}) {
  for (final b in bookings) {
    if (!b.status.isActive || b.doctorSlug != doctorSlug) continue;
    if (!b.startAt.isAtSameMomentAs(startAt)) continue;
    if (clinicId != null && b.clinicId != null && b.clinicId != clinicId) continue;
    return b;
  }
  return null;
}

/// The booking's clinic on the doctor's public profile: by id when the booking
/// carries one, else by exact Arabic name. Null when there is no single match —
/// a map link or phone number is never borrowed from a different clinic.
T? matchClinic<T>(
  List<T> clinics, {
  required String Function(T) idOf,
  required String Function(T) nameOf,
  String? clinicId,
  required String clinicName,
}) {
  if (clinicId != null && clinicId.isNotEmpty) {
    final byId = clinics.where((c) => idOf(c) == clinicId).toList();
    if (byId.length == 1) return byId.single;
  }
  final name = clinicName.trim();
  if (name.isEmpty) return null;
  final byName = clinics.where((c) => nameOf(c).trim() == name).toList();
  return byName.length == 1 ? byName.single : null;
}

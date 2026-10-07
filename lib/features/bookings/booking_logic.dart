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

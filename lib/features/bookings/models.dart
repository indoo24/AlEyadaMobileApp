import '../../core/api/envelope.dart';
import '../doctors/models.dart' show ContactInfo;

/// One bookable slot.
///
/// [startAt] is UTC and is what gets sent back to the server. [displayTime] is
/// the clinic-local wall-clock string the *backend* formatted, and it is what the
/// user is shown. Converting UTC to a local label in the app would use the
/// phone's timezone, which is not necessarily the clinic's — a patient booking
/// from abroad would otherwise see the wrong hour for their own appointment.
class Slot {
  const Slot({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.displayTime,
    required this.displayEndTime,
    required this.durationMinutes,
  });

  final String id;
  final DateTime startAt;
  final DateTime endAt;

  /// Clinic-local, formatted by the backend. Show this.
  final String displayTime;
  final String displayEndTime;
  final int durationMinutes;

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
    id: parseString(j['id']),
    startAt: parseUtc(j['start_at']) ?? DateTime.now().toUtc(),
    endAt: parseUtc(j['end_at']) ?? DateTime.now().toUtc(),
    displayTime: parseString(j['display_time']),
    displayEndTime: parseString(j['display_end_time']),
    durationMinutes: parseInt(j['default_duration_minutes']) ?? 30,
  );
}

/// One day of a doctor's offer at one clinic.
class AvailabilityDay {
  const AvailabilityDay({required this.date, required this.slots});

  /// `YYYY-MM-DD` in the clinic's timezone.
  final String date;
  final List<Slot> slots;

  bool get hasSlots => slots.isNotEmpty;

  factory AvailabilityDay.fromJson(Map<String, dynamic> j) {
    final raw = j['slots'];
    return AvailabilityDay(
      date: parseString(j['date']),
      slots: raw is List
          ? raw.whereType<Map>().map((e) => Slot.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
    );
  }
}

/// `/doctors/{slug}/availability/` — the whole offer for one clinic.
///
/// The live endpoint answers with an object (the spec documents a bare list of
/// days). For a contact-only doctor it carries no days but the doctor's phone
/// links and a server-written [message] instead.
class DoctorAvailability {
  const DoctorAvailability({
    required this.bookingEnabled,
    required this.days,
    required this.paymentRequired,
    this.clinicId,
    this.timezone,
    this.fee,
    this.message = '',
    this.contact = ContactInfo.empty,
  });

  final bool bookingEnabled;
  final List<AvailabilityDay> days;
  final bool paymentRequired;
  final String? clinicId;
  final String? timezone;
  final String? fee;

  /// The server's own explanation when booking is closed (Arabic, ready to show).
  final String message;

  /// Phone and WhatsApp links, sent when the doctor takes bookings by phone only.
  final ContactInfo contact;

  List<AvailabilityDay> get daysWithSlots => days.where((d) => d.hasSlots).toList();
  bool get hasAnySlot => days.any((d) => d.hasSlots);

  factory DoctorAvailability.fromJson(Map<String, dynamic> j) {
    final raw = j['days'];
    return DoctorAvailability(
      bookingEnabled: j['booking_enabled'] == true,
      paymentRequired: j['payment_required'] == true,
      clinicId: j['clinic_id'] as String?,
      timezone: j['timezone'] as String?,
      fee: parseMoney(j['fee']),
      message: parseString(j['message']).trim(),
      contact: ContactInfo.fromJson(j),
      days: raw is List
          ? raw
                .whereType<Map>()
                .map((e) => AvailabilityDay.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }

  static const empty = DoctorAvailability(bookingEnabled: false, days: [], paymentRequired: false);
}

/// Booking lifecycle states. Mirrors `BookingStatusEnum`.
enum BookingStatus {
  pending,
  confirmed,
  cancelledByPatient,
  cancelledByClinic,
  completed,
  noShow,
  rescheduled,
  expired,
  unknown;

  static BookingStatus parse(String? raw) => switch (raw) {
    'pending' => pending,
    'confirmed' => confirmed,
    'cancelled_by_patient' => cancelledByPatient,
    'cancelled_by_clinic' => cancelledByClinic,
    'completed' => completed,
    'no_show' => noShow,
    'rescheduled' => rescheduled,
    'expired' => expired,
    _ => unknown,
  };

  bool get isCancelled => this == cancelledByPatient || this == cancelledByClinic;

  /// Whether this booking still lies ahead of the patient.
  bool get isActive => this == pending || this == confirmed;

  bool get isFinished =>
      this == completed || this == noShow || isCancelled || this == expired || this == rescheduled;
}

enum VisitType {
  firstVisit,
  followUp,
  consultation,
  procedure,
  custom;

  String get wire => switch (this) {
    firstVisit => 'first_visit',
    followUp => 'follow_up',
    consultation => 'consultation',
    procedure => 'procedure',
    custom => 'custom',
  };

  static VisitType parse(String? raw) => switch (raw) {
    'follow_up' => followUp,
    'consultation' => consultation,
    'procedure' => procedure,
    'custom' => custom,
    _ => firstVisit,
  };
}

/// A patient's own appointment.
///
/// Note [canCancel] and [cancellationCutoffAt]: the backend computes both and
/// documents them as "the server decides" and "the policy is returned, not
/// hardcoded in the app". This app renders a button or does not; it never
/// recomputes the cutoff.
class PatientBooking {
  const PatientBooking({
    required this.id,
    required this.doctorName,
    required this.doctorSlug,
    required this.clinicName,
    required this.startAt,
    required this.endAt,
    required this.displayDate,
    required this.displayTime,
    required this.durationMinutes,
    required this.status,
    required this.visitType,
    required this.canCancel,
    required this.paymentRequired,
    required this.paymentStatus,
    required this.cancellationReason,
    this.feeSnapshot,
    this.cancellationCutoffAt,
    this.reasonForVisit,
    this.notesForDoctor,
    this.doctorPhoto,
    this.clinicAddress,
    this.clinicId,
    this.createdAt,
  });

  final String id;
  final String doctorName;
  final String doctorSlug;
  final String clinicName;
  final String? clinicAddress;

  /// The clinic's id when the nested `clinic` object carries one. Used only to
  /// find that clinic on the doctor's public profile (for its map link and
  /// phone); the name is the fallback match.
  final String? clinicId;
  final String? doctorPhoto;

  /// UTC — the source of truth for ordering and comparison.
  final DateTime startAt;
  final DateTime endAt;

  /// Clinic-local, formatted by the backend. Show these.
  final String displayDate;
  final String displayTime;

  final int durationMinutes;
  final BookingStatus status;
  final VisitType visitType;

  /// The server's answer to "may this be cancelled now?".
  final bool canCancel;
  final DateTime? cancellationCutoffAt;
  final String cancellationReason;

  final String? feeSnapshot;
  final bool paymentRequired;
  final String paymentStatus;
  final String? reasonForVisit;
  final String? notesForDoctor;
  final DateTime? createdAt;

  bool get isUpcoming => status.isActive && startAt.isAfter(DateTime.now().toUtc());

  factory PatientBooking.fromJson(Map<String, dynamic> j) {
    final doctor = j['doctor'];
    final clinic = j['clinic'];
    Map<String, dynamic>? asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
    final d = asMap(doctor);
    final c = asMap(clinic);
    return PatientBooking(
      id: parseString(j['id']),
      doctorName: parseString(d?['display_name'] ?? d?['full_name_ar'] ?? ''),
      doctorSlug: parseString(d?['slug']),
      doctorPhoto: d?['photo'] as String?,
      clinicName: parseString(c?['name_ar']),
      clinicAddress: c?['address_ar'] as String?,
      clinicId: parseString(c?['id']).trim().isEmpty ? null : parseString(c?['id']).trim(),
      startAt: parseUtc(j['start_at']) ?? DateTime.now().toUtc(),
      endAt: parseUtc(j['end_at']) ?? DateTime.now().toUtc(),
      displayDate: parseString(j['display_date']),
      displayTime: parseString(j['display_time']),
      durationMinutes: parseInt(j['duration_minutes']) ?? 30,
      status: BookingStatus.parse(j['status'] as String?),
      visitType: VisitType.parse(j['visit_type'] as String?),
      canCancel: j['can_cancel'] == true,
      cancellationCutoffAt: parseUtc(j['cancellation_cutoff_at']),
      cancellationReason: parseString(j['cancellation_reason']),
      feeSnapshot: parseMoney(j['fee_snapshot']),
      paymentRequired: j['payment_required'] == true,
      paymentStatus: parseString(j['payment_status']),
      reasonForVisit: j['reason_for_visit'] as String?,
      notesForDoctor: j['notes_for_doctor'] as String?,
      createdAt: parseUtc(j['created_at']),
    );
  }
}

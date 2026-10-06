import '../../core/api/envelope.dart';
import '../bookings/models.dart';

/// `"09:00:00"` → `"09:00"`. The backend sends clinic-local times with seconds;
/// nobody reading a clinic's hours wants them.
String shortTime(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

/// One opening shift of a clinic. A weekday with a split shift has two.
class WorkingShift {
  const WorkingShift({
    required this.weekday,
    required this.open,
    required this.close,
    this.label = '',
  });

  /// ISO weekday, the backend's own: Monday = 1 … Sunday = 7.
  final int weekday;
  final String open;
  final String close;

  /// The weekday's Arabic name, as the backend labelled it.
  final String label;

  factory WorkingShift.fromJson(Map<String, dynamic> j) => WorkingShift(
    weekday: parseInt(j['weekday']) ?? 1,
    open: shortTime(parseString(j['open_time'])),
    close: shortTime(parseString(j['close_time'])),
    label: parseString(j['weekday_label']),
  );

  Map<String, dynamic> toJson() => {'weekday': weekday, 'open_time': open, 'close_time': close};

  WorkingShift copyWith({int? weekday, String? open, String? close}) => WorkingShift(
    weekday: weekday ?? this.weekday,
    open: open ?? this.open,
    close: close ?? this.close,
  );
}

/// A clinic as the doctor manages it (`GET /doctor/clinics/`): the clinic plus
/// *this doctor's* terms there.
class MyClinic {
  const MyClinic({
    required this.id,
    required this.clinicId,
    required this.nameAr,
    required this.addressAr,
    required this.phone,
    required this.clinicIsActive,
    required this.iOwnIt,
    required this.bookingEnabled,
    required this.paymentRequired,
    required this.isPrimary,
    required this.isActive,
    required this.workingHours,
    required this.setupComplete,
    required this.blocking,
    this.consultationFee,
    this.followupFee,
  });

  /// The doctor-clinic link's id — the key every `/doctor/clinics/{id}/…` route
  /// and the assistants' clinic scope use.
  final String id;
  final String clinicId;
  final String nameAr;
  final String addressAr;
  final String phone;
  final bool clinicIsActive;

  /// Whether this doctor created the clinic (only owners edit it or invite).
  final bool iOwnIt;
  final String? consultationFee;
  final String? followupFee;
  final bool bookingEnabled;
  final bool paymentRequired;
  final bool isPrimary;
  final bool isActive;
  final List<WorkingShift> workingHours;

  /// True when nothing stops this clinic taking a booking.
  final bool setupComplete;

  /// Every reason it cannot take one yet, as the backend phrased them.
  final List<String> blocking;

  factory MyClinic.fromJson(Map<String, dynamic> j) {
    final hours = j['working_hours'];
    final blocking = j['blocking'];
    return MyClinic(
      id: parseString(j['id']),
      clinicId: parseString(j['clinic_id']),
      nameAr: parseString(j['name_ar']),
      addressAr: parseString(j['address_ar']),
      phone: parseString(j['phone']),
      clinicIsActive: j['clinic_is_active'] != false,
      iOwnIt: j['i_own_it'] == true,
      consultationFee: parseMoney(j['consultation_fee']),
      followupFee: parseMoney(j['followup_fee']),
      bookingEnabled: j['booking_enabled'] == true,
      paymentRequired: j['payment_required'] == true,
      isPrimary: j['is_primary'] == true,
      isActive: j['is_active'] != false,
      setupComplete: j['setup_complete'] == true,
      workingHours: hours is List
          ? hours
                .whereType<Map>()
                .map((e) => WorkingShift.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      blocking: blocking is List
          ? [
              for (final b in blocking)
                if (b is Map) parseString(b['message'] ?? b['label'] ?? b['code']) else b.toString(),
            ]
          : const [],
    );
  }
}

/// What an assistant may do under one assignment — the backend's own flags.
const assistantFlagKeys = <String>[
  'can_view_bookings',
  'can_create_bookings',
  'can_update_bookings',
  'can_cancel_bookings',
  'can_manage_schedule',
  'can_view_patient_phone',
  'can_create_patient_next_visit',
  'can_request_duration_verification',
  'can_review_payment_proofs',
];

class AssistantAssignment {
  const AssistantAssignment({
    required this.id,
    required this.clinicName,
    required this.coversAllClinics,
    required this.flags,
    required this.isActive,
    this.clinicId,
  });

  final String id;
  final String? clinicId;
  final String clinicName;
  final bool coversAllClinics;
  final Map<String, bool> flags;
  final bool isActive;

  int get grantedCount => flags.values.where((v) => v).length;

  factory AssistantAssignment.fromJson(Map<String, dynamic> j) {
    final raw = j['flags'];
    return AssistantAssignment(
      id: parseString(j['id']),
      clinicId: j['clinic'] as String?,
      clinicName: parseString(j['clinic_name']),
      coversAllClinics: j['covers_all_clinics'] == true,
      isActive: j['is_active'] != false,
      flags: {
        if (raw is Map)
          for (final e in raw.entries)
            if (e.value is bool) e.key.toString(): e.value as bool,
      },
    );
  }
}

class AssistantProfile {
  const AssistantProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.isActive,
    required this.notes,
    required this.assignments,
  });

  final String id;
  final String fullName;
  final String phone;
  final bool isActive;
  final String notes;
  final List<AssistantAssignment> assignments;

  factory AssistantProfile.fromJson(Map<String, dynamic> j) {
    final a = j['assignments'];
    return AssistantProfile(
      id: parseString(j['id']),
      fullName: parseString(j['full_name']),
      phone: parseString(j['phone']),
      isActive: j['is_active'] != false,
      notes: parseString(j['notes']),
      assignments: a is List
          ? a
                .whereType<Map>()
                .map((e) => AssistantAssignment.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }
}

/// A clinic invitation this doctor sent.
class SentInvitation {
  const SentInvitation({required this.id, required this.doctorName, required this.status});

  final String id;
  final String doctorName;

  /// `pending`, `accepted`, `declined` or `cancelled`.
  final String status;

  factory SentInvitation.fromJson(Map<String, dynamic> j) {
    final d = j['invited_doctor'];
    return SentInvitation(
      id: parseString(j['id']),
      doctorName: d is Map ? parseString(d['full_name_ar']) : parseString(j['phone']),
      status: parseString(j['status']),
    );
  }
}

/// An appointment as the doctor sees it (`GET /doctor/bookings/`).
class StaffBooking {
  const StaffBooking({
    required this.id,
    required this.patientName,
    required this.patientPhone,
    required this.clinicName,
    required this.startAt,
    required this.displayTime,
    required this.durationMinutes,
    required this.status,
    this.fee,
    this.reason = '',
  });

  final String id;
  final String patientName;
  final String patientPhone;
  final String clinicName;
  final DateTime? startAt;
  final String displayTime;
  final int? durationMinutes;
  final BookingStatus status;
  final String? fee;
  final String reason;

  factory StaffBooking.fromJson(Map<String, dynamic> j) => StaffBooking(
    id: parseString(j['id']),
    patientName: parseString(j['patient_name']),
    patientPhone: parseString(j['patient_phone']),
    clinicName: parseString(j['clinic_name']),
    startAt: parseUtc(j['start_at']),
    displayTime: parseString(j['display_time']),
    durationMinutes: parseInt(j['duration_minutes']),
    status: BookingStatus.parse(j['status'] as String?),
    fee: parseMoney(j['fee_snapshot']),
    reason: parseString(j['reason_for_visit']),
  );
}

/// A recurring weekly opening window the doctor works within.
class AvailabilityWindow {
  const AvailabilityWindow({
    required this.id,
    required this.clinicId,
    required this.weekday,
    required this.weekdayLabel,
    required this.start,
    required this.end,
    required this.durationMinutes,
    required this.stepMinutes,
    required this.isActive,
  });

  final String id;
  final String clinicId;
  final int weekday;
  final String weekdayLabel;
  final String start;
  final String end;
  final int? durationMinutes;
  final int? stepMinutes;
  final bool isActive;

  factory AvailabilityWindow.fromJson(Map<String, dynamic> j) => AvailabilityWindow(
    id: parseString(j['id']),
    clinicId: parseString(j['clinic']),
    weekday: parseInt(j['weekday']) ?? 1,
    weekdayLabel: parseString(j['weekday_label']),
    start: shortTime(parseString(j['start_time'])),
    end: shortTime(parseString(j['end_time'])),
    durationMinutes: parseInt(j['default_duration_minutes']),
    stepMinutes: parseInt(j['slot_step_minutes']),
    isActive: j['is_active'] != false,
  );
}

import '../api/envelope.dart';

/// Roles the backend issues. Mirrors `apps.accounts.constants.Role`.
///
/// Parsed permissively: an unknown value becomes [unknown] rather than throwing,
/// so a backend that adds a role does not crash older installs. Nothing is
/// *granted* on an unknown role — the backend still decides every permission.
enum UserRole {
  patient,
  doctor,
  assistant,
  admin,
  superAdmin,
  unknown;

  static UserRole parse(String? raw) => switch (raw) {
    'patient' => patient,
    'doctor' => doctor,
    'assistant' => assistant,
    'admin' => admin,
    'super_admin' => superAdmin,
    _ => unknown,
  };

  /// Whether this role's home is the practice dashboard rather than the
  /// directory. Matches the website's `isStaffRole`.
  bool get isStaff => this == doctor || this == assistant || this == admin || this == superAdmin;
}

class PatientProfileSummary {
  const PatientProfileSummary({
    required this.id,
    required this.fullName,
    this.gender,
    this.birthDate,
  });

  final String id;
  final String fullName;
  final String? gender;
  final String? birthDate;

  factory PatientProfileSummary.fromJson(Map<String, dynamic> j) => PatientProfileSummary(
    id: parseString(j['id']),
    fullName: parseString(j['full_name']),
    gender: j['gender'] as String?,
    birthDate: j['birth_date'] as String?,
  );
}

/// The slice of a doctor's own profile that `/auth/me/` carries — enough to
/// route, not the whole record.
class DoctorProfileBrief {
  const DoctorProfileBrief({
    required this.id,
    required this.slug,
    required this.fullNameAr,
    required this.verificationStatus,
    required this.isPublished,
  });

  final String id;
  final String slug;
  final String fullNameAr;
  final String verificationStatus;
  final bool isPublished;

  bool get isApproved => verificationStatus == 'approved';

  factory DoctorProfileBrief.fromJson(Map<String, dynamic> j) => DoctorProfileBrief(
    id: parseString(j['id']),
    slug: parseString(j['slug']),
    fullNameAr: parseString(j['full_name_ar']),
    verificationStatus: parseString(j['verification_status']),
    isPublished: j['is_published'] == true,
  );
}

/// Which kind of request a person is waiting on.
///
/// The distinction matters and cannot be inferred from the profile: applying
/// creates a draft profile immediately, whereas a claimant holds no profile at
/// all until an admin adjudicates. The backend tells us which, in
/// `doctor_application.kind`.
enum ApplicationKind {
  /// A new doctor application.
  application,

  /// A claim of ownership over an already-imported directory profile.
  claim,
  unknown;

  static ApplicationKind parse(String? raw) => switch (raw) {
    'application' => application,
    'claim' => claim,
    _ => unknown,
  };
}

/// Request statuses. Mirrors `apps.doctors.constants.RequestStatus`.
enum ApplicationStatus {
  pending,
  inReview,
  approved,
  rejected,
  changesRequested,
  needsMoreInfo,
  unknown;

  static ApplicationStatus parse(String? raw) => switch (raw) {
    'pending' => pending,
    'in_review' => inReview,
    'approved' => approved,
    'rejected' => rejected,
    'changes_requested' => changesRequested,
    'needs_more_info' => needsMoreInfo,
    _ => unknown,
  };
}

/// Where a join request stands. From `/auth/me/`'s `doctor_application`.
class DoctorApplication {
  const DoctorApplication({
    required this.kind,
    required this.status,
    required this.isOpen,
    required this.needsDoctorAction,
    required this.rejectionReason,
    required this.doctorName,
    this.submittedAt,
    this.reviewedAt,
  });

  final ApplicationKind kind;
  final ApplicationStatus status;
  final bool isOpen;

  /// The reviewer is waiting on the doctor, not the other way round.
  final bool needsDoctorAction;

  /// Written for the doctor to read. Empty unless an admin supplied one.
  final String rejectionReason;
  final String doctorName;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  factory DoctorApplication.fromJson(Map<String, dynamic> j) => DoctorApplication(
    kind: ApplicationKind.parse(j['kind'] as String?),
    status: ApplicationStatus.parse(j['status'] as String?),
    isOpen: j['is_open'] == true,
    needsDoctorAction: j['needs_doctor_action'] == true,
    rejectionReason: parseString(j['rejection_reason']),
    doctorName: parseString(j['doctor_name']),
    submittedAt: parseUtc(j['submitted_at']),
    reviewedAt: parseUtc(j['reviewed_at']),
  );
}

/// The signed-in user, as `/auth/me/` describes them.
class Me {
  const Me({
    required this.id,
    required this.phone,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.role,
    required this.preferredLanguage,
    required this.isPhoneVerified,
    required this.requiresReacceptance,
    this.patientProfile,
    this.doctorProfile,
    this.doctorApplication,
    this.dateJoined,
  });

  final String id;
  final String phone;
  final String? email;
  final String firstName;
  final String lastName;
  final String fullName;
  final UserRole role;
  final String preferredLanguage;
  final bool isPhoneVerified;

  /// Non-empty means the backend will reject writes until these policy types
  /// are re-accepted. The app shows the consent screen; it does not decide the
  /// rule.
  final List<String> requiresReacceptance;

  final PatientProfileSummary? patientProfile;
  final DoctorProfileBrief? doctorProfile;
  final DoctorApplication? doctorApplication;
  final DateTime? dateJoined;

  bool get mustReacceptPolicies => requiresReacceptance.isNotEmpty;

  /// An approved, published doctor. Anything less and the practice area is not
  /// theirs yet — which the backend enforces regardless of what we show.
  bool get isActiveDoctor => role == UserRole.doctor && doctorProfile != null;

  /// Someone whose doctor application or claim is still being decided. They are
  /// role=patient meanwhile, deliberately, so they can browse and book normally.
  bool get hasOpenApplication => doctorApplication?.isOpen == true;

  /// A display name that degrades gracefully: the patient profile's name, then
  /// the account name, then the first name, then the phone.
  String get displayName {
    final candidates = <String?>[
      patientProfile?.fullName,
      doctorProfile?.fullNameAr,
      fullName,
      firstName,
    ];
    for (final c in candidates) {
      final v = c?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return phone;
  }

  /// The first one or two words — what the dashboard greets a doctor with.
  String get shortName {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return displayName;
    return parts.take(2).join(' ');
  }

  factory Me.fromJson(Map<String, dynamic> j) {
    final patient = j['patient_profile'];
    final doctor = j['doctor_profile'];
    final application = j['doctor_application'];
    final reacceptance = j['requires_reacceptance'];
    return Me(
      id: parseString(j['id']),
      phone: parseString(j['phone']),
      email: j['email'] as String?,
      firstName: parseString(j['first_name']),
      lastName: parseString(j['last_name']),
      fullName: parseString(j['full_name']),
      role: UserRole.parse(j['role'] as String?),
      preferredLanguage: parseString(j['preferred_language']),
      isPhoneVerified: j['is_phone_verified'] == true,
      requiresReacceptance: reacceptance is List
          ? reacceptance.map((e) => e.toString()).toList()
          : const [],
      patientProfile: patient is Map
          ? PatientProfileSummary.fromJson(Map<String, dynamic>.from(patient))
          : null,
      doctorProfile: doctor is Map && doctor.isNotEmpty
          ? DoctorProfileBrief.fromJson(Map<String, dynamic>.from(doctor))
          : null,
      doctorApplication: application is Map && application.isNotEmpty
          ? DoctorApplication.fromJson(Map<String, dynamic>.from(application))
          : null,
      dateJoined: parseUtc(j['date_joined']),
    );
  }
}

/// The token pair `/auth/login/` and a signup OTP verification return.
class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});

  final String access;
  final String refresh;

  factory AuthTokens.fromJson(Map<String, dynamic> j) =>
      AuthTokens(access: parseString(j['access']), refresh: parseString(j['refresh']));

  bool get isUsable => access.isNotEmpty && refresh.isNotEmpty;
}

/// A legal policy version the user must accept at registration.
class LegalPolicy {
  const LegalPolicy({
    required this.id,
    required this.policyType,
    required this.version,
    required this.titleAr,
    this.bodyAr,
  });

  final String id;
  final String policyType;
  final String version;
  final String titleAr;
  final String? bodyAr;

  factory LegalPolicy.fromJson(Map<String, dynamic> j) => LegalPolicy(
    id: parseString(j['id']),
    policyType: parseString(j['policy_type']),
    version: parseString(j['version']),
    titleAr: parseString(j['title_ar']),
    bodyAr: j['body_ar'] as String?,
  );
}

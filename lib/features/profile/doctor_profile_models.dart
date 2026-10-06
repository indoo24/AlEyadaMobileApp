import '../../core/api/envelope.dart';
import '../doctors/models.dart';

/// The doctor's own profile, exactly as `GET /doctor/profile/` returns it.
///
/// It keeps the response as received and answers questions about it, rather than
/// copying fifty fields into a class that would then have to be kept in step with
/// the backend. A field the server does not send simply reads as empty, and the
/// screen shows nothing for it.
class DoctorOwnProfile {
  const DoctorOwnProfile(this.json);

  final Map<String, dynamic> json;

  /// A trimmed string field; `''` when absent, null or not a string.
  String text(String key) {
    final v = json[key];
    return v is String ? v.trim() : '';
  }

  String get id => text('id');
  String? get photo => text('photo').isEmpty ? null : text('photo');

  /// `years_of_experience`, or null when the doctor has not given one.
  int? get yearsOfExperience => parseInt(json['years_of_experience']);

  /// The default fee as a decimal string, or null.
  String? get defaultFee => parseMoney(json['default_consultation_fee']);

  String get gender => text('gender');
  String get verificationStatus => text('verification_status');
  bool get isPublished => json['is_published'] == true;

  /// The average rating as sent, and how many reviews stand behind it.
  String get avgRating => text('avg_rating');
  int get reviewsCount => parseInt(json['reviews_count']) ?? 0;

  String? get cityId => text('city').isEmpty ? null : text('city');
  String? get areaId => text('area').isEmpty ? null : text('area');

  /// Fields the server will let this doctor change right now.
  Set<String> get editableFields => _strings(json['editable_fields']);

  /// Fields whose change is *staged for review* instead of applied (empty while
  /// the profile is still a draft).
  Set<String> get credentialFields => _strings(json['credential_fields']);

  bool canEdit(String key) => editableFields.contains(key);

  /// Social links, whichever shape they arrive in: `{facebook: url, …}`. Empty
  /// values are dropped.
  Map<String, String> get socialLinks {
    final raw = json['social_links'];
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.value is String && (e.value as String).trim().isNotEmpty)
          e.key.toString(): (e.value as String).trim(),
    };
  }

  /// The specialties, primary first as the backend ordered them.
  List<Specialization> get specializations {
    final raw = json['specializations'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Specialization.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.nameAr.isNotEmpty || s.nameEn.isNotEmpty)
        .toList();
  }

  /// Current value of a profile field as the text a form would show.
  String valueOf(String key) {
    if (socialNetworks.contains(key)) return socialLinks[key] ?? '';
    return switch (key) {
      'years_of_experience' => yearsOfExperience?.toString() ?? '',
      'default_consultation_fee' => defaultFee ?? '',
      _ => text(key),
    };
  }

  static Set<String> _strings(Object? v) =>
      v is List ? {for (final e in v) if (e is String) e} : const {};
}

/// The five networks the profile carries, written back as separate keys.
const socialNetworks = ['facebook', 'instagram', 'linkedin', 'youtube', 'tiktok'];

enum ProfileFieldKind { text, multiline, integer, money, url, phone }

/// Where a field sits on the screen.
enum ProfileSection { basic, professional, biography, experience, qualifications, contact, links, search }

/// One field the profile PATCH accepts: its key, how it is typed, and its section.
///
/// The *list* here is the client's knowledge of how to render and send a field —
/// which of them the doctor may change at any moment is the server's call, via
/// `editable_fields`. A field this build has no entry for is not offered.
class ProfileField {
  const ProfileField(this.key, this.section, this.kind, {this.maxLength});

  final String key;
  final ProfileSection section;
  final ProfileFieldKind kind;
  final int? maxLength;

  bool get isNumber => kind == ProfileFieldKind.integer || kind == ProfileFieldKind.money;
  bool get isLatin => kind == ProfileFieldKind.url || kind == ProfileFieldKind.phone || isNumber;
}

/// Every field `PATCH /doctor/profile/` accepts (limits are the spec's).
const profileFields = <ProfileField>[
  ProfileField('full_name_ar', ProfileSection.basic, ProfileFieldKind.text, maxLength: 150),
  ProfileField('full_name_en', ProfileSection.basic, ProfileFieldKind.text, maxLength: 150),
  ProfileField('display_title', ProfileSection.basic, ProfileFieldKind.text, maxLength: 20),
  ProfileField('professional_title_ar', ProfileSection.professional, ProfileFieldKind.text, maxLength: 200),
  ProfileField('professional_title_en', ProfileSection.professional, ProfileFieldKind.text, maxLength: 200),
  ProfileField('academic_degree_ar', ProfileSection.professional, ProfileFieldKind.text, maxLength: 100),
  ProfileField('years_of_experience', ProfileSection.professional, ProfileFieldKind.integer),
  ProfileField('default_consultation_fee', ProfileSection.professional, ProfileFieldKind.money),
  ProfileField('bio_ar', ProfileSection.biography, ProfileFieldKind.multiline),
  ProfileField('bio_en', ProfileSection.biography, ProfileFieldKind.multiline),
  ProfileField('vision_ar', ProfileSection.biography, ProfileFieldKind.multiline),
  ProfileField('current_positions_ar', ProfileSection.experience, ProfileFieldKind.multiline),
  ProfileField('past_positions_ar', ProfileSection.experience, ProfileFieldKind.multiline),
  ProfileField('certifications_ar', ProfileSection.qualifications, ProfileFieldKind.multiline),
  ProfileField('fellowships_ar', ProfileSection.qualifications, ProfileFieldKind.multiline),
  ProfileField('phone', ProfileSection.contact, ProfileFieldKind.phone, maxLength: 20),
  ProfileField('whatsapp', ProfileSection.contact, ProfileFieldKind.phone, maxLength: 20),
  ProfileField('website', ProfileSection.links, ProfileFieldKind.url),
  ProfileField('external_booking_url', ProfileSection.links, ProfileFieldKind.url),
  ProfileField('google_maps_url', ProfileSection.links, ProfileFieldKind.url),
  ProfileField('facebook', ProfileSection.links, ProfileFieldKind.url),
  ProfileField('instagram', ProfileSection.links, ProfileFieldKind.url),
  ProfileField('linkedin', ProfileSection.links, ProfileFieldKind.url),
  ProfileField('youtube', ProfileSection.links, ProfileFieldKind.url),
  ProfileField('tiktok', ProfileSection.links, ProfileFieldKind.url),
  ProfileField('seo_title', ProfileSection.search, ProfileFieldKind.text, maxLength: 70),
  ProfileField('seo_description', ProfileSection.search, ProfileFieldKind.multiline, maxLength: 160),
];

/// Whether [key] is one the doctor may edit now: the server lists it as editable
/// (a social network counts when `social_links` is listed), and this build knows
/// how to send it.
bool isEditable(DoctorOwnProfile p, ProfileField f) {
  if (p.canEdit(f.key)) return true;
  return socialNetworks.contains(f.key) && p.canEdit('social_links');
}

/// Whether editing [f] is staged for review rather than applied.
bool isCredential(DoctorOwnProfile p, ProfileField f) =>
    p.credentialFields.contains(f.key) ||
    (socialNetworks.contains(f.key) && p.credentialFields.contains('social_links'));

/// A problem with what was typed, found before anything is sent.
enum ProfileInputError { notANumber }

/// Checks the typed numbers. Everything else (URL form, length beyond the field's
/// limit, uniqueness) is the server's to judge, and its message is shown.
Map<String, ProfileInputError> validateProfileDrafts(Map<String, String> drafts) {
  final errors = <String, ProfileInputError>{};
  for (final f in profileFields) {
    final t = drafts[f.key]?.trim();
    if (t == null || t.isEmpty) continue;
    if (f.kind == ProfileFieldKind.integer && int.tryParse(t) == null) {
      errors[f.key] = ProfileInputError.notANumber;
    }
    if (f.kind == ProfileFieldKind.money) {
      final n = double.tryParse(t);
      if (n == null || n < 0) errors[f.key] = ProfileInputError.notANumber;
    }
  }
  return errors;
}

/// The `PATCH` body: only the fields whose text differs from what the server
/// holds, typed as the API expects (`null` clears a number, `''` clears text).
///
/// Sending only what changed means an untouched field — including one this
/// doctor is not allowed to edit — is never part of the request.
Map<String, dynamic> buildProfilePatch(DoctorOwnProfile original, Map<String, String> drafts) {
  final body = <String, dynamic>{};
  for (final f in profileFields) {
    final draft = drafts[f.key];
    if (draft == null) continue;
    final now = draft.trim();
    if (now == original.valueOf(f.key)) continue;
    body[f.key] = switch (f.kind) {
      ProfileFieldKind.integer => now.isEmpty ? null : int.parse(now),
      ProfileFieldKind.money => now.isEmpty ? null : now,
      _ => now,
    };
  }
  return body;
}

// ---------------------------------------------------------------------------
// The doctor's own lists
// ---------------------------------------------------------------------------

class EducationItem {
  const EducationItem({required this.degreeAr, required this.degreeEn, required this.institutionAr, required this.institutionEn, this.year});

  final String degreeAr;
  final String degreeEn;
  final String institutionAr;
  final String institutionEn;
  final int? year;

  factory EducationItem.fromJson(Map<String, dynamic> j) => EducationItem(
    degreeAr: parseString(j['degree_ar']).trim(),
    degreeEn: parseString(j['degree_en']).trim(),
    institutionAr: parseString(j['institution_ar']).trim(),
    institutionEn: parseString(j['institution_en']).trim(),
    year: parseInt(j['year']),
  );
}

class CertificateItem {
  const CertificateItem({required this.titleAr, required this.titleEn, required this.issuer, required this.isPublic, this.year});

  final String titleAr;
  final String titleEn;
  final String issuer;
  final bool isPublic;
  final int? year;

  factory CertificateItem.fromJson(Map<String, dynamic> j) => CertificateItem(
    titleAr: parseString(j['title_ar']).trim(),
    titleEn: parseString(j['title_en']).trim(),
    issuer: parseString(j['issuer']).trim(),
    isPublic: j['is_public'] == true,
    year: parseInt(j['year']),
  );
}

class ServiceItem {
  const ServiceItem({required this.nameAr, required this.nameEn, required this.isActive, this.price});

  final String nameAr;
  final String nameEn;
  final bool isActive;
  final String? price;

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
    nameAr: parseString(j['name_ar']).trim(),
    nameEn: parseString(j['name_en']).trim(),
    isActive: j['is_active'] != false,
    price: parseMoney(j['price']),
  );
}

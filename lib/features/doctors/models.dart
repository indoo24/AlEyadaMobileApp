import '../../core/api/envelope.dart';
import '../../core/utils/contact_links.dart';

/// A city or area as the directory returns it inside another object: just an id
/// and an Arabic name.
class NamedRef {
  const NamedRef({required this.id, required this.nameAr});

  final String id;
  final String nameAr;

  factory NamedRef.fromJson(Map<String, dynamic> j) =>
      NamedRef(id: parseString(j['id']), nameAr: parseString(j['name_ar']));

  static NamedRef? maybe(dynamic v) =>
      v is Map ? NamedRef.fromJson(Map<String, dynamic>.from(v)) : null;
}

/// A city from `/locations/cities/`, with areas when `with_areas=1` was asked.
class City {
  const City({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    required this.areas,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String nameEn;
  final List<Area> areas;

  factory City.fromJson(Map<String, dynamic> j) {
    final raw = j['areas'];
    return City(
      id: parseString(j['id']),
      slug: parseString(j['slug']),
      nameAr: parseString(j['name_ar']),
      nameEn: parseString(j['name_en']),
      areas: raw is List
          ? raw.whereType<Map>().map((e) => Area.fromJson(Map<String, dynamic>.from(e))).toList()
          : const [],
    );
  }
}

class Area {
  const Area({required this.id, required this.slug, required this.nameAr, required this.nameEn});

  final String id;
  final String slug;
  final String nameAr;
  final String nameEn;

  factory Area.fromJson(Map<String, dynamic> j) => Area(
    id: parseString(j['id']),
    slug: parseString(j['slug']),
    nameAr: parseString(j['name_ar']),
    nameEn: parseString(j['name_en']),
  );
}

/// A specialty. The endpoint returns a tree; [children] is populated for parents.
class Specialization {
  const Specialization({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    required this.doctorsCount,
    required this.children,
    this.icon,
    this.isPrimary,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String nameEn;
  final int doctorsCount;
  final List<Specialization> children;
  final String? icon;

  /// Only meaningful inside a doctor's `specializations` list.
  final bool? isPrimary;

  factory Specialization.fromJson(Map<String, dynamic> j) {
    final kids = j['children'];
    return Specialization(
      id: parseString(j['id']),
      slug: parseString(j['slug']),
      nameAr: parseString(j['name_ar']),
      nameEn: parseString(j['name_en']),
      doctorsCount: parseInt(j['doctors_count']) ?? 0,
      icon: j['icon'] as String?,
      isPrimary: j['is_primary'] as bool?,
      children: kids is List
          ? kids
                .whereType<Map>()
                .map((e) => Specialization.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }

  /// This specialty and all its descendants, flattened — what a filter list
  /// needs when the API returns a tree.
  Iterable<Specialization> get flattened => [this, ...children.expand((c) => c.flattened)];
}

/// Contact details, with the launch URLs already built.
///
/// The app uses [telUrl] and [whatsappUrl] as given rather than assembling them
/// from the raw numbers. The backend composes the WhatsApp message text (in
/// Arabic, naming the doctor) and knows the country-code rules; rebuilding that
/// here would be a second implementation of the same thing, free to disagree.
class ContactInfo {
  const ContactInfo({this.phone, this.whatsapp, this.telUrl, this.whatsappUrl});

  final String? phone;
  final String? whatsapp;
  final String? telUrl;
  final String? whatsappUrl;

  /// Whether there is a link the app will actually open — a missing or unsafe
  /// one (see `contact_links.dart`) hides the button rather than leaving one
  /// that does nothing.
  bool get canCall => safePhoneUri(telUrl) != null;
  bool get canWhatsapp => safeWhatsappUri(whatsappUrl) != null;

  factory ContactInfo.fromJson(Map<String, dynamic> j) => ContactInfo(
    phone: j['phone'] as String?,
    whatsapp: j['whatsapp'] as String?,
    telUrl: j['tel_url'] as String?,
    whatsappUrl: j['whatsapp_url'] as String?,
  );

  static const empty = ContactInfo();

  static ContactInfo from(dynamic v) =>
      v is Map ? ContactInfo.fromJson(Map<String, dynamic>.from(v)) : empty;
}

/// A doctor as the list endpoint returns them.
class DoctorCard {
  const DoctorCard({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.fullNameAr,
    required this.displayTitle,
    required this.professionalTitleAr,
    required this.avgRating,
    required this.reviewsCount,
    required this.isFeatured,
    required this.bookingEnabled,
    required this.contact,
    this.fullNameEn,
    this.gender,
    this.photo,
    this.yearsOfExperience,
    this.primarySpecialization,
    this.city,
    this.area,
    this.minFee,
  });

  final String id;
  final String slug;

  /// Already includes the honorific where the backend has one.
  final String displayName;
  final String fullNameAr;
  final String? fullNameEn;
  final String displayTitle;
  final String professionalTitleAr;
  final String? gender;
  final String? photo;
  final int? yearsOfExperience;
  final Specialization? primarySpecialization;
  final NamedRef? city;
  final NamedRef? area;

  /// Decimal string, not a double — money is never floated through this app.
  final String? minFee;
  final String avgRating;
  final int reviewsCount;
  final bool isFeatured;

  /// Whether this doctor takes online bookings at all. False means
  /// contact-only: the clinic wants the phone to ring.
  final bool bookingEnabled;
  final ContactInfo contact;

  double get rating => parseDouble(avgRating) ?? 0;

  /// The average rating exactly as the backend sent it, or null when it sent
  /// nothing usable.
  ///
  /// Unlike [rating], this never turns "missing" into 0.0 — a doctor with no
  /// rating must not look like a doctor with a terrible one.
  double? get ratingValue => parseDouble(avgRating);

  /// Whether there is a rating worth showing.
  ///
  /// The backend sends `"0.00"` with `reviews_count: 0` for an unrated doctor, so
  /// a zero average only counts when reviews back it up. A non-zero average
  /// always counts, even if the count is missing.
  bool get hasRating {
    final v = ratingValue;
    if (v == null) return false;
    return v > 0 || reviewsCount > 0;
  }

  /// City and area as one line, in reading order for the current locale.
  String get locationLabel {
    final parts = [area?.nameAr, city?.nameAr].where((p) => (p ?? '').isNotEmpty).cast<String>();
    return parts.join('، ');
  }

  factory DoctorCard.fromJson(Map<String, dynamic> j) => DoctorCard(
    id: parseString(j['id']),
    slug: parseString(j['slug']),
    displayName: parseString(j['display_name']),
    fullNameAr: parseString(j['full_name_ar']),
    fullNameEn: j['full_name_en'] as String?,
    displayTitle: parseString(j['display_title']),
    professionalTitleAr: parseString(j['professional_title_ar']),
    gender: j['gender'] as String?,
    photo: j['photo'] as String?,
    yearsOfExperience: parseInt(j['years_of_experience']),
    primarySpecialization: j['primary_specialization'] is Map
        ? Specialization.fromJson(Map<String, dynamic>.from(j['primary_specialization'] as Map))
        : null,
    city: NamedRef.maybe(j['city']),
    area: NamedRef.maybe(j['area']),
    minFee: parseMoney(j['min_fee']),
    avgRating: parseString(j['avg_rating']),
    reviewsCount: parseInt(j['reviews_count']) ?? 0,
    isFeatured: j['is_featured'] == true,
    bookingEnabled: j['booking_enabled'] == true,
    contact: ContactInfo.from(j['contact']),
  );
}

/// A clinic, as nested in a doctor's detail or returned by the clinic endpoints.
class ClinicSummary {
  const ClinicSummary({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.addressAr,
    required this.contact,
    required this.workingHours,
    this.nameEn,
    this.city,
    this.area,
    this.landmark,
    this.googleMapsUrl,
    this.latitude,
    this.longitude,
    this.primaryImage,
    this.timezone,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String? nameEn;
  final String addressAr;
  final NamedRef? city;
  final NamedRef? area;
  final String? landmark;
  final String? googleMapsUrl;
  final double? latitude;
  final double? longitude;
  final String? primaryImage;
  final String? timezone;
  final ContactInfo contact;
  final List<ClinicWorkingHour> workingHours;

  /// The clinic's own map link, when it has a safe one.
  Uri? get mapsUri => webUri(googleMapsUrl);

  String get addressLine {
    final parts = [
      addressAr,
      area?.nameAr,
      city?.nameAr,
    ].where((p) => (p ?? '').isNotEmpty).cast<String>();
    return parts.join('، ');
  }

  factory ClinicSummary.fromJson(Map<String, dynamic> j) {
    final hours = j['working_hours'];
    return ClinicSummary(
      id: parseString(j['id']),
      slug: parseString(j['slug']),
      nameAr: parseString(j['name_ar']),
      nameEn: j['name_en'] as String?,
      addressAr: parseString(j['address_ar']),
      city: NamedRef.maybe(j['city']),
      area: NamedRef.maybe(j['area']),
      landmark: j['landmark'] as String?,
      googleMapsUrl: j['google_maps_url'] as String?,
      latitude: parseDouble(j['latitude']),
      longitude: parseDouble(j['longitude']),
      primaryImage: j['primary_image'] as String?,
      timezone: j['timezone'] as String?,
      contact: ContactInfo.from(j['contact']),
      workingHours: hours is List
          ? hours
                .whereType<Map>()
                .map((e) => ClinicWorkingHour.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }
}

class ClinicWorkingHour {
  const ClinicWorkingHour({
    required this.weekday,
    required this.openTime,
    required this.closeTime,
    this.weekdayLabel = '',
  });

  /// ISO weekday: Monday = 1 … Sunday = 7, matching the backend.
  final int weekday;
  final String openTime;
  final String closeTime;

  /// The day's name as the backend labels it (`"السبت"`); empty when not sent.
  final String weekdayLabel;

  factory ClinicWorkingHour.fromJson(Map<String, dynamic> j) => ClinicWorkingHour(
    weekday: parseInt(j['weekday']) ?? 1,
    openTime: parseString(j['open_time']),
    closeTime: parseString(j['close_time']),
    weekdayLabel: parseString(j['weekday_label']).trim(),
  );
}

/// A doctor's terms at one clinic.
class DoctorClinicLink {
  const DoctorClinicLink({
    required this.id,
    required this.clinic,
    required this.bookingEnabled,
    required this.isPrimary,
    required this.paymentRequired,
    this.consultationFee,
    this.followupFee,
  });

  final String id;
  final ClinicSummary clinic;
  final bool bookingEnabled;
  final bool isPrimary;
  final bool paymentRequired;
  final String? consultationFee;
  final String? followupFee;

  factory DoctorClinicLink.fromJson(Map<String, dynamic> j) => DoctorClinicLink(
    id: parseString(j['id']),
    clinic: ClinicSummary.fromJson(Map<String, dynamic>.from(j['clinic'] as Map)),
    bookingEnabled: j['booking_enabled'] == true,
    isPrimary: j['is_primary'] == true,
    paymentRequired: j['payment_required'] == true,
    consultationFee: parseMoney(j['consultation_fee']),
    followupFee: parseMoney(j['followup_fee']),
  );
}

/// The full public profile.
class DoctorDetail {
  const DoctorDetail({
    required this.card,
    required this.clinics,
    required this.specializations,
    required this.services,
    required this.education,
    required this.certificates,
    this.bioAr,
    this.bioEn,
    this.professionalTitleEn,
    this.academicDegreeAr = '',
    this.currentPositionsAr = '',
    this.pastPositionsAr = '',
    this.certificationsAr = '',
    this.fellowshipsAr = '',
    this.visionAr = '',
    this.website,
    this.googleMapsUrl,
    this.socialLinks = const {},
  });

  /// The fields shared with the list representation, parsed once.
  final DoctorCard card;
  final List<DoctorClinicLink> clinics;
  final List<Specialization> specializations;
  final List<DoctorService> services;
  final List<DoctorCredential> education;
  final List<DoctorCredential> certificates;
  final String? bioAr;
  final String? bioEn;
  final String? professionalTitleEn;

  // The fields below are returned by `GET /doctors/{slug}/` but not (yet) listed
  // in its OpenAPI schema. They are the same fields the doctor edits through
  // `PATCH /doctor/profile/`, so their meaning is known; each is optional and an
  // older server that omits it simply hides the matching section.

  final String academicDegreeAr;
  final String currentPositionsAr;
  final String pastPositionsAr;
  final String certificationsAr;
  final String fellowshipsAr;
  final String visionAr;

  /// The doctor's own website — `website`, and nothing else. Not the external
  /// booking link, not a maps link, not the clinic-management site.
  final Uri? website;

  /// The doctor's own map link. Not tied to any one clinic, so it is offered on
  /// its own rather than attached to a clinic it may not belong to.
  final Uri? googleMapsUrl;

  /// Network → address, only the networks with a usable web address.
  final Map<String, Uri> socialLinks;

  String get slug => card.slug;
  String get displayName => card.displayName;

  /// The clinic a booking should default to.
  DoctorClinicLink? get primaryClinic {
    if (clinics.isEmpty) return null;
    return clinics.firstWhere((c) => c.isPrimary, orElse: () => clinics.first);
  }

  /// Whether any clinic accepts online bookings. A doctor may be bookable at one
  /// clinic and contact-only at another.
  bool get anyClinicBookable => card.bookingEnabled && clinics.any((c) => c.bookingEnabled);

  factory DoctorDetail.fromJson(Map<String, dynamic> j) {
    List<T> listOf<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = j[key];
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((e) => parse(Map<String, dynamic>.from(e))).toList();
    }

    return DoctorDetail(
      card: DoctorCard.fromJson(j),
      clinics: listOf('clinics', DoctorClinicLink.fromJson),
      specializations: listOf('specializations', Specialization.fromJson),
      services: listOf('services', DoctorService.fromJson),
      education: listOf('education', DoctorCredential.fromJson),
      certificates: listOf('certificates', DoctorCredential.fromJson),
      bioAr: j['bio_ar'] as String?,
      bioEn: j['bio_en'] as String?,
      professionalTitleEn: j['professional_title_en'] as String?,
      academicDegreeAr: _text(j['academic_degree_ar']),
      currentPositionsAr: _text(j['current_positions_ar']),
      pastPositionsAr: _text(j['past_positions_ar']),
      certificationsAr: _text(j['certifications_ar']),
      fellowshipsAr: _text(j['fellowships_ar']),
      visionAr: _text(j['vision_ar']),
      website: webUri(j['website']),
      googleMapsUrl: webUri(j['google_maps_url']),
      socialLinks: _socialLinks(j['social_links']),
    );
  }

  /// The networks the app knows how to label, in display order.
  static const socialNetworks = ['facebook', 'instagram', 'linkedin', 'youtube', 'tiktok'];

  static Map<String, Uri> _socialLinks(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final k in socialNetworks)
        if (webUri(raw[k]) case final uri?) k: uri,
    };
  }
}

/// Trimmed text, with Windows line breaks normalised; empty for null or a
/// non-string.
String _text(dynamic v) => v is String ? v.replaceAll('\r\n', '\n').trim() : '';

/// A link that can be opened safely: an absolute http(s) address with a host.
///
/// Anything else — blank, a bare word, `javascript:`, a relative path — is
/// treated as absent. The value is never repaired or guessed at.
Uri? webUri(dynamic raw) {
  if (raw is! String) return null;
  final u = Uri.tryParse(raw.trim());
  if (u == null || u.host.isEmpty) return null;
  return (u.scheme == 'https' || u.scheme == 'http') ? u : null;
}

class DoctorService {
  const DoctorService({required this.id, required this.nameAr, this.price});

  final String id;
  final String nameAr;
  final String? price;

  factory DoctorService.fromJson(Map<String, dynamic> j) => DoctorService(
    id: parseString(j['id']),
    nameAr: parseString(j['name_ar']),
    price: parseMoney(j['price']),
  );
}

/// A qualification line — education or a certificate. Only the public parts:
/// the private document behind a certificate is never addressed from here.
class DoctorCredential {
  const DoctorCredential({required this.id, required this.titleAr, this.subtitle, this.year});

  final String id;
  final String titleAr;
  final String? subtitle;
  final String? year;

  factory DoctorCredential.fromJson(Map<String, dynamic> j) => DoctorCredential(
    id: parseString(j['id']),
    titleAr: parseString(j['title_ar'] ?? j['degree_ar'] ?? j['name_ar']),
    subtitle: _optionalText(j['institution_ar'] ?? j['issuer_ar'] ?? j['issuer']),
    year: j['year']?.toString(),
  );

  static String? _optionalText(dynamic v) {
    final t = _text(v);
    return t.isEmpty ? null : t;
  }
}

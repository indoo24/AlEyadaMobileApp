import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/envelope.dart';
import '../bookings/models.dart';
import 'models.dart';

/// Filters the directory list accepts.
///
/// These map onto the backend's own query parameters. Filtering is done
/// server-side throughout: the app never fetches a page and then hides rows from
/// it, because a page is 20 of a possibly large set and locally filtering it
/// would silently drop matches that were on page two.
class DoctorQuery {
  const DoctorQuery({
    this.search,
    this.specialization,
    this.city,
    this.area,
    this.gender,
    this.minRating,
    this.maxFee,
    this.bookingEnabled,
    this.ordering,
    this.page = 1,
  });

  final String? search;

  /// Specialty **slug**. Matching a parent also surfaces its sub-specialties,
  /// which is the backend's behaviour, not something replicated here.
  final String? specialization;

  /// City and area slugs.
  final String? city;
  final String? area;
  final String? gender;
  final double? minRating;
  final String? maxFee;
  final bool? bookingEnabled;
  final String? ordering;
  final int page;

  DoctorQuery copyWith({
    Object? search = _unset,
    Object? specialization = _unset,
    Object? city = _unset,
    Object? area = _unset,
    Object? gender = _unset,
    Object? minRating = _unset,
    Object? maxFee = _unset,
    Object? bookingEnabled = _unset,
    Object? ordering = _unset,
    int? page,
  }) => DoctorQuery(
    search: search == _unset ? this.search : search as String?,
    specialization: specialization == _unset ? this.specialization : specialization as String?,
    city: city == _unset ? this.city : city as String?,
    area: area == _unset ? this.area : area as String?,
    gender: gender == _unset ? this.gender : gender as String?,
    minRating: minRating == _unset ? this.minRating : minRating as double?,
    maxFee: maxFee == _unset ? this.maxFee : maxFee as String?,
    bookingEnabled: bookingEnabled == _unset ? this.bookingEnabled : bookingEnabled as bool?,
    ordering: ordering == _unset ? this.ordering : ordering as String?,
    page: page ?? this.page,
  );

  static const _unset = Object();

  Map<String, dynamic> toQuery() => {
    if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
    if (specialization != null) 'specialization': specialization,
    if (city != null) 'city': city,
    if (area != null) 'area': area,
    if (gender != null) 'gender': gender,
    if (minRating != null) 'min_rating': minRating,
    if (maxFee != null) 'max_fee': maxFee,
    if (bookingEnabled != null) 'booking_enabled': bookingEnabled,
    if (ordering != null) 'ordering': ordering,
    'page': page,
  };

  /// Whether any filter beyond the page number is set — drives the "clear
  /// filters" affordance.
  bool get hasFilters =>
      (search ?? '').isNotEmpty ||
      specialization != null ||
      city != null ||
      area != null ||
      gender != null ||
      minRating != null ||
      maxFee != null;

  /// Value equality so Riverpod can cache a page per distinct query.
  @override
  bool operator ==(Object other) =>
      other is DoctorQuery &&
      other.search == search &&
      other.specialization == specialization &&
      other.city == city &&
      other.area == area &&
      other.gender == gender &&
      other.minRating == minRating &&
      other.maxFee == maxFee &&
      other.bookingEnabled == bookingEnabled &&
      other.ordering == ordering &&
      other.page == page;

  @override
  int get hashCode => Object.hash(
    search,
    specialization,
    city,
    area,
    gender,
    minRating,
    maxFee,
    bookingEnabled,
    ordering,
    page,
  );
}

class DirectoryRepository {
  DirectoryRepository(this._api);

  final ApiClient _api;

  Future<Paginated<DoctorCard>> doctors(DoctorQuery query, {CancelToken? cancelToken}) async {
    final body = await _api.get(
      Endpoints.doctors,
      query: query.toQuery(),
      cancelToken: cancelToken,
      // Public endpoint: a guest must be able to browse before signing in.
      skipAuth: false,
    );
    return unwrapPaginated(body, DoctorCard.fromJson);
  }

  Future<DoctorDetail> doctor(String slug, {CancelToken? cancelToken}) async =>
      DoctorDetail.fromJson(
        unwrapObject(await _api.get(Endpoints.doctor(slug), cancelToken: cancelToken)),
      );

  /// A doctor's bookable times. `clinic_id` selects which clinic when a doctor
  /// works at several; omitted, the backend picks their primary.
  Future<DoctorAvailability> availability(
    String slug, {
    String? clinicId,
    CancelToken? cancelToken,
  }) async {
    final body = await _api.get(
      Endpoints.doctorAvailability(slug),
      query: {if (clinicId != null) 'clinic_id': clinicId},
      cancelToken: cancelToken,
    );
    final obj = unwrapObjectOrNull(body);
    return obj == null ? DoctorAvailability.empty : DoctorAvailability.fromJson(obj);
  }

  Future<Paginated<PublicReview>> doctorReviews(String slug, {int page = 1}) async {
    final body = await _api.get(Endpoints.doctorReviews(slug), query: {'page': page});
    return unwrapPaginated(body, PublicReview.fromJson);
  }

  /// The specialty tree. Cached by the provider — it changes rarely.
  Future<List<Specialization>> specializations() async =>
      unwrapList(await _api.get(Endpoints.specializations)).map(Specialization.fromJson).toList();

  /// Cities for **search filters** — the unrestricted list.
  ///
  /// Deliberately separate from [onboardingCities]: a doctor may only *register*
  /// in the launch governorate, but the directory must keep serving every city it
  /// already holds entries for. Collapsing these two calls would hide live
  /// clinics from patients.
  Future<List<City>> cities({bool withAreas = true}) async => unwrapList(
    await _api.get(Endpoints.cities, query: {if (withAreas) 'with_areas': 1}),
  ).map(City.fromJson).toList();

  /// Cities where doctor registration is currently open.
  ///
  /// The app asks the server which those are rather than shipping a list, so
  /// opening a new governorate is a server-side configuration change and not an
  /// app release.
  Future<List<City>> onboardingCities() async => unwrapList(
    await _api.get(Endpoints.cities, query: {'with_areas': 1, 'onboarding': 1}),
  ).map(City.fromJson).toList();

  /// Record that a patient pressed call or WhatsApp.
  ///
  /// Deliberately fire-and-forget: the contact action must happen whether or not
  /// this succeeds. Losing one analytics event is nothing; failing to connect a
  /// patient to a clinic is not.
  Future<void> trackContactClick({
    required String doctorId,
    required String contactType,
    String? clinicId,
  }) async {
    try {
      await _api.post(
        Endpoints.contactClick,
        body: {
          'doctor': doctorId,
          'contact_type': contactType,
          if (clinicId != null) 'clinic': clinicId,
        },
      );
    } catch (_) {
      // Intentionally swallowed.
    }
  }
}

/// A public review on a doctor's page.
class PublicReview {
  const PublicReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    this.createdAt,
  });

  final String id;
  final int rating;
  final String comment;

  /// The backend anonymises this; whatever it sends is what may be shown.
  final String reviewerName;
  final DateTime? createdAt;

  factory PublicReview.fromJson(Map<String, dynamic> j) {
    final reviewer = j['reviewer'];
    return PublicReview(
      id: parseString(j['id']),
      rating: parseInt(j['rating']) ?? 0,
      comment: parseString(j['comment']),
      reviewerName: reviewer is Map
          ? parseString(Map<String, dynamic>.from(reviewer)['display_name'])
          : parseString(j['reviewer_name']),
      createdAt: parseUtc(j['created_at']),
    );
  }
}

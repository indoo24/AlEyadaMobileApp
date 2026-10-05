import '../../core/api/envelope.dart';
import '../doctors/models.dart';

/// A clinic as `/clinics/` lists it: enough for a card, not the working hours or
/// contacts (those are on the detail endpoint).
class ClinicListItem {
  const ClinicListItem({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.addressAr,
    required this.avgRating,
    required this.reviewsCount,
    this.nameEn,
    this.city,
    this.area,
    this.primaryImage,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String? nameEn;
  final String addressAr;
  final NamedRef? city;
  final NamedRef? area;
  final String avgRating;
  final int reviewsCount;
  final String? primaryImage;

  double get rating => parseDouble(avgRating) ?? 0;

  /// Area and city as one line.
  String get locationLabel {
    final parts = [area?.nameAr, city?.nameAr].where((p) => (p ?? '').isNotEmpty).cast<String>();
    return parts.join('، ');
  }

  factory ClinicListItem.fromJson(Map<String, dynamic> j) => ClinicListItem(
    id: parseString(j['id']),
    slug: parseString(j['slug']),
    nameAr: parseString(j['name_ar']),
    nameEn: j['name_en'] as String?,
    addressAr: parseString(j['address_ar']),
    city: NamedRef.maybe(j['city']),
    area: NamedRef.maybe(j['area']),
    avgRating: parseString(j['avg_rating']),
    reviewsCount: parseInt(j['reviews_count']) ?? 0,
    primaryImage: j['primary_image'] as String?,
  );
}

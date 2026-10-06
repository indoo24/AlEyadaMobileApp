import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/envelope.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

/// What a doctor still owes before their page can be published.
///
/// The backend computes this; the app lists it. Which fields are required is a
/// server rule (`REQUIRED_ACTIVATION_FIELDS` plus a specialization and a live
/// clinic) and duplicating the list here would let the two disagree.
class ActivationReport {
  const ActivationReport({
    required this.isComplete,
    required this.missing,
    required this.isPublished,
    required this.verificationStatus,
  });

  final bool isComplete;
  final List<String> missing;
  final bool isPublished;
  final String verificationStatus;

  factory ActivationReport.fromJson(Map<String, dynamic> j) {
    final missing = j['missing'];
    return ActivationReport(
      isComplete: j['is_complete'] == true,
      isPublished: j['is_published'] == true,
      verificationStatus: parseString(j['verification_status']),
      missing: missing is List ? missing.map((e) => e.toString()).toList() : const [],
    );
  }
}

/// `GET /doctor/stats/` — the nightly rollup for the last [periodDays] days.
///
/// Every field is the backend's own; nothing is derived here. The endpoint takes
/// no period parameter, so the window is whatever the server reports.
class DoctorStats {
  const DoctorStats({
    required this.uniquePatients,
    required this.completedVisits,
    required this.avgRating,
    required this.reviewsCount,
    required this.profileViews,
    required this.contacts,
    required this.contactRate,
    required this.bookingsCreated,
    required this.bookingsCompleted,
    required this.periodDays,
  });

  final int uniquePatients;
  final int completedVisits;
  final String avgRating;
  final int reviewsCount;
  final int profileViews;

  /// Phone, WhatsApp and map taps on the doctor's profile, combined.
  final int contacts;

  /// Of the people who looked at the profile, how many got in touch. As sent.
  final double contactRate;
  final int bookingsCreated;
  final int bookingsCompleted;
  final int periodDays;

  factory DoctorStats.fromJson(Map<String, dynamic> j) => DoctorStats(
    uniquePatients: parseInt(j['unique_patients']) ?? 0,
    completedVisits: parseInt(j['total_completed_visits']) ?? 0,
    avgRating: parseString(j['avg_rating']),
    reviewsCount: parseInt(j['reviews_count']) ?? 0,
    profileViews: parseInt(j['profile_views']) ?? 0,
    contacts: parseInt(j['contacts']) ?? 0,
    contactRate: parseDouble(j['contact_rate']) ?? 0,
    bookingsCreated: parseInt(j['bookings_created']) ?? 0,
    bookingsCompleted: parseInt(j['bookings_completed']) ?? 0,
    periodDays: parseInt(j['period_days']) ?? 0,
  );
}

class PracticeRepository {
  PracticeRepository(this._api);

  final ApiClient _api;

  Future<ActivationReport> activation() async =>
      ActivationReport.fromJson(unwrapObject(await _api.get(Endpoints.doctorActivation)));

  Future<DoctorStats> stats() async =>
      DoctorStats.fromJson(unwrapObject(await _api.get(Endpoints.doctorStats)));
}

final practiceRepositoryProvider = Provider(
  (ref) => PracticeRepository(ref.watch(apiClientProvider)),
);

// Keyed to the signed-in account (not to every change of auth state, which would
// refetch whenever the profile is merely refreshed) and auto-disposed, so numbers
// are re-read each time the dashboard is opened rather than shown from an
// earlier visit — or from a different doctor.
final activationProvider = FutureProvider.autoDispose<ActivationReport>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(practiceRepositoryProvider).activation();
});

final doctorStatsProvider = FutureProvider.autoDispose<DoctorStats>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(practiceRepositoryProvider).stats();
});

/// The activation report returns backend field names. Translate the ones we know
/// and fall back to the raw name rather than hiding an unknown requirement — a
/// doctor needs to know *something* is missing even if this build has no label
/// for it.
String activationFieldLabel(BuildContext context, String field) {
  final l = L.of(context);
  return switch (field) {
    'photo' => l.uploadChoosePhoto,
    'bio_ar' => l.doctorAbout,
    'years_of_experience' => l.doctorYearsExperience(0).replaceAll('0 ', ''),
    'professional_title_ar' => l.joinSpecialty,
    'specialization' => l.joinSpecialty,
    'clinic' => l.doctorClinics,
    'full_name_ar' => l.joinNameAr,
    _ => field,
  };
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/envelope.dart';
import '../../core/providers.dart';
import 'doctor_profile_models.dart';

/// Reads and updates the signed-in doctor's own profile.
///
/// A thin wrapper over `/doctor/*`: which fields may change, and which of those
/// are held for review, is decided by the server and reported in the profile
/// itself — nothing about that is decided here.
class DoctorProfileRepository {
  DoctorProfileRepository(this._api);

  final ApiClient _api;

  Future<DoctorOwnProfile> profile() async =>
      DoctorOwnProfile(unwrapObject(await _api.get(Endpoints.doctorProfile)));

  /// Sends only the changed fields. The response body is not read: the spec says
  /// it "reports which fields did which" without declaring its shape, so the
  /// caller re-reads the profile instead.
  Future<void> update(Map<String, dynamic> changes) =>
      _api.patch(Endpoints.doctorProfile, body: changes);

  Future<List<EducationItem>> education() async =>
      unwrapList(await _api.get(Endpoints.doctorEducation, query: {'page_size': 50}))
          .map(EducationItem.fromJson)
          .toList();

  Future<List<CertificateItem>> certificates() async =>
      unwrapList(await _api.get(Endpoints.doctorCertificates, query: {'page_size': 50}))
          .map(CertificateItem.fromJson)
          .toList();

  Future<List<ServiceItem>> services() async =>
      unwrapList(await _api.get(Endpoints.doctorServices, query: {'page_size': 50}))
          .map(ServiceItem.fromJson)
          .toList();

  /// The reason the last review was rejected, if the backend recorded one.
  Future<String?> rejectionReason() async {
    final data = unwrapObjectOrNull(await _api.get(Endpoints.doctorVerificationStatus));
    final reason = data == null ? '' : parseString(data['rejection_reason']).trim();
    return reason.isEmpty ? null : reason;
  }
}

final doctorProfileRepositoryProvider = Provider<DoctorProfileRepository>(
  (ref) => DoctorProfileRepository(ref.watch(apiClientProvider)),
);

// Every provider below is tied to the signed-in account and auto-disposed: a
// different doctor never sees the previous one's profile, and reopening the screen
// reads the server again.
String? _accountOf(Ref ref) => ref.watch(authControllerProvider.select((s) => s.user?.id));

final doctorOwnProfileProvider = FutureProvider.autoDispose<DoctorOwnProfile>((ref) {
  _accountOf(ref);
  return ref.watch(doctorProfileRepositoryProvider).profile();
});

final doctorEducationProvider = FutureProvider.autoDispose<List<EducationItem>>((ref) {
  _accountOf(ref);
  return ref.watch(doctorProfileRepositoryProvider).education();
});

final doctorCertificatesProvider = FutureProvider.autoDispose<List<CertificateItem>>((ref) {
  _accountOf(ref);
  return ref.watch(doctorProfileRepositoryProvider).certificates();
});

final doctorServicesProvider = FutureProvider.autoDispose<List<ServiceItem>>((ref) {
  _accountOf(ref);
  return ref.watch(doctorProfileRepositoryProvider).services();
});

/// Only asked for when the profile has been rejected.
final doctorRejectionReasonProvider = FutureProvider.autoDispose<String?>((ref) {
  _accountOf(ref);
  return ref.watch(doctorProfileRepositoryProvider).rejectionReason();
});

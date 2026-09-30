import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/envelope.dart';
import 'models.dart';

class BookingRepository {
  BookingRepository(this._api);

  final ApiClient _api;

  /// The patient's own bookings. `scope=upcoming` is the backend's own filter.
  Future<Paginated<PatientBooking>> myBookings({
    int page = 1,
    String? scope,
    String? status,
  }) async {
    final body = await _api.get(
      Endpoints.bookings,
      query: {
        'page': page,
        if (scope != null) 'scope': scope,
        if (status != null) 'status': status,
      },
    );
    return unwrapPaginated(body, PatientBooking.fromJson);
  }

  Future<PatientBooking> booking(String id) async =>
      PatientBooking.fromJson(unwrapObject(await _api.get(Endpoints.booking(id))));

  /// Create a booking against a chosen slot.
  ///
  /// Every rule that could refuse this — the lead time, the doctor-wide clash,
  /// the per-patient limit, whether the time is genuinely within the published
  /// schedule — lives in the backend. The app sends the slot and renders the
  /// answer; it does not pre-judge any of them, because a client that thinks it
  /// knows the rules is a client that will eventually disagree with the server.
  Future<PatientBooking> create({
    required String doctorSlug,
    required String slotId,
    String? clinicId,
    VisitType? visitType,
    String? reasonForVisit,
    String? notesForDoctor,
  }) async {
    final body = <String, dynamic>{
      'slot': slotId,
      if (clinicId != null) 'clinic': clinicId,
      if (visitType != null) 'visit_type': visitType.wire,
      if (reasonForVisit != null && reasonForVisit.isNotEmpty) 'reason_for_visit': reasonForVisit,
      if (notesForDoctor != null && notesForDoctor.isNotEmpty) 'notes_for_doctor': notesForDoctor,
    };
    return PatientBooking.fromJson(
      unwrapObject(await _api.post(Endpoints.doctorBook(doctorSlug), body: body)),
    );
  }

  /// Cancel. Only offered when the booking's own `can_cancel` is true — but the
  /// backend is asked regardless and may still refuse, which the UI reports.
  Future<PatientBooking> cancel(String id, {String? reason}) async {
    final body = unwrapObjectOrNull(
      await _api.post(
        Endpoints.bookingCancel(id),
        body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      ),
    );
    // Some transitions answer with the updated booking, some with a envelope of
    // their own; re-read when the response is not the booking itself.
    if (body != null && body.containsKey('start_at')) return PatientBooking.fromJson(body);
    return booking(id);
  }

  /// Move an existing booking to a different slot.
  Future<PatientBooking> reschedule(String id, {required String slotId}) async {
    final body = unwrapObjectOrNull(
      await _api.post(Endpoints.bookingReschedule(id), body: {'slot': slotId}),
    );
    if (body != null && body.containsKey('start_at')) return PatientBooking.fromJson(body);
    return booking(id);
  }
}

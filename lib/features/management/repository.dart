import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/envelope.dart';
import 'models.dart';

/// Everything the doctor's Management area reads and writes.
///
/// A thin wrapper over the `/doctor/*` endpoints: the backend decides who may do
/// what (a 403 is a 403), so this does no permission checking of its own and
/// every rule — who can invite, what slots exist — stays on the server.
class ManagementRepository {
  ManagementRepository(this._api);

  final ApiClient _api;

  // --- clinics ------------------------------------------------------------

  Future<List<MyClinic>> clinics() async =>
      unwrapList(await _api.get(Endpoints.doctorClinics, query: {'page_size': 50}))
          .map(MyClinic.fromJson)
          .toList();

  Future<MyClinic> createClinic({
    required String nameAr,
    String? cityId,
    String? areaId,
    String? addressAr,
    String? phone,
  }) async => MyClinic.fromJson(
    unwrapObject(
      await _api.post(
        Endpoints.doctorClinicCreate,
        body: {
          'name_ar': nameAr,
          if (cityId != null) 'city': cityId,
          if (areaId != null) 'area': areaId,
          if (addressAr != null && addressAr.isNotEmpty) 'address_ar': addressAr,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      ),
    ),
  );

  /// The doctor's own terms at a clinic — fee, follow-up fee, online booking.
  Future<MyClinic> updateTerms(
    String clinicLinkId, {
    required String? consultationFee,
    required String? followupFee,
    required bool bookingEnabled,
  }) async => MyClinic.fromJson(
    unwrapObject(
      await _api.patch(
        Endpoints.doctorClinicTerms(clinicLinkId),
        body: {
          'consultation_fee': consultationFee,
          'followup_fee': followupFee,
          'booking_enabled': bookingEnabled,
        },
      ),
    ),
  );

  /// Replaces the whole week at once; split shifts are two entries.
  Future<void> setWorkingHours(String clinicLinkId, List<WorkingShift> shifts) => _api.put(
    Endpoints.doctorClinicWorkingHours(clinicLinkId),
    body: {'shifts': [for (final s in shifts) s.toJson()]},
  );

  Future<void> inviteDoctor(String clinicLinkId, {required String phone, String? message}) =>
      _api.post(
        Endpoints.doctorClinicInvitations(clinicLinkId),
        body: {'phone': phone, if (message != null && message.isNotEmpty) 'message': message},
      );

  Future<List<SentInvitation>> sentInvitations(String clinicLinkId) async {
    final data = unwrapList(await _api.get(Endpoints.doctorClinicInvitations(clinicLinkId)));
    return data.map(SentInvitation.fromJson).toList();
  }

  // --- assistants ---------------------------------------------------------

  Future<List<AssistantProfile>> assistants() async =>
      unwrapList(await _api.get(Endpoints.doctorAssistants, query: {'page_size': 50}))
          .map(AssistantProfile.fromJson)
          .toList();

  Future<AssistantProfile> createAssistant({
    required String fullName,
    required String phone,
    String? notes,
    String? clinicId,
    required Map<String, bool> flags,
  }) async => AssistantProfile.fromJson(
    unwrapObject(
      await _api.post(
        Endpoints.doctorAssistantCreate,
        body: {
          'full_name': fullName,
          'phone': phone,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (clinicId != null) 'clinic': clinicId,
          'flags': flags,
        },
      ),
    ),
  );

  Future<void> updatePermissions(String assignmentId, Map<String, bool> flags) =>
      _api.patch(Endpoints.doctorAssignment(assignmentId), body: {'flags': flags});

  Future<void> revokeAssignment(String assignmentId) =>
      _api.delete(Endpoints.doctorAssignment(assignmentId));

  // --- schedule -----------------------------------------------------------

  /// The doctor's appointments. With no filter the backend returns all of them,
  /// soonest first; `upcoming` limits it to today onward.
  Future<Paginated<StaffBooking>> bookings({
    bool upcoming = false,
    String? date,
    String? status,
    int page = 1,
  }) async => unwrapPaginated(
    await _api.get(
      Endpoints.doctorBookings,
      query: {
        'page': page,
        if (upcoming) 'upcoming': true,
        if (date != null) 'date': date,
        if (status != null) 'status': status,
      },
    ),
    StaffBooking.fromJson,
  );

  /// Move a booking on: `confirm`, `complete`, `no-show` or `cancel`.
  Future<void> transition(String bookingId, BookingAction action, {String? reason}) {
    final path = switch (action) {
      BookingAction.confirm => Endpoints.doctorBookingConfirm(bookingId),
      BookingAction.complete => Endpoints.doctorBookingComplete(bookingId),
      BookingAction.noShow => Endpoints.doctorBookingNoShow(bookingId),
      BookingAction.cancel => Endpoints.doctorBookingCancel(bookingId),
    };
    return _api.post(path, body: {if (reason != null && reason.isNotEmpty) 'reason': reason});
  }

  Future<List<AvailabilityWindow>> availabilityWindows() async =>
      unwrapList(await _api.get(Endpoints.doctorAvailabilityWindows, query: {'page_size': 100}))
          .map(AvailabilityWindow.fromJson)
          .toList();

  Future<void> addAvailabilityWindow({
    required String clinicId,
    required int weekday,
    required String start,
    required String end,
    required int durationMinutes,
  }) => _api.post(
    Endpoints.doctorAvailabilityWindows,
    body: {
      'clinic': clinicId,
      'weekday': weekday,
      'start_time': start,
      'end_time': end,
      'default_duration_minutes': durationMinutes,
      'slot_step_minutes': durationMinutes,
    },
  );

  Future<void> setWindowActive(String id, bool active) =>
      _api.patch(Endpoints.doctorAvailabilityWindow(id), body: {'is_active': active});

  Future<void> deleteWindow(String id) => _api.delete(Endpoints.doctorAvailabilityWindow(id));
}

enum BookingAction { confirm, complete, noShow, cancel }

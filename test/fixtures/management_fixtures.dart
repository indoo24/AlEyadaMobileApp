import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'api_fixtures.dart';

Map<String, dynamic> envelope(Object? data, {Map<String, dynamic>? meta}) => {
  'data': data,
  'meta': meta ?? <String, dynamic>{},
  'errors': <dynamic>[],
};

Map<String, dynamic> paged(List<Map<String, dynamic>> items, {int count = -1, int page = 1, int pages = 1}) =>
    envelope(
      items,
      meta: {
        'pagination': {
          'count': count < 0 ? items.length : count,
          'page': page,
          'pages': pages,
          'page_size': items.length,
          'next': null,
          'previous': null,
        },
      },
    );

/// A signed-in approved doctor, as `GET /auth/me/` reports them.
Map<String, dynamic> doctorUser({String id = 'doctor-user-1'}) => {
  ...meResponseData,
  'id': id,
  'role': 'doctor',
  'requires_reacceptance': <String>[],
  'patient_profile': null,
  'doctor_profile': {
    'id': '1f4a9a6c-0000-4000-8000-0000000000d1',
    'slug': 'nermeen',
    'full_name_ar': 'نرمين أحمد',
    'verification_status': 'approved',
    'is_published': true,
  },
};

Map<String, dynamic> patientUser({String id = 'patient-user-1'}) => {
  ...meResponseData,
  'id': id,
  'role': 'patient',
  'requires_reacceptance': <String>[],
};

/// `GET /doctor/stats/`.
const statsData = <String, dynamic>{
  'period_days': 7,
  'profile_views': 6,
  'phone_clicks': 1,
  'whatsapp_clicks': 1,
  'map_clicks': 1,
  'contacts': 3,
  'contact_rate': 12.5,
  'booking_attempts': 2,
  'bookings_created': 11,
  'bookings_completed': 8,
  'bookings_cancelled': 1,
  'daily': <dynamic>[],
  'date_from': '2026-09-30',
  'date_to': '2026-10-06',
  'avg_rating': '4.60',
  'reviews_count': 5,
  'unique_patients': 9,
  'total_completed_visits': 4,
  'ratings_daily': <dynamic>[],
};

const activationData = <String, dynamic>{
  'is_complete': true,
  'missing': <dynamic>[],
  'is_published': true,
  'verification_status': 'approved',
};

/// A clinic the doctor owns and that is ready for bookings.
const clinicOwned = <String, dynamic>{
  'id': 'link-1',
  'clinic_id': 'clinic-1',
  'name_ar': 'عيادة د. نرمين أحمد فؤاد',
  'slug': 'nermeen-clinic',
  'address_ar': 'طنطا، شارع النحاس',
  'phone': '01000000001',
  'clinic_is_active': true,
  'i_own_it': true,
  'consultation_fee': '160.00',
  'followup_fee': '100.00',
  'booking_enabled': true,
  'payment_required': false,
  'is_primary': true,
  'is_active': true,
  'working_hours': [
    {'id': 'wh1', 'weekday': 6, 'weekday_label': 'السبت', 'open_time': '09:00:00', 'close_time': '17:00:00', 'is_active': true},
  ],
  'setup_complete': true,
  'blocking': <dynamic>[],
};

/// A clinic the doctor works at but did not create, and that cannot take bookings yet.
const clinicShared = <String, dynamic>{
  'id': 'link-2',
  'clinic_id': 'clinic-2',
  'name_ar': 'مركز النيل الطبي',
  'slug': 'nile',
  'address_ar': 'القاهرة',
  'phone': '01000000002',
  'clinic_is_active': true,
  'i_own_it': false,
  'consultation_fee': null,
  'followup_fee': null,
  'booking_enabled': false,
  'payment_required': false,
  'is_primary': false,
  'is_active': true,
  'working_hours': <dynamic>[],
  'setup_complete': false,
  // Codes, exactly as the live API reports them.
  'blocking': ['clinic_hours_not_set', 'booking_disabled', 'some_future_code'],
};

const allFlagsOff = <String, dynamic>{
  'can_view_bookings': true,
  'can_create_bookings': false,
  'can_update_bookings': false,
  'can_cancel_bookings': false,
  'can_manage_schedule': false,
  'can_view_patient_phone': false,
  'can_create_patient_next_visit': false,
  'can_request_duration_verification': false,
  'can_review_payment_proofs': false,
};

const assistantData = <String, dynamic>{
  'id': 'as-1',
  'full_name': 'منى السيد',
  'phone': '+201012345678',
  'is_active': true,
  'notes': 'استقبال',
  'created_at': '2026-09-01T10:00:00Z',
  'assignments': [
    {
      'id': 'asg-1',
      'assistant': 'as-1',
      'doctor': 'd-1',
      'doctor_name': 'نرمين',
      'clinic': 'clinic-1',
      'clinic_name': 'عيادة د. نرمين أحمد فؤاد',
      'covers_all_clinics': false,
      'flags': allFlagsOff,
      'is_active': true,
      'created_at': '2026-09-01T10:00:00Z',
    },
  ],
};

Map<String, dynamic> booking(
  String id, {
  String status = 'pending',
  String name = 'محمد جاد',
  String time = '09:00',
  required String startAt,
  int minutes = 30,
}) => {
  'id': id,
  'patient_name': name,
  'patient_phone': '+201015959362',
  'clinic': 'clinic-1',
  'clinic_name': 'عيادة د. نرمين أحمد فؤاد',
  'start_at': startAt,
  'end_at': startAt,
  'display_time': time,
  'duration_minutes': minutes,
  'visit_type': 'first_visit',
  'reason_for_visit': '',
  'status': status,
  'fee_snapshot': '160.00',
  'payment_required': false,
  'created_at': '2026-10-01T10:00:00Z',
};

const windowData = <String, dynamic>{
  'id': 'win-1',
  'clinic': 'clinic-1',
  'weekday': 6,
  'weekday_label': 'السبت',
  'start_time': '09:00:00',
  'end_time': '13:00:00',
  'default_duration_minutes': 30,
  'slot_step_minutes': 30,
  'is_active': true,
};

/// Every request the app sent, in order, with the parts a test cares about.
class RequestLog {
  RequestLog(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add(options);
          handler.next(options);
        },
      ),
    );
  }

  final calls = <RequestOptions>[];

  Iterable<RequestOptions> where(String method, String path) =>
      calls.where((c) => c.method == method && c.path == path);

  RequestOptions last(String method, String path) => where(method, path).last;

  int count(String method, String path) => where(method, path).length;

  Map<String, dynamic> body(String method, String path) =>
      Map<String, dynamic>.from(last(method, path).data as Map);
}

/// Mock the doctor-side endpoints with sensible defaults; a test overrides any it
/// cares about by registering the route again afterwards.
void mockDoctorApi(DioAdapter a, {List<Map<String, dynamic>>? bookings}) {
  a
    ..onGet('/doctor/stats/', (s) => s.reply(200, envelope(statsData)))
    ..onGet('/doctor/activation/', (s) => s.reply(200, envelope(activationData)))
    ..onGet('/doctor/clinics/', (s) => s.reply(200, paged([clinicOwned, clinicShared])))
    ..onGet('/doctor/assistants/', (s) => s.reply(200, paged([assistantData])))
    ..onGet('/doctor/availability-windows/', (s) => s.reply(200, paged([windowData])))
    ..onGet('/doctor/clinics/link-1/invitations/', (s) => s.reply(200, envelope(<dynamic>[])))
    ..onGet(
      '/doctor/bookings/',
      (s) => s.reply(
        200,
        paged(
          bookings ??
              [
                booking('b1', status: 'pending', startAt: '2030-10-10T07:00:00Z'),
                booking('b2', status: 'confirmed', name: 'سارة علي', time: '09:30', startAt: '2030-10-10T07:30:00Z'),
              ],
        ),
      ),
    );
}

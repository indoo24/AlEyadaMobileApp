import 'dart:async';

import 'package:dio/dio.dart';

import 'management_fixtures.dart';

const slug = 'dr-sample';
const clinicA = 'aaaaaaaa-0000-4000-8000-00000000000a';
const clinicB = 'bbbbbbbb-0000-4000-8000-00000000000b';

/// A clinic as nested in `GET /doctors/{slug}/` → `clinics[].clinic`.
Map<String, dynamic> clinicJson(
  String id, {
  String name = 'عيادة',
  String mapsUrl = '',
  List<Map<String, dynamic>>? hours,
}) => {
  'id': id,
  'slug': 'c-$id',
  'name_ar': name,
  'name_en': '',
  'city': {'id': 'city-1', 'name_ar': 'الغربية'},
  'area': {'id': 'area-1', 'name_ar': 'طنطا'},
  'address_ar': 'شارع البحر',
  'landmark': 'أمام البنك',
  'latitude': null,
  'longitude': null,
  'avg_rating': '0.00',
  'reviews_count': 0,
  'primary_image': null,
  'google_maps_url': mapsUrl,
  'phone': '+201000000001',
  'whatsapp': '',
  'email': '',
  'website': 'https://clinic-site.example/',
  'social_links': <String, dynamic>{},
  'timezone': 'Africa/Cairo',
  'images': <dynamic>[],
  'contact': {
    'phone': '+201000000001',
    'whatsapp': '',
    'tel_url': 'tel:+201000000001',
    'whatsapp_url': '',
  },
  'contact_methods': <dynamic>[],
  'working_hours':
      hours ??
      [
        {
          'id': 'h1',
          'weekday': 6,
          'weekday_label': 'السبت',
          'open_time': '09:00:00',
          'close_time': '13:00:00',
        },
        {
          'id': 'h2',
          'weekday': 6,
          'weekday_label': 'السبت',
          'open_time': '17:00:00',
          'close_time': '21:00:00',
        },
        {
          'id': 'h3',
          'weekday': 1,
          'weekday_label': 'الاثنين',
          'open_time': '10:00:00',
          'close_time': '14:00:00',
        },
      ],
  'upcoming_holidays': <dynamic>[],
};

Map<String, dynamic> clinicLink(
  String clinicId, {
  String name = 'عيادة',
  bool bookingEnabled = true,
  bool isPrimary = false,
  String? fee = '200.00',
  String? followupFee = '100.00',
  String mapsUrl = '',
}) => {
  'id': 'link-$clinicId',
  'clinic': clinicJson(clinicId, name: name, mapsUrl: mapsUrl),
  'consultation_fee': fee,
  'followup_fee': followupFee,
  'booking_enabled': bookingEnabled,
  'payment_required': false,
  'is_primary': isPrimary,
};

/// `GET /doctors/{slug}/`, shaped like the live response (which carries more
/// than the spec's `DoctorDetail` lists). [overrides] replaces any key.
Map<String, dynamic> publicDoctor({Map<String, dynamic> overrides = const {}}) => {
  'id': 'doc-1',
  'slug': slug,
  'display_name': 'د. سارة محمود',
  'full_name_ar': 'سارة محمود',
  'full_name_en': '',
  'display_title': 'د.',
  'professional_title_ar': 'استشاري طب الأطفال',
  'gender': 'female',
  'photo': null,
  'years_of_experience': 12,
  'primary_specialization': {'id': 'sp1', 'name_ar': 'طب الأطفال', 'slug': 'pediatrics'},
  'city': {'id': 'city-1', 'name_ar': 'الغربية'},
  'area': {'id': 'area-1', 'name_ar': 'طنطا'},
  'min_fee': '150.00',
  'avg_rating': '4.50',
  'reviews_count': 3,
  'is_featured': false,
  'booking_enabled': true,
  'contact': {
    'phone': '+201000000009',
    'whatsapp': '+201000000009',
    'tel_url': 'tel:+201000000009',
    'whatsapp_url': 'https://wa.me/201000000009?text=hi',
  },
  'bio_ar': 'نبذة قصيرة عن الطبيبة.',
  'bio_en': '',
  'professional_title_en': '',
  'academic_degree_ar': 'دكتوراه طب الأطفال',
  'current_positions_ar': 'استشاري بمستشفى الجامعة',
  'past_positions_ar': 'مستشفى أ\r\nمستشفى ب',
  'certifications_ar': 'زمالة طب الأطفال',
  'fellowships_ar': '',
  'vision_ar': 'رعاية آمنة لكل طفل.',
  'website': 'https://dr-sample.example/',
  'external_booking_url': 'https://external-booking.example/book',
  'google_maps_url': 'https://maps.app.goo.gl/sample',
  'social_links': {
    'facebook': 'https://facebook.com/drsample',
    'instagram': '',
    'linkedin': 'not a url',
    'youtube': '',
    'tiktok': '',
  },
  'specializations': [
    {'id': 'sp2', 'name_ar': 'حديثي الولادة', 'slug': 'neonates', 'is_primary': false},
    {'id': 'sp1', 'name_ar': 'طب الأطفال', 'slug': 'pediatrics', 'is_primary': true},
  ],
  'services': [
    {'id': 'v1', 'name_ar': 'متابعة النمو', 'name_en': '', 'price': '250.00'},
    {'id': 'v2', 'name_ar': 'تطعيمات', 'name_en': '', 'price': null},
  ],
  'conditions': <dynamic>[],
  'procedures': <dynamic>[],
  'education': <dynamic>[],
  'certificates': <dynamic>[],
  'clinics': [
    clinicLink(clinicA, name: 'عيادة النخيل', isPrimary: true, fee: '150.00'),
    clinicLink(
      clinicB,
      name: 'مركز الشفاء',
      fee: '300.00',
      followupFee: null,
      mapsUrl: 'https://maps.app.goo.gl/clinicB',
    ),
  ],
  'seo': {'title': 't', 'description': 'd'},
  ...overrides,
};

Map<String, dynamic> slot(String id, String startUtc, String display) => {
  'id': id,
  'start_at': startUtc,
  'end_at': startUtc,
  'display_time': display,
  'display_end_time': '',
  'default_duration_minutes': 30,
};

/// `GET /doctors/{slug}/availability/?clinic_id=…` — the live object shape.
Map<String, dynamic> availability(
  String clinicId, {
  List<Map<String, dynamic>>? days,
  String fee = '150.00',
}) => {
  'booking_enabled': true,
  'clinic_id': clinicId,
  'timezone': 'Africa/Cairo',
  'fee': fee,
  'payment_required': false,
  'days':
      days ??
      [
        {
          'date': '2030-01-05',
          'slots': [
            slot('$clinicId-s1', '2030-01-05T07:00:00Z', '09:00'),
            slot('$clinicId-s2', '2030-01-05T07:30:00Z', '09:30'),
          ],
        },
        {
          'date': '2030-01-07',
          'slots': [slot('$clinicId-s3', '2030-01-07T08:00:00Z', '10:00')],
        },
      ],
};

/// The contact-only answer the live endpoint gives.
const contactOnlyAvailability = <String, dynamic>{
  'booking_enabled': false,
  'phone': '+201000000009',
  'whatsapp': '+201000000009',
  'tel_url': 'tel:+201000000009',
  'whatsapp_url': 'https://wa.me/201000000009',
  'message': 'هذا الطبيب يستقبل الحجوزات عبر الهاتف فقط.',
};

Map<String, dynamic> review(
  String id, {
  String name = 'أحمد',
  int rating = 5,
  bool verified = true,
}) => {
  'id': id,
  'rating': rating,
  'comment': 'تعليق $id',
  'patient_name': name,
  'verified_visit': verified,
  'created_at': '2026-09-01T10:00:00Z',
};

Map<String, dynamic> reviewsPage(
  List<Map<String, dynamic>> items, {
  required int page,
  required int pages,
  int? count,
}) => envelope(
  items,
  meta: {
    'pagination': {
      'count': count ?? items.length,
      'page': page,
      'pages': pages,
      'page_size': items.length,
      'next': page < pages ? 'next' : null,
      'previous': null,
    },
  },
);

/// `PatientBooking`, as `POST /doctors/{slug}/book/` returns it.
Map<String, dynamic> createdBooking({String clinicName = 'عيادة النخيل'}) => {
  'id': 'booking-123',
  'doctor': {'slug': slug, 'display_name': 'د. سارة محمود', 'photo': null},
  'clinic': {'name_ar': clinicName, 'address_ar': 'شارع البحر'},
  'start_at': '2030-01-05T07:00:00Z',
  'end_at': '2030-01-05T07:30:00Z',
  'display_date': '2030-01-05',
  'display_time': '09:00',
  'duration_minutes': 30,
  'visit_type': 'first_visit',
  'reason_for_visit': '',
  'notes_for_doctor': '',
  'status': 'confirmed',
  'fee_snapshot': '150.00',
  'payment_required': false,
  'payment_status': 'not_required',
  'payment_proofs': <dynamic>[],
  'can_cancel': true,
  'cancellation_cutoff_at': null,
  'cancellation_reason': '',
  'created_at': '2026-10-07T10:00:00Z',
};

/// A stand-in for the public doctor endpoints (and the account endpoints the
/// booking sheet uses), answering by path, method and query, and recording every
/// request.
///
/// Added *after* the real `ApiClient` interceptor, so what it records is what the
/// app actually sends — `Authorization` header included — and its failures go
/// through the client's error handling (token refresh and all).
class DetailServer {
  DetailServer(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) async {
          Response<dynamic> reply(Object? body, [int status = 200]) =>
              Response(requestOptions: o, statusCode: status, data: body);
          void fail(int status, Object body) => handler.reject(
            DioException.badResponse(
              statusCode: status,
              requestOptions: o,
              response: reply(body, status),
            ),
            true,
          );

          final base = '/doctors/$slug/';
          if (o.path == base && o.method == 'GET') {
            requests.add(o);
            return handler.resolve(reply(envelope(doctor)));
          }
          if (o.path == '${base}availability/') {
            requests.add(o);
            final clinic = o.queryParameters['clinic_id'] as String?;
            final gate = availabilityGates[clinic];
            if (gate != null) await gate.future;
            final data = availabilityByClinic[clinic];
            if (data == null) return fail(500, envelope(null));
            return handler.resolve(reply(envelope(data)));
          }
          if (o.path == '${base}reviews/') {
            requests.add(o);
            final page = int.tryParse('${o.queryParameters['page'] ?? 1}') ?? 1;
            if (failReviewPages.contains(page)) return fail(500, envelope(null));
            return handler.resolve(
              reply(reviewPages[page] ?? reviewsPage(const [], page: page, pages: 1)),
            );
          }
          if (o.path == '${base}book/' && o.method == 'POST') {
            requests.add(o);
            if (bookGate != null) await bookGate!.future;
            onBook?.call();
            final lost = bookAnswerLost;
            if (lost != null) {
              // The request arrived; whether it was carried out is up to the test.
              if (bookSavedBeforeLoss) booked.add(createdBooking());
              return handler.reject(DioException(requestOptions: o, type: lost), true);
            }
            if (bookUnreadable) {
              booked.add(createdBooking());
              return handler.resolve(reply('<html>proxy page</html>', 201));
            }
            if (bookError != null) return fail(bookErrorStatus, bookError!);
            booked.add(createdBooking());
            return handler.resolve(reply(envelope(createdBooking()), 201));
          }
          if (o.path == '/auth/me/' && o.method == 'GET') {
            requests.add(o);
            return handler.resolve(reply(envelope(me)));
          }
          if (o.path == '/auth/otp/request/') {
            requests.add(o);
            if (otpError != null) return fail(429, otpError!);
            return handler.resolve(reply(envelope({'sent': true})));
          }
          if (o.path == '/auth/token/refresh/') {
            requests.add(o);
            return fail(401, errorBody('token_not_valid', 'Token is invalid or expired'));
          }
          if (o.path == '/bookings/' && o.method == 'GET') {
            requests.add(o);
            if (bookingsListGate != null) await bookingsListGate!.future;
            if (bookingsListLost) {
              return handler.reject(
                DioException(requestOptions: o, type: DioExceptionType.connectionError),
                true,
              );
            }
            return handler.resolve(reply(paged(booked)));
          }
          if (o.path == '/auth/logout/') {
            requests.add(o);
            return handler.resolve(reply(envelope(null)));
          }
          if (o.path == '/tracking/contact-click/') {
            return handler.resolve(reply(envelope(null), 201));
          }
          handler.next(o);
        },
      ),
    );
  }

  Map<String, dynamic> doctor = publicDoctor();
  Map<String?, Map<String, dynamic>> availabilityByClinic = {
    clinicA: availability(clinicA),
    clinicB: availability(
      clinicB,
      fee: '300.00',
      days: [
        {
          'date': '2030-02-01',
          'slots': [slot('$clinicB-s1', '2030-02-01T10:00:00Z', '12:00')],
        },
      ],
    ),
  };

  /// Hold an availability answer until the test completes the gate.
  final availabilityGates = <String?, Completer<void>>{};
  Map<int, Map<String, dynamic>> reviewPages = {
    1: reviewsPage(
      [review('r1', name: 'أحمد'), review('r2', name: 'منى', rating: 4, verified: false)],
      page: 1,
      pages: 2,
      count: 3,
    ),
    2: reviewsPage([review('r3', name: 'خالد', rating: 3)], page: 2, pages: 2, count: 3),
  };
  final failReviewPages = <int>{};

  /// What `GET /auth/me/` answers — the account as the server knows it now.
  Map<String, dynamic> me = patientUser();

  /// Runs as a booking arrives, before it is answered.
  void Function()? onBook;

  /// The patient's bookings, as `GET /bookings/` lists them.
  final booked = <Map<String, dynamic>>[];
  Map<String, dynamic>? otpError;

  Completer<void>? bookGate;
  Map<String, dynamic>? bookError;
  int bookErrorStatus = 409;

  /// The booking's answer never reaches the app — lost this way.
  DioExceptionType? bookAnswerLost;

  /// With [bookAnswerLost]: the server made the booking before the answer was lost.
  bool bookSavedBeforeLoss = false;

  /// The booking is made and answered 201 — with a body that is not the API's.
  bool bookUnreadable = false;

  /// Hold `GET /bookings/`, or lose its answer.
  Completer<void>? bookingsListGate;
  bool bookingsListLost = false;
  Iterable<RequestOptions> get bookingsLists =>
      requests.where((r) => r.path == '/bookings/' && r.method == 'GET');

  final requests = <RequestOptions>[];

  Iterable<RequestOptions> get bookings => requests.where((r) => r.path.endsWith('/book/'));
  Iterable<RequestOptions> get meRequests => requests.where((r) => r.path == '/auth/me/');
  Iterable<RequestOptions> get otpRequests => requests.where((r) => r.path == '/auth/otp/request/');
  Iterable<RequestOptions> get refreshes => requests.where((r) => r.path == '/auth/token/refresh/');
  Iterable<RequestOptions> availabilityFor(String clinic) => requests.where(
    (r) => r.path.endsWith('/availability/') && r.queryParameters['clinic_id'] == clinic,
  );
  Iterable<RequestOptions> get reviewRequests =>
      requests.where((r) => r.path.endsWith('/reviews/'));
}

Map<String, dynamic> errorBody(String code, String detail) => {
  'data': null,
  'meta': <String, dynamic>{},
  'errors': [
    {'code': code, 'detail': detail, 'field': null},
  ],
};

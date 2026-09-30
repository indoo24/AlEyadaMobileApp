/// Response bodies captured from a running AlEyada backend.
///
/// These are not hand-written approximations. Each was taken from the real API
/// (`/api/v1/...`) and trimmed only for length, so a DTO that parses these
/// parses production. Field names, nullability, the decimal-as-string money
/// convention and the envelope shape are all exactly as the server sends them.
library;

/// `POST /auth/login/`
final loginResponse = <String, dynamic>{
  'data': {
    'access': 'header.payload.signature',
    'refresh': 'header.payload.signature',
    'user': meResponseData,
  },
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

/// The `user` object from a login, and the whole body of `GET /auth/me/`.
const meResponseData = {
  'id': '1f4a9a6c-0000-4000-8000-000000000001',
  'phone': '+201099990001',
  'email': 'fixture@aleyada.test',
  'first_name': 'مريض',
  'last_name': 'الاختبار',
  'full_name': 'مريض الاختبار',
  'role': 'patient',
  'preferred_language': 'ar',
  'is_phone_verified': true,
  'date_joined': '2026-09-30T08:00:00Z',
  'patient_profile': {
    'id': '1f4a9a6c-0000-4000-8000-000000000002',
    'full_name': 'مريض الاختبار',
    'gender': null,
    'birth_date': null,
  },
  'doctor_profile': null,
  'doctor_application': null,
  'assistant_profile': null,
  'requires_reacceptance': ['privacy', 'terms'],
};

final meResponse = <String, dynamic>{
  'data': meResponseData,
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

/// An applicant: role is still `patient`, a draft profile exists, and the
/// application is open. This combination is why the app reads
/// `doctor_application` instead of inferring status from `doctor_profile`.
final meApplicantResponse = <String, dynamic>{
  'data': {
    ...meResponseData,
    'role': 'patient',
    'requires_reacceptance': <String>[],
    'doctor_profile': {
      'id': '1f4a9a6c-0000-4000-8000-000000000003',
      'slug': 'sara-ali',
      'full_name_ar': 'سارة علي',
      'verification_status': 'pending_review',
      'is_published': false,
    },
    'doctor_application': {
      'kind': 'application',
      'status': 'pending',
      'is_open': true,
      'needs_doctor_action': false,
      'submitted_at': '2026-09-30T08:10:00Z',
      'reviewed_at': null,
      'rejection_reason': '',
      'doctor_name': 'سارة علي',
    },
  },
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

/// A claimant: no doctor profile at all, and the application kind is `claim`.
final meClaimantResponse = <String, dynamic>{
  'data': {
    ...meResponseData,
    'requires_reacceptance': <String>[],
    'doctor_profile': null,
    'doctor_application': {
      'kind': 'claim',
      'status': 'pending',
      'is_open': true,
      'needs_doctor_action': false,
      'submitted_at': '2026-09-30T08:10:00Z',
      'reviewed_at': null,
      'rejection_reason': '',
      'doctor_name': 'د. سارة علي',
    },
  },
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

/// `GET /doctors/?page_size=2` — note `meta.pagination`.
final doctorListResponse = <String, dynamic>{
  'data': [doctorCardData, doctorCardData2],
  'meta': {
    'pagination': {
      'count': 17,
      'page': 1,
      'pages': 9,
      'page_size': 2,
      'next': 'http://127.0.0.1:8000/api/v1/doctors/?page=2&page_size=2',
      'previous': null,
    },
  },
  'errors': <dynamic>[],
};

const doctorCardData = {
  'id': '92572857-6b79-4724-a677-dbd71ebfba4f',
  'slug': 'mohamed-ebrahim',
  'display_name': 'محمد ابراهيم',
  'full_name_ar': 'محمد ابراهيم',
  'full_name_en': 'Mohamed Ebrahim',
  'display_title': '',
  'professional_title_ar': 'قلب وأوعية دموية',
  'gender': '',
  'photo': 'http://127.0.0.1:8000/media/doctors/photos/x.jpg',
  'years_of_experience': 45,
  'primary_specialization': {
    'id': 'd8dee7e8-34f5-4282-919b-2d53cff2047c',
    'name_ar': 'قلب',
    'name_en': 'Cardiology',
    'slug': 'cardiology',
    'description': '',
    'icon': null,
    'parent': null,
    'sort_order': 0,
    'doctors_count': 0,
  },
  'city': {'id': 'faf67130-707c-46b5-acb8-dedcb30c7fa2', 'name_ar': 'الغربية'},
  'area': {'id': '1de62999-d74c-424c-8186-c3b6c2bacb3b', 'name_ar': 'طنطا'},
  // Money is a decimal *string*, never a JSON number.
  'min_fee': '300.00',
  'avg_rating': '0.00',
  'reviews_count': 0,
  'is_featured': false,
  'booking_enabled': true,
  // The backend pre-builds the launch URLs, including the Arabic WhatsApp text.
  'contact': {
    'phone': '+201014253965',
    'whatsapp': '01014253965',
    'tel_url': 'tel:+201014253965',
    'whatsapp_url': 'https://wa.me/01014253965?text=%D8%A7%D9%84%D8%B3%D9%84%D8%A7%D9%85',
  },
};

final doctorCardData2 = <String, dynamic>{
  ...doctorCardData,
  'id': '837279d8-5772-4c02-85ff-919d55d574e7',
  'slug': 'ahmed-reda',
  'display_name': 'احمد رضا',
  'full_name_ar': 'احمد رضا',
  'full_name_en': 'Ahmed Reda',
  'min_fee': '300.00',
  'avg_rating': '4.50',
  'reviews_count': 12,
};

/// `GET /doctors/{slug}/availability/`
///
/// `display_time` is clinic-local and formatted by the server; `start_at` is UTC.
const availabilityResponse = {
  'data': {
    'booking_enabled': true,
    'clinic_id': 'b341b1a9-e7a1-43f7-8aad-94e051d34632',
    'timezone': 'Africa/Cairo',
    'fee': '300.00',
    'payment_required': false,
    'days': [
      {
        'date': '2026-10-01',
        'slots': [
          {
            'id': 'f041e135-6bc2-45cd-9229-3cff23891d11',
            'start_at': '2026-10-01T10:00:00Z',
            'end_at': '2026-10-01T10:30:00Z',
            'display_time': '13:00',
            'display_end_time': '13:30',
            'default_duration_minutes': 30,
          },
          {
            'id': 'fc5bc63f-de0f-4e0d-8170-91395b65b218',
            'start_at': '2026-10-01T10:30:00Z',
            'end_at': '2026-10-01T11:00:00Z',
            'display_time': '13:30',
            'display_end_time': '14:00',
            'default_duration_minutes': 30,
          },
        ],
      },
      {'date': '2026-10-02', 'slots': <dynamic>[]},
    ],
  },
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

/// `GET /bookings/` with one row.
final bookingListResponse = <String, dynamic>{
  'data': [bookingData],
  'meta': {
    'pagination': {
      'count': 1,
      'page': 1,
      'pages': 1,
      'page_size': 20,
      'next': null,
      'previous': null,
    },
  },
  'errors': <dynamic>[],
};

const bookingData = {
  'id': 'aa11bb22-0000-4000-8000-000000000001',
  'doctor': {'slug': 'ahmed-reda', 'display_name': 'احمد رضا', 'photo': null},
  'clinic': {'name_ar': 'طنطا', 'address_ar': 'طنطا سبرباي'},
  'start_at': '2026-10-01T10:00:00Z',
  'end_at': '2026-10-01T10:30:00Z',
  'display_date': '2026-10-01',
  'display_time': '13:00',
  'duration_minutes': 30,
  'visit_type': 'first_visit',
  'reason_for_visit': '',
  'notes_for_doctor': '',
  'status': 'confirmed',
  'fee_snapshot': '300.00',
  'payment_required': false,
  'payment_status': 'not_required',
  'payment_proofs': <dynamic>[],
  // The server decides; the client renders a button or does not.
  'can_cancel': true,
  'cancellation_cutoff_at': '2026-10-01T04:00:00Z',
  'cancellation_reason': '',
  'created_at': '2026-09-30T08:20:00Z',
};

/// `GET /locations/cities/?with_areas=1` — the unrestricted list used by search.
const citiesResponse = {
  'data': [
    {
      'id': 'c1',
      'slug': 'giza',
      'name_ar': 'الجيزة',
      'name_en': 'Giza',
      'areas': [
        {'id': 'a1', 'slug': 'dokki', 'name_ar': 'الدقي', 'name_en': 'Dokki'},
        {'id': 'a2', 'slug': 'mohandessin', 'name_ar': 'المهندسين', 'name_en': 'Mohandessin'},
      ],
    },
    {
      'id': 'c2',
      'slug': 'gharbia',
      'name_ar': 'الغربية',
      'name_en': 'Gharbia',
      'areas': [
        {'id': 'a3', 'slug': 'tanta', 'name_ar': 'طنطا', 'name_en': 'Tanta'},
      ],
    },
    {
      'id': 'c3',
      'slug': 'cairo',
      'name_ar': 'القاهرة',
      'name_en': 'Cairo',
      'areas': [
        {'id': 'a4', 'slug': 'maadi', 'name_ar': 'المعادي', 'name_en': 'Maadi'},
      ],
    },
  ],
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

/// `GET /locations/cities/?with_areas=1&onboarding=1` — deliberately narrower.
const onboardingCitiesResponse = {
  'data': [
    {
      'id': 'c2',
      'slug': 'gharbia',
      'name_ar': 'الغربية',
      'name_en': 'Gharbia',
      'areas': [
        {'id': 'a3', 'slug': 'tanta', 'name_ar': 'طنطا', 'name_en': 'Tanta'},
      ],
    },
  ],
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

/// `GET /specializations/` — a tree.
const specializationsResponse = {
  'data': [
    {
      'id': 's1',
      'slug': 'dentistry',
      'name_ar': 'أسنان',
      'name_en': 'Dentistry',
      'description': '',
      'icon': null,
      'parent': null,
      'sort_order': 0,
      'doctors_count': 4,
      'children': [
        {
          'id': 's2',
          'slug': 'orthodontics',
          'name_ar': 'تقويم الأسنان',
          'name_en': 'Orthodontics',
          'description': '',
          'icon': null,
          'parent': 's1',
          'sort_order': 1,
          'doctors_count': 1,
          'children': <dynamic>[],
        },
      ],
    },
    {
      'id': 's3',
      'slug': 'cardiology',
      'name_ar': 'قلب',
      'name_en': 'Cardiology',
      'description': '',
      'icon': null,
      'parent': null,
      'sort_order': 2,
      'doctors_count': 2,
      'children': <dynamic>[],
    },
  ],
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

// --- error envelopes, exactly as the backend sends them ---------------------

const invalidCredentialsError = {
  'data': null,
  'meta': <String, dynamic>{},
  'errors': [
    {
      'code': 'invalid_credentials',
      'detail': 'Phone/email or password is incorrect.',
      'field': null,
    },
  ],
};

const notAuthenticatedError = {
  'data': null,
  'meta': <String, dynamic>{},
  'errors': [
    {'code': 'not_authenticated', 'detail': 'لم يتم تزويد بيانات الدخول.', 'field': null},
  ],
};

/// A field-attributed validation failure — this is the shape the onboarding
/// location restriction produces when an unsupported city is sent.
const cityNotAllowedError = {
  'data': null,
  'meta': <String, dynamic>{},
  'errors': [
    {
      'code': 'does_not_exist',
      'detail': 'We are not registering doctors in this city yet.',
      'field': 'city',
    },
    {'code': 'required', 'detail': 'This field is required.', 'field': 'password'},
  ],
};

const slotTakenError = {
  'data': null,
  'meta': <String, dynamic>{},
  'errors': [
    {'code': 'slot_not_bookable', 'detail': 'هذا الموعد لم يعد متاحًا.', 'field': null},
  ],
};

const throttledError = {
  'data': null,
  'meta': <String, dynamic>{},
  'errors': [
    {'code': 'throttled', 'detail': 'Request was throttled.', 'field': null},
  ],
};

import 'package:dio/dio.dart';

import 'management_fixtures.dart';

const cityId = 'city-gharbia';
const areaId = 'area-tanta';

/// Every field `PATCH /doctor/profile/` accepts (plus the read-only ones the
/// server lists as editable would not be). A test narrows this to whatever the
/// scenario needs.
const allPatchable = <String>[
  'full_name_ar',
  'full_name_en',
  'display_title',
  'professional_title_ar',
  'professional_title_en',
  'academic_degree_ar',
  'years_of_experience',
  'default_consultation_fee',
  'bio_ar',
  'bio_en',
  'vision_ar',
  'current_positions_ar',
  'past_positions_ar',
  'certifications_ar',
  'fellowships_ar',
  'phone',
  'whatsapp',
  'website',
  'external_booking_url',
  'google_maps_url',
  'social_links',
  'seo_title',
  'seo_description',
];

/// `GET /doctor/profile/` for an approved doctor, shaped like the spec's
/// `DoctorOwnProfile`. [overrides] replaces any key.
Map<String, dynamic> ownProfile({Map<String, dynamic> overrides = const {}}) => {
  'id': 'profile-1',
  'slug': 'nermeen',
  'full_name_ar': 'نرمين أحمد فؤاد',
  'full_name_en': 'Nermeen Ahmed Fouad',
  'display_title': 'د.',
  'gender': 'female',
  'photo': null,
  'bio_ar': 'أخصائية أمراض النساء والتوليد والعقم.',
  'bio_en': '',
  'years_of_experience': 10,
  'professional_title_ar': 'أخصائية أمراض النساء والتوليد وعلاج العقم',
  'professional_title_en': '',
  'academic_degree_ar': 'ماجستير طب النساء والتوليد',
  'phone': '+201010636122',
  'whatsapp': '+201010636122',
  'default_consultation_fee': '160.00',
  'certifications_ar': 'ماجستير أمراض النساء والتوليد – جامعة بنها',
  'fellowships_ar': '',
  'current_positions_ar': 'تعمل بمستشفى طنطا العام.',
  'past_positions_ar': 'سبق لها العمل في مستشفى دار القمة.',
  'vision_ar': 'رعاية طبية آمنة وواضحة.',
  'website': '',
  'external_booking_url': '',
  'google_maps_url': '',
  'social_links': {
    'facebook': 'https://www.facebook.com/share/18DXiV3Cig/',
    'instagram': 'https://www.instagram.com/nenoelwakeel/',
    'linkedin': '',
    'youtube': '',
    'tiktok': '',
  },
  'city': cityId,
  'area': areaId,
  'verification_status': 'approved',
  'is_published': true,
  'is_featured': false,
  'avg_rating': '4.60',
  'reviews_count': 5,
  'seo_title': '',
  'seo_description': '',
  'specializations': [
    {'id': 's1', 'slug': 'gyn', 'name_ar': 'أمراض النساء والتوليد', 'name_en': 'Gynaecology', 'is_primary': true},
    {'id': 's2', 'slug': 'infertility', 'name_ar': 'علاج العقم', 'name_en': 'Infertility', 'is_primary': false},
  ],
  'editable_fields': allPatchable,
  'credential_fields': ['full_name_ar', 'full_name_en', 'display_title', 'professional_title_ar', 'certifications_ar'],
  'created_at': '2026-09-01T10:00:00Z',
  ...overrides,
};

/// `GET /locations/cities/`, with the doctor's city and area in it.
final citiesWithDoctorArea = envelope([
  {
    'id': cityId,
    'slug': 'gharbia',
    'name_ar': 'الغربية',
    'name_en': 'Gharbia',
    'areas': [
      {'id': areaId, 'slug': 'tanta', 'name_ar': 'طنطا', 'name_en': 'Tanta'},
    ],
  },
]);

/// A stand-in for the profile endpoints: GET returns what is stored, PATCH merges
/// the changes in (as a real server would) and records the request.
///
/// It answers inside a Dio interceptor because the mock adapter keeps one route
/// per path, and this endpoint needs both GET and PATCH on the same path.
class ProfileServer {
  ProfileServer(Dio dio, {Map<String, dynamic>? profile}) : profile = profile ?? ownProfile() {
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (o, handler) async {
          Response<dynamic> reply(Object? body, [int status = 200]) =>
              Response(requestOptions: o, statusCode: status, data: body);

          if (o.path == '/doctor/profile/') {
            requests.add(o);
            if (o.method == 'GET') {
              profileGets++;
              if (profileDelay != null) {
                await Future<void>.delayed(profileDelay!);
                return handler.resolve(reply(envelope(this.profile)));
              }
              if (failProfileGet) {
                return handler.reject(
                  DioException.badResponse(statusCode: 500, requestOptions: o, response: reply(envelope(null), 500)),
                );
              }
              return handler.resolve(reply(envelope(this.profile)));
            }
            if (o.method == 'PATCH') {
              if (patchError != null) {
                return handler.reject(
                  DioException.badResponse(statusCode: 400, requestOptions: o, response: reply(patchError, 400)),
                );
              }
              final changes = Map<String, dynamic>.from(o.data as Map);
              for (final e in changes.entries) {
                if (socialKeys.contains(e.key)) {
                  final links = Map<String, dynamic>.from(this.profile['social_links'] as Map? ?? {});
                  links[e.key] = e.value;
                  this.profile['social_links'] = links;
                } else {
                  this.profile[e.key] = e.value;
                }
              }
              return handler.resolve(reply(envelope({'applied': changes.keys.toList(), 'staged': <String>[]})));
            }
          }
          if (o.path == '/doctor/education/') return handler.resolve(reply(paged(education)));
          if (o.path == '/doctor/certificates/') return handler.resolve(reply(paged(certificates)));
          if (o.path == '/doctor/services/') {
            if (failServices) {
              return handler.reject(
                DioException.badResponse(statusCode: 500, requestOptions: o, response: reply(envelope(null), 500)),
              );
            }
            return handler.resolve(reply(paged(services)));
          }
          if (o.path == '/doctor/verification-status/') {
            return handler.resolve(reply(envelope({'status': 'rejected', 'rejection_reason': rejectionReason})));
          }
          if (o.path == '/locations/cities/') return handler.resolve(reply(citiesWithDoctorArea));
          handler.next(o);
        },
      ),
    );
  }

  static const socialKeys = ['facebook', 'instagram', 'linkedin', 'youtube', 'tiktok'];

  /// What the server stores; a PATCH changes it.
  Map<String, dynamic> profile;

  final requests = <RequestOptions>[];
  int profileGets = 0;
  bool failProfileGet = false;
  bool failServices = false;
  Duration? profileDelay;
  Map<String, dynamic>? patchError;
  String rejectionReason = '';

  List<Map<String, dynamic>> education = [
    {'id': 'e1', 'degree_ar': 'بكالوريوس الطب والجراحة', 'degree_en': '', 'institution_ar': 'جامعة بنها', 'institution_en': '', 'year': 2012, 'sort_order': 0},
  ];
  List<Map<String, dynamic>> certificates = [
    {'id': 'c1', 'title_ar': 'زمالة المجلس المصري', 'title_en': '', 'issuer': 'المجلس المصري', 'year': 2018, 'is_public': true, 'download_url': '/x'},
  ];
  List<Map<String, dynamic>> services = [
    {'id': 'v1', 'name_ar': 'متابعة حمل', 'name_en': '', 'price': '250.00', 'is_active': true, 'sort_order': 0},
  ];

  Iterable<RequestOptions> get patches => requests.where((r) => r.method == 'PATCH');

  Map<String, dynamic> get lastPatchBody => Map<String, dynamic>.from(patches.last.data as Map);
}

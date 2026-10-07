import 'dart:async';

import 'package:dio/dio.dart';

import 'api_fixtures.dart';
import 'doctor_detail_fixtures.dart' as dd;
import 'management_fixtures.dart';

/// The pinned "now" for booking tests: 1 Jan 2030, 00:00 UTC.
final testNow = DateTime.utc(2030, 1, 1);

/// A `PatientBooking`, shaped like the captured [bookingData], with overrides.
///
/// [start] is UTC; `display_date` / `display_time` are the clinic-local labels
/// the server would send for it (Cairo is UTC+2 in January).
Map<String, dynamic> patientBooking({
  required String id,
  required DateTime start,
  String status = 'confirmed',
  String doctorName = 'د. سارة محمود',
  String doctorSlug = dd.slug,
  String clinicName = 'عيادة النخيل',
  String? clinicAddress = 'شارع البحر',
  bool canCancel = true,
  Duration cutoffBefore = const Duration(hours: 6),
  Map<String, dynamic> overrides = const {},
}) {
  final local = start.add(const Duration(hours: 2));
  String two(int n) => n.toString().padLeft(2, '0');
  return {
    ...bookingData,
    'id': id,
    'doctor': {'slug': doctorSlug, 'display_name': doctorName, 'photo': null},
    'clinic': {'name_ar': clinicName, 'address_ar': clinicAddress},
    'start_at': start.toIso8601String(),
    'end_at': start.add(const Duration(minutes: 30)).toIso8601String(),
    'display_date': '${local.year}-${two(local.month)}-${two(local.day)}',
    'display_time': '${two(local.hour)}:${two(local.minute)}',
    'status': status,
    'can_cancel': canCancel,
    'cancellation_cutoff_at': start.subtract(cutoffBefore).toIso8601String(),
    'created_at': '2029-12-20T09:00:00Z',
    ...overrides,
  };
}

/// Answers the booking endpoints (and the doctor profile they draw on), and
/// records every request. Runs after the real `ApiClient` interceptor.
class BookingsServer {
  BookingsServer(Dio dio) {
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

          requests.add(o);
          if (o.path == '/bookings/' && o.method == 'GET') {
            if (listGate != null) await listGate!.future;
            if (failList) return fail(500, envelope(null));
            final page = int.tryParse('${o.queryParameters['page'] ?? 1}') ?? 1;
            final items = pages.length >= page ? pages[page - 1] : <Map<String, dynamic>>[];
            return handler.resolve(
              reply(
                envelope(
                  items,
                  meta: <String, dynamic>{
                    'pagination': <String, dynamic>{
                      'count': all.length,
                      'page': page,
                      'pages': pages.length,
                      'page_size': pageSize,
                      'next': page < pages.length ? 'next' : null,
                      'previous': null,
                    },
                  },
                ),
              ),
            );
          }
          final cancel = RegExp(r'^/bookings/([^/]+)/cancel/$').firstMatch(o.path);
          if (cancel != null && o.method == 'POST') {
            if (cancelError != null) return fail(cancelErrorStatus, cancelError!);
            final id = cancel.group(1)!;
            final i = all.indexWhere((b) => b['id'] == id);
            all[i] = {...all[i], 'status': 'cancelled_by_patient', 'can_cancel': false};
            return handler.resolve(reply(envelope(all[i])));
          }
          final one = RegExp(r'^/bookings/([^/]+)/$').firstMatch(o.path);
          if (one != null && o.method == 'GET') {
            final b = all.where((b) => b['id'] == one.group(1)).firstOrNull;
            if (b == null) return fail(404, dd.errorBody('not_found', 'Not found.'));
            return handler.resolve(reply(envelope(b)));
          }
          if (o.path.startsWith('/doctors/') && o.method == 'GET') {
            final slug = o.path.split('/')[2];
            final d = doctors[slug];
            if (d == null) return fail(404, dd.errorBody('not_found', 'Not found.'));
            return handler.resolve(reply(envelope(d)));
          }
          if (o.path == '/tracking/contact-click/') {
            return handler.resolve(reply(envelope(null), 201));
          }
          if (o.path == '/auth/me/') return handler.resolve(reply(envelope(patientUser())));
          handler.next(o);
        },
      ),
    );
  }

  /// Every booking the server holds, in the order it lists them.
  List<Map<String, dynamic>> all = [];

  /// How [all] is split into pages; one page unless a test says otherwise.
  int pageSize = 50;
  List<List<Map<String, dynamic>>> get pages => [
    for (var i = 0; i < all.length; i += pageSize)
      all.sublist(i, (i + pageSize).clamp(0, all.length)),
    if (all.isEmpty) <Map<String, dynamic>>[],
  ];

  Map<String, Map<String, dynamic>> doctors = {dd.slug: dd.publicDoctor()};

  Completer<void>? listGate;
  bool failList = false;
  Map<String, dynamic>? cancelError;
  int cancelErrorStatus = 422;

  final requests = <RequestOptions>[];
  Iterable<RequestOptions> get listRequests =>
      requests.where((r) => r.path == '/bookings/' && r.method == 'GET');
  Iterable<RequestOptions> get cancels => requests.where((r) => r.path.endsWith('/cancel/'));
}

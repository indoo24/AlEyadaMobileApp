import 'dart:async';

import 'package:dio/dio.dart';

import 'management_fixtures.dart';

/// A `Notification` as `GET /notifications/` lists it.
Map<String, dynamic> notificationJson(
  String id, {
  required String type,
  required String title,
  String body = '',
  bool read = false,
  String? booking,
  DateTime? createdAt,
}) => {
  'id': id,
  'type': type,
  'title': title,
  'body': body,
  'booking': booking,
  'data': <String, dynamic>{},
  'is_read': read,
  'created_at': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
};

/// Answers the notification and account endpoints, recording requests.
class AccountServer {
  AccountServer(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) async {
          Response<dynamic> reply(Object? body, [int status = 200]) =>
              Response(requestOptions: o, statusCode: status, data: body);
          void fail(int status, Object? body) => handler.reject(
            DioException.badResponse(
              statusCode: status,
              requestOptions: o,
              response: reply(body, status),
            ),
            true,
          );

          requests.add(o);
          if (o.path == '/notifications/' && o.method == 'GET') {
            if (listGate != null) await listGate!.future;
            if (failList) return fail(500, envelope(null));
            final page = int.tryParse('${o.queryParameters['page'] ?? 1}') ?? 1;
            final items = page == 1 ? firstPage : (pages[page] ?? <Map<String, dynamic>>[]);
            final total = 1 + pages.length;
            return handler.resolve(
              reply(
                envelope(
                  items,
                  meta: <String, dynamic>{
                    'pagination': <String, dynamic>{
                      'count': items.length,
                      'page': page,
                      'pages': total,
                      'page_size': 20,
                      'next': page < total ? 'next' : null,
                      'previous': null,
                    },
                  },
                ),
              ),
            );
          }
          if (o.path == '/notifications/unread-count/') {
            final all = [...firstPage, for (final p in pages.values) ...p];
            return handler.resolve(
              reply(envelope({'count': all.where((n) => n['is_read'] != true).length})),
            );
          }
          if (o.path == '/notifications/read-all/') {
            if (failMark) return fail(500, envelope(null));
            for (final n in firstPage) {
              n['is_read'] = true;
            }
            return handler.resolve(reply(envelope(null)));
          }
          final read = RegExp(r'^/notifications/([^/]+)/read/$').firstMatch(o.path);
          if (read != null) {
            if (failMark) return fail(500, envelope(null));
            for (final n in firstPage) {
              if (n['id'] == read.group(1)) {
                n['is_read'] = true;
              }
            }
            return handler.resolve(reply(envelope(null)));
          }
          if (o.path == '/auth/me/' && o.method == 'PATCH') {
            if (patchError != null) return fail(400, patchError);
            me = {...me, ...Map<String, dynamic>.from(o.data as Map)};
            return handler.resolve(reply(envelope(me)));
          }
          if (o.path == '/auth/me/') return handler.resolve(reply(envelope(me)));
          if (o.path == '/auth/otp/request/') {
            return handler.resolve(reply(envelope({'sent': true})));
          }
          if (o.path == '/auth/logout/') return handler.resolve(reply(null, 204));
          handler.next(o);
        },
      ),
    );
  }

  Map<String, dynamic> me = patientUser();
  List<Map<String, dynamic>> firstPage = [];
  Map<int, List<Map<String, dynamic>>> pages = {};
  Completer<void>? listGate;
  bool failList = false;
  bool failMark = false;
  Map<String, dynamic>? patchError;

  final requests = <RequestOptions>[];
  Iterable<RequestOptions> where(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);
}

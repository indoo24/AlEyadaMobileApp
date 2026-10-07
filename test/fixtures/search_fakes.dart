import 'dart:async';

import 'package:aleyada_mobile/core/api/envelope.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:aleyada_mobile/features/doctors/repository.dart';
import 'package:dio/dio.dart';

import 'api_fixtures.dart';

/// A doctor card with a distinct identity.
DoctorCard doctorNo(int n, {bool bookable = true, int reviews = 12}) => DoctorCard.fromJson({
  ...doctorCardData,
  'id': 'doctor-$n',
  'slug': 'doctor-$n',
  'display_name': 'دكتور رقم $n',
  'booking_enabled': bookable,
  'reviews_count': reviews,
});

/// One page of [perPage] doctors out of [total], numbered across pages.
Paginated<DoctorCard> pageOf({int page = 1, int perPage = 2, int total = 17}) {
  final pages = (total / perPage).ceil();
  final first = (page - 1) * perPage;
  return Paginated(
    items: [
      for (var i = first; i < first + perPage && i < total; i++) doctorNo(i + 1),
    ],
    pagination: Pagination(count: total, page: page, pages: pages, pageSize: perPage),
  );
}

/// A directory whose answers the test controls.
///
/// Every call is recorded, and each is answered by [handler] — usually with a
/// [Completer] so the test decides *when* (and in what order) responses arrive,
/// which is the only honest way to test "the latest query wins".
class FakeDirectory extends DirectoryRepository {
  FakeDirectory(super.api, {this.handler});

  final calls = <DoctorQuery>[];
  final tokens = <CancelToken?>[];
  Future<Paginated<DoctorCard>> Function(DoctorQuery query)? handler;

  @override
  Future<Paginated<DoctorCard>> doctors(DoctorQuery query, {CancelToken? cancelToken}) {
    calls.add(query);
    tokens.add(cancelToken);
    return handler!(query);
  }

  /// The `q` of every request made so far (null = no search text).
  List<String?> get searches => [for (final c in calls) c.toQuery()['q'] as String?];
}

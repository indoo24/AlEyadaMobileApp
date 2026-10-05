import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/envelope.dart';
import 'models.dart';

class ClinicRepository {
  ClinicRepository(this._api);

  final ApiClient _api;

  /// Active clinics, optionally narrowed to one city (by slug). Filtering is the
  /// backend's; nothing is hidden client-side.
  Future<Paginated<ClinicListItem>> clinics({String? city, int page = 1, int? pageSize}) async {
    final body = await _api.get(
      Endpoints.clinics,
      query: {'page': page, if (pageSize != null) 'page_size': pageSize, if (city != null) 'city': city},
    );
    return unwrapPaginated(body, ClinicListItem.fromJson);
  }
}

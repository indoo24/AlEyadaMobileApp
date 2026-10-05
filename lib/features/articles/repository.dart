import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/envelope.dart';
import 'models.dart';

class ArticleRepository {
  ArticleRepository(this._api);

  final ApiClient _api;

  Future<Paginated<ArticleListItem>> articles({int page = 1, int? pageSize}) async {
    final body = await _api.get(
      Endpoints.articles,
      query: {'page': page, if (pageSize != null) 'page_size': pageSize},
    );
    return unwrapPaginated(body, ArticleListItem.fromJson);
  }
}

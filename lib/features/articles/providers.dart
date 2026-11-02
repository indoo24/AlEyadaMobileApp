import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/envelope.dart';
import '../../core/paging/paged_list.dart';
import '../../core/providers.dart';
import 'models.dart';
import 'repository.dart';

final articleRepositoryProvider = Provider<ArticleRepository>(
  (ref) => ArticleRepository(ref.watch(apiClientProvider)),
);

/// The newest published articles, for the home screen.
final homeArticlesProvider = FutureProvider<Paginated<ArticleListItem>>((ref) async {
  return ref.watch(articleRepositoryProvider).articles(pageSize: 4);
});

/// Every published article, newest first, a page at a time.
final allArticlesProvider =
    StateNotifierProvider.autoDispose<
      PagedListController<ArticleListItem>,
      PagedListState<ArticleListItem>
    >((ref) {
      final repo = ref.watch(articleRepositoryProvider);
      return PagedListController(
        (page) => repo.articles(page: page, pageSize: 20),
        idOf: (a) => a.id,
      );
    });

/// One article, body included, by slug.
final articleDetailProvider = FutureProvider.autoDispose
    .family<ArticleDetail, String>((ref, slug) {
      return ref.watch(articleRepositoryProvider).article(slug);
    });

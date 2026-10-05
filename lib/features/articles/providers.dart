import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/envelope.dart';
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

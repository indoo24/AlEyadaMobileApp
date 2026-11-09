import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/paged_list_view.dart';
import '../../l10n/app_localizations.dart';
import '../home/widgets/article_card.dart';
import 'models.dart';
import 'providers.dart';

/// Every published article, newest first — Home's "see all".
class ArticlesScreen extends ConsumerWidget {
  const ArticlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final controller = ref.read(allArticlesProvider.notifier);

    return Scaffold(
      backgroundColor: context.palette.page,
      appBar: AppBar(title: Text(l.homeArticlesTitle)),
      body: PagedListView<ArticleListItem>(
        state: ref.watch(allArticlesProvider),
        onReload: controller.reload,
        onLoadMore: controller.loadMore,
        empty: AppEmptyView(
          icon: Icons.article_outlined,
          title: l.homeNoArticles,
        ),
        itemBuilder: (context, a) => ArticleCard(
          article: a,
          onTap: () => context.push(Routes.articlePath(a.slug)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../articles/models.dart';
import '../home_style.dart';
import '../../../core/theme/app_palette.dart';

/// One article in the feed: category, title, excerpt, and the cover when the
/// article has one.
///
/// There is no reading time — the feed does not return one, and a made-up
/// "4 minutes" would be worse than none.
class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article, this.onTap});

  final ArticleListItem article;

  /// Null while there is no article page to open.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final category = article.categoryName ?? '';
    final image = article.featuredImage;

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: context.palette.border),
        boxShadow: context.palette.shadowSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null && image.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  cacheWidth:
                      (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  width: double.infinity,
                  // A missing cover collapses to the text card rather than
                  // leaving a grey box or a broken-image glyph.
                  errorBuilder: (_, __, ___) => ColoredBox(color: context.palette.pageSoft),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : ColoredBox(color: context.palette.pageSoft),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (category.isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.palette.pageSoft,
                              borderRadius: AppRadii.pillRadius,
                            ),
                            child: Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.homeType.pill.copyWith(color: context.palette.primary),
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (article.isCertified) ...[
                        Icon(Icons.verified_outlined, size: 13, color: context.palette.success),
                        const SizedBox(width: 4),
                        Text(
                          l.homeArticleCertified,
                          style: context.homeType.status.copyWith(color: context.palette.success),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article.titleAr,
                    style: context.homeType.articleTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (article.excerpt.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      article.excerpt,
                      style: context.homeType.articleBody,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

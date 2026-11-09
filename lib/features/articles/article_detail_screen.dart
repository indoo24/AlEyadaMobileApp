import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctor_detail_logic.dart';
import '../home/home_style.dart';
import 'article_html.dart';
import 'models.dart';
import 'providers.dart';

/// One article, read in full: cover, category, title, date, reviewer, body.
///
/// Only what the API returns is shown — no reading time, no author photo, no
/// invented byline. The article's own text is laid out in its own direction
/// (the API serves it in Arabic), while the screen around it follows the app's
/// language.
class ArticleDetailScreen extends ConsumerWidget {
  const ArticleDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: context.palette.page,
      appBar: AppBar(title: Text(l.articleScreenTitle)),
      body: AsyncValueView<ArticleDetail>(
        value: ref.watch(articleDetailProvider(slug)),
        onRetry: () => ref.invalidate(articleDetailProvider(slug)),
        data: (article) => _Article(article: article),
      ),
    );
  }
}

/// The direction [text] reads in, whatever the app's language.
TextDirection _directionOf(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;

class _Article extends StatelessWidget {
  const _Article({required this.article});

  final ArticleDetail article;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.palette;
    final a = article;
    final blocks = articleBlocks(a.contentHtml);
    final category = a.categoryName ?? '';
    final image = a.featuredImage ?? '';
    final locale = Localizations.localeOf(context).toLanguageTag();
    final meta = context.homeType.meta.copyWith(fontSize: 12.5);

    Widget metaLine(IconData icon, String text, {Color? color}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: color ?? p.muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: meta.copyWith(color: color)),
        ),
      ],
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (image.isNotEmpty) ...[
          _Cover(url: image),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (category.isNotEmpty || a.isCertified) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (category.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.pageSoft,
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Text(
                    category,
                    style: context.homeType.pill.copyWith(color: p.primary),
                  ),
                ),
              if (a.isCertified)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined, size: 14, color: p.success),
                    const SizedBox(width: 4),
                    Text(
                      l.homeArticleCertified,
                      style: context.homeType.status.copyWith(color: p.success),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Semantics(
          header: true,
          child: Text(
            a.titleAr,
            textDirection: _directionOf(a.titleAr),
            style: context.homeType.articleTitle.copyWith(
              fontSize: 21,
              height: 1.45,
            ),
          ),
        ),
        if (a.publishedAt != null || a.reviewer != null) ...[
          const SizedBox(height: AppSpacing.md),
          if (a.publishedAt != null)
            metaLine(
              Icons.calendar_today_outlined,
              reviewDateLabel(a.publishedAt!, locale),
            ),
          if (a.publishedAt != null && a.reviewer != null)
            const SizedBox(height: 6),
          if (a.reviewer != null)
            metaLine(
              Icons.health_and_safety_outlined,
              l.articleReviewedBy(a.reviewer!.name),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, color: p.border),
        const SizedBox(height: AppSpacing.lg),
        if (blocks.isEmpty && a.excerpt.trim().isNotEmpty)
          _Block(ArticleBlock(ArticleBlockKind.paragraph, a.excerpt.trim()))
        else if (blocks.isEmpty)
          Text(l.articleNoContent, style: meta)
        else
          for (final b in blocks) _Block(b),
      ],
    );
  }
}

/// The cover at the page's width, or nothing if it fails to load.
class _Cover extends StatelessWidget {
  const _Cover({required this.url, this.radius = homeCardRadius});

  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, c) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: c.maxWidth,
          fit: BoxFit.cover,
          // Decoded at the size it is shown, not the upload's full size.
          cacheWidth: (c.maxWidth * MediaQuery.devicePixelRatioOf(context))
              .round(),
          // Until it arrives, a box in the cover's usual shape.
          frameBuilder: (context, child, frame, sync) => frame == null && !sync
              ? AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(color: p.pageSoft),
                )
              : child,
          // A missing or broken cover leaves no gap and no broken-image glyph.
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// One block of the body, in its own reading direction.
class _Block extends StatelessWidget {
  const _Block(this.block);

  final ArticleBlock block;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final b = block;
    final dir = _directionOf(b.text);
    final body = context.homeType.articleBody.copyWith(
      fontSize: 15,
      height: 1.85,
      color: p.body,
    );

    final Widget child = switch (b.kind) {
      ArticleBlockKind.image => _Cover(url: b.text, radius: AppRadii.input),
      ArticleBlockKind.heading => Text(
        b.text,
        textDirection: dir,
        style: context.homeType.sectionTitle.copyWith(height: 1.5),
      ),
      ArticleBlockKind.paragraph => Text(
        b.text,
        textDirection: dir,
        style: body,
      ),
      ArticleBlockKind.quote => Directionality(
        textDirection: dir,
        child: Container(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.md),
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: p.primary, width: 3),
            ),
          ),
          child: Text(b.text, style: body.copyWith(color: p.muted)),
        ),
      ),
      ArticleBlockKind.bullet || ArticleBlockKind.numbered => Directionality(
        textDirection: dir,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                b.kind == ArticleBlockKind.numbered ? '${b.number}.' : '•',
                style: body.copyWith(color: p.primary),
              ),
            ),
            Expanded(child: Text(b.text, style: body)),
          ],
        ),
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

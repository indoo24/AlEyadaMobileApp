import '../../core/api/envelope.dart';

/// An article as the feed returns it — never the body.
class ArticleListItem {
  const ArticleListItem({
    required this.id,
    required this.slug,
    required this.titleAr,
    required this.excerpt,
    required this.isCertified,
    this.categoryName,
    this.featuredImage,
  });

  final String id;
  final String slug;
  final String titleAr;
  final String excerpt;
  final bool isCertified;
  final String? categoryName;
  final String? featuredImage;

  factory ArticleListItem.fromJson(Map<String, dynamic> j) {
    final category = j['category'];
    return ArticleListItem(
      id: parseString(j['id']),
      slug: parseString(j['slug']),
      titleAr: parseString(j['title_ar']),
      excerpt: parseString(j['excerpt']),
      isCertified: j['is_certified'] == true,
      categoryName: category is Map ? parseString(category['name_ar']) : null,
      featuredImage: j['featured_image'] as String?,
    );
  }
}

/// The doctor who reviewed an article — the byline that makes a medical
/// article worth trusting.
class ArticleReviewer {
  const ArticleReviewer({required this.fullNameAr, required this.displayTitle});

  final String fullNameAr;

  /// The honorific shown before the name, e.g. "د.".
  final String displayTitle;

  String get name => '$displayTitle $fullNameAr'.trim();

  static ArticleReviewer? maybe(Object? j) {
    if (j is! Map) return null;
    final reviewer = ArticleReviewer(
      fullNameAr: parseString(j['full_name_ar']),
      displayTitle: parseString(j['display_title']),
    );
    return reviewer.fullNameAr.isEmpty ? null : reviewer;
  }
}

/// One article, body included, as `/articles/{slug}/` returns it.
class ArticleDetail {
  const ArticleDetail({
    required this.slug,
    required this.titleAr,
    required this.excerpt,
    required this.contentHtml,
    required this.isCertified,
    this.categoryName,
    this.featuredImage,
    this.publishedAt,
    this.reviewer,
  });

  final String slug;
  final String titleAr;
  final String excerpt;

  /// Rich HTML, sanitised by the backend on save.
  final String contentHtml;
  final bool isCertified;
  final String? categoryName;
  final String? featuredImage;
  final DateTime? publishedAt;
  final ArticleReviewer? reviewer;

  factory ArticleDetail.fromJson(Map<String, dynamic> j) {
    final category = j['category'];
    return ArticleDetail(
      slug: parseString(j['slug']),
      titleAr: parseString(j['title_ar']),
      excerpt: parseString(j['excerpt']),
      contentHtml: parseString(j['content']),
      isCertified: j['is_certified'] == true,
      categoryName: category is Map ? parseString(category['name_ar']) : null,
      featuredImage: j['featured_image'] as String?,
      publishedAt: parseUtc(j['published_at']),
      reviewer: ArticleReviewer.maybe(j['reviewed_by_doctor']),
    );
  }
}

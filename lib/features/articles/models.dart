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

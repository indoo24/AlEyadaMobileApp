/// Decoders for the backend's single response shape.
///
/// Every endpoint answers `{data, meta, errors}` — the website's API layer has
/// exactly one place that unwraps it, and so does this app. Keeping that in one
/// file is what stops `json['data']['data']` appearing somewhere at 2am.
library;

/// Paging information, as `meta.pagination`.
class Pagination {
  const Pagination({
    required this.count,
    required this.page,
    required this.pages,
    required this.pageSize,
    this.next,
    this.previous,
  });

  final int count;
  final int page;
  final int pages;
  final int pageSize;
  final String? next;
  final String? previous;

  bool get hasMore => page < pages;

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    count: (json['count'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    pages: (json['pages'] as num?)?.toInt() ?? 1,
    pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
    next: json['next'] as String?,
    previous: json['previous'] as String?,
  );

  static const empty = Pagination(count: 0, page: 1, pages: 1, pageSize: 20);
}

/// A page of results plus the paging metadata that came with it.
class Paginated<T> {
  const Paginated({required this.items, required this.pagination});

  final List<T> items;
  final Pagination pagination;

  bool get isEmpty => items.isEmpty;
  bool get hasMore => pagination.hasMore;

  Paginated<T> append(Paginated<T> next) =>
      Paginated(items: [...items, ...next.items], pagination: next.pagination);

  static Paginated<T> emptyOf<T>() => Paginated<T>(items: const [], pagination: Pagination.empty);
}

/// Unwrap `data` from an envelope.
///
/// Tolerates a bare (un-enveloped) body so a proxy error page or a
/// non-conforming endpoint degrades to "unexpected shape" rather than a crash.
Map<String, dynamic> unwrapObject(dynamic body) {
  final data = _dataOf(body);
  if (data is Map) return Map<String, dynamic>.from(data);
  throw const FormatException('Expected a JSON object in `data`.');
}

/// Unwrap `data` when it may legitimately be absent (204, or an action that
/// answers with nothing useful).
Map<String, dynamic>? unwrapObjectOrNull(dynamic body) {
  final data = _dataOf(body);
  if (data == null) return null;
  if (data is Map) return Map<String, dynamic>.from(data);
  return null;
}

List<Map<String, dynamic>> unwrapList(dynamic body) {
  final data = _dataOf(body);
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  throw const FormatException('Expected a JSON array in `data`.');
}

/// Unwrap a paginated list, reading `meta.pagination`.
Paginated<T> unwrapPaginated<T>(dynamic body, T Function(Map<String, dynamic>) parse) {
  final items = unwrapList(body).map(parse).toList();
  final meta = (body is Map ? body['meta'] : null);
  final pag = (meta is Map ? meta['pagination'] : null);
  return Paginated<T>(
    items: items,
    pagination: pag is Map
        ? Pagination.fromJson(Map<String, dynamic>.from(pag))
        // An un-paginated list endpoint still gives a usable shape: one page.
        : Pagination(count: items.length, page: 1, pages: 1, pageSize: items.length),
  );
}

dynamic _dataOf(dynamic body) {
  if (body is Map && body.containsKey('data')) return body['data'];
  // Not an envelope. Hand it back so the caller's parser decides.
  return body;
}

// --- small parsing helpers, used by the DTOs -------------------------------

/// Parse a backend timestamp. Times arrive as UTC ISO-8601; everything in this
/// app compares them in UTC and only converts for display.
DateTime? parseUtc(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v)?.toUtc();
}

/// Money arrives as a decimal *string* ("300.00"), never a double — the backend
/// uses DecimalField and this app must not round-trip it through binary floating
/// point. Kept as a string for display; parsed only when arithmetic is needed.
String? parseMoney(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

int? parseInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

String parseString(dynamic v) => v?.toString() ?? '';

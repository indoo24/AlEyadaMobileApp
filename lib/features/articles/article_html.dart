/// An article body is rich HTML, sanitised by the backend on save. The app has
/// no HTML renderer, so the body is read into the blocks a reader needs —
/// headings, paragraphs, list items, quotes and images — and shown with the
/// app's own text styles. Inline formatting (bold, links) is read as plain
/// text: the words survive, the emphasis does not.
library;

enum ArticleBlockKind { heading, paragraph, bullet, numbered, quote, image }

class ArticleBlock {
  const ArticleBlock(this.kind, this.text, {this.number});

  final ArticleBlockKind kind;

  /// The block's text; for an image, its URL.
  final String text;

  /// A numbered item's number.
  final int? number;

  @override
  bool operator ==(Object other) =>
      other is ArticleBlock &&
      other.kind == kind &&
      other.text == text &&
      other.number == number;

  @override
  int get hashCode => Object.hash(kind, text, number);

  @override
  String toString() =>
      'ArticleBlock($kind, "$text"${number == null ? '' : ', $number'})';
}

final _hidden = RegExp(
  r'<!--.*?-->|<(script|style)\b[^>]*>.*?</\1\s*>',
  caseSensitive: false,
  dotAll: true,
);
final _tag = RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)\b([^>]*)>');
final _src = RegExp(
  r'''\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
  caseSensitive: false,
);

/// Tags that start and end a block of their own.
const _blockTags = {
  'p', 'div', 'section', 'article', 'header', 'footer', 'figure', //
  'figcaption', 'table', 'tr', 'pre', 'hr',
};

/// The body's blocks, in order. Empty blocks are dropped.
List<ArticleBlock> articleBlocks(String html) {
  final source = html.replaceAll(_hidden, '');
  final blocks = <ArticleBlock>[];

  // Not HTML at all: blank lines separate paragraphs.
  if (!_tag.hasMatch(source)) {
    for (final p in source.split(RegExp(r'\n\s*\n'))) {
      final text = _clean(p, keepNewlines: true);
      if (text.isNotEmpty) {
        blocks.add(ArticleBlock(ArticleBlockKind.paragraph, text));
      }
    }
    return blocks;
  }

  final buffer = StringBuffer();
  var heading = false;
  var quoteDepth = 0;
  final lists = <({bool ordered, int count})>[];
  // The list item being read, until its first block is out; later blocks in the
  // same item are plain paragraphs, not another bullet.
  ({ArticleBlockKind kind, int? number})? item;

  void flush() {
    final text = _clean(buffer.toString());
    buffer.clear();
    if (text.isEmpty) return;
    if (heading) {
      blocks.add(ArticleBlock(ArticleBlockKind.heading, text));
    } else if (item != null) {
      blocks.add(ArticleBlock(item!.kind, text, number: item!.number));
      item = null;
    } else if (quoteDepth > 0) {
      blocks.add(ArticleBlock(ArticleBlockKind.quote, text));
    } else {
      blocks.add(ArticleBlock(ArticleBlockKind.paragraph, text));
    }
  }

  var at = 0;
  for (final m in _tag.allMatches(source)) {
    buffer.write(source.substring(at, m.start));
    at = m.end;
    final closing = m[1] == '/';
    final name = m[2]!.toLowerCase();

    if (name == 'br') {
      buffer.write(_lineBreak);
    } else if (RegExp(r'^h[1-6]$').hasMatch(name)) {
      flush();
      heading = !closing;
    } else if (name == 'ul' || name == 'ol') {
      flush();
      if (closing) {
        if (lists.isNotEmpty) lists.removeLast();
      } else {
        lists.add((ordered: name == 'ol', count: 0));
      }
    } else if (name == 'li') {
      flush();
      item = null;
      if (!closing) {
        final list = lists.isEmpty ? null : lists.removeLast();
        if (list != null && list.ordered) {
          lists.add((ordered: true, count: list.count + 1));
          item = (kind: ArticleBlockKind.numbered, number: list.count + 1);
        } else {
          if (list != null) lists.add(list);
          item = (kind: ArticleBlockKind.bullet, number: null);
        }
      }
    } else if (name == 'blockquote') {
      flush();
      quoteDepth = closing
          ? (quoteDepth > 0 ? quoteDepth - 1 : 0)
          : quoteDepth + 1;
    } else if (name == 'img') {
      flush();
      final src = _src.firstMatch(m[3] ?? '');
      final url = _decode((src?[1] ?? src?[2] ?? src?[3] ?? '').trim());
      final uri = Uri.tryParse(url);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        blocks.add(ArticleBlock(ArticleBlockKind.image, url));
      }
    } else if (name == 'td' || name == 'th') {
      buffer.write(' ');
    } else if (_blockTags.contains(name)) {
      flush();
    }
    // Anything else (strong, em, a, span…) is inline: its text carries on.
  }
  buffer.write(source.substring(at));
  flush();
  return blocks;
}

/// Where a `<br>` was. Source newlines are only whitespace in HTML, so the
/// break is held apart from them until whitespace has been collapsed.
const _lineBreak = ' ';

/// Entities decoded, whitespace collapsed as a browser would, `<br>` lines
/// kept.
String _clean(String raw, {bool keepNewlines = false}) {
  final text = (keepNewlines ? raw : raw.replaceAll(RegExp(r'[\r\n\t]'), ' '))
      .replaceAll(_lineBreak, '\n');
  return _decode(text)
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t\r ]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

const _named = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'laquo': '«',
  'raquo': '»',
  'hellip': '…',
  'ndash': '–',
  'mdash': '—',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
};

String _decode(
  String s,
) => s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'), (m) {
  final e = m[1]!;
  if (e.startsWith('#')) {
    final hex = e.startsWith('#x') || e.startsWith('#X');
    final code = int.tryParse(e.substring(hex ? 2 : 1), radix: hex ? 16 : 10);
    return code == null || code > 0x10FFFF ? m[0]! : String.fromCharCode(code);
  }
  return _named[e.toLowerCase()] ?? m[0]!;
});

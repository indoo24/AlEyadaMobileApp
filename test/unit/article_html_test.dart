import 'package:aleyada_mobile/features/articles/article_html.dart';
import 'package:flutter_test/flutter_test.dart';

ArticleBlock p(String text) => ArticleBlock(ArticleBlockKind.paragraph, text);
ArticleBlock h(String text) => ArticleBlock(ArticleBlockKind.heading, text);
ArticleBlock bullet(String text) => ArticleBlock(ArticleBlockKind.bullet, text);
ArticleBlock n(int number, String text) =>
    ArticleBlock(ArticleBlockKind.numbered, text, number: number);

void main() {
  test('paragraphs and headings, in order, with inline tags read as text', () {
    expect(
      articleBlocks(
        '<h2>الأعراض</h2><p>يشعر <strong>المريض</strong> بـ<a href="x">العطش</a>.</p>'
        '<p>فقرة ثانية</p>',
      ),
      [h('الأعراض'), p('يشعر المريض بـالعطش.'), p('فقرة ثانية')],
    );
  });

  test('whitespace collapses as a browser would; <br> keeps its line', () {
    expect(articleBlocks('<p>  سطر\n   أول<br>سطر   ثانٍ </p>'), [
      p('سطر أول\nسطر ثانٍ'),
    ]);
  });

  test('bulleted and numbered lists, numbering per list', () {
    expect(
      articleBlocks(
        '<ul><li>ماء</li><li>رياضة</li></ul>'
        '<ol><li>أول</li><li>ثانٍ</li></ol><ol><li>من جديد</li></ol>',
      ),
      [
        bullet('ماء'),
        bullet('رياضة'),
        n(1, 'أول'),
        n(2, 'ثانٍ'),
        n(1, 'من جديد'),
      ],
    );
  });

  test('a list item with paragraphs inside is one item, then paragraphs', () {
    expect(articleBlocks('<ul><li><p>البند</p><p>شرح</p></li></ul>'), [
      bullet('البند'),
      p('شرح'),
    ]);
  });

  test('quotes and images', () {
    expect(
      articleBlocks(
        '<blockquote><p>اقتباس</p></blockquote>'
        '<img alt="" src="https://cdn.example.test/a.jpg?w=1&amp;h=2">'
        "<img src='javascript:alert(1)'><img src=\"/relative.png\">",
      ),
      [
        ArticleBlock(ArticleBlockKind.quote, 'اقتباس'),
        ArticleBlock(
          ArticleBlockKind.image,
          'https://cdn.example.test/a.jpg?w=1&h=2',
        ),
      ],
    );
  });

  test('entities are decoded; scripts, styles and comments are dropped', () {
    expect(
      articleBlocks(
        '<p>&laquo;صحة&raquo; &amp; &#1593;&#x0627;&#1605; &nbsp;&lt;3&gt;</p>'
        '<script>alert(1)</script><style>p{}</style><!-- note -->'
        '<p>&unknown; يبقى</p>',
      ),
      [p('«صحة» & عام <3>'), p('&unknown; يبقى')],
    );
  });

  test('a body that is not HTML: blank lines separate paragraphs', () {
    expect(articleBlocks('فقرة أولى\nتكملة\n\nفقرة ثانية'), [
      p('فقرة أولى\nتكملة'),
      p('فقرة ثانية'),
    ]);
  });

  test('nothing to read: no blocks', () {
    expect(articleBlocks(''), isEmpty);
    expect(articleBlocks('<p> </p><div><br></div>'), isEmpty);
  });
}

import 'dart:async';

import 'package:aleyada_mobile/core/api/envelope.dart';
import 'package:aleyada_mobile/core/paging/paged_list.dart';
import 'package:aleyada_mobile/features/articles/models.dart';
import 'package:flutter_test/flutter_test.dart';

Paginated<String> page(List<String> items, int number, int pages) => Paginated(
  items: items,
  pagination: Pagination(
    count: 99,
    page: number,
    pages: pages,
    pageSize: items.length,
  ),
);

void main() {
  group('PagedListController', () {
    test('loads page 1, appends page 2, and knows when it is done', () async {
      final asked = <int>[];
      final c = PagedListController<String>((n) async {
        asked.add(n);
        return n == 1 ? page(['a', 'b'], 1, 2) : page(['c'], 2, 2);
      }, idOf: (s) => s);
      expect(c.state.loading, isTrue);
      await pumpEventQueue();
      expect(c.state.items, ['a', 'b']);
      expect(c.state.hasMore, isTrue);

      await c.loadMore();
      expect(c.state.items, ['a', 'b', 'c']);
      expect(c.state.hasMore, isFalse);
      await c.loadMore(); // nothing more to ask for
      expect(asked, [1, 2]);
    });

    test(
      'an item that shifted onto the next page is not shown twice',
      () async {
        final c = PagedListController<String>(
          (n) async => n == 1 ? page(['a', 'b'], 1, 2) : page(['b', 'c'], 2, 2),
          idOf: (s) => s,
        );
        await pumpEventQueue();
        await c.loadMore();
        expect(c.state.items, ['a', 'b', 'c']);
      },
    );

    test('a failed first page is an error; retry recovers', () async {
      var fail = true;
      final c = PagedListController<String>((n) async {
        if (fail) throw StateError('offline');
        return page(['a'], 1, 1);
      }, idOf: (s) => s);
      await pumpEventQueue();
      expect(c.state.error, isA<StateError>());
      expect(c.state.items, isEmpty);

      fail = false;
      expect(await c.reload(), isTrue);
      expect(c.state.error, isNull);
      expect(c.state.items, ['a']);
    });

    test(
      'a failed next page keeps what is shown, and can be retried',
      () async {
        var fail = true;
        final c = PagedListController<String>((n) async {
          if (n == 2 && fail) throw StateError('offline');
          return n == 1 ? page(['a'], 1, 2) : page(['b'], 2, 2);
        }, idOf: (s) => s);
        await pumpEventQueue();
        await c.loadMore();
        expect(c.state.items, ['a']);
        expect(c.state.moreError, isA<StateError>());
        expect(c.state.hasMore, isTrue);

        fail = false;
        await c.loadMore();
        expect(c.state.items, ['a', 'b']);
        expect(c.state.moreError, isNull);
      },
    );

    test('a failed refresh keeps the list on screen', () async {
      var fail = false;
      final c = PagedListController<String>((n) async {
        if (fail) throw StateError('offline');
        return page(['a'], 1, 1);
      }, idOf: (s) => s);
      await pumpEventQueue();
      fail = true;
      expect(await c.reload(), isFalse);
      expect(c.state.items, ['a']);
      expect(c.state.error, isNull);
    });

    test('a page that lands after a refresh is dropped', () async {
      final slow = Completer<Paginated<String>>();
      var calls = 0;
      final c = PagedListController<String>((n) {
        calls++;
        if (calls == 1) return Future.value(page(['a'], 1, 2));
        if (n == 2) return slow.future;
        return Future.value(page(['fresh'], 1, 1));
      }, idOf: (s) => s);
      await pumpEventQueue();
      final more = c.loadMore();
      await c.reload();
      slow.complete(page(['stale'], 2, 2));
      await more;
      expect(c.state.items, ['fresh']);
    });
  });

  test('ArticleDetail reads the body, date and reviewer', () {
    final a = ArticleDetail.fromJson({
      'id': '1',
      'slug': 'diabetes',
      'title_ar': 'السكري',
      'excerpt': 'ملخص',
      'content': '<p>نص</p>',
      'featured_image': null,
      'category': {'name_ar': 'باطنة'},
      'reviewed_by_doctor': {'full_name_ar': 'سارة علي', 'display_title': 'د.'},
      'is_certified': true,
      'published_at': '2026-03-14T09:00:00Z',
    });
    expect(a.contentHtml, '<p>نص</p>');
    expect(a.categoryName, 'باطنة');
    expect(a.reviewer?.name, 'د. سارة علي');
    expect(a.publishedAt, DateTime.utc(2026, 3, 14, 9));
    expect(a.isCertified, isTrue);

    final bare = ArticleDetail.fromJson({
      'slug': 'x',
      'title_ar': 'ع',
      'reviewed_by_doctor': null,
      'published_at': null,
    });
    expect(bare.reviewer, isNull);
    expect(bare.publishedAt, isNull);
    expect(bare.contentHtml, '');
  });
}

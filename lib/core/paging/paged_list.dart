import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/envelope.dart';

/// One page of a list, by its 1-based number.
typedef PageFetcher<T> = Future<Paginated<T>> Function(int page);

/// A list read a page at a time: the pages so far, and what is in flight.
class PagedListState<T> {
  const PagedListState({
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loading = false,
    this.error,
    this.loadingMore = false,
    this.moreError,
  });

  final List<T> items;

  /// The last page loaded; 0 before the first.
  final int page;
  final bool hasMore;

  /// The first page is loading, with nothing to show yet.
  final bool loading;

  /// The first page failed, with nothing to show.
  final Object? error;

  final bool loadingMore;

  /// The next page failed; the pages already loaded stay.
  final Object? moreError;
}

/// Loads a list's first page and appends the next on request.
///
/// A refresh keeps the current list on screen until the new one arrives, and
/// keeps it if the refresh fails. Items already shown are not repeated when a
/// later page overlaps an earlier one (an item published in between shifts
/// every page by one).
class PagedListController<T> extends StateNotifier<PagedListState<T>> {
  PagedListController(this._fetch, {required this.idOf})
    : super(PagedListState<T>(loading: true)) {
    reload();
  }

  final PageFetcher<T> _fetch;

  /// What makes two items the same item.
  final Object Function(T item) idOf;

  /// Bumped by each reload so an older answer is dropped.
  int _generation = 0;

  /// Reload the first page. Returns whether it succeeded.
  Future<bool> reload() async {
    final gen = ++_generation;
    if (state.items.isEmpty) state = PagedListState<T>(loading: true);
    try {
      final page = await _fetch(1);
      if (!mounted || gen != _generation) return true;
      state = PagedListState<T>(
        items: page.items,
        page: 1,
        hasMore: page.hasMore,
      );
      return true;
    } catch (e) {
      if (!mounted || gen != _generation) return true;
      if (state.items.isEmpty) state = PagedListState<T>(error: e);
      return false;
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s.loading || s.loadingMore || !s.hasMore) return;
    final gen = _generation;
    state = PagedListState<T>(
      items: s.items,
      page: s.page,
      hasMore: s.hasMore,
      loadingMore: true,
    );
    try {
      final next = await _fetch(s.page + 1);
      if (!mounted || gen != _generation) return;
      final seen = {for (final item in s.items) idOf(item)};
      state = PagedListState<T>(
        items: [...s.items, ...next.items.where((i) => seen.add(idOf(i)))],
        page: s.page + 1,
        hasMore: next.hasMore,
      );
    } catch (e) {
      if (!mounted || gen != _generation) return;
      state = PagedListState<T>(
        items: s.items,
        page: s.page,
        hasMore: s.hasMore,
        moreError: e,
      );
    }
  }
}

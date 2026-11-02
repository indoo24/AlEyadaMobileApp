import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../paging/paged_list.dart';
import '../theme/tokens.dart';
import 'async_value_view.dart';

/// A full-screen list read a page at a time: loading, error with retry, empty,
/// and the list itself, which pulls to refresh and fetches the next page as the
/// reader nears its end (or on a tap, if the first page does not fill it).
class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.state,
    required this.onReload,
    required this.onLoadMore,
    required this.itemBuilder,
    required this.empty,
    this.loading,
  });

  final PagedListState<T> state;
  final Future<bool> Function() onReload;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget empty;

  /// Shown while the first page loads; a spinner by default.
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final s = state;
    if (s.loading) return loading ?? const AppLoading();
    if (s.error != null) {
      return AppErrorView(error: s.error!, onRetry: onReload);
    }

    // Under the system navigation bar, the last item still scrolls clear.
    final bottom = MediaQuery.paddingOf(context).bottom;
    final Widget body;
    if (s.items.isEmpty) {
      body = LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - bottom),
            child: empty,
          ),
        ),
      );
    } else {
      final footer = s.loadingMore
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : s.moreError != null || s.hasMore
          ? Center(
              child: TextButton(
                onPressed: onLoadMore,
                child: Text(
                  s.moreError != null ? l.actionRetry : l.actionLoadMore,
                ),
              ),
            )
          : null;
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400 && s.hasMore && s.moreError == null) {
            onLoadMore();
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xl + bottom,
          ),
          itemCount: s.items.length + (footer == null ? 0 : 1),
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) =>
              i < s.items.length ? itemBuilder(context, s.items[i]) : footer!,
        ),
      );
    }
    return RefreshIndicator(onRefresh: onReload, child: body);
  }
}

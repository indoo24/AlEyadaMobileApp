import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../l10n/app_localizations.dart';
import 'providers.dart';
import 'repository.dart';
import 'widgets/doctor_card_tile.dart';
import 'widgets/filter_sheet.dart';

/// Doctor discovery.
///
/// Search and every filter are query parameters on the backend's list endpoint.
/// Nothing is filtered client-side: a page is 20 rows out of a larger set, so
/// hiding rows locally would quietly drop matches that were on page two.
class DoctorsScreen extends ConsumerStatefulWidget {
  const DoctorsScreen({super.key});

  @override
  ConsumerState<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends ConsumerState<DoctorsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(doctorQueryProvider).search ?? '';
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      ref.read(doctorListProvider.notifier).loadMore();
    }
  }

  void _applySearch(String value) {
    final q = ref.read(doctorQueryProvider);
    ref.read(doctorQueryProvider.notifier).state = q.copyWith(search: value, page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final list = ref.watch(doctorListProvider);
    final query = ref.watch(doctorQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.doctorsTitle),
        actions: [
          IconButton(
            tooltip: l.actionFilter,
            onPressed: () => showDoctorFilterSheet(context),
            icon: Badge(
              isLabelVisible: query.hasFilters,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _applySearch,
              decoration: InputDecoration(
                hintText: l.doctorsSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: l.actionClearFilters,
                        onPressed: () {
                          _search.clear();
                          _applySearch('');
                        },
                      ),
              ),
            ),
          ),
          if (query.hasFilters)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _search.clear();
                      ref.read(doctorQueryProvider.notifier).state = const DoctorQuery();
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l.actionClearFilters),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(doctorListProvider.notifier).refresh(),
              child: AsyncValueView(
                value: list,
                loading: const SkeletonList(),
                onRetry: () => ref.read(doctorListProvider.notifier).refresh(),
                isEmpty: (page) => page.isEmpty,
                empty: AppEmptyView(
                  icon: Icons.search_off_rounded,
                  title: l.doctorsEmpty,
                  action: query.hasFilters
                      ? OutlinedButton(
                          onPressed: () {
                            _search.clear();
                            ref.read(doctorQueryProvider.notifier).state = const DoctorQuery();
                          },
                          child: Text(l.actionClearFilters),
                        )
                      : null,
                ),
                data: (page) => ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.xl,
                  ),
                  itemCount: page.items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    if (i == page.items.length) {
                      if (!page.hasMore) {
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.lg),
                          child: Center(
                            child: Text(
                              l.doctorsResultCount(page.pagination.count),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
                      );
                    }
                    final doctor = page.items[i];
                    return DoctorCardTile(
                      doctor: doctor,
                      onTap: () => context.push(Routes.doctorPath(doctor.slug)),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

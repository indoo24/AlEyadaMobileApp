import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/debouncer.dart';
import '../../core/widgets/async_value_view.dart';
import '../../l10n/app_localizations.dart';
import '../clinics/models.dart';
import '../home/home_style.dart';
import 'providers.dart';
import 'repository.dart';
import 'search_state.dart';
import 'widgets/doctor_result_card.dart';
import 'widgets/search_filter_row.dart';
import 'widgets/search_panels.dart';

/// How long typing must pause before the search runs.
const kSearchDebounce = Duration(milliseconds: 400);

/// Doctor discovery.
///
/// Typing searches by itself: each keystroke restarts a short timer, and only
/// when it expires does the text become the query. The list controller then makes
/// sure only the *latest* query's answer is ever shown (see
/// [DoctorListController]). Filters and sort are query parameters on the backend's
/// list endpoint; nothing is filtered client-side, because a page is 20 rows out
/// of a larger set and hiding rows locally would quietly drop matches on page two.
class DoctorsScreen extends ConsumerStatefulWidget {
  const DoctorsScreen({super.key, this.autofocus = false});

  /// Put the cursor in the search box on arrival — set when the person came from
  /// tapping the search field on Home.
  final bool autofocus;

  @override
  ConsumerState<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends ConsumerState<DoctorsScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _debounce = Debouncer(kSearchDebounce);

  /// The typed text once it has settled; keys the clinic-name suggestions so
  /// they, too, cost one request per pause rather than one per keystroke.
  String _settledText = '';

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(doctorQueryProvider).search ?? '';
    _settledText = _search.text.trim();
    _focus.addListener(_onFocusChange);
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce.cancel();
    _search.dispose();
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _scroll
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent * 0.8) {
      ref.read(doctorListProvider.notifier).loadMore();
    }
  }

  DoctorQuery get _query => ref.read(doctorQueryProvider);

  /// Make the typed text the query (a no-op if it changes nothing, or is too
  /// short to mean anything yet).
  void _commit(String text) {
    final next = _query.withSearchText(text);
    if (next != _query) ref.read(doctorQueryProvider.notifier).state = next;
  }

  void _onChanged(String text) {
    setState(() {});
    _debounce(() {
      if (!mounted) return;
      _commit(text);
      setState(() => _settledText = text.trim());
    });
  }

  /// The keyboard's search key: run it now rather than waiting for the pause.
  void _onSubmitted(String text) {
    _debounce.cancel();
    _commit(text);
    _settledText = text.trim();
    ref.read(recentSearchesProvider.notifier).add(text);
    _focus.unfocus();
  }

  void _clearText() {
    _debounce.cancel();
    _search.clear();
    _settledText = '';
    _commit('');
    setState(() {});
  }

  void _useRecent(String text) {
    _search.text = text;
    _onSubmitted(text);
  }

  void _applySuggestion(SearchSuggestion s) {
    _debounce.cancel();
    _search.clear();
    _settledText = '';
    ref.read(doctorQueryProvider.notifier).state = s.apply(_query);
    _focus.unfocus();
  }

  void _open(String slug) {
    final text = _query.search;
    if (text != null) ref.read(recentSearchesProvider.notifier).add(text);
    context.push(Routes.doctorPath(slug));
  }

  @override
  Widget build(BuildContext context) {
    // Someone else changed the search text (clearing filters from an empty state,
    // a recent search): mirror it into the box. Typing never trips this, because
    // the text it commits is the text already in the box.
    ref.listen<DoctorQuery>(doctorQueryProvider, (prev, next) {
      if (prev?.search == next.search) return;
      if ((next.search ?? '') != _search.text.trim() && _query.search == next.search) {
        _search.text = next.search ?? '';
        _settledText = _search.text.trim();
      }
    });

    final showIdle = _focus.hasFocus && _search.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _Header(
            controller: _search,
            focusNode: _focus,
            autofocus: widget.autofocus,
            onChanged: _onChanged,
            onSubmitted: _onSubmitted,
            onClear: _clearText,
          ),
          Expanded(child: showIdle ? _idle() : _results()),
        ],
      ),
    );
  }

  Widget _idle() {
    final query = _query;
    return SearchIdlePanel(
      recents: ref.watch(recentSearchesProvider),
      specialties: ref.watch(specializationsProvider).valueOrNull ?? const [],
      onPickRecent: _useRecent,
      onRemoveRecent: (t) => ref.read(recentSearchesProvider.notifier).remove(t),
      onClearRecents: () => ref.read(recentSearchesProvider.notifier).clear(),
      onPickSpecialty: (s) {
        ref.read(doctorQueryProvider.notifier).state = query.copyWith(
          specialization: s.slug,
          page: 1,
        );
        _focus.unfocus();
      },
    );
  }

  List<SearchSuggestion> _suggestions() {
    final text = _search.text.trim();
    if (!_focus.hasFocus || text.isEmpty) return const [];
    final List<ClinicListItem> clinics = _settledText.length >= kMinSearchChars
        ? ref.watch(clinicSuggestionsProvider(_settledText)).valueOrNull ?? const []
        : const [];
    return [
      ...localSuggestions(
        text,
        specialties: ref.watch(specializationsProvider).valueOrNull ?? const [],
        cities: ref.watch(citiesProvider).valueOrNull ?? const [],
      ),
      ...clinics.map(clinicSuggestion),
    ];
  }

  Widget _results() {
    final list = ref.watch(doctorListProvider);
    final query = ref.watch(doctorQueryProvider);
    final page = list.valueOrNull;
    // A new query is loading but the old results are still here: keep them, dim
    // them, and show a thin bar, rather than flashing a skeleton per keystroke.
    final reloading = list.isLoading && page != null;
    final suggestions = _suggestions();

    const gutter = AppSpacing.gutter;

    return RefreshIndicator(
      onRefresh: () => ref.read(doctorListProvider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(gutter, HomeSpacing.top, gutter, HomeSpacing.heading),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (suggestions.isNotEmpty) ...[
                    SearchSuggestionList(suggestions: suggestions, onPick: _applySuggestion),
                    const SizedBox(height: HomeSpacing.section),
                  ],
                  SearchResultHeader(
                    count: page?.pagination.count,
                    sort: query.sort,
                    onSort: (s) => ref.read(doctorQueryProvider.notifier).state = query.copyWith(
                      sort: s == DoctorSort.featured ? null : s,
                      page: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (reloading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
            ),
          if (list.hasError && page == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorView(
                error: list.error!,
                onRetry: () => ref.read(doctorListProvider.notifier).refresh(),
              ),
            )
          else if (page == null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
              sliver: SliverList.separated(
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: HomeSpacing.card),
                itemBuilder: (_, __) => const Skeleton(height: 210, radius: homeCardRadius),
              ),
            )
          else if (page.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyResults(
                canClear: query.hasFilters,
                onClear: () {
                  _search.clear();
                  _settledText = '';
                  ref.read(doctorQueryProvider.notifier).state = DoctorQuery(sort: query.sort);
                },
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(gutter, 4, gutter, 0),
              sliver: SliverAnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: reloading ? 0.5 : 1,
                sliver: SliverList.separated(
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: HomeSpacing.card),
                  itemBuilder: (context, i) {
                    final doctor = page.items[i];
                    return DoctorResultCard(doctor: doctor, onOpen: () => _open(doctor.slug));
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: page.hasMore
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2.2))
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The search box and the filter row, on a white surface above the results.
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surface, boxShadow: AppShadows.soft),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: autofocus,
                  textInputAction: TextInputAction.search,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  style: const TextStyle(fontSize: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: l.doctorsSearchHint,
                    hintStyle: HomeType.searchHint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 22, color: AppColors.primary),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l.searchClearField,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: onClear,
                          ),
                    border: _border(AppColors.border),
                    enabledBorder: _border(AppColors.border),
                    focusedBorder: _border(AppColors.primary, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const SearchFilterRow(),
            ],
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.canClear, required this.onClear});

  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.bgSoft, shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.searchEmptyTitle,
              style: HomeType.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.searchEmptyHint,
              style: HomeType.tagline.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (canClear) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: onClear,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(180, 44),
                  textStyle: HomeType.button.copyWith(fontSize: 13.5),
                ),
                child: Text(l.searchClearFilters),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

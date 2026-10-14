import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/envelope.dart';
import '../../core/providers.dart';
import '../bookings/models.dart';
import 'models.dart';
import 'repository.dart';

final directoryRepositoryProvider = Provider<DirectoryRepository>(
  (ref) => DirectoryRepository(ref.watch(apiClientProvider)),
);

/// The specialty tree. Reference data, so it is fetched once and kept.
final specializationsProvider = FutureProvider<List<Specialization>>((ref) async {
  return ref.watch(directoryRepositoryProvider).specializations();
});

/// Cities for **search filters** — the full list.
final citiesProvider = FutureProvider<List<City>>((ref) async {
  return ref.watch(directoryRepositoryProvider).cities();
});

/// Cities where doctor registration is open, straight from the server.
///
/// A separate provider from [citiesProvider] on purpose: these two lists are
/// different by design and merging them would either restrict patient search or
/// let a doctor apply somewhere we do not serve.
final onboardingCitiesProvider = FutureProvider<List<City>>((ref) async {
  return ref.watch(directoryRepositoryProvider).onboardingCities();
});

/// The filters currently applied to the doctor list.
///
/// Back to no filters whenever the signed-in account changes: the next person on
/// the phone does not inherit the previous one's search text, specialty or area.
final doctorQueryProvider = StateProvider<DoctorQuery>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return const DoctorQuery();
});

/// One page of results for a given query.
final doctorPageProvider = FutureProvider.family<Paginated<DoctorCard>, DoctorQuery>((
  ref,
  query,
) async {
  return ref.watch(directoryRepositoryProvider).doctors(query);
});

/// The doctor list as the user scrolls it: accumulated pages for the active
/// query, resetting whenever the query changes.
///
/// Three guarantees the search experience depends on:
///
///  * **The latest query wins.** Every load takes a generation number, and a
///    response is only applied if its generation is still the current one. A slow
///    answer for "احمد" can therefore never overwrite the answer for "احمد جمال",
///    whatever order the network returns them in. The superseded request is also
///    cancelled so it stops costing bandwidth.
///  * **Nothing is reloaded for nothing.** Setting a query equal to the one
///    already shown is ignored, so a repeated tap or an unchanged filter sheet
///    sends no request.
///  * **Results survive a reload.** While a new query loads, the previous page
///    stays in [state] (as a loading value that still has data), so the list can
///    dim instead of blanking to a skeleton on every keystroke that gets through.
class DoctorListController extends StateNotifier<AsyncValue<Paginated<DoctorCard>>> {
  DoctorListController(this._ref) : super(const AsyncValue.loading()) {
    _load();
    // Refetch from page one whenever a filter moves.
    _ref.listen<DoctorQuery>(doctorQueryProvider, (previous, next) {
      if (previous == next) return;
      _load();
    });
  }

  final Ref _ref;
  int _generation = 0;
  CancelToken? _cancel;
  bool _loadingMore = false;

  DoctorQuery get _query => _ref.read(doctorQueryProvider);

  Future<void> _load() async {
    final query = _query.copyWith(page: 1);
    final generation = ++_generation;
    _cancel?.cancel();
    final token = _cancel = CancelToken();
    _loadingMore = false;

    // Keep showing the previous results while this loads.
    state = state.hasValue
        ? const AsyncLoading<Paginated<DoctorCard>>().copyWithPrevious(state)
        : const AsyncValue.loading();

    try {
      final page = await _ref.read(directoryRepositoryProvider).doctors(query, cancelToken: token);
      if (generation != _generation || !mounted) return;
      state = AsyncValue.data(_withoutDuplicates(page));
    } catch (e, st) {
      if (generation != _generation || !mounted) return;
      // The query stays in doctorQueryProvider, so retrying does not lose it.
      state = AsyncValue.error(e, st);
    }
  }

  /// Reload the current query — pull-to-refresh and "retry".
  Future<void> refresh() => _load();

  /// Fetch the next page and append. Guarded so a fast scroll cannot fire
  /// several overlapping requests for the same page, and so a page that
  /// arrives after the query changed is discarded.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || state.isLoading || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    final generation = _generation;
    try {
      final next = await _ref
          .read(directoryRepositoryProvider)
          .doctors(_query.copyWith(page: current.pagination.page + 1), cancelToken: _cancel);
      if (generation != _generation || !mounted) return;
      final seen = current.items.map((d) => d.id).toSet();
      state = AsyncValue.data(
        Paginated(
          items: [...current.items, ...next.items.where((d) => !seen.contains(d.id))],
          pagination: next.pagination,
        ),
      );
    } catch (_) {
      // Keep what is already on screen. A failed "load more" should not empty
      // the list the user is reading.
    } finally {
      if (generation == _generation) _loadingMore = false;
    }
  }

  /// A page can repeat a doctor (a list shifting under the user as it grows);
  /// the first occurrence wins.
  Paginated<DoctorCard> _withoutDuplicates(Paginated<DoctorCard> page) {
    final seen = <String>{};
    return Paginated(
      items: [
        for (final d in page.items)
          if (seen.add(d.id)) d,
      ],
      pagination: page.pagination,
    );
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }
}

final doctorListProvider =
    StateNotifierProvider<DoctorListController, AsyncValue<Paginated<DoctorCard>>>(
      DoctorListController.new,
    );

/// One doctor's public profile.
final doctorDetailProvider = FutureProvider.family<DoctorDetail, String>((ref, slug) async {
  return ref.watch(directoryRepositoryProvider).doctor(slug);
});

/// Which clinic the booking sheet is looking at. Null means "not chosen yet".
final selectedClinicProvider = StateProvider.family<String?, String>((ref, slug) => null);

/// A doctor's availability at one clinic.
///
/// Keyed by clinic, so switching clinics can never show the previous clinic's
/// late answer: the sheet only ever reads the key it is on (latest wins by
/// construction). Auto-disposed, so closing the profile and coming back later
/// asks again rather than offering times that have since been taken.
final availabilityProvider = FutureProvider.autoDispose
    .family<DoctorAvailability, ({String slug, String? clinicId})>((ref, arg) async {
      final token = CancelToken();
      ref.onDispose(token.cancel);
      return ref
          .watch(directoryRepositoryProvider)
          .availability(arg.slug, clinicId: arg.clinicId, cancelToken: token);
    });

/// A doctor's public reviews, loaded a page at a time.
class ReviewsState {
  const ReviewsState({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.moreError,
  });

  final List<PublicReview> items;

  /// The server's `count` — every published review, not only the loaded ones.
  final int total;
  final int page;
  final bool hasMore;

  /// The first page is on its way.
  final bool loading;

  /// A further page is on its way.
  final bool loadingMore;

  /// The first page failed; nothing to show.
  final Object? error;

  /// A further page failed; what is loaded stays on screen.
  final Object? moreError;

  ReviewsState copyWith({
    List<PublicReview>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    Object? error = _keep,
    Object? moreError = _keep,
  }) => ReviewsState(
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: identical(error, _keep) ? this.error : error,
    moreError: identical(moreError, _keep) ? this.moreError : moreError,
  );

  static const _keep = Object();
}

class DoctorReviewsController extends StateNotifier<ReviewsState> {
  DoctorReviewsController(this._repo, this._slug) : super(const ReviewsState(loading: true)) {
    _loadFirst();
  }

  final DirectoryRepository _repo;
  final String _slug;

  /// Bumped by every reload, so an answer to an older request is dropped.
  int _generation = 0;

  Future<void> _loadFirst() async {
    final gen = ++_generation;
    state = const ReviewsState(loading: true);
    try {
      final page = await _repo.doctorReviews(_slug);
      if (!mounted || gen != _generation) return;
      state = ReviewsState(
        items: page.items,
        total: page.pagination.count,
        page: 1,
        hasMore: page.hasMore,
      );
    } catch (e) {
      if (!mounted || gen != _generation) return;
      state = ReviewsState(error: e);
    }
  }

  Future<void> reload() => _loadFirst();

  /// The next page. Ignored while anything is loading or when there is none.
  Future<void> loadMore() async {
    final s = state;
    if (s.loading || s.loadingMore || !s.hasMore) return;
    final gen = _generation;
    state = s.copyWith(loadingMore: true, moreError: null);
    try {
      final page = await _repo.doctorReviews(_slug, page: s.page + 1);
      if (!mounted || gen != _generation) return;
      // A review published meanwhile shifts the pages by one; never list it twice.
      final seen = {for (final r in state.items) r.id};
      state = state.copyWith(
        items: [...state.items, ...page.items.where((r) => seen.add(r.id))],
        total: page.pagination.count,
        page: s.page + 1,
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } catch (e) {
      if (!mounted || gen != _generation) return;
      state = state.copyWith(loadingMore: false, moreError: e);
    }
  }
}

final doctorReviewsProvider = StateNotifierProvider.autoDispose
    .family<DoctorReviewsController, ReviewsState, String>(
      (ref, slug) => DoctorReviewsController(ref.watch(directoryRepositoryProvider), slug),
    );

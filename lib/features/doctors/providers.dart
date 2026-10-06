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
final doctorQueryProvider = StateProvider<DoctorQuery>((ref) => const DoctorQuery());

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
      if (generation != _generation) return;
      state = AsyncValue.data(_withoutDuplicates(page));
    } catch (e, st) {
      if (generation != _generation) return;
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
      if (generation != _generation) return;
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

/// Which clinic the booking screen is looking at. Null means "the doctor's
/// primary", which is what the backend defaults to.
final selectedClinicProvider = StateProvider.family<String?, String>((ref, slug) => null);

/// A doctor's availability at the selected clinic.
final availabilityProvider =
    FutureProvider.family<DoctorAvailability, ({String slug, String? clinicId})>((ref, arg) async {
      return ref.watch(directoryRepositoryProvider).availability(arg.slug, clinicId: arg.clinicId);
    });

final doctorReviewsProvider = FutureProvider.family<Paginated<PublicReview>, String>((
  ref,
  slug,
) async {
  return ref.watch(directoryRepositoryProvider).doctorReviews(slug);
});

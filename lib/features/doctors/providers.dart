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
class DoctorListController extends StateNotifier<AsyncValue<Paginated<DoctorCard>>> {
  DoctorListController(this._ref) : super(const AsyncValue.loading()) {
    _load(reset: true);
    // Refetch from page one whenever a filter moves.
    _ref.listen<DoctorQuery>(doctorQueryProvider, (_, __) => _load(reset: true));
  }

  final Ref _ref;
  bool _loadingMore = false;

  DoctorQuery get _query => _ref.read(doctorQueryProvider);

  Future<void> _load({bool reset = false}) async {
    if (reset) state = const AsyncValue.loading();
    try {
      final page = await _ref.read(directoryRepositoryProvider).doctors(_query.copyWith(page: 1));
      state = AsyncValue.data(page);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load(reset: false);

  /// Fetch the next page and append. Guarded so a fast scroll cannot fire
  /// several overlapping requests for the same page.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await _ref
          .read(directoryRepositoryProvider)
          .doctors(_query.copyWith(page: current.pagination.page + 1));
      state = AsyncValue.data(current.append(next));
    } catch (_) {
      // Keep what is already on screen. A failed "load more" should not empty
      // the list the user is reading.
    } finally {
      _loadingMore = false;
    }
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/envelope.dart';
import '../../core/config/env.dart';
import '../../core/providers.dart';
import 'models.dart';
import 'repository.dart';

final managementRepositoryProvider = Provider<ManagementRepository>(
  (ref) => ManagementRepository(ref.watch(apiClientProvider)),
);

/// The web management system's address, or null when this build has none.
///
/// Only an absolute http(s) URL counts; anything else is treated as "not
/// configured" so a typo in the build configuration hides the button instead of
/// handing the user a link that cannot open. See [Env.managementUrl] for why this
/// is configuration rather than an API field.
final managementUrlProvider = Provider<Uri?>((ref) => parseManagementUrl(Env.managementUrl));

/// An absolute http(s) address, or null for anything else (including empty).
Uri? parseManagementUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  return uri;
}

/// The id of whoever is signed in. Every provider below watches it, so a different
/// account — or signing out — rebuilds them from scratch and one doctor's data is
/// never shown to the next.
final _accountId = Provider<String?>((ref) => ref.watch(authControllerProvider.select((s) => s.user?.id)));

// The lists are auto-disposed: they are dropped when their screen is left, so
// coming back reads the server again instead of showing whatever was true the
// last time (assistants and clinics can change from the web dashboard too).

/// The doctor's clinics.
final myClinicsProvider = FutureProvider.autoDispose<List<MyClinic>>((ref) async {
  ref.watch(_accountId);
  return ref.watch(managementRepositoryProvider).clinics();
});

final assistantsProvider = FutureProvider.autoDispose<List<AssistantProfile>>((ref) async {
  ref.watch(_accountId);
  return ref.watch(managementRepositoryProvider).assistants();
});

final availabilityWindowsProvider = FutureProvider.autoDispose<List<AvailabilityWindow>>((ref) async {
  ref.watch(_accountId);
  return ref.watch(managementRepositoryProvider).availabilityWindows();
});

/// Invitations a doctor sent for one clinic.
final sentInvitationsProvider = FutureProvider.autoDispose.family<List<SentInvitation>, String>((
  ref,
  id,
) {
  ref.watch(_accountId);
  return ref.watch(managementRepositoryProvider).sentInvitations(id);
});

// ---------------------------------------------------------------------------
// Appointments
// ---------------------------------------------------------------------------

/// What the schedule is filtered by. Plain values so equal filters compare equal.
class ScheduleFilter {
  const ScheduleFilter({this.upcoming = true, this.date, this.status});

  /// Today onward — the doctor's working list. False means every appointment.
  final bool upcoming;

  /// One day, `YYYY-MM-DD`.
  final String? date;

  /// A backend booking status (`pending`, `confirmed`, …).
  final String? status;

  ScheduleFilter copyWith({
    bool? upcoming,
    Object? date = _unset,
    Object? status = _unset,
  }) => ScheduleFilter(
    upcoming: upcoming ?? this.upcoming,
    date: date == _unset ? this.date : date as String?,
    status: status == _unset ? this.status : status as String?,
  );

  static const _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is ScheduleFilter &&
      other.upcoming == upcoming &&
      other.date == date &&
      other.status == status;

  @override
  int get hashCode => Object.hash(upcoming, date, status);
}

/// Reset to the default whenever the account changes: a filter one doctor chose
/// must not be applied to the next doctor's appointments.
final scheduleFilterProvider = StateProvider<ScheduleFilter>((ref) {
  ref.watch(_accountId);
  return const ScheduleFilter();
});

/// The appointment list: pages accumulate for the current filter and reset when
/// it changes. Like the doctor directory's list, only the latest filter's answer
/// is ever applied, and a page that arrives after the filter moved is dropped.
class ScheduleController extends StateNotifier<AsyncValue<Paginated<StaffBooking>>> {
  ScheduleController(this._ref) : super(const AsyncValue.loading()) {
    _load();
    _ref.listen<ScheduleFilter>(scheduleFilterProvider, (prev, next) {
      if (prev != next) _load();
    });
  }

  final Ref _ref;
  int _generation = 0;
  bool _loadingMore = false;

  ScheduleFilter get _filter => _ref.read(scheduleFilterProvider);

  Future<Paginated<StaffBooking>> _fetch(int page) {
    final f = _filter;
    return _ref
        .read(managementRepositoryProvider)
        .bookings(
          // The API offers "today onward" and "one day" as alternative views; a
          // chosen day must not be intersected with "upcoming", or yesterday would
          // show nothing.
          upcoming: f.upcoming && f.date == null,
          date: f.date,
          status: f.status,
          page: page,
        );
  }

  Future<void> _load() async {
    // A refresh can be requested by a screen that is already gone.
    if (!mounted) return;
    final generation = ++_generation;
    _loadingMore = false;
    state = state.hasValue
        ? const AsyncLoading<Paginated<StaffBooking>>().copyWithPrevious(state)
        : const AsyncValue.loading();
    try {
      final page = await _fetch(1);
      if (generation != _generation || !mounted) return;
      state = AsyncValue.data(page);
    } catch (e, st) {
      if (generation != _generation || !mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || state.isLoading || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    final generation = _generation;
    try {
      final next = await _fetch(current.pagination.page + 1);
      if (generation != _generation || !mounted) return;
      final seen = current.items.map((b) => b.id).toSet();
      state = AsyncValue.data(
        Paginated(
          items: [...current.items, ...next.items.where((b) => !seen.contains(b.id))],
          pagination: next.pagination,
        ),
      );
    } catch (_) {
      // Keep what is on screen; a failed "load more" must not empty the list.
    } finally {
      if (generation == _generation) _loadingMore = false;
    }
  }

}

/// Auto-disposed and tied to the account: leaving the screen drops the list (so
/// returning re-reads it), and a different doctor starts empty.
final scheduleProvider =
    StateNotifierProvider.autoDispose<ScheduleController, AsyncValue<Paginated<StaffBooking>>>((
      ref,
    ) {
      ref.watch(_accountId);
      return ScheduleController(ref);
    });

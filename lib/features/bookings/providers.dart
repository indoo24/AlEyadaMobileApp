import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'booking_logic.dart';
import 'models.dart';
import 'repository.dart';

export 'booking_logic.dart' show BookingsTab, BookingGroups;

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(apiClientProvider)),
);

/// Which section of My Bookings is showing. Lives outside the screen so it
/// survives leaving the tab and coming back.
final bookingsTabProvider = StateProvider<BookingsTab>((ref) => BookingsTab.upcoming);

/// "Now", in UTC. A provider so tests can pin the clock; the app reads the
/// device's.
final bookingsClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

/// The most pages the list will walk. A patient with more than this many
/// appointments sees the most recent pages; the cap only stops a runaway loop.
const _maxPages = 10;
const _pageSize = 50;

/// Every booking the signed-in patient owns, all pages.
///
/// One list feeds all three sections, so switching sections asks nothing of
/// the server and a pull-to-refresh is a single reload. Tied to the account:
/// signing in as someone else never shows the previous person's appointments.
final myBookingsProvider = FutureProvider<List<PatientBooking>>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  final repo = ref.watch(bookingRepositoryProvider);

  final out = <PatientBooking>[];
  final seen = <String>{};
  for (var page = 1; page <= _maxPages; page++) {
    final result = await repo.myBookings(page: page, pageSize: _pageSize);
    for (final b in result.items) {
      if (seen.add(b.id)) out.add(b);
    }
    if (!result.hasMore) break;
  }
  return out;
});

/// The bookings split into sections, sorted for reading.
final bookingGroupsProvider = Provider<AsyncValue<BookingGroups>>((ref) {
  final now = ref.watch(bookingsClockProvider);
  return ref.watch(myBookingsProvider).whenData((all) => groupBookings(all, now()));
});

final bookingDetailProvider = FutureProvider.family<PatientBooking, String>((ref, id) async {
  return ref.watch(bookingRepositoryProvider).booking(id);
});

/// Drives the booking sheet: which slot is chosen, and whether a submit is in
/// flight.
class BookingDraft {
  const BookingDraft({
    this.selectedDate,
    this.selectedSlot,
    this.visitType = VisitType.firstVisit,
    this.notes,
    this.submitting = false,
  });

  final String? selectedDate;
  final Slot? selectedSlot;
  final VisitType visitType;
  final String? notes;
  final bool submitting;

  bool get isComplete => selectedSlot != null;

  BookingDraft copyWith({
    Object? selectedDate = _unset,
    Object? selectedSlot = _unset,
    VisitType? visitType,
    Object? notes = _unset,
    bool? submitting,
  }) => BookingDraft(
    selectedDate: selectedDate == _unset ? this.selectedDate : selectedDate as String?,
    selectedSlot: selectedSlot == _unset ? this.selectedSlot : selectedSlot as Slot?,
    visitType: visitType ?? this.visitType,
    notes: notes == _unset ? this.notes : notes as String?,
    submitting: submitting ?? this.submitting,
  );

  static const _unset = Object();
}

class BookingDraftController extends StateNotifier<BookingDraft> {
  BookingDraftController() : super(const BookingDraft());

  /// Picking a day clears the chosen time: a slot from another day is not a
  /// valid selection, and leaving it set is how you book the wrong afternoon.
  void chooseDate(String date) => state = state.copyWith(selectedDate: date, selectedSlot: null);

  void chooseSlot(Slot slot) => state = state.copyWith(selectedSlot: slot);

  /// Drop the chosen time while keeping the day — used when the server reports
  /// the slot was taken between selecting and confirming.
  void clearSlot() => state = state.copyWith(selectedSlot: null);
  void setVisitType(VisitType t) => state = state.copyWith(visitType: t);
  void setNotes(String? n) => state = state.copyWith(notes: n);
  void setSubmitting(bool v) => state = state.copyWith(submitting: v);
  void reset() => state = const BookingDraft();
}

final bookingDraftProvider =
    StateNotifierProvider.family<BookingDraftController, BookingDraft, String>(
      (ref, slug) => BookingDraftController(),
    );

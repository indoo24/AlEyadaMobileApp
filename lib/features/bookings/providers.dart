import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/envelope.dart';
import '../../core/providers.dart';
import 'models.dart';
import 'repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(apiClientProvider)),
);

/// Which half of the bookings screen is showing.
enum BookingsTab { upcoming, past }

final bookingsTabProvider = StateProvider<BookingsTab>((ref) => BookingsTab.upcoming);

/// The patient's bookings for the active tab.
///
/// Scoped server-side rather than fetched whole and split here: "upcoming" is a
/// moving target that depends on the server's clock, not the phone's.
final myBookingsProvider = FutureProvider.family<Paginated<PatientBooking>, BookingsTab>((
  ref,
  tab,
) async {
  // Watch auth so signing in or out refetches rather than showing a stale list.
  ref.watch(authControllerProvider);
  return ref
      .watch(bookingRepositoryProvider)
      .myBookings(scope: tab == BookingsTab.upcoming ? 'upcoming' : 'all');
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

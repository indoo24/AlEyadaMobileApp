import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/models.dart';
import '../doctors/providers.dart';
import 'models.dart';
import 'providers.dart';

/// Booking flow: pick a clinic, a day, a time, confirm.
///
/// A signed-out visitor is sent to sign in first and returned here — browsing is
/// public, booking is not.
Future<void> showBookingSheet(BuildContext context, DoctorDetail doctor) async {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BookingSheet(doctor: doctor),
  );
}

class _BookingSheet extends ConsumerStatefulWidget {
  const _BookingSheet({required this.doctor});

  final DoctorDetail doctor;

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  final _notes = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String get _slug => widget.doctor.slug;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final auth = ref.watch(authControllerProvider);
    final clinicId = ref.watch(selectedClinicProvider(_slug));
    final availability = ref.watch(availabilityProvider((slug: _slug, clinicId: clinicId)));
    final draft = ref.watch(bookingDraftProvider(_slug));

    // Bookable clinics only: a contact-only clinic has no times to offer.
    final clinics = widget.doctor.clinics.where((c) => c.bookingEnabled).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              children: [
                Text(l.bookingTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(widget.doctor.displayName, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.lg),

                FormErrorBanner(message: _error),

                if (clinics.length > 1) ...[
                  AppDropdown<String?>(
                    label: l.bookingClinic,
                    value: clinicId ?? clinics.first.clinic.id,
                    items: [
                      for (final c in clinics)
                        DropdownMenuItem(
                          value: c.clinic.id,
                          child: Text(c.clinic.nameAr, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) {
                      // A different clinic means a different schedule, so the
                      // chosen day and time no longer apply.
                      ref.read(selectedClinicProvider(_slug).notifier).state = v;
                      ref.read(bookingDraftProvider(_slug).notifier).reset();
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                AsyncValueView<DoctorAvailability>(
                  value: availability,
                  onRetry: () =>
                      ref.invalidate(availabilityProvider((slug: _slug, clinicId: clinicId))),
                  loading: const Skeleton(height: 180, radius: AppRadii.card),
                  isEmpty: (a) => !a.hasAnySlot,
                  empty: AppEmptyView(
                    icon: Icons.event_busy_outlined,
                    title: l.bookingNoSlotsAtAll,
                  ),
                  data: (a) => _DayAndTimePicker(availability: a, slug: _slug, notes: _notes),
                ),
              ],
            ),
          ),
          if (availability.valueOrNull?.hasAnySlot ?? false)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: FilledButton(
                  onPressed: !draft.isComplete || draft.submitting
                      ? null
                      : () => _confirm(auth.isAuthenticated),
                  child: draft.submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : Text(l.bookingConfirm),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirm(bool isAuthenticated) async {
    final l = L.of(context);

    if (!isAuthenticated) {
      // Send them to sign in and bring them back to this doctor.
      final target = Uri.encodeComponent(Routes.doctorPath(_slug));
      Navigator.of(context).pop();
      context.push('${Routes.signIn}?next=$target');
      return;
    }

    final controller = ref.read(bookingDraftProvider(_slug).notifier);
    final draft = ref.read(bookingDraftProvider(_slug));
    final slot = draft.selectedSlot;
    if (slot == null) return;

    setState(() => _error = null);
    controller.setSubmitting(true);
    try {
      final booking = await ref
          .read(bookingRepositoryProvider)
          .create(
            doctorSlug: _slug,
            slotId: slot.id,
            clinicId: ref.read(selectedClinicProvider(_slug)),
            visitType: draft.visitType,
            notesForDoctor: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (!mounted) return;

      // The list is now stale.
      ref.invalidate(myBookingsProvider);
      controller.reset();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.bookingSuccessTitle)));
      context.push(Routes.bookingPath(booking.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = messageForError(context, e));
      // If the slot went while they were deciding, drop the dead selection and
      // refetch, so they are choosing from what is actually still free. The sheet
      // deliberately stays open: the fix is one tap away.
      if (isRecoverableBookingError(e)) {
        controller.clearSlot();
        ref.invalidate(
          availabilityProvider((slug: _slug, clinicId: ref.read(selectedClinicProvider(_slug)))),
        );
      }
    } finally {
      if (mounted) controller.setSubmitting(false);
    }
  }
}

class _DayAndTimePicker extends ConsumerWidget {
  const _DayAndTimePicker({required this.availability, required this.slug, required this.notes});

  final DoctorAvailability availability;
  final String slug;
  final TextEditingController notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final draft = ref.watch(bookingDraftProvider(slug));
    final controller = ref.read(bookingDraftProvider(slug).notifier);
    final days = availability.daysWithSlots;

    // Default to the first day that actually has times, rather than today —
    // landing on an empty day looks like a broken screen.
    final selectedDate = draft.selectedDate ?? (days.isNotEmpty ? days.first.date : null);
    final day = days.where((d) => d.date == selectedDate).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.bookingChooseDay, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final d = days[i];
              final selected = d.date == selectedDate;
              return _DayChip(
                date: d.date,
                slotCount: d.slots.length,
                selected: selected,
                onTap: () => controller.chooseDate(d.date),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l.bookingChooseTime, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        if (day == null || day.slots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(l.bookingNoSlots, style: Theme.of(context).textTheme.bodySmall),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final slot in day.slots)
                ChoiceChip(
                  // The backend's clinic-local label. Not derived from the UTC
                  // timestamp here: the phone's timezone is not necessarily the
                  // clinic's, and a patient abroad must not see a shifted hour.
                  label: Text(slot.displayTime, textDirection: TextDirection.ltr),
                  selected: draft.selectedSlot?.id == slot.id,
                  onSelected: (_) => controller.chooseSlot(slot),
                ),
            ],
          ),

        const SizedBox(height: AppSpacing.lg),
        AppDropdown<VisitType>(
          label: l.bookingVisitType,
          value: draft.visitType,
          items: [
            DropdownMenuItem(value: VisitType.firstVisit, child: Text(l.bookingVisitFirst)),
            DropdownMenuItem(value: VisitType.followUp, child: Text(l.bookingVisitFollowUp)),
          ],
          onChanged: (v) => v == null ? null : controller.setVisitType(v),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppTextField(label: l.bookingNotes, controller: notes, maxLines: 3, minLines: 2),

        if (draft.selectedSlot != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: AppRadii.cardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.bookingSummary, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                _SummaryRow(
                  label: l.bookingDateTime,
                  value: '$selectedDate  •  ${draft.selectedSlot!.displayTime}',
                ),
                if (availability.fee != null)
                  _SummaryRow(label: l.bookingFee, value: availability.fee!),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.slotCount,
    required this.selected,
    required this.onTap,
  });

  final String date;
  final int slotCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `date` is the clinic-local calendar day as a plain YYYY-MM-DD string.
    // Parsed only to render a weekday label; never converted across zones.
    final parsed = DateTime.tryParse(date);
    final weekday = parsed == null
        ? ''
        : MaterialLocalizations.of(context).narrowWeekdays[parsed.weekday % 7];
    final dayNum = parsed?.day.toString() ?? date;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.inputRadius,
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.input,
            borderRadius: AppRadii.inputRadius,
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekday,
                style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : AppColors.muted),
              ),
              Text(
                dayNum,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.navy,
                ),
                textDirection: TextDirection.ltr,
              ),
              Text(
                '$slotCount',
                style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : AppColors.muted),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

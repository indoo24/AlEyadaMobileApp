import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import 'models.dart';
import 'providers.dart';
import 'widgets/booking_tile.dart';

/// One appointment, with the actions the *server* says are available.
///
/// The cancel button appears when `can_cancel` is true and not otherwise. The
/// app never recomputes the cancellation window — the backend returns both the
/// decision and `cancellation_cutoff_at`, precisely so a client does not have to
/// hold a copy of the policy.
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final booking = ref.watch(bookingDetailProvider(widget.id));

    return Scaffold(
      appBar: AppBar(title: Text(l.bookingsTitle)),
      body: AsyncValueView<PatientBooking>(
        value: booking,
        onRetry: () => ref.invalidate(bookingDetailProvider(widget.id)),
        data: (b) => ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(b.doctorName, style: Theme.of(context).textTheme.titleLarge),
                        ),
                        BookingStatusChip(status: b.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _Row(
                      icon: Icons.event_outlined,
                      label: l.bookingDateTime,
                      value: '${b.displayDate}  •  ${b.displayTime}',
                    ),
                    _Row(
                      icon: Icons.schedule_outlined,
                      label: l.bookingVisitType,
                      value: b.visitType == VisitType.followUp
                          ? l.bookingVisitFollowUp
                          : l.bookingVisitFirst,
                    ),
                    if (b.clinicName.isNotEmpty)
                      _Row(
                        icon: Icons.local_hospital_outlined,
                        label: l.bookingClinic,
                        value: b.clinicName,
                      ),
                    if (b.clinicAddress != null && b.clinicAddress!.isNotEmpty)
                      _Row(icon: Icons.place_outlined, label: '', value: b.clinicAddress!),
                    if (b.feeSnapshot != null)
                      _Row(
                        icon: Icons.payments_outlined,
                        label: l.bookingFee,
                        value: b.feeSnapshot!,
                      ),
                  ],
                ),
              ),
            ),

            if ((b.notesForDoctor ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(l.bookingNotes, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(b.notesForDoctor!, style: Theme.of(context).textTheme.bodyMedium),
            ],

            if (b.cancellationReason.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              InfoNote(text: '${l.bookingCancelReason}: ${b.cancellationReason}'),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Offered strictly on the server's answer.
            if (b.canCancel)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _cancel(b),
                icon: const Icon(Icons.close_rounded),
                label: Text(l.bookingCancelTitle),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
              )
            else if (b.status.isActive && b.cancellationCutoffAt != null)
              // Explain rather than silently hide the button: "why can't I
              // cancel?" is otherwise a support call.
              InfoNote(icon: Icons.info_outline_rounded, text: l.errorLeadTime),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(PatientBooking b) async {
    final l = L.of(context);
    final reason = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.bookingCancelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.bookingCancelBody),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(label: l.bookingCancelReason, controller: reason, maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.actionBack)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(100, 44),
            ),
            child: Text(l.actionConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      reason.dispose();
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .cancel(b.id, reason: reason.text.trim().isEmpty ? null : reason.text.trim());
      if (!mounted) return;
      ref.invalidate(bookingDetailProvider(widget.id));
      ref.invalidate(myBookingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.bookingCancelled)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageForError(context, e))));
    } finally {
      reason.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: AppSpacing.sm),
          if (label.isNotEmpty) ...[
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

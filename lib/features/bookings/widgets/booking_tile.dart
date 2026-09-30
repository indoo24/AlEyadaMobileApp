import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../models.dart';

/// One appointment in a list.
class BookingTile extends StatelessWidget {
  const BookingTile({super.key, required this.booking, this.onTap});

  final PatientBooking booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.doctorName,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  BookingStatusChip(status: booking.status),
                ],
              ),
              if (booking.clinicName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(booking.clinicName, style: text.bodySmall),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 17, color: AppColors.muted),
                  const SizedBox(width: 6),
                  // Both strings come pre-formatted from the backend in the
                  // clinic's timezone.
                  Text(booking.displayDate, style: text.bodyMedium),
                  const SizedBox(width: AppSpacing.md),
                  const Icon(Icons.schedule_outlined, size: 17, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    booking.displayTime,
                    style: text.bodyMedium,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
              if (booking.feeSnapshot != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${l.bookingFee}: ${booking.feeSnapshot}',
                  style: text.labelMedium?.copyWith(color: AppColors.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A booking's state, as a label plus a colour.
///
/// The text carries the meaning; the colour only reinforces it. A status shown
/// by colour alone would be unreadable to a screen reader and ambiguous to anyone
/// who cannot separate the hues.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final (label, color) = switch (status) {
      BookingStatus.pending => (l.statusPending, AppColors.star),
      BookingStatus.confirmed => (l.statusConfirmed, AppColors.whatsapp),
      BookingStatus.completed => (l.statusCompleted, AppColors.muted),
      BookingStatus.cancelledByPatient => (l.statusCancelled, AppColors.danger),
      BookingStatus.cancelledByClinic => (l.statusCancelled, AppColors.danger),
      BookingStatus.noShow => (l.statusNoShow, AppColors.danger),
      BookingStatus.rescheduled => (l.statusRescheduled, AppColors.muted),
      BookingStatus.expired => (l.statusExpired, AppColors.muted),
      BookingStatus.unknown => ('—', AppColors.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.pillRadius,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

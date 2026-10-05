import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../models.dart';

/// One doctor in a list.
class DoctorCardTile extends StatelessWidget {
  const DoctorCardTile({super.key, required this.doctor, this.onTap});

  final DoctorCard doctor;
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoctorAvatar(photo: doctor.photo, name: doctor.displayName, size: 64),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.displayName,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (doctor.professionalTitleAr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        doctor.professionalTitleAr,
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    // Wrap rather than Row: Arabic specialty names plus a city can
                    // easily exceed one line on a small phone, and clipping the
                    // location is worse than wrapping it.
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 6,
                      children: [
                        if (doctor.reviewsCount > 0)
                          RatingBadge(rating: doctor.rating, count: doctor.reviewsCount),
                        if (doctor.locationLabel.isNotEmpty)
                          MetaChip(icon: Icons.place_outlined, label: doctor.locationLabel),
                        if (doctor.yearsOfExperience != null && doctor.yearsOfExperience! > 0)
                          MetaChip(
                            icon: Icons.workspace_premium_outlined,
                            label: l.doctorYearsExperience(doctor.yearsOfExperience!),
                          ),
                      ],
                    ),
                    if (doctor.minFee != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l.doctorFeeFrom(doctor.minFee!),
                        style: text.titleSmall?.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A doctor's photo, or their initial when there is none.
class DoctorAvatar extends StatelessWidget {
  const DoctorAvatar({super.key, this.photo, required this.name, this.size = 56, this.radius});

  final String? photo;
  final String name;
  final double size;

  /// Corner radius; defaults to the rounded square used in lists.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '؟' : name.trim().characters.first;
    return Semantics(
      label: L.of(context).semanticDoctorPhoto,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.bgSoft,
          borderRadius: BorderRadius.circular(radius ?? size * 0.28),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: (photo == null || photo!.isEmpty)
            ? Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              )
            : Image.network(
                photo!,
                fit: BoxFit.cover,
                // A missing photo must not leave a broken-image glyph on a
                // medical directory; fall back to the initial.
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const ColoredBox(color: AppColors.bgSoft),
              ),
      ),
    );
  }
}

/// A rating, as a number plus a star.
///
/// The star is decorative; the value is in the semantics label, because a rating
/// communicated only by a gold glyph is invisible to a screen reader and
/// ambiguous to anyone who cannot distinguish the colour.
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.rating,
    required this.count,
    this.compact = false,
  });

  final double rating;
  final int count;

  /// A smaller, neutral pill for dense feeds.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final value = rating.toStringAsFixed(1);
    return Semantics(
      label: '${l.semanticRating(value)} — ${l.doctorReviewsCount(count)}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : AppSpacing.sm, vertical: compact ? 3 : 4),
        decoration: BoxDecoration(
          color: compact ? AppColors.bgSoft : AppColors.star.withValues(alpha: 0.12),
          borderRadius: AppRadii.pillRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: compact ? 13 : 15, color: AppColors.star),
            const SizedBox(width: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: compact ? 11.5 : 13,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(width: 3),
            Text(
              '($count)',
              style: TextStyle(fontSize: compact ? 10.5 : 12, color: AppColors.muted),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}

class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

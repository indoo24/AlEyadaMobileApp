import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../clinics/models.dart';
import '../home_style.dart';

/// A clinic or medical center in the horizontal strip.
///
/// Open/closed is not shown: the list endpoint carries no working hours, and
/// deriving it would mean a detail request per card. Rating and place are real.
class MedicalCenterCard extends StatelessWidget {
  const MedicalCenterCard({super.key, required this.clinic, required this.width, this.onTap});

  final ClinicListItem clinic;
  final double width;

  /// Null while there is no clinic page to open, so the card does not pretend to
  /// be tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(homeCardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(HomeSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Logo(url: clinic.primaryImage),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clinic.nameAr,
                            style: HomeType.cardTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (clinic.addressAr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              clinic.addressAr,
                              style: HomeType.meta,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (clinic.locationLabel.isNotEmpty)
                      _Pill(
                        icon: Icons.location_on_outlined,
                        label: clinic.locationLabel,
                        color: AppColors.muted,
                        background: AppColors.bgSoft,
                      ),
                    if (clinic.reviewsCount > 0)
                      _Pill(
                        icon: Icons.star_rounded,
                        label: clinic.rating.toStringAsFixed(1),
                        color: AppColors.navy,
                        iconColor: AppColors.star,
                        background: AppColors.star.withValues(alpha: 0.12),
                        ltrLabel: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const fallback = Center(
      child: Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 24),
    );
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    this.iconColor,
    this.ltrLabel = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color? iconColor;
  final Color background;

  /// For numerals, which read left-to-right inside Arabic text.
  final bool ltrLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: AppRadii.pillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor ?? color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: ltrLabel ? TextDirection.ltr : null,
              style: HomeType.pill.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

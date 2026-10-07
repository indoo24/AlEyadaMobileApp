import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../clinics/models.dart';
import '../../doctors/widgets/doctor_rating.dart';
import '../home_style.dart';
import 'pressable.dart';

/// A clinic or medical center in the horizontal strip.
///
/// Name, place and rating come from `/clinics/`. There is no distance (the app
/// has no location to measure from) and no open/closed (the list carries no
/// hours). Tapping lists the doctors who work there — the directory's own clinic
/// filter, the same one search suggestions use.
class MedicalCenterCard extends StatelessWidget {
  const MedicalCenterCard({super.key, required this.clinic, required this.width, this.onTap});

  final ClinicListItem clinic;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = clinic;
    final rated = c.reviewsCount > 0 && c.rating > 0;

    return SizedBox(
      width: width,
      child: Pressable(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(homeCardRadius),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.soft,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(homeCardRadius),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Logo(url: c.primaryImage),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.nameAr,
                                style: HomeType.cardTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (c.locationLabel.isNotEmpty)
                                Text(
                                  c.locationLabel,
                                  style: HomeType.meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (c.addressAr.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              c.addressAr.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: HomeType.meta,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (rated)
                          Expanded(
                            child: DoctorRating.values(
                              avgRating: c.avgRating,
                              reviewsCount: c.reviewsCount,
                              fontSize: 12,
                            ),
                          )
                        else
                          const Spacer(),
                        if (onTap != null)
                          Text(
                            l.hmClinicDoctors,
                            style: HomeType.seeAll.copyWith(color: AppColors.primary),
                          ),
                        if (onTap != null)
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
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
      child: Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 22),
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(
              url!,
              fit: BoxFit.cover,
              // Decoded at the size it is shown, not the upload's full size.
              cacheWidth: (44 * dpr).round(),
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

/// A placeholder in the shape of a [MedicalCenterCard].
class MedicalCenterSkeleton extends StatelessWidget {
  const MedicalCenterSkeleton({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(homeCardRadius),
      border: Border.all(color: AppColors.border),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Skeleton(height: 44, width: 44, radius: 12),
            SizedBox(width: 10),
            Expanded(child: Skeleton(height: 14)),
          ],
        ),
        SizedBox(height: 12),
        Skeleton(height: 11, width: 160),
        SizedBox(height: 16),
        Skeleton(height: 12, width: 90),
      ],
    ),
  );
}

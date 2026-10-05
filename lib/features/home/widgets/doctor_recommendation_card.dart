import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../doctors/models.dart';
import '../../doctors/widgets/doctor_card_tile.dart';
import '../home_style.dart';

/// A recommended doctor: photo, name, specialty, place and rating on top; fee,
/// booking status and the primary action in a tinted footer.
///
/// Only fields the doctor list actually returns are shown. There is no
/// "available today at 6 PM" line because the list endpoint does not carry
/// availability — that lives on the per-doctor endpoint, and fetching it for
/// every card would be N extra requests on the home screen.
class DoctorRecommendationCard extends StatelessWidget {
  const DoctorRecommendationCard({super.key, required this.doctor, required this.onTap});

  final DoctorCard doctor;

  /// Opens the doctor's profile, which is where booking starts.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final specialty = doctor.professionalTitleAr.isNotEmpty
        ? doctor.professionalTitleAr
        : (doctor.primarySpecialization?.nameAr ?? '');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(HomeSpacing.cardPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Photo(doctor: doctor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                doctor.displayName,
                                style: HomeType.doctorName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (doctor.reviewsCount > 0) ...[
                              const SizedBox(width: 6),
                              RatingBadge(
                                rating: doctor.rating,
                                count: doctor.reviewsCount,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                        if (specialty.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            specialty,
                            style: HomeType.doctorSpecialty,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (doctor.locationLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  doctor.locationLabel,
                                  style: HomeType.meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: AppColors.input,
            padding: const EdgeInsets.symmetric(horizontal: HomeSpacing.cardPadding, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _FeeAndStatus(doctor: doctor)),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    // The whole card is the same tap target, so the button can be
                    // its visual size without a 48px hit area inflating the footer.
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: HomeType.button,
                  ),
                  child: Text(doctor.bookingEnabled ? l.homeBookNow : l.homeViewProfile),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.doctor});

  final DoctorCard doctor;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DoctorAvatar(photo: doctor.photo, name: doctor.displayName, size: 78, radius: 10),
          ),
          // Green when the doctor takes online bookings — the only availability
          // signal the list carries. Labelled for screen readers, not colour-only.
          if (doctor.bookingEnabled)
            PositionedDirectional(
              bottom: 4,
              end: 4,
              child: Semantics(
                label: l.homeBookingAvailable,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeeAndStatus extends StatelessWidget {
  const _FeeAndStatus({required this.doctor});

  final DoctorCard doctor;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bookable = doctor.bookingEnabled;
    final color = bookable ? AppColors.success : AppColors.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (doctor.minFee != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${l.homeFeeLabel}: ', style: HomeType.feeLabel),
                TextSpan(text: l.homeFeeAmount(doctor.minFee!), style: HomeType.feeAmount),
              ],
            ),
          ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              bookable ? Icons.event_available_outlined : Icons.phone_in_talk_outlined,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                bookable ? l.homeBookingAvailable : l.homeContactOnly,
                style: HomeType.status.copyWith(color: color),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

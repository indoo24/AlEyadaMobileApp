import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../models.dart';

/// A rating as the backend reports it, trimmed of padding zeros but never
/// rounded: `"4.60"` → `4.6`, `"4.95"` → `4.95`, `"5.00"` → `5.0`.
///
/// Rounding to one decimal would show a 4.95 doctor as a perfect 5.0.
String formatRating(double value) {
  final s = value.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

/// A doctor's rating, for every place a doctor is shown.
///
/// One widget, one source ([DoctorCard.avgRating] and [DoctorCard.reviewsCount]),
/// so Home, Search, Favorites and the profile cannot disagree:
///
///  * rated → `★ 4.9 (142 تقييم)`
///  * rated but no review count → `★ 4.9`
///  * not rated → "no reviews yet" in muted text — never `★ 0.0`
class DoctorRating extends StatelessWidget {
  DoctorRating({super.key, required DoctorCard doctor, this.fontSize = 12.5})
    : _value = doctor.ratingValue,
      _count = doctor.reviewsCount,
      _has = doctor.hasRating;

  /// The same rule, from the two raw values the API sends (the doctor's own
  /// profile has no card to read them from).
  DoctorRating.values({
    super.key,
    required String avgRating,
    required int reviewsCount,
    this.fontSize = 12.5,
  }) : _value = double.tryParse(avgRating.trim()),
       _count = reviewsCount,
       _has = _hasRating(double.tryParse(avgRating.trim()), reviewsCount);

  final double? _value;
  final int _count;
  final bool _has;
  final double fontSize;

  static bool _hasRating(double? v, int count) => v != null && (v > 0 || count > 0);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    if (!_has) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_outline_rounded, size: fontSize + 2, color: AppColors.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l.ratingNone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize, color: AppColors.muted),
            ),
          ),
        ],
      );
    }

    final value = formatRating(_value!);
    final count = _count;

    return Semantics(
      label: count > 0
          ? '${l.semanticRating(value)} — ${l.doctorReviewsCount(count)}'
          : l.semanticRating(value),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: fontSize + 3, color: AppColors.star),
          const SizedBox(width: 3),
          // Digits read left-to-right inside Arabic text.
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: fontSize + 0.5,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '(${l.doctorReviewsCount(count)})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize - 0.5, color: AppColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

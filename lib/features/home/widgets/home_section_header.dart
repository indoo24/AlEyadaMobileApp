import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../home_style.dart';

/// A section title with the blue marker and a "see all" action.
///
/// Built from start-relative parts, so the marker sits at the reading start in
/// Arabic and English alike.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.onSeeAll, this.seeAllLabel});

  final String title;
  final VoidCallback? onSeeAll;

  /// Overrides "See all", e.g. "See all (+15)".
  final String? seeAllLabel;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadii.pillRadius),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          // Wraps rather than truncating: the title is the point of the section,
          // and the action beside it can be wide.
          child: Text(title, style: HomeType.sectionTitle),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(seeAllLabel ?? l.actionSeeAll, style: HomeType.seeAll),
                Icon(rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}

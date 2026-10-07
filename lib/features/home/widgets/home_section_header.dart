import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../home_style.dart';

/// A section title with an optional "see all".
///
/// The chevron is `chevron_right`, which Flutter mirrors in right-to-left
/// layouts: it points *forward* — left in Arabic, right in English.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.onSeeAll, this.seeAllLabel});

  final String title;
  final VoidCallback? onSeeAll;

  /// Overrides "See all", e.g. "See all (+15)".
  final String? seeAllLabel;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Row(
      children: [
        Expanded(
          // Wraps rather than truncating: the title is the point of the section,
          // and the action beside it can be wide.
          child: Semantics(header: true, child: Text(title, style: HomeType.sectionTitle)),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(48, 36),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(seeAllLabel ?? l.actionSeeAll, style: HomeType.seeAll),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// A sideways row of cards that runs to the screen edges.
///
/// The gutter is padding *inside* the scroll view, so the first card lines up
/// with the page and the last can scroll fully into view — at the right edge in
/// Arabic and the left in English, with no direction-specific code.
///
/// Cards are laid out at their natural height and stretched to the tallest, so
/// a larger text size grows the row instead of overflowing a fixed-height strip.
/// Meant for short lists (Home shows at most ten per strip): every card is
/// built, which is what makes equal heights possible.
class HorizontalStrip extends StatelessWidget {
  const HorizontalStrip({
    super.key,
    required this.children,
    this.gap = AppSpacing.md,
    this.scrollable = true,
  });

  final List<Widget> children;
  final double gap;

  /// False for placeholders, which should clip at the edge rather than scroll.
  final bool scrollable;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: scrollable ? null : const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
    // Room for the cards' soft shadows above and below.
    clipBehavior: Clip.none,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            children[i],
          ],
        ],
      ),
    ),
  );
}

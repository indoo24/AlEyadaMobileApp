import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_palette.dart';

/// An empty or failed section, sized to sit where the content would have been.
///
/// A failed section says so and offers a retry, but stays a card among cards: one
/// unreachable list must not turn the whole feed into an error page.
class HomeSectionMessage extends StatelessWidget {
  const HomeSectionMessage({super.key, required this.message, this.icon, this.onRetry});

  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          Icon(icon ?? Icons.inbox_outlined, size: 32, color: context.palette.muted),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: Text(l.actionRetry)),
          ],
        ],
      ),
    );
  }
}

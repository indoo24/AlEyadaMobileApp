import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/greeting.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../home_style.dart';
import 'location_picker.dart';

/// The welcome line (with "Dr." only for a doctor account), the city chip and
/// the tagline.
///
/// The wording comes from [welcomeGreeting], the one place that decides when a
/// title is used — so this screen cannot disagree with the rest of the app.
///
/// The greeting is a single line that ellipsises: a long name must never grow
/// this block, since it sits above everything else on the screen. The tagline
/// spans the full width underneath for the same reason — beside the chip it would
/// wrap to a third line.
class GreetingSection extends ConsumerWidget {
  const GreetingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(currentUserProvider);
    final greeting = user == null ? l.homeGreetingGuest : welcomeGreeting(l, user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Takes all the room the chip leaves (an Expanded, not a Flexible beside
            // a Spacer — those would split the free space between them).
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      greeting,
                      style: HomeType.greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Decorative, and kept out of the greeting string so the wording
                  // stays translatable and testable on its own.
                  const ExcludeSemantics(child: Text('👋', style: TextStyle(fontSize: 17))),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.4),
              child: _LocationChip(label: homeLocationLabel(context, ref)),
            ),
          ],
        ),
        Text(l.appTagline, style: HomeType.tagline, maxLines: 2),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSoft,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => showCityPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeType.locationChip,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

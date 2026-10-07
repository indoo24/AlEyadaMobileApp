import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../providers.dart';

/// The heart on a doctor card.
///
/// It owns no state. Whether it is filled is read from [favoritesProvider] by the
/// doctor's id, so the same doctor looks the same on Home, Search, Favorites and
/// the profile — and only the hearts of doctors whose status changed rebuild.
/// Tapping it never navigates: the surrounding card's tap and this tap are
/// separate targets.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.doctorId, required this.slug, this.size = 22});

  final String doctorId;
  final String slug;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final isFavorite = ref.watch(favoritesProvider.select((s) => s.contains(doctorId)));
    final label = isFavorite ? l.favoriteRemove : l.favoriteAdd;

    return Semantics(
      button: true,
      toggled: isFavorite,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          radius: size,
          onTap: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            final saved = await ref
                .read(favoritesProvider.notifier)
                .toggle(id: doctorId, slug: slug);
            // The heart has already put itself back; say why.
            if (!saved) {
              messenger?.showSnackBar(SnackBar(content: Text(l.favoriteFailed)));
            }
          },
          child: SizedBox(
            width: size + 18,
            height: size + 18,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(isFavorite),
                  size: size,
                  color: isFavorite ? AppColors.primary : AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

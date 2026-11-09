import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../doctors/providers.dart';
import '../../doctors/repository.dart';
import '../home_providers.dart';
import '../home_style.dart';
import 'specialty_section.dart';
import '../../../core/theme/app_palette.dart';

/// Open the directory on [query], scoped to the Home city.
///
/// Every shortcut on Home goes through here: it sets the directory's own query
/// and navigates, so there is one search implementation and its results screen
/// shows (and can clear) exactly what was applied.
void openDirectory(BuildContext context, WidgetRef ref, DoctorQuery query) {
  ref.read(doctorQueryProvider.notifier).state = query.copyWith(
    city: query.city ?? ref.read(homeCitySlugProvider),
  );
  context.go(Routes.doctors);
}

/// Four ways into the directory, each a filter or sort the API supports:
/// everyone, by specialty, online booking only, and cheapest first.
///
/// "Nearest" is deliberately absent: the API can sort by distance, but the app
/// has no location permission to give it coordinates with.
class QuickDiscovery extends ConsumerWidget {
  const QuickDiscovery({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final items = [
      (
        Icons.person_search_rounded,
        l.hmQuickDoctors,
        () => openDirectory(context, ref, const DoctorQuery()),
      ),
      (Icons.grid_view_rounded, l.hmQuickSpecialties, () => showAllSpecialties(context)),
      (
        Icons.event_available_rounded,
        l.hmQuickOnline,
        () => openDirectory(context, ref, const DoctorQuery(bookingEnabled: true)),
      ),
      (
        Icons.savings_outlined,
        l.hmQuickLowestFee,
        () => openDirectory(context, ref, const DoctorQuery(sort: DoctorSort.feeAsc)),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across needs ~68 logical pixels of label per tile at the reader's
        // text size; below that a word would break mid-word, so the shortcuts
        // become a 2 × 2 grid, which doubles each label's width.
        final perTile = (constraints.maxWidth - 3 * AppSpacing.sm) / 4;
        final compact = perTile / MediaQuery.textScalerOf(context).scale(1) < 68;
        // A two-word label can still wrap to a second line ("حجز إلكتروني" is the
        // widest, with a few pixels to spare at 360 wide). Every tile in a row
        // takes the height of the tallest, so a wrap never makes one card stand
        // out: icons stay level and each label starts on the same line.
        Widget row(Iterable<int> tiles) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in tiles) ...[
                if (i != tiles.first) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Shortcut(
                    icon: items[i].$1,
                    label: items[i].$2,
                    onTap: items[i].$3,
                  ),
                ),
              ],
            ],
          ),
        );
        if (!compact) return row([0, 1, 2, 3]);
        return Column(
          children: [
            row([0, 1]),
            const SizedBox(height: AppSpacing.sm),
            row([2, 3]),
          ],
        );
      },
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(homeCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(homeCardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(homeCardRadius),
            border: Border.all(color: context.palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBox(icon: icon),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.homeType.tileLabel.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: context.palette.pageSoft,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, color: context.palette.primary, size: 22),
  );
}

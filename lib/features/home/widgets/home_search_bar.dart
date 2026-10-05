import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../doctors/providers.dart';
import '../../doctors/widgets/filter_sheet.dart';
import '../home_style.dart';

/// The rounded search card (46 high: a 36 control, 4 of padding and the 1 border each side).
///
/// Tapping the field goes to the directory rather than searching in place — one
/// search implementation, not two. The filter button opens the directory's own
/// filter sheet and, if the filters changed, takes the user to the results.
class HomeSearchBar extends ConsumerWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hasFilters = ref.watch(doctorQueryProvider.select((q) => q.hasFilters));

    Future<void> openFilters() async {
      final before = ref.read(doctorQueryProvider);
      await showDoctorFilterSheet(context);
      if (!context.mounted) return;
      if (ref.read(doctorQueryProvider) != before) context.go(Routes.doctors);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.go(Routes.doctors),
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 36,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l.doctorsSearchHint,
                          style: HomeType.searchHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: AppColors.bgSoft,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: openFilters,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Tooltip(
                  message: l.actionFilter,
                  child: Center(
                    child: Badge(
                      isLabelVisible: hasFilters,
                      backgroundColor: AppColors.primary,
                      smallSize: 8,
                      child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 19),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

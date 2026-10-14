import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/home_style.dart';
import '../models.dart';
import '../repository.dart';
import '../search_state.dart';
import '../../../core/theme/app_palette.dart';

/// What the empty, focused search box offers: earlier searches, and a way into
/// the specialty list.
///
/// There is no "popular searches" block. The backend does not record or expose
/// one, and a hardcoded list dressed up as popular would be made up; browsing the
/// real specialty list (busiest first) stands in for it.
class SearchIdlePanel extends StatelessWidget {
  const SearchIdlePanel({
    super.key,
    required this.recents,
    required this.specialties,
    required this.onPickRecent,
    required this.onRemoveRecent,
    required this.onClearRecents,
    required this.onPickSpecialty,
  });

  final List<String> recents;
  final List<Specialization> specialties;
  final ValueChanged<String> onPickRecent;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecents;
  final ValueChanged<Specialization> onPickSpecialty;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final busiest = [...specialties]..sort((a, b) => b.doctorsCount.compareTo(a.doctorsCount));

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, 32),
      children: [
        if (recents.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text(l.searchRecentTitle, style: context.homeType.sectionTitle)),
              TextButton(
                onPressed: onClearRecents,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(l.searchClearAll, style: context.homeType.seeAll),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final r in recents)
            _RecentRow(
              text: r,
              removeLabel: l.searchRemoveRecent,
              onTap: () => onPickRecent(r),
              onRemove: () => onRemoveRecent(r),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (busiest.isNotEmpty) ...[
          Text(l.searchBrowseTitle, style: context.homeType.sectionTitle),
          const SizedBox(height: HomeSpacing.heading),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in busiest.take(10))
                ActionChip(
                  label: Text(s.nameAr, style: context.homeType.chip),
                  backgroundColor: context.palette.surface,
                  side: BorderSide(color: context.palette.border),
                  shape: const StadiumBorder(),
                  onPressed: () => onPickSpecialty(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.text,
    required this.removeLabel,
    required this.onTap,
    required this.onRemove,
  });

  final String text;
  final String removeLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.inputRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(Icons.history_rounded, size: 20, color: context.palette.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: context.homeType.doctorSpecialty.copyWith(fontSize: 14)),
            ),
            IconButton(
              tooltip: removeLabel,
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: Icon(Icons.close_rounded, size: 18, color: context.palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Matching specialties, places and clinics for what is being typed.
class SearchSuggestionList extends StatelessWidget {
  const SearchSuggestionList({super.key, required this.suggestions, required this.onPick});

  final List<SearchSuggestion> suggestions;
  final ValueChanged<SearchSuggestion> onPick;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: context.palette.border),
        boxShadow: context.palette.shadowSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final s in suggestions)
            InkWell(
              onTap: () => onPick(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(_icon(s.kind), size: 20, color: context.palette.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.label,
                            style: context.homeType.cardTitle.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (s.subtitle != null)
                            Text(
                              s.subtitle!,
                              style: context.homeType.meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_kind(l, s.kind), style: context.homeType.meta),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _icon(SuggestionKind k) => switch (k) {
    SuggestionKind.specialty => Icons.medical_services_outlined,
    SuggestionKind.city => Icons.location_city_rounded,
    SuggestionKind.area => Icons.place_outlined,
    SuggestionKind.clinic => Icons.local_hospital_outlined,
  };

  static String _kind(L l, SuggestionKind k) => switch (k) {
    SuggestionKind.specialty => l.searchSuggestSpecialty,
    SuggestionKind.city => l.searchSuggestCity,
    SuggestionKind.area => l.searchSuggestArea,
    SuggestionKind.clinic => l.searchSuggestClinic,
  };
}

/// "18 doctors found" and the sort control.
class SearchResultHeader extends StatelessWidget {
  const SearchResultHeader({
    super.key,
    required this.count,
    required this.sort,
    required this.onSort,
  });

  /// Null while the first page is still loading.
  final int? count;
  final String? sort;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final current = sort ?? DoctorSort.featured;

    return Row(
      children: [
        Expanded(
          child: Text(
            count == null ? '' : l.searchResultsCount(count!),
            style: context.homeType.sectionTitle,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: l.searchSortLabel,
          initialValue: current,
          onSelected: onSort,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.inputRadius),
          itemBuilder: (_) => [
            for (final key in DoctorSort.all)
              PopupMenuItem(
                value: key,
                child: Text(
                  sortLabel(l, key),
                  style: TextStyle(
                    fontWeight: key == current ? FontWeight.w700 : FontWeight.w500,
                    color: key == current ? context.palette.primary : context.palette.body,
                  ),
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: AppRadii.pillRadius,
              border: Border.all(color: context.palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort_rounded, size: 17, color: context.palette.primary),
                const SizedBox(width: 6),
                Text(
                  sortLabel(l, current),
                  style: context.homeType.chip.copyWith(color: context.palette.heading),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: context.palette.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String sortLabel(L l, String key) => switch (key) {
  DoctorSort.rating => l.searchSortRating,
  DoctorSort.newest => l.searchSortNewest,
  DoctorSort.feeAsc => l.searchSortFeeAsc,
  _ => l.searchSortFeatured,
};

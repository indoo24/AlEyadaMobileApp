import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/home_style.dart';
import '../models.dart';
import '../providers.dart';
import '../repository.dart';
import 'filter_sheet.dart';

/// One applied filter as a chip: what to call it, and the query without it.
class ActiveFilter {
  const ActiveFilter({required this.label, required this.without});

  final String label;
  final DoctorQuery Function(DoctorQuery) without;
}

/// The filters on [query] as removable chips, in a stable order.
///
/// Names are looked up in the specialty tree and city list the app already holds;
/// until those load the slug stands in, so a chip never appears blank.
List<ActiveFilter> activeFilters(
  DoctorQuery query,
  L l, {
  List<Specialization> specialties = const [],
  List<City> cities = const [],
}) {
  String? specialtyName(String slug) =>
      specialties.expand((s) => s.flattened).where((s) => s.slug == slug).firstOrNull?.nameAr;
  final city = cities.where((c) => c.slug == query.city).firstOrNull;
  final area = city?.areas.where((a) => a.slug == query.area).firstOrNull;

  return [
    if (query.specialization != null)
      ActiveFilter(
        label: specialtyName(query.specialization!) ?? query.specialization!,
        without: (q) => q.copyWith(specialization: null, page: 1),
      ),
    if (query.city != null)
      ActiveFilter(
        label: city?.nameAr ?? query.city!,
        // An area only means something inside its city.
        without: (q) => q.copyWith(city: null, area: null, page: 1),
      ),
    if (query.area != null)
      ActiveFilter(
        label: area?.nameAr ?? query.area!,
        without: (q) => q.copyWith(area: null, page: 1),
      ),
    if (query.clinic != null)
      ActiveFilter(
        label: query.clinicName ?? query.clinic!,
        without: (q) => q.copyWith(clinic: null, clinicName: null, page: 1),
      ),
    if (query.gender != null)
      ActiveFilter(
        label: query.gender == 'female' ? l.searchGenderFemale : l.searchGenderMale,
        without: (q) => q.copyWith(gender: null, page: 1),
      ),
    if (query.minRating != null)
      ActiveFilter(
        label: l.searchChipRating(_trim(query.minRating!)),
        without: (q) => q.copyWith(minRating: null, page: 1),
      ),
    if (query.maxFee != null)
      ActiveFilter(
        label: l.searchChipMaxFee(query.maxFee!),
        without: (q) => q.copyWith(maxFee: null, page: 1),
      ),
    if (query.bookingEnabled == true)
      ActiveFilter(
        label: l.searchChipBooking,
        without: (q) => q.copyWith(bookingEnabled: null, page: 1),
      ),
  ];
}

String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// The filter button, the applied filters as removable chips, and "clear all".
///
/// Removing a chip changes the query and the list reloads on its own — there is
/// no Search button to press.
class SearchFilterRow extends ConsumerWidget {
  const SearchFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final query = ref.watch(doctorQueryProvider);
    final chips = activeFilters(
      query,
      l,
      specialties: ref.watch(specializationsProvider).valueOrNull ?? const [],
      cities: ref.watch(citiesProvider).valueOrNull ?? const [],
    );

    void set(DoctorQuery next) => ref.read(doctorQueryProvider.notifier).state = next;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Row(
        children: [
          _FilterButton(
            label: l.searchFilterButton,
            count: chips.length,
            onTap: () => showDoctorFilterSheet(context),
          ),
          // Only this strip scrolls. "Clear all" leads it, so it is always the first
          // thing next to the filter button — at the end it would sit off-screen
          // whenever several filters are applied.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Row(
                children: [
                  if (chips.isNotEmpty)
                    TextButton(
                      onPressed: () => set(query.withoutFilters().copyWith(page: 1)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(l.searchClearAll, style: HomeType.seeAll),
                    ),
                  for (final chip in chips) ...[
                    const SizedBox(width: 4),
                    _RemovableChip(label: chip.label, onRemove: () => set(chip.without(query))),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label, required this.count, required this.onTap});

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune_rounded, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: HomeType.chip.copyWith(color: Colors.white)),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSoft,
      shape: StadiumBorder(side: BorderSide(color: AppColors.primary.withValues(alpha: 0.18))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 8, top: 8, bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeType.chip.copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close_rounded, size: 15, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

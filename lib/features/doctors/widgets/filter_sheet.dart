import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../l10n/app_localizations.dart';
import '../models.dart';
import '../providers.dart';
import '../repository.dart';

/// The directory filters.
///
/// Specialties and cities come from the API, not a hardcoded list, so adding a
/// specialty or opening a city needs no app release. The city list here is the
/// **unrestricted** one — a patient must be able to search everywhere the
/// directory has entries, even though a doctor may only register in the launch
/// governorate.
Future<void> showDoctorFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late DoctorQuery _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(doctorQueryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final specs = ref.watch(specializationsProvider);
    final cities = ref.watch(citiesProvider);

    // Areas depend on the chosen city, and the dependency is real: an area from
    // another city is not a valid combination.
    final selectedCity = cities.valueOrNull?.where((c) => c.slug == _draft.city).firstOrNull;
    final areas = selectedCity?.areas ?? const <Area>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
        ),
        children: [
          Text(l.actionFilter, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xl),

          specs.when(
            loading: () => const Skeleton(height: 56, radius: AppRadii.input),
            error: (_, __) => const SizedBox.shrink(),
            data: (tree) {
              // Flattened so sub-specialties are selectable, with the tree's own
              // ordering preserved.
              final flat = tree.expand((s) => s.flattened).toList();
              return AppDropdown<String?>(
                label: l.doctorsFilterSpecialty,
                value: _draft.specialization,
                hint: l.doctorsFilterAny,
                items: [
                  DropdownMenuItem(value: null, child: Text(l.doctorsFilterAny)),
                  for (final s in flat)
                    DropdownMenuItem(
                      value: s.slug,
                      child: Text(s.nameAr, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _draft = _draft.copyWith(specialization: v)),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          cities.when(
            loading: () => const Skeleton(height: 56, radius: AppRadii.input),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) => Column(
              children: [
                AppDropdown<String?>(
                  label: l.doctorsFilterCity,
                  value: _draft.city,
                  hint: l.doctorsFilterAny,
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.doctorsFilterAny)),
                    for (final c in list) DropdownMenuItem(value: c.slug, child: Text(c.nameAr)),
                  ],
                  // Changing city clears the area: keeping a stale area would
                  // produce a filter combination with no possible results.
                  onChanged: (v) => setState(() => _draft = _draft.copyWith(city: v, area: null)),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppDropdown<String?>(
                  label: l.doctorsFilterArea,
                  value: _draft.area,
                  hint: l.doctorsFilterAny,
                  enabled: areas.isNotEmpty,
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.doctorsFilterAny)),
                    for (final a in areas) DropdownMenuItem(value: a.slug, child: Text(a.nameAr)),
                  ],
                  onChanged: (v) => setState(() => _draft = _draft.copyWith(area: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppDropdown<String?>(
            label: l.doctorsFilterGender,
            value: _draft.gender,
            hint: l.doctorsFilterAny,
            items: [
              DropdownMenuItem(value: null, child: Text(l.doctorsFilterAny)),
              DropdownMenuItem(value: 'male', child: Text(l.doctorsFilterMale)),
              DropdownMenuItem(value: 'female', child: Text(l.doctorsFilterFemale)),
            ],
            onChanged: (v) => setState(() => _draft = _draft.copyWith(gender: v)),
          ),

          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () {
              ref.read(doctorQueryProvider.notifier).state = _draft.copyWith(page: 1);
              Navigator.of(context).pop();
            },
            child: Text(l.actionApply),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () {
              ref.read(doctorQueryProvider.notifier).state = const DoctorQuery();
              Navigator.of(context).pop();
            },
            child: Text(l.actionClearFilters),
          ),
        ],
      ),
    );
  }
}

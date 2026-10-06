import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/home_style.dart';
import '../models.dart';
import '../providers.dart';
import '../repository.dart';

/// The directory filters.
///
/// Only what `GET /doctors/` actually filters on is offered: specialty, city,
/// area, doctor gender, minimum rating, **maximum** fee (there is no minimum),
/// and online-booking only. Availability ("available now"), facility type and
/// minimum price are deliberately absent — the backend cannot apply them, and a
/// control that changes nothing is worse than no control.
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

/// Rating floors on offer. 5.0 means "only perfect scores".
const _ratingOptions = <double>[4.0, 4.5, 5.0];

/// Fee ceilings on offer, in EGP.
const _feeOptions = <String>['200', '300', '500', '1000'];

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

  void _edit(DoctorQuery Function(DoctorQuery) change) => setState(() => _draft = change(_draft));

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
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Row(
              children: [
                Expanded(child: Text(l.searchFilterTitle, style: Theme.of(context).textTheme.titleLarge)),
                TextButton(
                  onPressed: () => _edit((q) => q.withoutFilters()),
                  child: Text(l.searchClearFilters),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.lg),
              children: [
                specs.when(
                  loading: () => const Skeleton(height: 56, radius: AppRadii.input),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (tree) {
                    // Flattened so sub-specialties are selectable, with the tree's
                    // own ordering preserved.
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
                      onChanged: (v) => _edit((q) => q.copyWith(specialization: v, page: 1)),
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
                        onChanged: (v) => _edit((q) => q.copyWith(city: v, area: null, page: 1)),
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
                        onChanged: (v) => _edit((q) => q.copyWith(area: v, page: 1)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _Section(
                  title: l.searchFilterRating,
                  child: _Choices<double?>(
                    value: _draft.minRating,
                    options: [null, ..._ratingOptions],
                    label: (v) => v == null ? l.searchAny : '${_fmt(v)}+',
                    leading: (v) => v == null ? null : Icons.star_rounded,
                    onChanged: (v) => _edit((q) => q.copyWith(minRating: v, page: 1)),
                  ),
                ),
                _Section(
                  title: l.searchFilterMaxFee,
                  child: _Choices<String?>(
                    value: _draft.maxFee,
                    options: [null, ..._feeOptions],
                    label: (v) => v == null ? l.searchAnyPrice : l.homeFeeAmount(v),
                    onChanged: (v) => _edit((q) => q.copyWith(maxFee: v, page: 1)),
                  ),
                ),
                _Section(
                  title: l.doctorsFilterGender,
                  child: _Choices<String?>(
                    value: _draft.gender,
                    options: const [null, 'male', 'female'],
                    label: (v) => switch (v) {
                      'male' => l.searchGenderMale,
                      'female' => l.searchGenderFemale,
                      _ => l.searchAny,
                    },
                    onChanged: (v) => _edit((q) => q.copyWith(gender: v, page: 1)),
                  ),
                ),
                _Section(
                  title: l.searchFilterBooking,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.searchFilterBookingOnly, style: HomeType.doctorSpecialty.copyWith(fontSize: 14)),
                    value: _draft.bookingEnabled == true,
                    // Off means "don't filter", not "only doctors without booking".
                    onChanged: (on) => _edit((q) => q.copyWith(bookingEnabled: on ? true : null, page: 1)),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.md),
              child: FilledButton(
                onPressed: () {
                  ref.read(doctorQueryProvider.notifier).state = _draft.copyWith(page: 1);
                  Navigator.of(context).pop();
                },
                child: Text(l.actionApply),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HomeType.sectionTitle.copyWith(fontSize: 15)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A single-choice row of pills.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
    this.leading,
  });

  final T value;
  final List<T> options;
  final String Function(T) label;
  final IconData? Function(T)? leading;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          Semantics(
            button: true,
            selected: o == value,
            child: Material(
              color: o == value ? AppColors.primary : AppColors.surface,
              shape: StadiumBorder(
                side: BorderSide(color: o == value ? AppColors.primary : AppColors.border),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(o),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading?.call(o) != null) ...[
                        Icon(
                          leading!(o),
                          size: 15,
                          color: o == value ? Colors.white : AppColors.star,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label(o),
                        style: HomeType.chip.copyWith(
                          color: o == value ? Colors.white : AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

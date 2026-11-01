import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../doctors/models.dart';
import '../../doctors/providers.dart';
import '../home_providers.dart';
import '../../../core/theme/app_palette.dart';

/// A city's name in the reader's language.
String cityName(BuildContext context, City c) {
  final english = Localizations.localeOf(context).languageCode == 'en';
  return english && c.nameEn.isNotEmpty ? c.nameEn : c.nameAr;
}

/// The label for the home feed's current city.
String homeLocationLabel(BuildContext context, WidgetRef ref) {
  final city = ref.watch(homeCityProvider);
  return city == null ? L.of(context).homeLocationAll : cityName(context, city);
}

/// Choose the city the home feed is scoped to. The list is the directory's own
/// (unrestricted) city list, so every city a patient can search is offered.
///
/// On the root navigator, so the tab shell's floating dock is not painted
/// over the sheet.
Future<void> showCityPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CityPicker(),
  );
}

class _CityPicker extends ConsumerWidget {
  const _CityPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final cities = ref.watch(citiesProvider);
    final selected = ref.watch(homeCitySlugProvider);

    void choose(String? slug) {
      ref.read(homeCitySlugProvider.notifier).state = slug;
      Navigator.of(context).pop();
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Text(l.homeLocationPickerTitle, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: AsyncValueView(
              value: cities,
              onRetry: () => ref.invalidate(citiesProvider),
              isEmpty: (list) => list.isEmpty,
              data: (list) => ListView(
                shrinkWrap: true,
                // The last city scrolls clear of the system navigation bar.
                padding: EdgeInsets.only(
                  bottom: AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _CityTile(
                    label: l.homeLocationAll,
                    selected: selected == null,
                    onTap: () => choose(null),
                  ),
                  for (final c in list)
                    _CityTile(
                      label: cityName(context, c),
                      selected: selected == c.slug,
                      onTap: () => choose(c.slug),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedColor: context.palette.primary,
      title: Text(label),
      trailing: selected ? Icon(Icons.check_rounded, color: context.palette.primary) : null,
      onTap: onTap,
    );
  }
}

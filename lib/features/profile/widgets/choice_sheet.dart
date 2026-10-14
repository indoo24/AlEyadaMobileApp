import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../home/home_style.dart';

/// One choice in a [ChoiceSheet].
class ChoiceOption<T> {
  const ChoiceOption(this.value, this.label);

  final T value;
  final String label;
}

/// Opens a bottom sheet for [builder] — the frame every settings picker shares,
/// so the language and the appearance sheets look and behave the same.
Future<void> showChoiceSheetFrame(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: context.palette.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: builder,
    );

/// A short list of mutually exclusive choices, the current one marked.
///
/// Choosing one calls [onSelected] and closes the sheet. Each row is a button
/// that says whether it is selected, to a screen reader as much as to the eye.
class ChoiceSheet<T> extends StatelessWidget {
  const ChoiceSheet({
    super.key,
    required this.title,
    required this.options,
    required this.current,
    required this.onSelected,
  });

  final String title;
  final List<ChoiceOption<T>> options;
  final T current;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    Widget option(ChoiceOption<T> o) {
      final selected = o.value == current;
      return Semantics(
        selected: selected,
        button: true,
        label: o.label,
        excludeSemantics: true,
        child: Material(
          color: selected ? p.pageSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              onSelected(o.value);
              Navigator.of(context).pop();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.label,
                        style: context.homeType.cardTitle.copyWith(
                          fontSize: 15,
                          color: selected ? p.primary : p.heading,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              key: const ValueKey('on'),
                              color: p.primary,
                            )
                          : Icon(
                              Icons.radio_button_unchecked_rounded,
                              key: const ValueKey('off'),
                              color: p.border,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 10, AppSpacing.gutter, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: p.border, borderRadius: AppRadii.pillRadius),
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(title, style: context.homeType.sectionTitle.copyWith(fontSize: 17)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            option(options[i]),
          ],
        ],
      ),
    );
  }
}

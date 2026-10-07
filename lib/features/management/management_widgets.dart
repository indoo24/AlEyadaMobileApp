import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_messages.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_style.dart';

/// A white card in the home feed's style.
class MgmtCard extends StatelessWidget {
  const MgmtCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(homeCardRadius),
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadows.soft,
    ),
    // List tiles and buttons inside paint their ink on the nearest Material; a
    // coloured DecoratedBox above them would hide it.
    child: Material(type: MaterialType.transparency, child: child),
  );
}

/// A small coloured label. The text carries the meaning; colour only echoes it.
class MgmtBadge extends StatelessWidget {
  const MgmtBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: AppRadii.pillRadius,
    ),
    child: Text(label, style: HomeType.pill.copyWith(color: color, fontSize: 11)),
  );
}

/// A ready / not-ready banner with the reasons underneath when there are any.
class MgmtNotice extends StatelessWidget {
  const MgmtNotice({super.key, required this.ok, required this.title, this.lines = const []});

  final bool ok;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.star;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded, size: 17, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: HomeType.status.copyWith(color: color, fontSize: 12.5))),
            ],
          ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 23, top: 3),
              child: Text(line, style: HomeType.meta),
            ),
        ],
      ),
    );
  }
}

/// The primary button of a management form, with a spinner while it saves.
class MgmtSaveButton extends StatelessWidget {
  const MgmtSaveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.saving = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool saving;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: saving ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: HomeType.button.copyWith(fontSize: 13.5),
      ),
      child: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    ),
  );
}

/// Run a management request, report the outcome, and say whether it worked.
///
/// A failure shows the server's own message (already localized by
/// [messageForError]) rather than a raw exception. [onDone] runs only on success,
/// and is handed the app's provider container captured *before* the request: the
/// screen that started it may have been left by the time the answer arrives, and
/// a widget's `ref` must not be used after that.
Future<bool> runManagementAction(
  BuildContext context,
  Future<Object?> Function() action, {
  String? successMessage,
  void Function(ProviderContainer container)? onDone,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context);
  final fallback = L.of(context).managementFailed;
  String reason(Object e) {
    try {
      return messageForError(context, e);
    } catch (_) {
      return fallback;
    }
  }

  try {
    await action();
    onDone?.call(container);
    if (successMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    }
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(reason(e))));
    return false;
  }
}

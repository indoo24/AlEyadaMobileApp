import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../home/home_style.dart';
import '../../home/widgets/pressable.dart';
import '../../../core/theme/app_palette.dart';

/// The building blocks of My Account and Personal Information.
///
/// Settings sit in grouped white panels with inset dividers — one surface per
/// group rather than a bordered box per row — matching the sections of the
/// doctor profile and booking screens.

/// A round avatar with the account's initial. The account API carries no photo,
/// so there is no image to show — and no stock picture is put in its place.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, this.size = 64, this.onDark = false});

  final String name;
  final double size;

  /// White ring and tint, for the navy header.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '' : trimmed.characters.first;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(onDark ? 3 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onDark ? Colors.white.withValues(alpha: 0.18) : null,
        ),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.palette.pageSoft),
          alignment: Alignment.center,
          child: initial.isEmpty
              ? Icon(Icons.person_rounded, size: size * 0.5, color: context.palette.primary)
              : Text(
                  initial.toUpperCase(),
                  style: TextStyle(
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.w800,
                    color: context.palette.primary,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

/// A titled group of [SettingsRow]s on one white surface.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                title!,
                style: context.homeType.meta.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(homeCardRadius),
            boxShadow: context.palette.shadowSoft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, indent: 64, color: context.palette.border),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One row: an icon in a tinted square, a label, an optional value or badge,
/// and a forward chevron (mirrored in Arabic).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.badge,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// The current setting, shown at the end (e.g. the language).
  final String? value;

  /// A small count pill (e.g. unread notifications).
  final String? badge;

  /// Red, with no chevron — for signing out.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.palette.danger : context.palette.primary;
    return Semantics(
      container: true,
      button: true,
      label: [label, ?value, ?badge].join('، '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: destructive
                        ? context.palette.danger.withValues(alpha: 0.08)
                        : context.palette.pageSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: context.homeType.cardTitle.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: destructive ? context.palette.danger : context.palette.heading,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.palette.danger,
                      borderRadius: AppRadii.pillRadius,
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                if (value != null) ...[
                  const SizedBox(width: 8),
                  // At the end, beside the chevron — capped so a long value
                  // never squeezes the label.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.35),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.homeType.meta.copyWith(fontSize: 13),
                    ),
                  ),
                ],
                if (!destructive) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 20, color: context.palette.muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Phone verified" / "Phone not verified", from `/auth/me/`'s
/// `is_phone_verified`. Unverified can be tapped to start verification.
class PhoneStatusChip extends StatelessWidget {
  const PhoneStatusChip({
    super.key,
    required this.verified,
    required this.label,
    this.actionLabel,
    this.onVerify,
    this.onDark = false,
  });

  final bool verified;
  final String label;
  final String? actionLabel;
  final VoidCallback? onVerify;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final tone = verified ? context.palette.toneSuccess : context.palette.toneWarning;
    // On the navy header the chip is always the pale pair, in either mode.
    final fg = onDark ? (verified ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D)) : tone.fg;
    final bg = onDark ? context.palette.heroChip : tone.bg;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.pillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: 15,
            color: fg,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
          if (onVerify != null && actionLabel != null) ...[
            const SizedBox(width: 6),
            Text(
              actionLabel!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: onDark ? Colors.white : context.palette.primary,
                decoration: TextDecoration.underline,
                decorationColor: onDark ? Colors.white : context.palette.primary,
              ),
            ),
          ],
        ],
      ),
    );
    if (onVerify == null) return chip;
    return Semantics(
      button: true,
      child: Pressable(
        child: InkWell(onTap: onVerify, borderRadius: AppRadii.pillRadius, child: chip),
      ),
    );
  }
}

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';

/// One destination in [GlassBottomNav].
class BottomNavItem {
  const BottomNavItem({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// A floating, frosted-glass tab dock.
///
/// A rounded capsule inset from the screen edges, blurring whatever scrolls
/// behind it, with a soft blue pill that glides to the selected tab. It only
/// draws and reports taps — which tabs exist, and where they go, stays in
/// [AppShell].
///
/// Items share the width equally, so it fits any number of tabs and any screen
/// width. Everything is laid out with start-relative geometry, so in Arabic the
/// order, the pill and its slide all mirror without any manual reversal.
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _radius = 28.0;
  static const _inset = 6.0;
  static const _itemHeight = 54.0;
  static const _slide = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(_radius);

    return SafeArea(
      top: false,
      // Keeps the dock off the edge on devices with no bottom inset at all.
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Shadow is painted outside the capsule only: a normal BoxShadow also
            // shows *through* a translucent surface and greys the glass.
            Positioned.fill(
              child: CustomPaint(painter: _DockShadowPainter(shape, context.palette.dockShadow)),
            ),
            ClipRRect(
              borderRadius: shape,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: shape,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        context.palette.surfaceRaised.withValues(alpha: 0.82),
                        context.palette.surfaceRaised.withValues(alpha: 0.64),
                      ],
                    ),
                    border: Border.all(
                      color: context.palette.isDark
                          ? context.palette.border
                          : context.palette.surface.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(_inset),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final itemWidth = c.maxWidth / items.length;
                        return SizedBox(
                          height: _itemHeight,
                          child: Stack(
                            children: [
                              AnimatedPositionedDirectional(
                                duration: _slide,
                                curve: Curves.easeOutCubic,
                                start: itemWidth * selectedIndex,
                                top: 0,
                                bottom: 0,
                                width: itemWidth,
                                child: const _ActivePill(),
                              ),
                              Row(
                                children: [
                                  for (var i = 0; i < items.length; i++)
                                    Expanded(
                                      child: _NavButton(
                                        item: items[i],
                                        selected: i == selectedIndex,
                                        onTap: () => onSelected(i),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The selected tab's backdrop: a faint blue tint, not a solid block.
class _ActivePill extends StatelessWidget {
  const _ActivePill();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GlassBottomNav._radius - GlassBottomNav._inset),
          color: context.palette.primary.withValues(alpha: 0.11),
          border: Border.all(color: context.palette.primary.withValues(alpha: 0.10)),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final target = selected ? context.palette.primary : context.palette.muted;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(GlassBottomNav._radius - GlassBottomNav._inset),
        containedInkWell: true,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target),
          duration: GlassBottomNav._slide,
          builder: (context, color, _) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.06 : 1.0,
                duration: GlassBottomNav._slide,
                curve: Curves.easeOutCubic,
                child: Icon(selected ? item.activeIcon : item.icon, size: 22, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                // Large system text must not push the dock taller than its pill.
                textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockShadowPainter extends CustomPainter {
  const _DockShadowPainter(this.radius, this.color);

  final BorderRadius radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final capsule = radius.toRRect(Offset.zero & size);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(80)),
      Path()..addRRect(capsule),
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        capsule.shift(const Offset(0, 10)),
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_DockShadowPainter old) => old.radius != radius || old.color != color;
}

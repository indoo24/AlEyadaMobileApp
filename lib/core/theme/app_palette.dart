import 'package:flutter/material.dart';

import 'tokens.dart';

/// A foreground/background pair for a status: a pill, a badge, a banner.
///
/// The two are chosen together so the text on the tint always reads — the pairs
/// below are checked against WCAG AA in `test/unit/palette_contrast_test.dart`
/// for both modes. The label and icon carry a status's meaning; colour only
/// echoes it.
@immutable
class StatusTone {
  const StatusTone({required this.fg, required this.bg});

  final Color fg;
  final Color bg;

  static StatusTone lerp(StatusTone a, StatusTone b, double t) =>
      StatusTone(fg: Color.lerp(a.fg, b.fg, t)!, bg: Color.lerp(a.bg, b.bg, t)!);
}

/// Every colour the UI uses, by what it is *for* rather than what it looks like.
///
/// Read it with `context.palette`. Light is exactly the website's design tokens
/// ([AppColors]); dark is a deep navy-slate (not black) with the same blue
/// identity, lifted so text, icons and borders keep their contrast. Widgets
/// never branch on the brightness themselves: they ask for a role.
///
/// A [ThemeExtension], so a change of theme animates (`lerp`) and every widget
/// that reads it rebuilds.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.page,
    required this.pageSoft,
    required this.surface,
    required this.surfaceRaised,
    required this.input,
    required this.border,
    required this.heading,
    required this.body,
    required this.muted,
    required this.primary,
    required this.primaryFill,
    required this.onPrimaryFill,
    required this.danger,
    required this.dangerFill,
    required this.success,
    required this.star,
    required this.whatsapp,
    required this.whatsappFg,
    required this.toneInfo,
    required this.toneSuccess,
    required this.toneWarning,
    required this.toneCaution,
    required this.toneDanger,
    required this.toneNeutral,
    required this.heroStart,
    required this.heroEnd,
    required this.heroEdge,
    required this.heroChip,
    required this.shadowCard,
    required this.shadowSoft,
    required this.shadowFloat,
    required this.shadowBar,
    required this.dockShadow,
  });

  final Brightness brightness;

  /// The page behind everything.
  final Color page;

  /// Selected and tinted fills: a chosen chip, an icon's round background.
  final Color pageSoft;

  /// Cards and panels.
  final Color surface;

  /// What floats above a surface: sheets, dialogs, the glass navigation bar.
  final Color surfaceRaised;

  /// Form field fill.
  final Color input;
  final Color border;

  /// Headings.
  final Color heading;

  /// Body text.
  final Color body;

  /// Subtitles and meta text.
  final Color muted;

  /// Links, icons and text in the brand blue. Always legible *on* a surface.
  final Color primary;

  /// The brand blue as a *fill* — a filled button, a selected chip — under
  /// [onPrimaryFill]. Not the same as [primary] in dark, where text blue is
  /// light and a fill that light would not carry white text.
  final Color primaryFill;
  final Color onPrimaryFill;

  /// Errors as text, icons and borders.
  final Color danger;

  /// Destructive actions as a *fill* (a "cancel booking" button) under white.
  final Color dangerFill;
  final Color success;
  final Color star;

  /// The WhatsApp button's fill (white label on it).
  final Color whatsapp;

  /// WhatsApp green as an icon or outline on a surface.
  final Color whatsappFg;

  final StatusTone toneInfo;
  final StatusTone toneSuccess;
  final StatusTone toneWarning;
  final StatusTone toneCaution;
  final StatusTone toneDanger;
  final StatusTone toneNeutral;

  /// The navy header's gradient, and the hairline that keeps its edge visible
  /// against a dark page. White text sits on both stops.
  final Color heroStart;
  final Color heroEnd;
  final Color heroEdge;

  /// A chip's fill on the hero (translucent, so it takes the gradient under it).
  final Color heroChip;

  final List<BoxShadow> shadowCard;
  final List<BoxShadow> shadowSoft;
  final List<BoxShadow> shadowFloat;

  /// The shadow of a bar pinned to the bottom of a screen (casts upward).
  final List<BoxShadow> shadowBar;

  /// The floating navigation dock's drop shadow.
  final Color dockShadow;

  bool get isDark => brightness == Brightness.dark;

  /// The navy header's gradient.
  LinearGradient get heroGradient => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [heroStart, heroEnd],
  );

  // ---------------------------------------------------------------------------

  /// The website's tokens, unchanged.
  static const light = AppPalette(
    brightness: Brightness.light,
    page: AppColors.bg,
    pageSoft: AppColors.bgSoft,
    surface: AppColors.surface,
    surfaceRaised: AppColors.surface,
    input: AppColors.input,
    border: AppColors.border,
    heading: AppColors.navy,
    body: AppColors.ink,
    muted: AppColors.muted,
    primary: AppColors.primary,
    primaryFill: AppColors.primary,
    onPrimaryFill: Colors.white,
    danger: AppColors.danger,
    dangerFill: AppColors.danger,
    success: AppColors.success,
    star: AppColors.star,
    whatsapp: AppColors.whatsapp,
    whatsappFg: AppColors.whatsapp,
    toneInfo: StatusTone(fg: AppColors.primary, bg: AppColors.bgSoft),
    toneSuccess: StatusTone(fg: Color(0xFF15803D), bg: Color(0xFFDCFCE7)),
    toneWarning: StatusTone(fg: Color(0xFFB45309), bg: Color(0xFFFEF3C7)),
    toneCaution: StatusTone(fg: Color(0xFFC2410C), bg: Color(0xFFFFEDD5)),
    toneDanger: StatusTone(fg: Color(0xFFB91C1C), bg: Color(0xFFFEE2E2)),
    toneNeutral: StatusTone(fg: AppColors.muted, bg: Color(0xFFEEF2F7)),
    heroStart: Color(0xFF022253),
    heroEnd: Color(0xFF0A3F86),
    heroEdge: Color(0x00FFFFFF),
    heroChip: Color(0x1FFFFFFF),
    shadowCard: AppShadows.card,
    shadowSoft: AppShadows.soft,
    shadowFloat: AppShadows.float,
    shadowBar: [BoxShadow(color: Color(0x140F172A), blurRadius: 20, offset: Offset(0, -4))],
    dockShadow: Color(0x260F172A),
  );

  /// Deep navy-slate surfaces, one step lighter per level of elevation; the
  /// same blue, lifted for text and icons.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    page: Color(0xFF0B1220),
    // One step above the raised surface, so a soft panel still reads inside a sheet.
    pageSoft: Color(0xFF1B2B47),
    surface: Color(0xFF111B2E),
    surfaceRaised: Color(0xFF17233A),
    input: Color(0xFF0E1828),
    border: Color(0xFF26364F),
    heading: Color(0xFFE8EEF7),
    body: Color(0xFFCBD5E1),
    muted: Color(0xFF94A3B8),
    primary: Color(0xFF6EA8FE),
    primaryFill: Color(0xFF1F6FD1),
    onPrimaryFill: Colors.white,
    danger: Color(0xFFF87171),
    dangerFill: Color(0xFFDC2626),
    success: Color(0xFF4ADE80),
    star: Color(0xFFFBBF24),
    whatsapp: Color(0xFF15803D),
    whatsappFg: Color(0xFF4ADE80),
    toneInfo: StatusTone(fg: Color(0xFF93C5FD), bg: Color(0xFF172C4A)),
    toneSuccess: StatusTone(fg: Color(0xFF86EFAC), bg: Color(0xFF0E2E1B)),
    toneWarning: StatusTone(fg: Color(0xFFFCD34D), bg: Color(0xFF3A2A08)),
    toneCaution: StatusTone(fg: Color(0xFFFDBA74), bg: Color(0xFF3A1F0C)),
    toneDanger: StatusTone(fg: Color(0xFFFCA5A5), bg: Color(0xFF3B1518)),
    toneNeutral: StatusTone(fg: Color(0xFFCBD5E1), bg: Color(0xFF1E293B)),
    heroStart: Color(0xFF0D3270),
    heroEnd: Color(0xFF1A5CB0),
    heroEdge: Color(0x24FFFFFF),
    // Darker than the page it lifts from: the pale chip text needs the contrast.
    heroChip: Color(0x4D000000),
    // Elevation in dark is mostly the lighter surface; the shadow only grounds it.
    shadowCard: [BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1))],
    shadowSoft: [BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 4))],
    shadowFloat: [BoxShadow(color: Color(0x59000000), blurRadius: 32, offset: Offset(0, 12))],
    shadowBar: [BoxShadow(color: Color(0x73000000), blurRadius: 20, offset: Offset(0, -4))],
    dockShadow: Color(0x80000000),
  );

  // ---------------------------------------------------------------------------

  @override
  AppPalette copyWith({Brightness? brightness}) => AppPalette(
    brightness: brightness ?? this.brightness,
    page: page,
    pageSoft: pageSoft,
    surface: surface,
    surfaceRaised: surfaceRaised,
    input: input,
    border: border,
    heading: heading,
    body: body,
    muted: muted,
    primary: primary,
    primaryFill: primaryFill,
    onPrimaryFill: onPrimaryFill,
    danger: danger,
    dangerFill: dangerFill,
    success: success,
    star: star,
    whatsapp: whatsapp,
    whatsappFg: whatsappFg,
    toneInfo: toneInfo,
    toneSuccess: toneSuccess,
    toneWarning: toneWarning,
    toneCaution: toneCaution,
    toneDanger: toneDanger,
    toneNeutral: toneNeutral,
    heroStart: heroStart,
    heroEnd: heroEnd,
    heroEdge: heroEdge,
    heroChip: heroChip,
    shadowCard: shadowCard,
    shadowSoft: shadowSoft,
    shadowFloat: shadowFloat,
    shadowBar: shadowBar,
    dockShadow: dockShadow,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    StatusTone tone(StatusTone a, StatusTone b) => StatusTone.lerp(a, b, t);
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      page: c(page, other.page),
      pageSoft: c(pageSoft, other.pageSoft),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      input: c(input, other.input),
      border: c(border, other.border),
      heading: c(heading, other.heading),
      body: c(body, other.body),
      muted: c(muted, other.muted),
      primary: c(primary, other.primary),
      primaryFill: c(primaryFill, other.primaryFill),
      onPrimaryFill: c(onPrimaryFill, other.onPrimaryFill),
      danger: c(danger, other.danger),
      dangerFill: c(dangerFill, other.dangerFill),
      success: c(success, other.success),
      star: c(star, other.star),
      whatsapp: c(whatsapp, other.whatsapp),
      whatsappFg: c(whatsappFg, other.whatsappFg),
      toneInfo: tone(toneInfo, other.toneInfo),
      toneSuccess: tone(toneSuccess, other.toneSuccess),
      toneWarning: tone(toneWarning, other.toneWarning),
      toneCaution: tone(toneCaution, other.toneCaution),
      toneDanger: tone(toneDanger, other.toneDanger),
      toneNeutral: tone(toneNeutral, other.toneNeutral),
      heroStart: c(heroStart, other.heroStart),
      heroEnd: c(heroEnd, other.heroEnd),
      heroEdge: c(heroEdge, other.heroEdge),
      heroChip: c(heroChip, other.heroChip),
      shadowCard: BoxShadow.lerpList(shadowCard, other.shadowCard, t)!,
      shadowSoft: BoxShadow.lerpList(shadowSoft, other.shadowSoft, t)!,
      shadowFloat: BoxShadow.lerpList(shadowFloat, other.shadowFloat, t)!,
      shadowBar: BoxShadow.lerpList(shadowBar, other.shadowBar, t)!,
      dockShadow: c(dockShadow, other.dockShadow),
    );
  }
}

/// `context.palette` — the colours of the theme in force here.
///
/// Falls back to the palette for the ambient brightness when a tree has no
/// [AppPalette] (a bare `MaterialApp`), so a widget never has to care.
extension PaletteContext on BuildContext {
  AppPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark ? AppPalette.dark : AppPalette.light);
  }
}

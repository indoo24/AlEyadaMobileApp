import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Vertical rhythm of the home feed, in logical pixels.
///
/// One place for the numbers the reference design fixes, so the sections cannot
/// drift apart and a later tweak is one edit.
class HomeSpacing {
  const HomeSpacing._();

  /// Between the header and the greeting.
  static const top = 12.0;

  /// Greeting → search.
  static const afterGreeting = 14.0;

  /// Between one section and the next.
  static const section = 20.0;

  /// A section's title → its content.
  static const heading = 10.0;

  /// Between stacked cards.
  static const card = 12.0;

  /// Inner padding of a card.
  static const cardPadding = 12.0;
}

/// Type scale of the home feed.
///
/// Sizes are deliberately a notch below the app theme's (which is tuned for
/// forms and detail pages): the home feed is dense, and the reference sets its
/// hierarchy with weight and colour more than with size. Colours come from the
/// palette; font family, letter-spacing and the user's text scale still come
/// from the theme and the app-level text-scale clamp.
///
/// Read with `context.homeType`: the colours come from the theme in force, so
/// the same style is dark-on-light in light mode and light-on-dark in dark.
class HomeType {
  const HomeType(this._p);

  final AppPalette _p;

  TextStyle get greeting =>
      TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _p.heading, height: 1.3);
  TextStyle get tagline => TextStyle(fontSize: 12, color: _p.muted, height: 1.3);

  TextStyle get brand =>
      TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _p.primary, height: 1.2);
  TextStyle get location => TextStyle(fontSize: 12, color: _p.muted, height: 1.4);
  TextStyle get locationChip =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _p.primary);

  TextStyle get searchHint => TextStyle(fontSize: 13, color: _p.muted);

  TextStyle get sectionTitle =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _p.heading, height: 1.3);
  TextStyle get seeAll => TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

  TextStyle get chip => TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);

  TextStyle get doctorName =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _p.heading, height: 1.35);
  TextStyle get doctorSpecialty => TextStyle(fontSize: 12.5, color: _p.body, height: 1.4);
  TextStyle get meta => TextStyle(fontSize: 11.5, color: _p.muted, height: 1.4);

  TextStyle get feeLabel => TextStyle(fontSize: 11, color: _p.muted);
  TextStyle get feeAmount =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _p.primary);
  TextStyle get status => TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

  /// Button text styles *replace* the theme's rather than merging with it, so
  /// the family must be named here or the label drops out of Cairo.
  TextStyle get button =>
      TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, fontWeight: FontWeight.w700);

  TextStyle get cardTitle =>
      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _p.heading, height: 1.4);
  TextStyle get articleTitle =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _p.heading, height: 1.5);
  TextStyle get articleBody => TextStyle(fontSize: 12.5, color: _p.muted, height: 1.6);
  TextStyle get pill => TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600);

  TextStyle get navLabel => TextStyle(fontSize: 11, height: 1.2);

  // The navy header.
  TextStyle get heroGreeting =>
      TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3);
  TextStyle get heroTagline => TextStyle(fontSize: 12.5, color: Color(0xCCFFFFFF), height: 1.4);
  TextStyle get heroSearch => TextStyle(fontSize: 14, color: _p.muted);

  // Shortcut and specialty tiles: a short label under an icon.
  TextStyle get tileLabel =>
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _p.heading, height: 1.35);
  TextStyle get tileMeta => TextStyle(fontSize: 11, color: _p.muted, height: 1.3);
}

/// `context.homeType` — the home feed's type scale in the colours of the theme.
extension HomeTypeContext on BuildContext {
  HomeType get homeType => HomeType(palette);
}

/// Card corner radius on the home feed.
const homeCardRadius = AppRadii.card;

import 'package:flutter/material.dart';

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
/// hierarchy with weight and colour more than with size. Colours are fixed here;
/// font family, letter-spacing and the user's text scale still come from the
/// theme and the app-level text-scale clamp.
class HomeType {
  const HomeType._();

  static const greeting = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
    height: 1.3,
  );
  static const tagline = TextStyle(fontSize: 12, color: AppColors.muted, height: 1.3);

  static const brand = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    height: 1.2,
  );
  static const location = TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4);
  static const locationChip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const searchHint = TextStyle(fontSize: 13, color: AppColors.muted);

  static const sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
    height: 1.3,
  );
  static const seeAll = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

  static const chip = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);

  static const doctorName = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
    height: 1.35,
  );
  static const doctorSpecialty = TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.4);
  static const meta = TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4);

  static const feeLabel = TextStyle(fontSize: 11, color: AppColors.muted);
  static const feeAmount = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );
  static const status = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

  /// Button text styles *replace* the theme's rather than merging with it, so
  /// the family must be named here or the label drops out of Cairo.
  static const button = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
  );

  static const cardTitle = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
    height: 1.4,
  );
  static const articleTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
    height: 1.5,
  );
  static const articleBody = TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.6);
  static const pill = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600);

  static const navLabel = TextStyle(fontSize: 11, height: 1.2);

  // The navy header.
  static const heroGreeting = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.3,
  );
  static const heroTagline = TextStyle(fontSize: 12.5, color: Color(0xCCFFFFFF), height: 1.4);
  static const heroSearch = TextStyle(fontSize: 14, color: AppColors.muted);

  // Shortcut and specialty tiles: a short label under an icon.
  static const tileLabel = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: AppColors.navy,
    height: 1.35,
  );
  static const tileMeta = TextStyle(fontSize: 11, color: AppColors.muted, height: 1.3);
}

/// Card corner radius on the home feed.
const homeCardRadius = AppRadii.card;

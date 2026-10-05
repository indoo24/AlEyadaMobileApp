import 'package:flutter/material.dart';

/// The design contract shared with the website.
///
/// These values come from `design-tokens.md` and `Frontend/src/app/globals.css`
/// — not from looking at screenshots. If a token changes there it changes here;
/// the two clients are meant to look like one product.
class AppColors {
  const AppColors._();

  /// Action blue: buttons, links, icons. 6.2:1 on white (AA).
  static const primary = Color(0xFF0057B8);
  static const primaryHover = Color(0xFF004494);

  /// Headings and the footer.
  static const navy = Color(0xFF0F172A);

  /// Body text.
  static const ink = Color(0xFF1A2332);

  /// Subtitles and meta text.
  static const muted = Color(0xFF5B6B84);

  /// Page tint.
  static const bg = Color(0xFFEDF4FB);
  static const bgSoft = Color(0xFFE8F0FB);

  /// Cards and sheets.
  static const surface = Color(0xFFFFFFFF);

  /// Form field fill.
  static const input = Color(0xFFF8FBFF);
  static const border = Color(0xFFDBE7F5);

  /// Reserved: WhatsApp and availability only. Never a general accent — that is
  /// an identity rule in the tokens document, not a preference.
  static const whatsapp = Color(0xFF16A34A);
  static const whatsappHover = Color(0xFF15803D);

  static const star = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
}

class AppRadii {
  const AppRadii._();

  /// Cards and panels.
  static const card = 16.0;

  /// Form fields.
  static const input = 12.0;

  /// Every button, chip and badge.
  static const pill = 9999.0;

  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get inputRadius => BorderRadius.circular(input);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}

class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;

  /// Vertical rhythm between sections on a phone (the tokens document gives 40px
  /// for mobile against 64px on desktop).
  static const section = 40.0;

  /// Page gutter.
  static const gutter = 16.0;
}

class AppShadows {
  const AppShadows._();

  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const cardHover = <BoxShadow>[
    BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Resting cards on the home feed: a wide, faint lift rather than a hairline.
  static const soft = <BoxShadow>[
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// The floating search card.
  static const float = <BoxShadow>[
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 32, offset: Offset(0, 12)),
  ];
}

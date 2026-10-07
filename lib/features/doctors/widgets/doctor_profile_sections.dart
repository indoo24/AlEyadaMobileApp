import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/home_style.dart';
import '../doctor_detail_logic.dart';
import '../models.dart';
import 'doctor_card_tile.dart';
import 'doctor_rating.dart';

/// The building blocks of a doctor's public profile.
///
/// Every section renders only what the API sent: a section with nothing to show
/// is left out entirely rather than shown empty or padded with placeholder text.

/// Deep navy of the brand (the splash and launch background).
const profileNavy = Color(0xFF022253);

/// Open a web or map link outside the app, telling the patient when it fails.
Future<void> openExternalLink(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = L.of(context).dpLinkFailed;
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
}

/// The top of the profile: photo, name, title, specialty, rating, location.
class DoctorHero extends StatelessWidget {
  const DoctorHero({super.key, required this.detail});

  final DoctorDetail detail;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final card = detail.card;
    final specialty =
        card.primarySpecialization?.nameAr ??
        detail.specializations.where((s) => s.isPrimary == true).firstOrNull?.nameAr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 4, AppSpacing.gutter, 52),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [profileNavy, Color(0xFF0A3F86)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: DoctorAvatar(photo: card.photo, name: card.displayName, size: 104, radius: 52),
          ),
          const SizedBox(height: 14),
          Text(
            card.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.35,
            ),
          ),
          if (card.professionalTitleAr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              card.professionalTitleAr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((specialty ?? '').isNotEmpty)
                _HeroPill(icon: Icons.medical_services_outlined, label: specialty!),
              if (card.locationLabel.isNotEmpty)
                _HeroPill(icon: Icons.place_outlined, label: card.locationLabel),
            ],
          ),
          const SizedBox(height: 12),
          _HeroRating(card: card, noneLabel: l.ratingNone),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: AppRadii.pillRadius,
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The same rating rule as [DoctorRating] — never `★ 0.0` for an unrated
/// doctor — drawn for a dark background.
class _HeroRating extends StatelessWidget {
  const _HeroRating({required this.card, required this.noneLabel});

  final DoctorCard card;
  final String noneLabel;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (!card.hasRating) {
      return Text(
        noneLabel,
        style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.75)),
      );
    }
    final value = card.ratingValue!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            value >= i
                ? Icons.star_rounded
                : value >= i - 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: 18,
            color: AppColors.star,
          ),
        const SizedBox(width: 6),
        Text(
          formatRating(value),
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        if (card.reviewsCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '(${l.doctorReviewsCount(card.reviewsCount)})',
            style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ],
    );
  }
}

/// Experience, rating, starting fee and clinic count — whichever exist.
class DoctorStatsCard extends StatelessWidget {
  const DoctorStatsCard({super.key, required this.detail});

  final DoctorDetail detail;

  static bool hasAny(DoctorDetail d) =>
      (d.card.yearsOfExperience ?? 0) > 0 ||
      d.card.hasRating ||
      d.card.minFee != null ||
      d.clinics.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final card = detail.card;
    final stats = <Widget>[
      if ((card.yearsOfExperience ?? 0) > 0)
        _Stat(
          icon: Icons.workspace_premium_outlined,
          value: l.ddStatYears(card.yearsOfExperience!),
          label: l.ddStatExperience,
        ),
      if (card.hasRating)
        _Stat(
          icon: Icons.star_rounded,
          iconColor: AppColors.star,
          value: formatRating(card.ratingValue!),
          label: l.ddStatRating,
          ltr: true,
        ),
      if (card.minFee != null)
        _Stat(icon: Icons.payments_outlined, value: l.ddMoney(card.minFee!), label: l.ddStatFee),
      if (detail.clinics.isNotEmpty)
        _Stat(
          icon: Icons.local_hospital_outlined,
          value: '${detail.clinics.length}',
          label: l.ddStatClinics,
          ltr: true,
        ),
    ];
    if (stats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.float,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
              Expanded(child: stats[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.ltr = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;
  final bool ltr;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            textDirection: ltr ? TextDirection.ltr : null,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: HomeType.meta.copyWith(fontSize: 11),
        ),
      ],
    ),
  );
}

/// A titled white card, the unit every profile section is drawn in.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(homeCardRadius),
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadows.soft,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.bgSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Semantics(header: true, child: Text(title, style: HomeType.sectionTitle)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

/// Text that folds to [collapsedLines] with a "show more" toggle — shown only
/// when the text actually overflows.
class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text, {super.key, this.collapsedLines = 5, this.style});

  final String text;
  final int collapsedLines;
  final TextStyle? style;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = widget.style ?? const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.8);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: DefaultTextStyle.of(context).style.merge(style)),
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: AlignmentDirectional.topStart,
              child: Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : widget.collapsedLines,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.fade,
              ),
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  minimumSize: const Size(48, 36),
                  textStyle: HomeType.button.copyWith(fontSize: 13),
                ),
                child: Text(_expanded ? l.ddShowLess : l.ddShowMore),
              ),
          ],
        );
      },
    );
  }
}

/// About: the biography, then the doctor's stated vision.
class DoctorAboutSection extends StatelessWidget {
  const DoctorAboutSection({super.key, required this.detail});

  final DoctorDetail detail;

  static bool hasAny(DoctorDetail d) => (d.bioAr ?? '').trim().isNotEmpty || d.visionAr.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bio = (detail.bioAr ?? '').trim();
    return ProfileSection(
      title: l.doctorAbout,
      icon: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bio.isNotEmpty) ExpandableText(bio),
          if (detail.visionAr.isNotEmpty) ...[
            if (bio.isNotEmpty) const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSoft,
                borderRadius: AppRadii.inputRadius,
                border: const BorderDirectional(
                  start: BorderSide(color: AppColors.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.dpField_vision_ar,
                    style: HomeType.meta.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail.visionAr,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.7),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Degree, positions, certifications, fellowships, education and certificates.
class DoctorProfessionalSection extends StatelessWidget {
  const DoctorProfessionalSection({super.key, required this.detail});

  final DoctorDetail detail;

  static bool hasAny(DoctorDetail d) =>
      d.academicDegreeAr.isNotEmpty ||
      d.currentPositionsAr.isNotEmpty ||
      d.pastPositionsAr.isNotEmpty ||
      d.certificationsAr.isNotEmpty ||
      d.fellowshipsAr.isNotEmpty ||
      d.education.isNotEmpty ||
      d.certificates.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final rows = <Widget>[
      if (detail.academicDegreeAr.isNotEmpty)
        _InfoRow(
          icon: Icons.school_outlined,
          label: l.dpField_academic_degree_ar,
          text: detail.academicDegreeAr,
        ),
      if (detail.currentPositionsAr.isNotEmpty)
        _InfoRow(
          icon: Icons.work_outline_rounded,
          label: l.dpField_current_positions_ar,
          text: detail.currentPositionsAr,
        ),
      if (detail.pastPositionsAr.isNotEmpty)
        _InfoRow(
          icon: Icons.history_rounded,
          label: l.dpField_past_positions_ar,
          text: detail.pastPositionsAr,
        ),
      if (detail.certificationsAr.isNotEmpty)
        _InfoRow(
          icon: Icons.verified_outlined,
          label: l.dpField_certifications_ar,
          text: detail.certificationsAr,
        ),
      if (detail.fellowshipsAr.isNotEmpty)
        _InfoRow(
          icon: Icons.military_tech_outlined,
          label: l.dpField_fellowships_ar,
          text: detail.fellowshipsAr,
        ),
      if (detail.education.isNotEmpty)
        _CredentialList(
          icon: Icons.menu_book_outlined,
          label: l.dpEducationTitle,
          items: detail.education,
        ),
      if (detail.certificates.isNotEmpty)
        _CredentialList(
          icon: Icons.card_membership_outlined,
          label: l.dpCertificatesTitle,
          items: detail.certificates,
        ),
    ];

    return ProfileSection(
      title: l.dpSectionProfessional,
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 22, color: AppColors.border),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// A labelled block of text; several lines become a bulleted list.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.text});

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    const body = TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.65);
    return _LabelledBlock(
      icon: icon,
      label: label,
      child: lines.length <= 1
          ? Text(lines.isEmpty ? text : lines.single, style: body)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final line in lines) _Bullet(text: line, style: body)],
            ),
    );
  }
}

class _CredentialList extends StatelessWidget {
  const _CredentialList({required this.icon, required this.label, required this.items});

  final IconData icon;
  final String label;
  final List<DoctorCredential> items;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.6);
    return _LabelledBlock(
      icon: icon,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in items.where((c) => c.titleAr.trim().isNotEmpty))
            _Bullet(
              text: [
                c.titleAr.trim(),
                if ((c.subtitle ?? '').isNotEmpty) c.subtitle!,
                if ((c.year ?? '').isNotEmpty && c.year != 'null') c.year!,
              ].join(' — '),
              style: body,
            ),
        ],
      ),
    );
  }
}

class _LabelledBlock extends StatelessWidget {
  const _LabelledBlock({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: HomeType.meta.copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    ],
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: style)),
      ],
    ),
  );
}

/// Specialties (primary first, highlighted) and services as chips.
class DoctorChipsSection extends StatelessWidget {
  const DoctorChipsSection.specialties({super.key, required this.detail}) : _services = false;
  const DoctorChipsSection.services({super.key, required this.detail}) : _services = true;

  final DoctorDetail detail;
  final bool _services;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final chips = <Widget>[];
    if (_services) {
      for (final s in detail.services.where((s) => s.nameAr.trim().isNotEmpty)) {
        chips.add(
          _InfoChip(label: s.nameAr.trim(), trailing: s.price == null ? null : l.ddMoney(s.price!)),
        );
      }
    } else {
      final specs = [...detail.specializations.where((s) => s.nameAr.trim().isNotEmpty)]
        ..sort((a, b) => (b.isPrimary == true ? 1 : 0) - (a.isPrimary == true ? 1 : 0));
      for (final s in specs) {
        chips.add(_InfoChip(label: s.nameAr.trim(), highlighted: s.isPrimary == true));
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return ProfileSection(
      title: _services ? l.ddServices : l.dpSpecializations,
      icon: _services ? Icons.healing_outlined : Icons.medical_services_outlined,
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.trailing, this.highlighted = false});

  final String label;
  final String? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: highlighted ? AppColors.primary : AppColors.bgSoft,
      borderRadius: AppRadii.pillRadius,
      border: Border.all(color: highlighted ? AppColors.primary : AppColors.border),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label),
          if (trailing != null)
            TextSpan(
              text: '  ·  $trailing',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: highlighted ? Colors.white : AppColors.primary,
              ),
            ),
        ],
      ),
      style: HomeType.chip.copyWith(color: highlighted ? Colors.white : AppColors.navy),
    ),
  );
}

/// One clinic the doctor works at: where, when, how much, and the actions.
class DoctorClinicCard extends StatelessWidget {
  const DoctorClinicCard({
    super.key,
    required this.link,
    required this.bookable,
    required this.onBook,
    required this.onCall,
  });

  final DoctorClinicLink link;

  /// Whether this clinic takes online bookings for this doctor.
  final bool bookable;
  final VoidCallback onBook;

  /// Call the clinic; null when it has no number.
  final VoidCallback? onCall;

  /// The clinic's own map link, else one built from its own coordinates. A
  /// clinic with neither gets no map button.
  Uri? get _mapUri {
    final c = link.clinic;
    if (c.mapsUri != null) return c.mapsUri;
    if (c.latitude != null && c.longitude != null) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${c.latitude},${c.longitude}',
      });
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = link.clinic;
    final days = groupWorkingHours(c.workingHours);
    final map = _mapUri;
    final location = [c.area?.nameAr, c.city?.nameAr].where((p) => (p ?? '').isNotEmpty).join('، ');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(
          color: link.isPrimary ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
        ),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ClinicThumb(image: c.primaryImage),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nameAr, style: HomeType.cardTitle.copyWith(fontSize: 15)),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(location, style: HomeType.meta),
                        ],
                        if (link.isPrimary || !bookable) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (link.isPrimary)
                                _Badge(label: l.clinicBadgePrimary, color: AppColors.primary),
                              if (!bookable) _Badge(label: l.ddPhoneOnly, color: AppColors.muted),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (c.addressAr.trim().isNotEmpty ||
                  (c.landmark ?? '').trim().isNotEmpty ||
                  map != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _IconLine(
                        icon: Icons.location_on_outlined,
                        text: [
                          c.addressAr.trim(),
                          (c.landmark ?? '').trim(),
                        ].where((s) => s.isNotEmpty).join(' — '),
                      ),
                    ),
                    if (map != null)
                      TextButton.icon(
                        onPressed: () => openExternalLink(context, map),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(l.ddOpenLocation),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          textStyle: HomeType.button.copyWith(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ],
              if (link.consultationFee != null || link.followupFee != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (link.consultationFee != null)
                      Expanded(
                        child: _FeeBox(
                          label: l.clinicFeeConsult,
                          amount: l.ddMoney(link.consultationFee!),
                        ),
                      ),
                    if (link.consultationFee != null && link.followupFee != null)
                      const SizedBox(width: 8),
                    if (link.followupFee != null)
                      Expanded(
                        child: _FeeBox(
                          label: l.clinicFeeFollowup,
                          amount: l.ddMoney(link.followupFee!),
                        ),
                      ),
                  ],
                ),
              ],
              if (days.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 17, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      l.doctorWorkingHours,
                      style: HomeType.meta.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final d in days)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            d.label.isNotEmpty ? d.label : _weekdayName(l, d.weekday),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            d.ranges.join('  ،  '),
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 13, color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (bookable || onCall != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (bookable)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onBook,
                          icon: const Icon(Icons.event_available_rounded, size: 18),
                          label: Text(
                            l.ddBookAtClinic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            textStyle: HomeType.button.copyWith(fontSize: 13.5),
                          ),
                        ),
                      ),
                    if (onCall != null) ...[
                      if (bookable) const SizedBox(width: 8),
                      if (bookable)
                        IconButton.outlined(
                          onPressed: onCall,
                          tooltip: l.doctorCall,
                          icon: const Icon(Icons.phone_rounded, size: 20),
                          style: IconButton.styleFrom(minimumSize: const Size(46, 46)),
                        )
                      else
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onCall,
                            icon: const Icon(Icons.phone_rounded, size: 18),
                            label: Text(l.doctorCall),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              textStyle: HomeType.button.copyWith(fontSize: 13.5),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _weekdayName(L l, int iso) => switch (iso) {
    1 => l.weekday1,
    2 => l.weekday2,
    3 => l.weekday3,
    4 => l.weekday4,
    5 => l.weekday5,
    6 => l.weekday6,
    _ => l.weekday7,
  };
}

class _ClinicThumb extends StatelessWidget {
  const _ClinicThumb({this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    const fallback = Center(
      child: Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 24),
    );
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: (image ?? '').isEmpty
          ? fallback
          : Image.network(image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: AppRadii.pillRadius,
    ),
    child: Text(label, style: HomeType.pill.copyWith(color: color, fontSize: 11)),
  );
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 17, color: AppColors.muted),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.6)),
      ),
    ],
  );
}

class _FeeBox extends StatelessWidget {
  const _FeeBox({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: AppRadii.inputRadius),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: HomeType.feeLabel),
        const SizedBox(height: 2),
        Text(amount, style: HomeType.feeAmount.copyWith(fontSize: 14)),
      ],
    ),
  );
}

/// The doctor's own map link, website and social accounts.
class DoctorLinksSection extends StatelessWidget {
  const DoctorLinksSection({super.key, required this.detail});

  final DoctorDetail detail;

  static bool hasAny(DoctorDetail d) =>
      d.googleMapsUrl != null || d.website != null || d.socialLinks.isNotEmpty;

  static IconData _socialIcon(String network) => switch (network) {
    'facebook' => Icons.facebook_rounded,
    'instagram' => Icons.camera_alt_outlined,
    'linkedin' => Icons.work_outline_rounded,
    'youtube' => Icons.smart_display_outlined,
    'tiktok' => Icons.music_note_rounded,
    _ => Icons.link_rounded,
  };

  static String _socialLabel(L l, String network) => switch (network) {
    'facebook' => l.dpField_facebook,
    'instagram' => l.dpField_instagram,
    'linkedin' => l.dpField_linkedin,
    'youtube' => l.dpField_youtube,
    'tiktok' => l.dpField_tiktok,
    _ => network,
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final map = detail.googleMapsUrl;
    final site = detail.website;

    return ProfileSection(
      title: l.ddLinksTitle,
      icon: Icons.public_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (map != null)
            _LinkTile(
              icon: Icons.map_outlined,
              title: l.ddMapLink,
              actionLabel: l.ddOpenLocation,
              onTap: () => openExternalLink(context, map),
            ),
          if (site != null)
            _LinkTile(
              icon: Icons.language_rounded,
              title: l.dpField_website,
              subtitle: site.host,
              onTap: () => openExternalLink(context, site),
            ),
          if (detail.socialLinks.isNotEmpty) ...[
            if (map != null || site != null) const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in detail.socialLinks.entries)
                  ActionChip(
                    avatar: Icon(_socialIcon(e.key), size: 18, color: AppColors.primary),
                    label: Text(_socialLabel(l, e.key)),
                    labelStyle: HomeType.chip.copyWith(
                      color: AppColors.navy,
                      fontFamily: AppTheme.fontFamily,
                    ),
                    backgroundColor: AppColors.bgSoft,
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                    onPressed: () => openExternalLink(context, e.value),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadii.inputRadius,
    child: Semantics(
      link: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bgSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HomeType.cardTitle.copyWith(fontSize: 14)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeType.meta.copyWith(color: AppColors.primary),
                    ),
                ],
              ),
            ),
            if (actionLabel != null)
              Text(actionLabel!, style: HomeType.seeAll.copyWith(color: AppColors.primary))
            else
              const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

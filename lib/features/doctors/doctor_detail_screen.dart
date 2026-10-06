import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../bookings/booking_sheet.dart';
import 'models.dart';
import 'providers.dart';
import '../favorites/widgets/favorite_button.dart';
import 'widgets/doctor_card_tile.dart';
import 'widgets/doctor_rating.dart';

/// A doctor's public profile.
///
/// Only public fields are shown. Nothing here surfaces moderation metadata — no
/// verification status text, no rejection reasons, no internal notes — because
/// the public serializer does not carry them and this screen must not imply
/// otherwise.
class DoctorDetailScreen extends ConsumerWidget {
  const DoctorDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final detail = ref.watch(doctorDetailProvider(slug));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.displayName ?? l.doctorsTitle),
        actions: [
          if (detail.valueOrNull != null)
            FavoriteButton(doctorId: detail.requireValue.card.id, slug: detail.requireValue.slug),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncValueView<DoctorDetail>(
        value: detail,
        onRetry: () => ref.invalidate(doctorDetailProvider(slug)),
        data: (d) => _Body(detail: d),
      ),
      bottomNavigationBar: detail.valueOrNull == null
          ? null
          : _ActionBar(detail: detail.requireValue),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final DoctorDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final card = detail.card;
    final reviews = ref.watch(doctorReviewsProvider(detail.slug));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DoctorAvatar(photo: card.photo, name: card.displayName, size: 84),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.displayName, style: text.headlineMedium),
                  if (card.professionalTitleAr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(card.professionalTitleAr, style: text.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 6,
                    children: [
                      DoctorRating(doctor: card, fontSize: 13),
                      if (card.yearsOfExperience != null && card.yearsOfExperience! > 0)
                        MetaChip(
                          icon: Icons.workspace_premium_outlined,
                          label: l.doctorYearsExperience(card.yearsOfExperience!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        if (card.minFee != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: AppRadii.cardRadius),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(l.bookingFee, style: text.titleSmall),
                const Spacer(),
                Text(
                  l.doctorFeeFrom(card.minFee!),
                  style: text.titleMedium?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],

        if (detail.specializations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in detail.specializations)
                Chip(label: Text(s.nameAr), backgroundColor: AppColors.bgSoft),
            ],
          ),
        ],

        if ((detail.bioAr ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(l.doctorAbout),
          const SizedBox(height: AppSpacing.sm),
          Text(detail.bioAr!, style: text.bodyMedium),
        ],

        if (detail.clinics.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(l.doctorClinics),
          const SizedBox(height: AppSpacing.md),
          for (final link in detail.clinics) _ClinicCard(link: link),
        ],

        if (detail.services.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(l.dashboardProfile),
          const SizedBox(height: AppSpacing.sm),
          for (final s in detail.services)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(s.nameAr, style: text.bodyMedium),
              trailing: s.price == null ? null : Text(s.price!, style: text.titleSmall),
            ),
        ],

        const SizedBox(height: AppSpacing.xl),
        _SectionTitle(l.doctorReviews),
        const SizedBox(height: AppSpacing.sm),
        reviews.when(
          loading: () => const Skeleton(height: 72, radius: AppRadii.card),
          error: (_, __) => Text(l.doctorNoReviews, style: text.bodySmall),
          data: (page) => page.isEmpty
              ? Text(l.doctorNoReviews, style: text.bodySmall)
              : Column(
                  children: [
                    for (final r in page.items.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    RatingBadge(rating: r.rating.toDouble(), count: 0),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(child: Text(r.reviewerName, style: text.labelMedium)),
                                  ],
                                ),
                                if (r.comment.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(r.comment, style: text.bodySmall),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({required this.link});

  final DoctorClinicLink link;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final c = link.clinic;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_hospital_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(c.nameAr, style: text.titleSmall)),
                if (link.isPrimary)
                  Chip(
                    label: Text(l.doctorVerified),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.bgSoft,
                  ),
              ],
            ),
            if (c.addressLine.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(c.addressLine, style: text.bodySmall),
            ],
            if (link.consultationFee != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${l.bookingFee}: ${link.consultationFee}',
                style: text.labelMedium?.copyWith(color: AppColors.primary),
              ),
            ],
            if (c.workingHours.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l.doctorWorkingHours, style: text.labelLarge),
              const SizedBox(height: 4),
              for (final h in c.workingHours)
                Text(
                  '${_weekdayName(context, h.weekday)}  ${h.openTime} – ${h.closeTime}',
                  style: text.bodySmall,
                ),
            ],
            if (!link.bookingEnabled) ...[
              const SizedBox(height: AppSpacing.md),
              InfoNote(text: l.doctorBookingUnavailable),
            ],
          ],
        ),
      ),
    );
  }

  /// ISO weekday names, using the platform's own localized list rather than a
  /// hand-written one — Monday is 1 on the backend and index 0 here.
  String _weekdayName(BuildContext context, int isoWeekday) {
    final symbols = MaterialLocalizations.of(context);
    // DateTime.monday == 1, matching the backend's ISO numbering.
    final date = DateTime(2024, 1, 1).add(Duration(days: isoWeekday - 1));
    return symbols.formatFullDate(date).split(RegExp(r'[,،]')).first;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: Theme.of(context).textTheme.titleLarge);
}

/// Call, WhatsApp and Book, pinned to the bottom.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.detail});

  final DoctorDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final contact = detail.card.contact;
    final bookable = detail.anyClinicBookable;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            if (contact.canCall)
              _CircleAction(
                icon: Icons.phone_rounded,
                tooltip: l.doctorCall,
                color: AppColors.primary,
                onTap: () => _open(ref, contact.telUrl!, 'phone'),
              ),
            if (contact.canWhatsapp) ...[
              const SizedBox(width: AppSpacing.sm),
              _CircleAction(
                icon: Icons.chat_rounded,
                tooltip: l.doctorWhatsapp,
                // Green is reserved for WhatsApp and availability by the design
                // tokens' identity rule — this is one of the two places it is
                // allowed.
                color: AppColors.whatsapp,
                onTap: () => _open(ref, contact.whatsappUrl!, 'whatsapp'),
              ),
            ],
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: bookable ? () => showBookingSheet(context, detail) : null,
                child: Text(
                  bookable ? l.doctorBookNow : l.doctorBookingUnavailable,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Open a tel:/wa.me URL the API built, and record the click.
  ///
  /// The tracking call is fired without awaiting and cannot block the launch:
  /// connecting a patient to a clinic matters, an analytics row does not.
  Future<void> _open(WidgetRef ref, String url, String type) async {
    ref
        .read(directoryRepositoryProvider)
        .trackContactClick(
          doctorId: detail.card.id,
          contactType: type,
          clinicId: detail.primaryClinic?.clinic.id,
        );
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pillRadius,
          child: Container(
            // 52 keeps the tap target comfortably above the 48dp minimum.
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadii.pillRadius,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}

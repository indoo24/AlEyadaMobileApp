import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/contact_links.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../bookings/booking_sheet.dart';
import '../favorites/widgets/favorite_button.dart';
import '../home/home_style.dart';
import 'doctor_detail_logic.dart';
import 'models.dart';
import 'providers.dart';
import 'widgets/doctor_profile_sections.dart';
import 'widgets/doctor_reviews_section.dart';
import '../../core/theme/app_palette.dart';

/// A doctor's public profile.
///
/// Only public fields are shown. Nothing here surfaces moderation metadata — no
/// verification status text, no rejection reasons, no internal notes — because
/// the public serializer does not carry them and this screen must not imply
/// otherwise. Every section is drawn from `GET /doctors/{slug}/` (plus the
/// reviews and availability endpoints) and disappears when its data is absent.
class DoctorDetailScreen extends ConsumerStatefulWidget {
  const DoctorDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen> {
  final _scroll = ScrollController();

  /// Whether the hero has scrolled away, so the name moves into the bar.
  final _collapsed = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _collapsed.value = _scroll.hasClients && _scroll.offset > 170);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final detail = ref.watch(doctorDetailProvider(widget.slug));
    final d = detail.valueOrNull;

    if (d == null) {
      return Scaffold(
        backgroundColor: context.palette.page,
        appBar: AppBar(title: Text(l.doctorsTitle)),
        body: AsyncValueView<DoctorDetail>(
          value: detail,
          onRetry: () => ref.invalidate(doctorDetailProvider(widget.slug)),
          data: (_) => const SizedBox.shrink(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.page,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(doctorReviewsProvider(d.slug));
          final hint = availabilityHintClinic(d);
          if (hint != null) {
            ref.invalidate(availabilityProvider((slug: d.slug, clinicId: hint.clinic.id)));
          }
          return ref.refresh(doctorDetailProvider(widget.slug).future);
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: context.palette.heroStart,
              surfaceTintColor: Colors.transparent,
              foregroundColor: Colors.white,
              title: ValueListenableBuilder<bool>(
                valueListenable: _collapsed,
                builder: (_, collapsed, __) => AnimatedOpacity(
                  opacity: collapsed ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    d.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: FavoriteButton(doctorId: d.card.id, slug: d.slug),
                  ),
                ),
              ],
            ),
            // One sliver, not two: a viewport paints earlier slivers on top, which
            // would hide the stats card where it overlaps the hero's edge.
            SliverToBoxAdapter(
              child: Column(
                children: [
                  DoctorHero(detail: d),
                  _Sections(detail: d),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BookingBar(detail: d),
    );
  }
}

/// Everything under the hero, in reading order.
class _Sections extends ConsumerWidget {
  const _Sections({required this.detail});

  final DoctorDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final bookable = bookableClinics(detail);
    final hint = availabilityHintClinic(detail);
    const gap = SizedBox(height: 14);

    final sections = <Widget>[
      if (hint != null)
        _NextAvailableCard(detail: detail, clinic: hint, multipleClinics: bookable.length > 1),
      if (bookable.isEmpty)
        InfoNote(text: l.doctorBookingUnavailable, icon: Icons.phone_in_talk_outlined),
      if (DoctorAboutSection.hasAny(detail)) DoctorAboutSection(detail: detail),
      if (detail.specializations.isNotEmpty) DoctorChipsSection.specialties(detail: detail),
      if (DoctorProfessionalSection.hasAny(detail)) DoctorProfessionalSection(detail: detail),
      if (detail.services.isNotEmpty) DoctorChipsSection.services(detail: detail),
      if (detail.clinics.isNotEmpty)
        _ClinicsBlock(detail: detail, bookableIds: {for (final c in bookable) c.clinic.id}),
      if (DoctorLinksSection.hasAny(detail)) DoctorLinksSection(detail: detail),
      DoctorReviewsSection(detail: detail),
    ];

    final hasStats = DoctorStatsCard.hasAny(detail);
    final content = Column(
      children: [
        if (hasStats) ...[DoctorStatsCard(detail: detail), gap],
        for (var i = 0; i < sections.length; i++) ...[if (i > 0) gap, sections[i]],
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        hasStats ? 0 : AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      // The stats card is pulled up over the hero's rounded bottom edge.
      child: hasStats ? Transform.translate(offset: const Offset(0, -30), child: content) : content,
    );
  }
}

class _ClinicsBlock extends ConsumerWidget {
  const _ClinicsBlock({required this.detail, required this.bookableIds});

  final DoctorDetail detail;
  final Set<String> bookableIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    // Primary clinic first; the rest in the order the API sent.
    final clinics = [...detail.clinics]
      ..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10, top: 4),
          child: Semantics(
            header: true,
            child: Text(
              l.doctorClinics,
              style: context.homeType.sectionTitle.copyWith(fontSize: 17),
            ),
          ),
        ),
        for (var i = 0; i < clinics.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          DoctorClinicCard(
            link: clinics[i],
            bookable: bookableIds.contains(clinics[i].clinic.id),
            onBook: () => showBookingSheet(context, detail, clinicId: clinics[i].clinic.id),
            onCall: clinics[i].clinic.contact.canCall
                ? () => openContact(
                    ref,
                    detail: detail,
                    url: clinics[i].clinic.contact.telUrl!,
                    channel: ContactChannel.phone,
                    clinicId: clinics[i].clinic.id,
                  )
                : null,
          ),
        ],
      ],
    );
  }
}

/// "Next available: Saturday 10 October · 09:00", straight from the
/// availability endpoint for the doctor's primary bookable clinic.
class _NextAvailableCard extends ConsumerWidget {
  const _NextAvailableCard({
    required this.detail,
    required this.clinic,
    required this.multipleClinics,
  });

  final DoctorDetail detail;
  final DoctorClinicLink clinic;
  final bool multipleClinics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final availability = ref.watch(
      availabilityProvider((slug: detail.slug, clinicId: clinic.clinic.id)),
    );

    return availability.when(
      skipLoadingOnRefresh: false,
      loading: () => const Skeleton(height: 68, radius: AppRadii.card),
      // A hint, not a gate: if it cannot be fetched the booking button still works.
      error: (_, __) => const SizedBox.shrink(),
      data: (a) {
        final first = a.bookingEnabled ? firstFreeSlot(a) : null;
        final subtitle = first == null
            ? l.ddNoSlotsShort
            : '${longDayLabel(first.date, locale)}  •  ${first.slot.displayTime}';
        return Material(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(homeCardRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(homeCardRadius),
            onTap: () => showBookingSheet(context, detail, clinicId: clinic.clinic.id),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(homeCardRadius),
                border: Border.all(color: context.palette.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      // Green: the tokens reserve it for availability.
                      color: (first == null ? context.palette.muted : context.palette.success)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      first == null ? Icons.event_busy_outlined : Icons.event_available_rounded,
                      color: first == null ? context.palette.muted : context.palette.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.ddNextAvailable,
                          style: context.homeType.meta.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: context.homeType.cardTitle.copyWith(fontSize: 14.5)),
                        if (multipleClinics)
                          Text(
                            clinic.clinic.nameAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.homeType.meta,
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.palette.muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The sticky bottom bar: starting fee and "book", plus call and WhatsApp.
class _BookingBar extends ConsumerWidget {
  const _BookingBar({required this.detail});

  final DoctorDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final contact = detail.card.contact;
    final bookable = bookableClinics(detail).isNotEmpty;
    if (!bookable && !contact.canCall && !contact.canWhatsapp) return const SizedBox.shrink();

    final call = contact.canCall
        ? () =>
              openContact(ref, detail: detail, url: contact.telUrl!, channel: ContactChannel.phone)
        : null;
    final whatsapp = contact.canWhatsapp
        ? () => openContact(
            ref,
            detail: detail,
            url: contact.whatsappUrl!,
            channel: ContactChannel.whatsapp,
          )
        : null;

    final width = MediaQuery.sizeOf(context).width - 2 * AppSpacing.gutter;
    final roomy = width / MediaQuery.textScalerOf(context).scale(1) >= 330;

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        boxShadow: context.palette.shadowBar,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 12, AppSpacing.gutter, 12),
          child: Row(
            children: [
              if (bookable) ...[
                // The starting fee yields first when the bar is tight (small
                // phone, large text): it is also in the stats card, while the
                // book button must stay readable.
                if (detail.card.minFee != null && roomy) ...[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.ddStatFee, style: context.homeType.feeLabel),
                      Text(
                        l.ddMoney(detail.card.minFee!),
                        style: context.homeType.feeAmount.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showBookingSheet(context, detail),
                    icon: const Icon(Icons.calendar_month_rounded, size: 20),
                    label: Text(l.doctorBookNow, maxLines: 1, overflow: TextOverflow.ellipsis),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      textStyle: context.homeType.button.copyWith(fontSize: 15),
                    ),
                  ),
                ),
                if (call != null) ...[
                  const SizedBox(width: 8),
                  _CircleAction(
                    icon: Icons.phone_rounded,
                    tooltip: l.doctorCall,
                    color: context.palette.primary,
                    onTap: call,
                  ),
                ],
                if (whatsapp != null) ...[
                  const SizedBox(width: 8),
                  _CircleAction(
                    icon: Icons.chat_rounded,
                    tooltip: l.doctorWhatsapp,
                    // Green is reserved for WhatsApp and availability.
                    color: context.palette.whatsappFg,
                    onTap: whatsapp,
                  ),
                ],
              ] else ...[
                if (call != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: call,
                      icon: const Icon(Icons.phone_rounded, size: 20),
                      label: Text(l.doctorCall),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        textStyle: context.homeType.button.copyWith(fontSize: 15),
                      ),
                    ),
                  ),
                if (call != null && whatsapp != null) const SizedBox(width: 8),
                if (whatsapp != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: whatsapp,
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: Text(l.doctorWhatsapp),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.palette.whatsapp,
                        minimumSize: const Size(0, 52),
                        textStyle: context.homeType.button.copyWith(fontSize: 15),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Open a tel:/wa.me URL the API built, and record the click.
///
/// The link must pass [safeContactUri] for its [channel]; one that does not is
/// neither opened nor counted. The tracking call is fired without awaiting and
/// cannot block the launch: connecting a patient to a clinic matters, an
/// analytics row does not.
Future<void> openContact(
  WidgetRef ref, {
  required DoctorDetail detail,
  required String url,
  required ContactChannel channel,
  String? clinicId,
}) async {
  if (safeContactUri(channel, url) == null) return;
  ref
      .read(directoryRepositoryProvider)
      .trackContactClick(
        doctorId: detail.card.id,
        contactType: channel.trackingType,
        clinicId: clinicId ?? detail.primaryClinic?.clinic.id,
      );
  await launchContact(channel, url);
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

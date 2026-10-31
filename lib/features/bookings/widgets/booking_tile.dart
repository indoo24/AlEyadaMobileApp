import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../doctors/doctor_detail_logic.dart';
import '../../doctors/models.dart';
import '../../doctors/providers.dart';
import '../../doctors/widgets/doctor_card_tile.dart';
import '../../home/home_style.dart';
import '../booking_logic.dart';
import '../models.dart';
import '../../../core/theme/app_palette.dart';

/// The pieces My Bookings and Booking Details are built from.
///
/// Every value shown comes from the booking itself (`GET /bookings/`), except a
/// doctor's specialty, which is read from the doctor's public profile through
/// the same cached provider the doctor page uses — one request per doctor, not
/// per card, and nothing at all when the booking carries no doctor slug.

/// The doctor's specialty from their public profile, or null while it loads,
/// when it fails, or when the profile has none.
String? specialtyOf(DoctorDetail? d) {
  if (d == null) return null;
  final primary = d.card.primarySpecialization?.nameAr.trim();
  if (primary != null && primary.isNotEmpty) return primary;
  final title = d.card.professionalTitleAr.trim();
  return title.isEmpty ? null : title;
}

/// The name to show for the doctor of [b].
///
/// The booking's own, when it carries one; otherwise the public profile's — which
/// the screens already load for the specialty — trying `display_name`, then the
/// Arabic, then the English full name. Empty only when neither source has any
/// name at all.
String doctorNameOf(PatientBooking b, DoctorDetail? profile) {
  final own = b.doctorName.trim();
  if (own.isNotEmpty) return own;
  final card = profile?.card;
  if (card == null) return '';
  for (final name in [card.displayName, card.fullNameAr, card.fullNameEn ?? '']) {
    if (name.trim().isNotEmpty) return name.trim();
  }
  return '';
}

/// The photo to show for the doctor of [b]: the booking's, else the profile's —
/// as an absolute URL — or null when there is none (the avatar then shows an
/// initial, or a doctor icon when there is no name either).
String? doctorPhotoOf(PatientBooking b, DoctorDetail? profile) {
  final own = (b.doctorPhoto ?? '').trim();
  if (own.isNotEmpty) return own;
  return resolveMediaUrl(profile?.card.photo);
}

/// The public profile behind a booking, when there is a slug to look it up by.
AsyncValue<DoctorDetail>? doctorOf(WidgetRef ref, PatientBooking b) =>
    b.doctorSlug.isEmpty ? null : ref.watch(doctorDetailProvider(b.doctorSlug));

/// A countdown label, or null when there is nothing honest to say.
String? countdownLabel(L l, PatientBooking b, DateTime nowUtc) {
  final c = countdownTo(b.startAt, b.endAt, nowUtc);
  if (c == null) return null;
  return switch (c.unit) {
    CountdownUnit.now => l.mbNow,
    CountdownUnit.minutes => l.mbInMinutes(c.value),
    CountdownUnit.hours => l.mbInHours(c.value),
    CountdownUnit.days => l.mbInDays(c.value),
  };
}

/// The visual identity of each status: a label, an icon, and a restrained
/// colour pair. The label and icon carry the meaning; colour only echoes it.
({String label, IconData icon, Color fg, Color bg}) statusStyle(
  L l,
  AppPalette p,
  BookingStatus s,
) => switch (s) {
  BookingStatus.pending => (
    label: l.statusPending,
    icon: Icons.hourglass_top_rounded,
    fg: p.toneWarning.fg,
    bg: p.toneWarning.bg,
  ),
  BookingStatus.confirmed => (
    label: l.statusConfirmed,
    icon: Icons.check_circle_rounded,
    fg: p.toneSuccess.fg,
    bg: p.toneSuccess.bg,
  ),
  BookingStatus.completed => (
    label: l.statusCompleted,
    icon: Icons.task_alt_rounded,
    fg: p.toneInfo.fg,
    bg: p.toneInfo.bg,
  ),
  BookingStatus.cancelledByPatient || BookingStatus.cancelledByClinic => (
    label: l.statusCancelled,
    icon: Icons.cancel_rounded,
    fg: p.toneDanger.fg,
    bg: p.toneDanger.bg,
  ),
  BookingStatus.noShow => (
    label: l.statusNoShow,
    icon: Icons.person_off_outlined,
    fg: p.toneCaution.fg,
    bg: p.toneCaution.bg,
  ),
  BookingStatus.rescheduled => (
    label: l.statusRescheduled,
    icon: Icons.update_rounded,
    fg: p.toneNeutral.fg,
    bg: p.toneNeutral.bg,
  ),
  BookingStatus.expired => (
    label: l.statusExpired,
    icon: Icons.schedule_rounded,
    fg: p.toneNeutral.fg,
    bg: p.toneNeutral.bg,
  ),
  BookingStatus.unknown => (
    label: '—',
    icon: Icons.help_outline_rounded,
    fg: p.toneNeutral.fg,
    bg: p.toneNeutral.bg,
  ),
};

/// A booking's state as a pill: icon, label, tinted background.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final st = statusStyle(L.of(context), context.palette, status);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: st.bg, borderRadius: AppRadii.pillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(st.icon, size: 13, color: st.fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              st.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: st.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// The day-of-month block at the start of a booking's date row.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, required this.locale, this.dark = false});

  final String date;
  final String locale;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final p = calendarParts(date, locale);
    final fg = dark ? Colors.white : context.palette.primary;
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.14) : context.palette.pageSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: p == null
          ? Icon(Icons.event_rounded, color: fg)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.day,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    height: 1.1,
                  ),
                ),
                Text(
                  p.month,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white70 : context.palette.muted,
                  ),
                ),
              ],
            ),
    );
  }
}

/// "السبت  •  13:00" — the clinic-local day and the backend's own time label.
String dayAndTime(PatientBooking b, String locale) {
  final p = calendarParts(b.displayDate, locale);
  final day = p?.weekday ?? b.displayDate;
  return b.displayTime.isEmpty ? day : '$day  •  ${b.displayTime}';
}

/// One appointment in the list.
class BookingTile extends ConsumerWidget {
  const BookingTile({super.key, required this.booking, this.onTap});

  final PatientBooking booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final b = booking;
    final profile = doctorOf(ref, b)?.valueOrNull;
    final specialty = specialtyOf(profile);
    final doctorName = doctorNameOf(b, profile);
    final address = (b.clinicAddress ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: context.palette.border),
        boxShadow: context.palette.shadowSoft,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(homeCardRadius),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DoctorAvatar(
                      photo: doctorPhotoOf(b, profile),
                      name: doctorName,
                      size: 46,
                      radius: 23,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.homeType.doctorName,
                          ),
                          if (specialty != null)
                            Text(
                              specialty,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.homeType.meta,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: BookingStatusChip(status: b.status)),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: context.palette.border),
                ),
                Row(
                  children: [
                    _DateBlock(date: b.displayDate, locale: locale),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayAndTime(b, locale),
                            style: context.homeType.cardTitle.copyWith(fontSize: 15),
                          ),
                          if (b.clinicName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            _IconText(icon: Icons.local_hospital_outlined, text: b.clinicName),
                          ],
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            _IconText(icon: Icons.location_on_outlined, text: address),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.palette.muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: color ?? context.palette.muted),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.homeType.meta.copyWith(fontSize: 12.5, color: color),
        ),
      ),
    ],
  );
}

/// The soonest upcoming appointment, featured at the top of the list.
class NextBookingCard extends ConsumerWidget {
  const NextBookingCard({
    super.key,
    required this.booking,
    required this.nowUtc,
    required this.onOpen,
  });

  final PatientBooking booking;
  final DateTime nowUtc;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final b = booking;
    final profile = doctorOf(ref, b)?.valueOrNull;
    final specialty = specialtyOf(profile);
    final doctorName = doctorNameOf(b, profile);
    final countdown = countdownLabel(l, b, nowUtc);
    final parts = calendarParts(b.displayDate, locale);

    return Semantics(
      container: true,
      label: l.mbNextAppointment,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [context.palette.heroStart, context.palette.heroEnd],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: context.palette.shadowFloat,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l.mbNextAppointment,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (countdown != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: AppRadii.pillRadius,
                      ),
                      child: Text(
                        countdown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: DoctorAvatar(
                    photo: doctorPhotoOf(b, profile),
                    name: doctorName,
                    size: 44,
                    radius: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (specialty != null)
                        Text(
                          specialty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
                if (b.status != BookingStatus.confirmed) ...[
                  const SizedBox(width: 8),
                  Flexible(child: BookingStatusChip(status: b.status)),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _DateBlock(date: b.displayDate, locale: locale, dark: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parts?.weekday ?? b.displayDate,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        Text(
                          b.displayTime,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        if (b.clinicName.isNotEmpty)
                          _IconText(
                            icon: Icons.local_hospital_outlined,
                            text: b.clinicName,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: context.palette.primary,
                  minimumSize: const Size(0, 46),
                  textStyle: context.homeType.button.copyWith(fontSize: 14),
                ),
                child: Text(l.mbViewDetails, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A placeholder in the shape of a [BookingTile].
class BookingCardSkeleton extends StatelessWidget {
  const BookingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(homeCardRadius),
      border: Border.all(color: context.palette.border),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Skeleton(height: 46, width: 46, radius: 23),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 140),
                  SizedBox(height: 6),
                  Skeleton(height: 11, width: 90),
                ],
              ),
            ),
            Skeleton(height: 22, width: 64, radius: AppRadii.pill),
          ],
        ),
        SizedBox(height: 24),
        Row(
          children: [
            Skeleton(height: 52, width: 54, radius: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 150),
                  SizedBox(height: 6),
                  Skeleton(height: 11, width: 110),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

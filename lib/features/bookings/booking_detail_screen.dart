import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/contact_links.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctor_detail_logic.dart';
import '../doctors/doctor_detail_screen.dart' show openContact;
import '../doctors/models.dart';
import '../doctors/providers.dart' show doctorDetailProvider;
import '../doctors/widgets/doctor_card_tile.dart';
import '../doctors/widgets/doctor_profile_sections.dart' show openExternalLink;
import '../doctors/widgets/doctor_rating.dart';
import '../home/home_style.dart';
import 'booking_logic.dart';
import 'models.dart';
import 'providers.dart';
import 'widgets/booking_tile.dart';
import '../../core/theme/app_palette.dart';

/// One appointment, with the actions the *server* says are available.
///
/// Everything about the appointment comes from `GET /bookings/{id}/`. The
/// doctor's specialty and rating, and the clinic's map link and phone, come from
/// the doctor's public profile (`GET /doctors/{slug}/`, the cached provider the
/// doctor page uses) — and only when the booking's clinic can be found on it
/// unambiguously. Anything missing is simply not shown.
///
/// The cancel button appears when `can_cancel` is true and not otherwise; the
/// app never recomputes the cancellation window.
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final watched = ref.watch(bookingDetailProvider(widget.id));
    // A reload means the account changed underneath the screen (a refresh or a
    // retry is a "refresh", not a reload). The value it still carries belongs to
    // the previous account, so it is not drawn — not even the action bar.
    final booking = watched.isReloading ? const AsyncLoading<PatientBooking>() : watched;
    // An error can still carry an older value; the bar is for a loaded booking only.
    final b = booking is AsyncData<PatientBooking> ? booking.value : null;

    return Scaffold(
      backgroundColor: context.palette.page,
      appBar: AppBar(
        title: Text(l.bdTitle),
        backgroundColor: context.palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: AsyncValueView<PatientBooking>(
        value: booking,
        onRetry: () => ref.invalidate(bookingDetailProvider(widget.id)),
        loading: const _LoadingDetail(),
        data: (b) => RefreshIndicator(
          onRefresh: () async {
            if (b.doctorSlug.isNotEmpty) ref.invalidate(doctorDetailProvider(b.doctorSlug));
            ref.invalidate(bookingDetailProvider(widget.id));
            await ref.read(bookingDetailProvider(widget.id).future);
          },
          child: _Content(booking: b, nowUtc: ref.watch(bookingsClockProvider)()),
        ),
      ),
      bottomNavigationBar: b == null
          ? null
          : _ActionBar(booking: b, cancelling: _cancelling, onCancel: () => _cancel(b)),
    );
  }

  Future<void> _cancel(PatientBooking b) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    // Null means the dialog was dismissed; an empty string is "no reason given".
    if (reason == null || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .cancel(b.id, reason: reason.isEmpty ? null : reason);
      ref.invalidate(bookingDetailProvider(widget.id));
      ref.invalidate(myBookingsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l.bookingCancelled)));
    } on ApiException catch (e) {
      // e.g. 422 inside the clinic's cutoff window. The server's own message
      // explains it; the clinic's phone stays one tap away on this screen.
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(messageForError(context, e))));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

/// The doctor's profile and the booking's clinic on it, when both are known.
({DoctorDetail? doctor, DoctorClinicLink? clinic}) _profileOf(WidgetRef ref, PatientBooking b) {
  final doctor = doctorOf(ref, b)?.valueOrNull;
  if (doctor == null) return (doctor: null, clinic: null);
  final clinic = matchClinic<DoctorClinicLink>(
    doctor.clinics,
    idOf: (c) => c.clinic.id,
    nameOf: (c) => c.clinic.nameAr,
    clinicId: b.clinicId,
    clinicName: b.clinicName,
  );
  return (doctor: doctor, clinic: clinic);
}

/// The clinic's phone: its own, or — for a doctor with a single clinic — the
/// doctor's contact (which the backend already resolves to the clinic number
/// first). Never another clinic's number.
ContactInfo? _contactFor(DoctorDetail? doctor, DoctorClinicLink? clinic) {
  final own = clinic?.clinic.contact;
  if (own != null && (own.canCall || own.canWhatsapp)) return own;
  if (doctor != null && clinic != null && doctor.clinics.length == 1) {
    final c = doctor.card.contact;
    if (c.canCall || c.canWhatsapp) return c;
  }
  return null;
}

Uri? _mapFor(DoctorClinicLink? link) {
  final c = link?.clinic;
  if (c == null) return null;
  if (c.mapsUri != null) return c.mapsUri;
  if (c.latitude != null && c.longitude != null) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${c.latitude},${c.longitude}',
    });
  }
  return null;
}

class _Content extends ConsumerWidget {
  const _Content({required this.booking, required this.nowUtc});

  final PatientBooking booking;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final b = booking;
    final profile = _profileOf(ref, b);
    final upcoming = sectionFor(b, nowUtc) == BookingsTab.upcoming;
    const gap = SizedBox(height: 14);

    final notice = _cancellationNotice(context, l, b, upcoming);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 16, AppSpacing.gutter, 28),
      children: [
        _DoctorHeader(booking: b, doctor: profile.doctor),
        gap,
        _AppointmentCard(booking: b, nowUtc: nowUtc, upcoming: upcoming),
        if (notice != null) ...[gap, notice],
        gap,
        _InfoCard(
          booking: b,
          doctorName: doctorNameOf(b, profile.doctor),
          specialty: specialtyOf(profile.doctor),
        ),
        if (b.clinicName.isNotEmpty || (b.clinicAddress ?? '').trim().isNotEmpty) ...[
          gap,
          _ClinicCard(booking: b, doctor: profile.doctor, link: profile.clinic),
        ],
        gap,
        _TimelineCard(booking: b, nowUtc: nowUtc),
      ],
    );
  }

  Widget? _cancellationNotice(BuildContext context, L l, PatientBooking b, bool upcoming) {
    final p = context.palette;
    if (b.status.isCancelled && b.cancellationReason.trim().isNotEmpty) {
      return _Notice(
        icon: Icons.info_outline_rounded,
        color: p.toneDanger.fg,
        title: l.bdCancellationReason,
        text: b.cancellationReason.trim(),
      );
    }
    if (!upcoming) return null;
    final cutoff = b.cancellationCutoffAt;
    if (b.canCancel && cutoff != null) {
      // Expressed relative to the appointment: a duration between two UTC
      // instants, true in any timezone.
      final hours = b.startAt.difference(cutoff).inHours;
      if (hours < 1) return null;
      return _Notice(
        icon: Icons.event_repeat_rounded,
        color: p.primary,
        text: l.bdCancelBefore(hours),
      );
    }
    if (!b.canCancel && cutoff != null) {
      return _Notice(
        icon: Icons.lock_clock_outlined,
        color: p.toneWarning.fg,
        text: l.bdCancelClosed,
      );
    }
    return null;
  }
}

/// A white titled card — the same unit as the doctor profile's sections.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.title, this.icon});

  final String? title;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(homeCardRadius),
      border: Border.all(color: context.palette.border),
      boxShadow: context.palette.shadowSoft,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: context.palette.pageSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 17, color: context.palette.primary),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title!, style: context.homeType.sectionTitle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    ),
  );
}

class _DoctorHeader extends StatelessWidget {
  const _DoctorHeader({required this.booking, required this.doctor});

  final PatientBooking booking;
  final DoctorDetail? doctor;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final b = booking;
    final specialty = specialtyOf(doctor);
    final doctorName = doctorNameOf(b, doctor);
    final canOpen = b.doctorSlug.isNotEmpty;

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
          borderRadius: BorderRadius.circular(homeCardRadius),
          onTap: canOpen ? () => context.push(Routes.doctorPath(b.doctorSlug)) : null,
          child: Semantics(
            button: canOpen,
            hint: canOpen ? l.bdViewDoctor : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  DoctorAvatar(
                    photo: doctorPhotoOf(b, doctor),
                    name: doctorName,
                    size: 56,
                    radius: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doctorName, style: context.homeType.doctorName.copyWith(fontSize: 16)),
                        if (specialty != null)
                          Text(
                            specialty,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.homeType.meta.copyWith(fontSize: 12.5),
                          ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            BookingStatusChip(status: b.status),
                            if (doctor != null && doctor!.card.hasRating)
                              DoctorRating(doctor: doctor!.card, fontSize: 12),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canOpen) Icon(Icons.chevron_right_rounded, color: context.palette.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The appointment itself — the one thing the patient opened this page for.
class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.booking, required this.nowUtc, required this.upcoming});

  final PatientBooking booking;
  final DateTime nowUtc;
  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final b = booking;
    final parsed = DateTime.tryParse(b.displayDate);
    final parts = calendarParts(b.displayDate, locale);
    final countdown = upcoming ? countdownLabel(l, b, nowUtc) : null;
    final fullDate = parts == null ? b.displayDate : '${parts.day} ${parts.month} ${parsed!.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: upcoming
            ? LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [context.palette.heroStart, context.palette.heroEnd],
              )
            : null,
        color: upcoming ? null : context.palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: upcoming
            ? (context.palette.isDark ? Border.all(color: context.palette.heroEdge) : null)
            : Border.all(color: context.palette.border),
        boxShadow: upcoming ? context.palette.shadowFloat : context.palette.shadowSoft,
      ),
      child: Builder(
        builder: (context) {
          final fg = upcoming ? Colors.white : context.palette.heading;
          final sub = upcoming ? Colors.white.withValues(alpha: 0.8) : context.palette.muted;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note_rounded, size: 18, color: fg),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.bdYourAppointment,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg),
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
              if (parts != null) Text(parts.weekday, style: TextStyle(fontSize: 14, color: sub)),
              Text(
                fullDate,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg, height: 1.3),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 20, color: fg),
                      const SizedBox(width: 6),
                      Text(
                        // The backend's clinic-local label, shown as sent.
                        b.displayTime,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: fg),
                      ),
                    ],
                  ),
                  if (b.durationMinutes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: upcoming
                            ? Colors.white.withValues(alpha: 0.12)
                            : context.palette.pageSoft,
                        borderRadius: AppRadii.pillRadius,
                      ),
                      child: Text(
                        l.bkDuration(b.durationMinutes),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
                      ),
                    ),
                ],
              ),
              if (b.clinicName.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.local_hospital_outlined, size: 16, color: sub),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(b.clinicName, style: TextStyle(fontSize: 13, color: sub)),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text, this.title});

  final IconData icon;
  final Color color;
  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: AppRadii.inputRadius,
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
                ),
              Text(text, style: TextStyle(fontSize: 13, color: context.palette.body, height: 1.6)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.booking, required this.doctorName, required this.specialty});

  final PatientBooking booking;
  final String doctorName;
  final String? specialty;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final b = booking;
    final payment = PaymentState.parse(b.paymentStatus);

    final rows = <(String, String, bool)>[
      if (doctorName.isNotEmpty) (l.bkDoctor, doctorName, false),
      if (specialty != null) (l.bdSpecialty, specialty!, false),
      if (b.clinicName.isNotEmpty) (l.bookingClinic, b.clinicName, false),
      if (b.displayDate.isNotEmpty) (l.bdDate, longDayLabel(b.displayDate, locale), false),
      if (b.displayTime.isNotEmpty) (l.bkTime, b.displayTime, true),
      if (b.durationMinutes > 0) (l.bkDurationLabel, l.bkDuration(b.durationMinutes), false),
      (l.bookingVisitType, _visitLabel(l, b.visitType), false),
      if (b.feeSnapshot != null) (l.bdFee, l.ddMoney(b.feeSnapshot!), false),
      if (b.paymentRequired && payment != PaymentState.unknown)
        (l.bdPayment, _paymentLabel(l, payment), false),
      if ((b.reasonForVisit ?? '').trim().isNotEmpty) (l.bdReason, b.reasonForVisit!.trim(), false),
      if ((b.notesForDoctor ?? '').trim().isNotEmpty) (l.bdNotes, b.notesForDoctor!.trim(), false),
    ];

    return _Card(
      title: l.bdInfoTitle,
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 18, color: context.palette.border),
            _InfoRow(label: rows[i].$1, value: rows[i].$2, ltr: rows[i].$3),
          ],
        ],
      ),
    );
  }

  static String _visitLabel(L l, VisitType t) => switch (t) {
    VisitType.firstVisit => l.bookingVisitFirst,
    VisitType.followUp => l.bookingVisitFollowUp,
    VisitType.consultation => l.bdVisitConsultation,
    VisitType.procedure => l.bdVisitProcedure,
    VisitType.custom => l.bdVisitCustom,
  };

  static String _paymentLabel(L l, PaymentState p) => switch (p) {
    PaymentState.notRequired => l.bdPayNotRequired,
    PaymentState.proofPending => l.bdPayProofPending,
    PaymentState.proofUploaded => l.bdPayProofUploaded,
    PaymentState.accepted => l.bdPayAccepted,
    PaymentState.rejected => l.bdPayRejected,
    PaymentState.unknown => '',
  };
}

/// Label above the value when the value is long text, beside it otherwise.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.ltr = false});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(label, style: context.homeType.meta.copyWith(fontSize: 12.5));
    final valueText = Text(
      value,
      textDirection: ltr ? TextDirection.ltr : null,
      style: context.homeType.cardTitle.copyWith(fontSize: 13.5),
    );
    if (value.length > 32 || value.contains('\n')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelText, const SizedBox(height: 4), valueText],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: labelText),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Align(alignment: AlignmentDirectional.centerEnd, child: valueText),
        ),
      ],
    );
  }
}

class _ClinicCard extends ConsumerWidget {
  const _ClinicCard({required this.booking, required this.doctor, required this.link});

  final PatientBooking booking;
  final DoctorDetail? doctor;
  final DoctorClinicLink? link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final b = booking;
    final c = link?.clinic;
    final address = (b.clinicAddress ?? '').trim();
    final area = [c?.area?.nameAr, c?.city?.nameAr].where((p) => (p ?? '').isNotEmpty).join('، ');
    final landmark = (c?.landmark ?? '').trim();
    final map = _mapFor(link);
    final contact = _contactFor(doctor, link);

    void track(String url, ContactChannel channel) =>
        openContact(ref, detail: doctor!, url: url, channel: channel, clinicId: c?.id);

    return _Card(
      title: l.bdClinicTitle,
      icon: Icons.local_hospital_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b.clinicName.isNotEmpty)
            Text(b.clinicName, style: context.homeType.cardTitle.copyWith(fontSize: 15)),
          if (area.isNotEmpty) Text(area, style: context.homeType.meta),
          if (address.isNotEmpty || landmark.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.location_on_outlined, size: 17, color: context.palette.muted),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [address, landmark].where((s) => s.isNotEmpty).join(' — '),
                    style: TextStyle(fontSize: 13, color: context.palette.body, height: 1.6),
                  ),
                ),
              ],
            ),
          ],
          if (map != null || (contact?.canCall ?? false) || (contact?.canWhatsapp ?? false)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (map != null)
                  _ActionPill(
                    icon: Icons.map_outlined,
                    label: l.ddOpenLocation,
                    color: context.palette.primary,
                    onTap: () => openExternalLink(context, map),
                  ),
                if (contact?.canCall ?? false)
                  _ActionPill(
                    icon: Icons.phone_rounded,
                    label: l.doctorCall,
                    color: context.palette.primary,
                    onTap: () => track(contact!.telUrl!, ContactChannel.phone),
                  ),
                if (contact?.canWhatsapp ?? false)
                  _ActionPill(
                    icon: Icons.chat_rounded,
                    label: l.doctorWhatsapp,
                    // Green is reserved for WhatsApp by the design tokens.
                    color: context.palette.whatsappFg,
                    onTap: () => track(contact!.whatsappUrl!, ContactChannel.whatsapp),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.05),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: context.homeType.button.copyWith(fontSize: 13),
    ),
  );
}

/// Where the booking stands, built only from what the API records: when it was
/// made, the appointment, and the current status. No step gets a time the
/// server never sent.
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.booking, required this.nowUtc});

  final PatientBooking booking;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final b = booking;
    final steps = timelineFor(b, nowUtc);

    String? created() {
      final c = b.createdAt?.toLocal();
      if (c == null) return null;
      return '${c.day} ${DateFormat.MMMM(locale).format(c)} ${c.year}';
    }

    String title(TimelineStepKind k) => switch (k) {
      TimelineStepKind.booked => l.bdStepBooked,
      TimelineStepKind.awaiting => l.bdStepAwaiting,
      TimelineStepKind.confirmed => l.bdStepConfirmed,
      TimelineStepKind.appointment => l.bdStepAppointment,
      TimelineStepKind.outcome => switch (b.status) {
        BookingStatus.completed => l.bdStepCompleted,
        BookingStatus.noShow => l.bdStepNoShow,
        BookingStatus.cancelledByPatient => l.bdStepCancelledByPatient,
        BookingStatus.cancelledByClinic => l.bdStepCancelledByClinic,
        BookingStatus.expired => l.bdStepExpired,
        BookingStatus.rescheduled => l.bdStepRescheduled,
        _ => statusStyle(l, context.palette, b.status).label,
      },
    };

    String? subtitle(TimelineStepKind k) => switch (k) {
      TimelineStepKind.booked => created(),
      TimelineStepKind.appointment => dayAndTime(b, locale),
      _ => null,
    };

    return _Card(
      title: l.bdTimelineTitle,
      icon: Icons.timeline_rounded,
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepRow(
              title: title(steps[i].kind),
              subtitle: subtitle(steps[i].kind),
              state: steps[i].state,
              last: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.last,
  });

  final String title;
  final String? subtitle;
  final TimelineState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      TimelineState.done => (context.palette.toneSuccess.fg, Icons.check_rounded),
      TimelineState.current => (context.palette.primary, Icons.radio_button_checked_rounded),
      TimelineState.upcoming => (context.palette.border, Icons.circle_outlined),
      TimelineState.failed => (context.palette.toneDanger.fg, Icons.close_rounded),
    };
    final filled = state == TimelineState.done || state == TimelineState.failed;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: filled ? color : context.palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  // On the filled circle: white in light; in dark the circle is a pale tone,
                  // so the glyph is the dark page colour instead.
                  child: Icon(
                    icon,
                    size: 14,
                    color: filled
                        ? (context.palette.isDark ? context.palette.page : Colors.white)
                        : color,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: filled ? color.withValues(alpha: 0.4) : context.palette.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.homeType.cardTitle.copyWith(
                      fontSize: 13.5,
                      color: state == TimelineState.upcoming
                          ? context.palette.muted
                          : context.palette.heading,
                    ),
                  ),
                  if (subtitle != null) Text(subtitle!, style: context.homeType.meta),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sticky bottom bar. What it offers depends on where the booking stands
/// and on what the server allows — never a button that cannot work.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.booking, required this.cancelling, required this.onCancel});

  final PatientBooking booking;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final b = booking;
    final now = ref.watch(bookingsClockProvider)();
    final upcoming = sectionFor(b, now) == BookingsTab.upcoming;
    final profile = _profileOf(ref, b);
    final contact = _contactFor(profile.doctor, profile.clinic);

    final buttons = <Widget>[];
    if (upcoming) {
      if (b.canCancel) {
        buttons.add(
          Expanded(
            child: OutlinedButton(
              onPressed: cancelling ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.palette.danger,
                side: BorderSide(color: context.palette.danger),
                minimumSize: const Size(0, 52),
                textStyle: context.homeType.button.copyWith(fontSize: 14.5),
              ),
              child: cancelling
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Text(l.bdCancelConfirm, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        );
      }
      if (contact != null && contact.canCall && profile.doctor != null) {
        if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
        buttons.add(
          Expanded(
            child: FilledButton.icon(
              onPressed: () => openContact(
                ref,
                detail: profile.doctor!,
                url: contact.telUrl!,
                channel: ContactChannel.phone,
                clinicId: profile.clinic?.clinic.id,
              ),
              icon: const Icon(Icons.phone_rounded, size: 20),
              label: Text(l.bdCallClinic, maxLines: 1, overflow: TextOverflow.ellipsis),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                textStyle: context.homeType.button.copyWith(fontSize: 14.5),
              ),
            ),
          ),
        );
      }
    } else if (b.doctorSlug.isNotEmpty) {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(Routes.doctorPath(b.doctorSlug)),
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            label: Text(
              b.status.isCancelled ? l.bdBookNew : l.bdBookAgain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              textStyle: context.homeType.button.copyWith(fontSize: 14.5),
            ),
          ),
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        boxShadow: context.palette.shadowBar,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 12, AppSpacing.gutter, 12),
          child: Row(children: buttons),
        ),
      ),
    );
  }
}

/// Confirm a cancellation. Owns its text controller, so it is disposed with the
/// dialog — not while the closing animation is still drawing the field.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AlertDialog(
      icon: Icon(Icons.event_busy_rounded, color: context.palette.danger),
      title: Text(l.bookingCancelTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.bookingCancelBody, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l.bookingCancelReason,
              controller: _reason,
              maxLines: 2,
              private: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(l.bdCancelKeep),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: context.palette.dangerFill,
            minimumSize: const Size(100, 44),
            textStyle: context.homeType.button.copyWith(fontSize: 14),
          ),
          child: Text(l.bdCancelConfirm),
        ),
      ],
    );
  }
}

class _LoadingDetail extends StatelessWidget {
  const _LoadingDetail();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 16, AppSpacing.gutter, 28),
    children: const [
      Skeleton(height: 86, radius: homeCardRadius),
      SizedBox(height: 14),
      Skeleton(height: 170, radius: 20),
      SizedBox(height: 14),
      Skeleton(height: 260, radius: homeCardRadius),
    ],
  );
}

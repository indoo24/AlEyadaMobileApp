import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctor_detail_logic.dart';
import '../doctors/doctor_detail_screen.dart' show openContact;
import '../doctors/models.dart';
import '../doctors/providers.dart' show doctorDetailProvider;
import '../doctors/widgets/doctor_card_tile.dart';
import '../doctors/widgets/doctor_profile_sections.dart' show openExternalLink, profileNavy;
import '../doctors/widgets/doctor_rating.dart';
import '../home/home_style.dart';
import 'booking_logic.dart';
import 'models.dart';
import 'providers.dart';
import 'widgets/booking_tile.dart';

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
    final booking = ref.watch(bookingDetailProvider(widget.id));
    final b = booking.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l.bdTitle),
        backgroundColor: AppColors.surface,
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

    final notice = _cancellationNotice(l, b, upcoming);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 16, AppSpacing.gutter, 28),
      children: [
        _DoctorHeader(booking: b, doctor: profile.doctor),
        gap,
        _AppointmentCard(booking: b, nowUtc: nowUtc, upcoming: upcoming),
        if (notice != null) ...[gap, notice],
        gap,
        _InfoCard(booking: b, specialty: specialtyOf(profile.doctor)),
        if (b.clinicName.isNotEmpty || (b.clinicAddress ?? '').trim().isNotEmpty) ...[
          gap,
          _ClinicCard(booking: b, doctor: profile.doctor, link: profile.clinic),
        ],
        gap,
        _TimelineCard(booking: b, nowUtc: nowUtc),
      ],
    );
  }

  Widget? _cancellationNotice(L l, PatientBooking b, bool upcoming) {
    if (b.status.isCancelled && b.cancellationReason.trim().isNotEmpty) {
      return _Notice(
        icon: Icons.info_outline_rounded,
        color: const Color(0xFFB91C1C),
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
        color: AppColors.primary,
        text: l.bdCancelBefore(hours),
      );
    }
    if (!b.canCancel && cutoff != null) {
      return _Notice(
        icon: Icons.lock_clock_outlined,
        color: const Color(0xFFB45309),
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
          if (title != null) ...[
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
                  child: Semantics(header: true, child: Text(title!, style: HomeType.sectionTitle)),
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
    final canOpen = b.doctorSlug.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
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
                  DoctorAvatar(photo: b.doctorPhoto, name: b.doctorName, size: 56, radius: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.doctorName, style: HomeType.doctorName.copyWith(fontSize: 16)),
                        if (specialty != null)
                          Text(
                            specialty,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HomeType.meta.copyWith(fontSize: 12.5),
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
                  if (canOpen) const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
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
            ? const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [profileNavy, Color(0xFF0A4A9C)],
              )
            : null,
        color: upcoming ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: upcoming ? null : Border.all(color: AppColors.border),
        boxShadow: upcoming ? AppShadows.float : AppShadows.soft,
      ),
      child: Builder(
        builder: (context) {
          final fg = upcoming ? Colors.white : AppColors.navy;
          final sub = upcoming ? Colors.white.withValues(alpha: 0.8) : AppColors.muted;
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
                        color: upcoming ? Colors.white.withValues(alpha: 0.12) : AppColors.bgSoft,
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
              Text(text, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.6)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.booking, required this.specialty});

  final PatientBooking booking;
  final String? specialty;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final b = booking;
    final payment = PaymentState.parse(b.paymentStatus);

    final rows = <(String, String, bool)>[
      (l.bkDoctor, b.doctorName, false),
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
            if (i > 0) const Divider(height: 18, color: AppColors.border),
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
    final labelText = Text(label, style: HomeType.meta.copyWith(fontSize: 12.5));
    final valueText = Text(
      value,
      textDirection: ltr ? TextDirection.ltr : null,
      style: HomeType.cardTitle.copyWith(fontSize: 13.5),
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

    void track(String url, String type) =>
        openContact(ref, detail: doctor!, url: url, type: type, clinicId: c?.id);

    return _Card(
      title: l.bdClinicTitle,
      icon: Icons.local_hospital_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (b.clinicName.isNotEmpty)
            Text(b.clinicName, style: HomeType.cardTitle.copyWith(fontSize: 15)),
          if (area.isNotEmpty) Text(area, style: HomeType.meta),
          if (address.isNotEmpty || landmark.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.location_on_outlined, size: 17, color: AppColors.muted),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [address, landmark].where((s) => s.isNotEmpty).join(' — '),
                    style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.6),
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
                    color: AppColors.primary,
                    onTap: () => openExternalLink(context, map),
                  ),
                if (contact?.canCall ?? false)
                  _ActionPill(
                    icon: Icons.phone_rounded,
                    label: l.doctorCall,
                    color: AppColors.primary,
                    onTap: () => track(contact!.telUrl!, 'phone'),
                  ),
                if (contact?.canWhatsapp ?? false)
                  _ActionPill(
                    icon: Icons.chat_rounded,
                    label: l.doctorWhatsapp,
                    // Green is reserved for WhatsApp by the design tokens.
                    color: AppColors.whatsapp,
                    onTap: () => track(contact!.whatsappUrl!, 'whatsapp'),
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
      textStyle: HomeType.button.copyWith(fontSize: 13),
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
        _ => statusStyle(l, b.status).label,
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
      TimelineState.done => (const Color(0xFF15803D), Icons.check_rounded),
      TimelineState.current => (AppColors.primary, Icons.radio_button_checked_rounded),
      TimelineState.upcoming => (AppColors.border, Icons.circle_outlined),
      TimelineState.failed => (const Color(0xFFB91C1C), Icons.close_rounded),
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
                    color: filled ? color : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 14, color: filled ? Colors.white : color),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: filled ? color.withValues(alpha: 0.4) : AppColors.border,
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
                    style: HomeType.cardTitle.copyWith(
                      fontSize: 13.5,
                      color: state == TimelineState.upcoming ? AppColors.muted : AppColors.navy,
                    ),
                  ),
                  if (subtitle != null) Text(subtitle!, style: HomeType.meta),
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
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size(0, 52),
                textStyle: HomeType.button.copyWith(fontSize: 14.5),
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
                type: 'phone',
                clinicId: profile.clinic?.clinic.id,
              ),
              icon: const Icon(Icons.phone_rounded, size: 20),
              label: Text(l.bdCallClinic, maxLines: 1, overflow: TextOverflow.ellipsis),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                textStyle: HomeType.button.copyWith(fontSize: 14.5),
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
              textStyle: HomeType.button.copyWith(fontSize: 14.5),
            ),
          ),
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Color(0x140F172A), blurRadius: 20, offset: Offset(0, -4))],
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
      icon: const Icon(Icons.event_busy_rounded, color: AppColors.danger),
      title: Text(l.bookingCancelTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.bookingCancelBody, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(label: l.bookingCancelReason, controller: _reason, maxLines: 2),
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
            backgroundColor: AppColors.danger,
            minimumSize: const Size(100, 44),
            textStyle: HomeType.button.copyWith(fontSize: 14),
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

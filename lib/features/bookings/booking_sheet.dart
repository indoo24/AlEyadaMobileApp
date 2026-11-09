import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/contact_links.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/doctor_detail_logic.dart';
import '../doctors/models.dart';
import '../doctors/providers.dart';
import '../doctors/widgets/doctor_card_tile.dart';
import '../home/home_style.dart';
import 'booking_logic.dart';
import 'models.dart';
import 'providers.dart';
import 'widgets/booking_tile.dart';
import '../../core/theme/app_palette.dart';

/// Booking flow: pick a clinic (when there is a choice), a day, a time, confirm.
///
/// [clinicId] opens the sheet on that clinic — the "book" button on a clinic's
/// card. Without it, a doctor with one bookable clinic opens straight on its
/// times and a doctor with several asks which clinic first.
///
/// A signed-out visitor is sent to sign in first and returned here — browsing is
/// public, booking is not.
Future<void> showBookingSheet(BuildContext context, DoctorDetail doctor, {String? clinicId}) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(selectedClinicProvider(doctor.slug).notifier).state = initialBookingClinic(
    doctor,
    requested: clinicId,
  );
  // A fresh choice each time the sheet opens — unless a confirm from a sheet that
  // was swiped away is still in flight, which must keep its "submitting" guard.
  if (!container.read(bookingDraftProvider(doctor.slug)).submitting) {
    container.read(bookingDraftProvider(doctor.slug).notifier).reset();
  }
  // Booking depends on account state the backend checks on every request —
  // above all a verified phone. Re-read it, so a change made elsewhere (verified
  // on the website, policies updated) is what the sheet acts on, not a copy
  // loaded when the app started.
  if (container.read(authControllerProvider).isAuthenticated) {
    unawaited(container.read(authControllerProvider.notifier).refreshUser());
  }
  // A booking confirmed after an earlier sheet was swiped away: this sheet opens
  // on it, once, rather than on times that no longer include it.
  final completed = container.read(completedBookingProvider(doctor.slug));
  if (completed != null) {
    container.read(completedBookingProvider(doctor.slug).notifier).state = null;
  }
  return showModalBottomSheet<void>(
    context: context,
    // Over the tab shell, not in its navigator, where Home's doctor cards
    // would open it under the floating dock.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.palette.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _BookingSheet(doctor: doctor, completed: completed),
  );
}

class _BookingSheet extends ConsumerStatefulWidget {
  const _BookingSheet({required this.doctor, this.completed});

  final DoctorDetail doctor;

  /// See [completedBookingProvider].
  final PatientBooking? completed;

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  final _notes = TextEditingController();
  String? _error;

  /// The confirmed booking, once the server has answered with one.
  PatientBooking? _booked;

  /// Slots the server refused during this sheet (taken meanwhile). Shown as
  /// unavailable even if a stale answer still lists them.
  final _refused = <String>{};

  /// A verification code is being requested.
  bool _verifying = false;

  /// [_booked] came from reading My Bookings after an unconfirmed submission,
  /// not from the booking request's own answer.
  bool _foundByCheck = false;

  /// My Bookings is being read to look for an unconfirmed booking, and why that
  /// last failed, if it did.
  bool _checking = false;
  Object? _checkError;

  @override
  void initState() {
    super.initState();
    _booked = widget.completed;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String get _slug => widget.doctor.slug;

  @override
  Widget build(BuildContext context) {
    final clinicId = ref.watch(selectedClinicProvider(_slug));
    final draft = ref.watch(bookingDraftProvider(_slug));
    final clinics = bookableClinics(widget.doctor);
    final link = clinics.where((c) => c.clinic.id == clinicId).firstOrNull;
    final key = (slug: _slug, clinicId: clinicId);
    final availability = link == null ? null : ref.watch(availabilityProvider(key));
    final hasSlots = availability?.valueOrNull?.hasAnySlot ?? false;
    final user = ref.watch(authControllerProvider.select((s) => s.isAuthenticated ? s.user : null));
    // The backend only takes bookings from accounts with a verified phone (the
    // website asks for the code at this same step). Sending the booking anyway
    // would only earn a 403.
    final unverifiedPhone = user != null && !user.isPhoneVerified ? user.phone : null;
    final unconfirmed = ref.watch(unconfirmedBookingProvider(_slug));
    // A confirm from a sheet that was swiped away, answered while this one is
    // open: shown here, and so not again at the next opening.
    ref.listen<PatientBooking?>(completedBookingProvider(_slug), (_, next) {
      if (next == null || _booked != null) return;
      setState(() => _booked = next);
      final kept = ref.read(completedBookingProvider(_slug).notifier);
      // Once this change has finished notifying its listeners.
      scheduleMicrotask(() {
        if (kept.mounted && identical(kept.state, next)) kept.state = null;
      });
    });

    final Widget content;
    if (_booked != null) {
      final bookedAt = clinics.where((c) => c.clinic.id == _booked!.clinicId).firstOrNull;
      content = _SuccessView(
        doctor: widget.doctor,
        booking: _booked!,
        clinic: bookedAt ?? link,
        found: _foundByCheck,
      );
    } else if (unconfirmed != null) {
      // Until it has been looked for, the lost booking replaces the calendar:
      // there is nothing to confirm a second time, and no other time to take.
      content = _UnconfirmedView(
        unconfirmed: unconfirmed,
        checking: _checking,
        error: _checkError,
        onCheck: _checkBookings,
        onOpenBookings: _openBookings,
        onBookAnyway: _bookAnyway,
      );
    } else if (link == null) {
      content = _ClinicPicker(
        clinics: clinics,
        onPick: (id) {
          ref.read(selectedClinicProvider(_slug).notifier).state = id;
          ref.read(bookingDraftProvider(_slug).notifier).reset();
          setState(() => _error = null);
        },
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SelectedClinic(
            link: link,
            onChange: clinics.length > 1 && !draft.submitting
                ? () {
                    // A different clinic is a different schedule: the chosen day
                    // and time no longer apply.
                    ref.read(selectedClinicProvider(_slug).notifier).state = null;
                    ref.read(bookingDraftProvider(_slug).notifier).reset();
                    setState(() => _error = null);
                  }
                : null,
          ),
          const SizedBox(height: 16),
          FormErrorBanner(message: _error),
          if (unverifiedPhone != null) ...[
            _VerifyPhoneNotice(phone: unverifiedPhone),
            const SizedBox(height: 16),
          ],
          availability!.when(
            skipLoadingOnRefresh: false,
            loading: () => const _PickerSkeleton(),
            error: (e, _) =>
                AppErrorView(error: e, onRetry: () => ref.invalidate(availabilityProvider(key))),
            data: (a) {
              if (!a.bookingEnabled) return _ContactOnly(availability: a, doctor: widget.doctor);
              if (!a.hasAnySlot) {
                return AppEmptyView(
                  icon: Icons.event_busy_outlined,
                  title: L.of(context).bookingNoSlotsAtAll,
                );
              }
              return _DayAndTimePicker(
                availability: a,
                slug: _slug,
                clinic: link,
                notes: _notes,
                refused: _refused,
              );
            },
          ),
        ],
      );
    }

    final confirmBar =
        _booked == null && unconfirmed == null && link != null && hasSlots;

    return PopScope(
      // Never lose track of a booking mid-request.
      canPop: !draft.submitting,
      child: Padding(
        // Lift the sheet above the keyboard when the notes field is focused.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) => Column(
            children: [
              _Header(doctor: widget.doctor, canClose: !draft.submitting),
              Divider(height: 1, color: context.palette.border),
              Expanded(
                child: ListView(
                  controller: controller,
                  // The confirm bar keeps itself above the system navigation
                  // bar; without it, the content's end has to.
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    16,
                    AppSpacing.gutter,
                    24 +
                        (confirmBar ? 0 : MediaQuery.paddingOf(context).bottom),
                  ),
                  children: [content],
                ),
              ),
              if (confirmBar)
                _ConfirmBar(
                  slug: _slug,
                  onConfirm: _confirm,
                  verifyPhone: unverifiedPhone == null
                      ? null
                      : () => _startPhoneVerification(unverifiedPhone),
                  verifying: _verifying,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final draft = ref.read(bookingDraftProvider(_slug));
    final slot = draft.selectedSlot;
    final clinicId = ref.read(selectedClinicProvider(_slug));
    // The button is disabled while submitting; this guards a double tap that
    // lands before the rebuild.
    if (draft.submitting || slot == null || clinicId == null) return;

    if (!ref.read(authControllerProvider).isAuthenticated) {
      // Send them to sign in and bring them back to this doctor.
      final router = GoRouter.of(context);
      final target = Uri.encodeComponent(Routes.doctorPath(_slug));
      Navigator.of(context).pop();
      router.push('${Routes.signIn}?next=$target');
      return;
    }

    final user = ref.read(authControllerProvider).user;
    if (user != null && !user.isPhoneVerified) {
      unawaited(_startPhoneVerification(user.phone));
      return;
    }

    // Read before the await: the sheet may be dismissed while the request runs,
    // and the bookings list must still learn about a booking that went through.
    final container = ProviderScope.containerOf(context, listen: false);
    final controller = ref.read(bookingDraftProvider(_slug).notifier);
    final key = (slug: _slug, clinicId: clinicId);

    // Who is booking. Every answer below is acted on only while that is still
    // the session: a booking — or a failure — that arrives after a sign-out or
    // another account's sign-in is the earlier account's, and is not shown,
    // remembered or acted on for whoever is here now.
    final session = container.read(authRepositoryProvider).session;
    bool sessionEnded() => container.read(authRepositoryProvider).session != session;

    // A drag closes the sheet even while the request is out, and the request
    // carries on regardless — it is never cancelled or sent again for that. So
    // everything needed to tell the patient how it ended is read now, from
    // things that outlive the sheet: the app's messenger and router, and the
    // words. Nothing below reaches the sheet's context or state unless it is
    // still mounted.
    final slug = _slug;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final router = GoRouter.maybeOf(context);
    final l = L.of(context);
    final doctorName = widget.doctor.displayName;
    void announce(String message, [(String, VoidCallback)? action]) =>
        _announceAfterClose(container, messenger, session, message, action);

    setState(() => _error = null);
    controller.setSubmitting(true);
    try {
      final booking = await container
          .read(bookingRepositoryProvider)
          .create(
            doctorSlug: _slug,
            slotId: slot.id,
            // Always sent: `clinic` is required by the booking endpoint.
            clinicId: clinicId,
            visitType: draft.visitType,
            notesForDoctor: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (sessionEnded()) return;
      // The list is stale, and so is the offer this slot came from.
      container.invalidate(myBookingsProvider);
      container.invalidate(availabilityProvider(key));
      controller.reset();
      if (!mounted) {
        // Made, after the sheet was swiped away: kept for the next opening of
        // this doctor's sheet, and announced where the patient is now.
        container.read(completedBookingProvider(slug).notifier).state = booking;
        announce(l.bkBookedAfterClose(doctorName), (
          l.bkViewBooking,
          () => router?.push(Routes.bookingPath(booking.id)),
        ));
        return;
      }
      setState(() => _booked = booking);
    } catch (error) {
      // This session's own credentials refused: the client has just dropped
      // them, which is why "no session now" still means this one. That is
      // reported (as "sign in again"); anything else, once the session has
      // moved on, is not.
      final ownSessionRefused =
          error is ApiException &&
          error.isAuthFailure &&
          container.read(authRepositoryProvider).session == null;
      if (sessionEnded() && !ownSessionRefused) return;
      if (bookingOutcomeUncertain(error)) {
        // Sent, with no answer to rely on: it may exist. It is not sent again,
        // and no other time is offered, until My Bookings has been looked at —
        // even if this sheet is closed and opened again.
        container.invalidate(myBookingsProvider);
        container.read(unconfirmedBookingProvider(slug).notifier).state = UnconfirmedBooking(
          clinicId: clinicId,
          startAt: slot.startAt,
          date: draft.selectedDate ?? '',
          displayTime: slot.displayTime,
        );
        if (mounted) {
          setState(() => _error = null);
        } else {
          announce(l.bkUnconfirmedAfterClose(doctorName), (
            l.bkUnconfirmedOpenBookings,
            () => router?.go(Routes.bookings),
          ));
        }
        return;
      }
      // Anything that is not uncertain is an answer the server sent and the app
      // read: a refusal.
      final e = error as ApiException;
      // A 403 for a signed-in patient means the *account* failed a check the
      // backend makes on every booking — an unverified phone, or policies that
      // must be re-accepted. Re-read the account: the sheet then shows the
      // verification step, or the router moves to the consent screen, instead of
      // a bare "no permission" the user can do nothing about.
      if (e.failure == ApiFailure.forbidden) {
        await container.read(authControllerProvider.notifier).refreshUser();
        if (sessionEnded()) return;
      }
      final account = container.read(authControllerProvider).user;
      final needsVerification =
          e.failure == ApiFailure.forbidden && account != null && !account.isPhoneVerified;
      if (!mounted) {
        // Refused after the sheet was swiped away: said so — never as a
        // success — in the messenger's own words, since this context is gone.
        if (messenger != null && messenger.mounted) {
          final reason = needsVerification
              ? l.bkVerifyPhoneTitle
              : messageForError(messenger.context, e);
          announce(l.bkNotBookedAfterClose(doctorName, reason));
        }
        return;
      }
      setState(() => _error = needsVerification ? null : messageForError(context, e));
      // If the slot went while they were deciding, drop the dead selection and
      // refetch, so they are choosing from what is actually still free. The sheet
      // deliberately stays open: the fix is one tap away.
      if (isRecoverableBookingError(e) || e.failure == ApiFailure.conflict) {
        _refused.add(slot.id);
        controller.clearSlot();
        container.invalidate(availabilityProvider(key));
      }
    } finally {
      // A draft that belonged to an account that has since changed is gone.
      if (controller.mounted) controller.setSubmitting(false);
    }
  }

  /// Read My Bookings again and look for the booking whose answer was lost.
  ///
  /// Found, it is shown as the server lists it. Not found, the sheet says so
  /// without concluding it was never made: the endpoint gives no way to know.
  Future<void> _checkBookings() async {
    final pending = ref.read(unconfirmedBookingProvider(_slug));
    if (pending == null || _checking) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final session = container.read(authRepositoryProvider).session;
    bool sessionEnded() => container.read(authRepositoryProvider).session != session;

    setState(() {
      _checking = true;
      _checkError = null;
    });
    try {
      container.invalidate(myBookingsProvider);
      final all = await container.read(myBookingsProvider.future);
      if (!mounted || sessionEnded()) return;
      final found = findSubmittedBooking(
        all,
        doctorSlug: _slug,
        startAt: pending.startAt,
        clinicId: pending.clinicId,
      );
      final unconfirmed = container.read(unconfirmedBookingProvider(_slug).notifier);
      if (found == null) {
        unconfirmed.state = pending.notFound();
        return;
      }
      unconfirmed.state = null;
      container.invalidate(availabilityProvider((slug: _slug, clinicId: pending.clinicId)));
      setState(() {
        _booked = found;
        _foundByCheck = true;
      });
    } catch (e) {
      if (mounted && !sessionEnded()) setState(() => _checkError = e);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// My Bookings itself. The unconfirmed booking is kept, so the sheet asks
  /// again if it is reopened before the booking turned up.
  void _openBookings() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(Routes.bookings);
  }

  /// Book a time after all — only offered once My Bookings was read and did
  /// not list the lost booking, and only on the patient's say-so.
  void _bookAnyway() {
    ref.read(unconfirmedBookingProvider(_slug).notifier).state = null;
    ref.read(bookingDraftProvider(_slug).notifier).reset();
    final clinicId = ref.read(selectedClinicProvider(_slug));
    if (clinicId != null) ref.invalidate(availabilityProvider((slug: _slug, clinicId: clinicId)));
    setState(() => _checkError = null);
  }

  /// Send a verification code and open the existing code screen, which returns
  /// here (to this doctor) once the phone is verified.
  ///
  /// Purpose `signup` is what the website's booking step uses for the same job.
  Future<void> _startPhoneVerification(String phone) async {
    if (_verifying) return;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestOtp(phone: phone, purpose: 'signup');
      if (!mounted) return;
      final next = Uri.encodeComponent(Routes.doctorPath(_slug));
      navigator.pop();
      router.push('${Routes.otp}?phone=${Uri.encodeComponent(phone)}&purpose=signup&next=$next');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = messageForError(context, e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }
}

/// How a booking ended, told where the patient is now — for when its sheet was
/// swiped away before the answer came, and so cannot show it.
///
/// A snack bar on the app's own messenger: never a dialog, and never a
/// navigation the patient did not ask for. It goes after a few seconds rather
/// than staying until dismissed (the default for one with an action), it is
/// taken down if the account changes meanwhile, and its action does nothing
/// once the account has changed: the outcome belongs to the account that booked.
void _announceAfterClose(
  ProviderContainer container,
  ScaffoldMessengerState? messenger,
  int? session,
  String message, [
  (String, VoidCallback)? action,
]) {
  if (messenger == null || !messenger.mounted) return;
  bool sameSession() => container.read(authRepositoryProvider).session == session;
  final shown = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      persist: false,
      duration: const Duration(seconds: 6),
      action: action == null
          ? null
          : SnackBarAction(
              label: action.$1,
              onPressed: () {
                if (sameSession()) action.$2();
              },
            ),
    ),
  );
  final whoIsHere = container.listen<String?>(
    authControllerProvider.select((s) => s.user?.id),
    (_, __) => shown.close(),
  );
  unawaited(shown.closed.whenComplete(whoIsHere.close));
}

/// Why the confirm button asks for a phone code instead.
class _VerifyPhoneNotice extends StatelessWidget {
  const _VerifyPhoneNotice({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.pageSoft,
        borderRadius: AppRadii.inputRadius,
        border: Border.all(color: context.palette.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: context.palette.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.bkVerifyPhoneTitle,
                  style: context.homeType.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  // Isolated so "+20…" keeps its order inside Arabic text.
                  l.bkVerifyPhoneBody('\u2066$phone\u2069'),
                  style: context.homeType.meta.copyWith(fontSize: 12.5, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The doctor the patient is booking with, and a close button.
class _Header extends StatelessWidget {
  const _Header({required this.doctor, required this.canClose});

  final DoctorDetail doctor;
  final bool canClose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final subtitle = doctor.card.professionalTitleAr.isNotEmpty
        ? doctor.card.professionalTitleAr
        : (doctor.card.primarySpecialization?.nameAr ?? '');
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.gutter, 10, 8, 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.palette.border,
              borderRadius: AppRadii.pillRadius,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              DoctorAvatar(
                photo: doctor.card.photo,
                name: doctor.displayName,
                size: 46,
                radius: 23,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.bookingTitle,
                      style: context.homeType.meta.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      doctor.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.homeType.cardTitle.copyWith(fontSize: 16),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.homeType.meta,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.bkClose,
                onPressed: canClose ? () => Navigator.of(context).maybePop() : null,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Step one when the doctor works at several bookable clinics.
class _ClinicPicker extends StatelessWidget {
  const _ClinicPicker({required this.clinics, required this.onPick});

  final List<DoctorClinicLink> clinics;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.bkChooseClinic, style: context.homeType.sectionTitle),
        const SizedBox(height: 4),
        Text(l.bkChooseClinicHint, style: context.homeType.meta.copyWith(fontSize: 12.5)),
        const SizedBox(height: 14),
        for (final c in clinics) ...[
          _ClinicOption(link: c, onTap: () => onPick(c.clinic.id)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ClinicOption extends StatelessWidget {
  const _ClinicOption({required this.link, required this.onTap});

  final DoctorClinicLink link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final c = link.clinic;
    return Material(
      color: context.palette.input,
      borderRadius: BorderRadius.circular(homeCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(homeCardRadius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(homeCardRadius),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.palette.pageSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_hospital_rounded, color: context.palette.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(c.nameAr, style: context.homeType.cardTitle)),
                        if (link.isPrimary) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· ${l.clinicBadgePrimary}',
                            style: context.homeType.meta.copyWith(
                              color: context.palette.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (c.addressLine.isNotEmpty)
                      Text(
                        c.addressLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.homeType.meta,
                      ),
                    if (link.consultationFee != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${l.clinicFeeConsult}: ${l.ddMoney(link.consultationFee!)}',
                          style: context.homeType.meta.copyWith(
                            color: context.palette.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
  }
}

/// The clinic being booked, with "change" when there is another to choose.
class _SelectedClinic extends StatelessWidget {
  const _SelectedClinic({required this.link, this.onChange});

  final DoctorClinicLink link;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: context.palette.pageSoft,
        borderRadius: AppRadii.inputRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.local_hospital_outlined, color: context.palette.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.bookingClinic, style: context.homeType.meta),
                Text(link.clinic.nameAr, style: context.homeType.cardTitle.copyWith(fontSize: 14)),
                if (link.clinic.addressLine.isNotEmpty)
                  Text(
                    link.clinic.addressLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.homeType.meta,
                  ),
              ],
            ),
          ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(
                textStyle: context.homeType.button.copyWith(fontSize: 13),
              ),
              child: Text(l.bkChangeClinic),
            ),
        ],
      ),
    );
  }
}

class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Skeleton(height: 16, width: 90),
      const SizedBox(height: 10),
      Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            const Expanded(child: Skeleton(height: 86, radius: AppRadii.input)),
          ],
        ],
      ),
      const SizedBox(height: 20),
      const Skeleton(height: 16, width: 90),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < 8; i++) const Skeleton(height: 42, width: 76, radius: AppRadii.pill),
        ],
      ),
    ],
  );
}

/// A doctor who takes bookings by phone only at this clinic: the server's own
/// message, and its call / WhatsApp links.
class _ContactOnly extends StatelessWidget {
  const _ContactOnly({required this.availability, required this.doctor});

  final DoctorAvailability availability;
  final DoctorDetail doctor;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final contact = availability.contact.canCall || availability.contact.canWhatsapp
        ? availability.contact
        : doctor.card.contact;

    return Column(
      children: [
        InfoNote(
          text: availability.message.isNotEmpty ? availability.message : l.doctorBookingUnavailable,
          icon: Icons.phone_in_talk_outlined,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (contact.canCall)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => launchContact(ContactChannel.phone, contact.telUrl),
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: Text(l.doctorCall),
                ),
              ),
            if (contact.canCall && contact.canWhatsapp) const SizedBox(width: 8),
            if (contact.canWhatsapp)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: context.palette.whatsapp),
                  onPressed: () => launchContact(ContactChannel.whatsapp, contact.whatsappUrl),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: Text(l.doctorWhatsapp),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayAndTimePicker extends ConsumerWidget {
  const _DayAndTimePicker({
    required this.availability,
    required this.slug,
    required this.clinic,
    required this.notes,
    required this.refused,
  });

  final DoctorAvailability availability;
  final String slug;
  final DoctorClinicLink clinic;
  final TextEditingController notes;
  final Set<String> refused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final draft = ref.watch(bookingDraftProvider(slug));
    final controller = ref.read(bookingDraftProvider(slug).notifier);
    final days = availability.daysWithSlots;

    // Default to the first day that actually has times, rather than today —
    // landing on an empty day looks like a broken screen.
    final selectedDate = days.any((d) => d.date == draft.selectedDate)
        ? draft.selectedDate
        : (days.isNotEmpty ? days.first.date : null);
    final day = days.where((d) => d.date == selectedDate).firstOrNull;
    final now = DateTime.now().toUtc();
    final selected = draft.selectedSlot;
    final fee = feeFor(visitType: draft.visitType, clinic: clinic, availability: availability);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(icon: Icons.calendar_month_rounded, title: l.bookingChooseDay),
        const SizedBox(height: 10),
        SizedBox(
          // Four short lines of text plus padding; grows with the text size.
          height: MediaQuery.textScalerOf(context).scale(80) + 22,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final d = days[i];
              return _DayChip(
                date: d.date,
                locale: locale,
                slotCount: d.slots.length,
                selected: d.date == selectedDate,
                onTap: () => controller.chooseDate(d.date),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _StepTitle(icon: Icons.schedule_rounded, title: l.bookingChooseTime),
        const SizedBox(height: 10),
        if (day == null || day.slots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(l.bookingNoSlots, style: Theme.of(context).textTheme.bodySmall),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in day.slots)
                _TimeChip(
                  slot: slot,
                  selected: selected?.id == slot.id,
                  // Taken while the sheet was open, or already in the past.
                  unavailable: refused.contains(slot.id) || !slot.startAt.isAfter(now),
                  onTap: () {
                    // Picking a time on the default day makes that day explicit.
                    if (draft.selectedDate != selectedDate && selectedDate != null) {
                      controller.chooseDate(selectedDate);
                    }
                    controller.chooseSlot(slot);
                  },
                ),
            ],
          ),
        if ((availability.timezone ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.public_rounded, size: 14, color: context.palette.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(l.bkTimezoneNote, style: context.homeType.meta)),
            ],
          ),
        ],

        const SizedBox(height: 20),
        _StepTitle(icon: Icons.assignment_outlined, title: l.bookingVisitType),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final (type, label) in [
              (VisitType.firstVisit, l.bookingVisitFirst),
              (VisitType.followUp, l.bookingVisitFollowUp),
            ])
              ChoiceChip(
                label: Text(label),
                selected: draft.visitType == type,
                onSelected: (_) => controller.setVisitType(type),
                labelStyle: context.homeType.chip.copyWith(
                  color: draft.visitType == type ? Colors.white : context.palette.heading,
                ),
                selectedColor: context.palette.primaryFill,
                backgroundColor: context.palette.input,
                side: BorderSide(
                  color: draft.visitType == type ? context.palette.primary : context.palette.border,
                ),
                showCheckmark: false,
                shape: const StadiumBorder(),
              ),
          ],
        ),

        const SizedBox(height: 20),
        // Notes for the doctor are health information: kept out of the keyboard.
        AppTextField(
          label: l.bookingNotes,
          controller: notes,
          maxLines: 3,
          minLines: 2,
          private: true,
        ),

        if (availability.paymentRequired || clinic.paymentRequired) ...[
          const SizedBox(height: 14),
          InfoNote(text: l.bkPaymentRequired, icon: Icons.payments_outlined),
        ],

        const SizedBox(height: 20),
        if (selected == null)
          Row(
            children: [
              Icon(Icons.touch_app_outlined, size: 18, color: context.palette.muted),
              const SizedBox(width: 6),
              Text(l.bkPickTimeHint, style: context.homeType.meta.copyWith(fontSize: 12.5)),
            ],
          )
        else
          _Summary(
            rows: [
              (l.bookingClinic, clinic.clinic.nameAr, false),
              (l.bookingDateTime, longDayLabel(selectedDate ?? '', locale), false),
              (
                l.bkTime,
                selected.displayEndTime.isEmpty
                    ? selected.displayTime
                    : '${selected.displayTime} – ${selected.displayEndTime}',
                true,
              ),
              if (selected.durationMinutes > 0)
                (l.bkDurationLabel, l.bkDuration(selected.durationMinutes), false),
              (
                l.bookingVisitType,
                draft.visitType == VisitType.followUp
                    ? l.bookingVisitFollowUp
                    : l.bookingVisitFirst,
                false,
              ),
              if (fee != null) (l.bookingFee, l.ddMoney(fee), false),
            ],
          ),
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: context.palette.primary),
      const SizedBox(width: 8),
      Text(title, style: context.homeType.sectionTitle.copyWith(fontSize: 15)),
    ],
  );
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.locale,
    required this.slotCount,
    required this.selected,
    required this.onTap,
  });

  final String date;
  final String locale;
  final int slotCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // `date` is the clinic-local calendar day; parsed only for its labels.
    final parts = calendarParts(date, locale);
    final fg = selected ? Colors.white : context.palette.heading;
    final sub = selected ? Colors.white70 : context.palette.muted;

    return Semantics(
      selected: selected,
      button: true,
      label: longDayLabel(date, locale),
      excludeSemantics: true,
      child: Material(
        color: selected ? context.palette.primaryFill : context.palette.input,
        borderRadius: AppRadii.inputRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.inputRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 74,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: AppRadii.inputRadius,
              border: Border.all(
                color: selected ? context.palette.primaryFill : context.palette.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  parts?.weekday ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sub),
                ),
                Text(
                  parts?.day ?? date,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    height: 1.25,
                  ),
                ),
                Text(parts?.month ?? '', maxLines: 1, style: TextStyle(fontSize: 11, color: sub)),
                Text(
                  l.bkSlotsCount(slotCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? Colors.white : context.palette.success,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.slot,
    required this.selected,
    required this.unavailable,
    required this.onTap,
  });

  final Slot slot;
  final bool selected;
  final bool unavailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bg = unavailable
        ? context.palette.page
        : selected
        ? context.palette.primaryFill
        : context.palette.surface;
    final fg = unavailable
        ? context.palette.muted.withValues(alpha: 0.6)
        : selected
        ? Colors.white
        : context.palette.heading;

    return Semantics(
      button: true,
      selected: selected,
      enabled: !unavailable,
      label: unavailable ? '${slot.displayTime} — ${l.bkSlotUnavailable}' : slot.displayTime,
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: AppRadii.pillRadius,
        child: InkWell(
          onTap: unavailable ? null : onTap,
          borderRadius: AppRadii.pillRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minWidth: 78, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: AppRadii.pillRadius,
              border: Border.all(
                color: selected
                    ? context.palette.primaryFill
                    : (unavailable
                          ? context.palette.border
                          : context.palette.primary.withValues(alpha: 0.35)),
              ),
            ),
            // Sized to the label (a Wrap child that aligns would fill the row),
            // centred within the minimum size.
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                // The backend's clinic-local label. Not derived from the UTC
                // timestamp here: the phone's timezone is not necessarily the
                // clinic's, and a patient abroad must not see a shifted hour.
                slot.displayTime,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  decoration: unavailable ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.rows});

  /// Label, value, and whether the value is left-to-right (times).
  final List<(String, String, bool)> rows;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.pageSoft,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bookingSummary, style: context.homeType.sectionTitle.copyWith(fontSize: 15)),
          const SizedBox(height: 8),
          for (final (label, value, ltr) in rows) _SummaryRow(label: label, value: value, ltr: ltr),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.ltr = false});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: context.homeType.meta.copyWith(fontSize: 12.5)),
        ),
        Expanded(
          // Aligned to the row's end in the page's direction, even for a
          // left-to-right value such as a time.
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              value,
              textAlign: TextAlign.start,
              textDirection: ltr ? TextDirection.ltr : null,
              style: context.homeType.cardTitle.copyWith(fontSize: 13.5),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The pinned confirm button, with the chosen day and time above it.
class _ConfirmBar extends ConsumerWidget {
  const _ConfirmBar({
    required this.slug,
    required this.onConfirm,
    this.verifyPhone,
    this.verifying = false,
  });

  final String slug;
  final VoidCallback onConfirm;

  /// Set when the account's phone must be verified first; the button then
  /// starts that instead of booking.
  final VoidCallback? verifyPhone;
  final bool verifying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final draft = ref.watch(bookingDraftProvider(slug));
    final signedIn = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 12, AppSpacing.gutter, 12),
          child: FilledButton(
            onPressed: verifyPhone != null
                ? (verifying ? null : verifyPhone)
                : (!draft.isComplete || draft.submitting ? null : onConfirm),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: context.homeType.button.copyWith(fontSize: 15),
            ),
            child: draft.submitting || verifying
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Text(
                    !signedIn
                        ? l.bkSignInToBook
                        : (verifyPhone != null ? l.bkVerifyPhoneAction : l.bookingConfirm),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
      ),
    );
  }
}

/// What the server confirmed. Every value comes from the booking it returned;
/// there is no reference number because the API does not issue one.
class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.doctor,
    required this.booking,
    required this.clinic,
    this.found = false,
  });

  final DoctorDetail doctor;
  final PatientBooking booking;
  final DoctorClinicLink? clinic;

  /// Found in My Bookings after its own answer was lost, rather than answered
  /// by the booking request: titled as found, with the status the server lists.
  final bool found;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final clinicName = booking.clinicName.isNotEmpty
        ? booking.clinicName
        : (clinic?.clinic.nameAr ?? '');

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: context.palette.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, color: context.palette.success, size: 48),
        ),
        const SizedBox(height: 14),
        Semantics(
          liveRegion: true,
          child: Text(
            found ? l.bkUnconfirmedFoundTitle : l.bookingSuccessTitle,
            style: context.homeType.greeting.copyWith(fontSize: 19),
          ),
        ),
        if (found) ...[const SizedBox(height: 10), BookingStatusChip(status: booking.status)],
        const SizedBox(height: 18),
        _Summary(
          rows: [
            (
              l.bkDoctor,
              booking.doctorName.isNotEmpty ? booking.doctorName : doctor.displayName,
              false,
            ),
            if (clinicName.isNotEmpty) (l.bookingClinic, clinicName, false),
            if (booking.displayDate.isNotEmpty)
              (l.bookingDateTime, longDayLabel(booking.displayDate, locale), false),
            if (booking.displayTime.isNotEmpty) (l.bkTime, booking.displayTime, true),
            if (booking.feeSnapshot != null) (l.bookingFee, l.ddMoney(booking.feeSnapshot!), false),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push(Routes.bookingPath(booking.id));
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            textStyle: context.homeType.button.copyWith(fontSize: 15),
          ),
          child: Text(l.bkViewBooking),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            textStyle: context.homeType.button.copyWith(fontSize: 14),
          ),
          child: Text(l.bkDone),
        ),
      ],
    );
  }
}

/// A booking that was sent but never answered: it may or may not exist.
///
/// Says so plainly, shows which appointment it was, and offers to look in My
/// Bookings. It never claims the booking failed — the endpoint gives no way to
/// know — and offers another time only once My Bookings was read without it.
class _UnconfirmedView extends StatelessWidget {
  const _UnconfirmedView({
    required this.unconfirmed,
    required this.checking,
    required this.error,
    required this.onCheck,
    required this.onOpenBookings,
    required this.onBookAnyway,
  });

  final UnconfirmedBooking unconfirmed;
  final bool checking;
  final Object? error;
  final VoidCallback onCheck;
  final VoidCallback onOpenBookings;
  final VoidCallback onBookAnyway;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tone = context.palette.toneWarning;
    final notFound = unconfirmed.checkedNotFound;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
            child: Icon(Icons.sync_problem_rounded, color: tone.fg, size: 44),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          liveRegion: true,
          child: Text(
            l.bkUnconfirmedTitle,
            textAlign: TextAlign.center,
            style: context.homeType.greeting.copyWith(fontSize: 19),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          notFound ? l.bkUnconfirmedNotFound : l.bkUnconfirmedBody,
          textAlign: TextAlign.center,
          style: context.homeType.meta.copyWith(fontSize: 13.5, height: 1.6),
        ),
        const SizedBox(height: 18),
        _Summary(
          rows: [
            if (unconfirmed.date.isNotEmpty)
              (l.bookingDateTime, longDayLabel(unconfirmed.date, locale), false),
            if (unconfirmed.displayTime.isNotEmpty) (l.bkTime, unconfirmed.displayTime, true),
          ],
        ),
        const SizedBox(height: 16),
        FormErrorBanner(message: error == null ? null : messageForError(context, error!)),
        FilledButton(
          onPressed: checking ? null : onCheck,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            textStyle: context.homeType.button.copyWith(fontSize: 15),
          ),
          child: checking
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(notFound ? l.bkUnconfirmedCheckAgain : l.bkUnconfirmedCheck),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: checking ? null : onOpenBookings,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            textStyle: context.homeType.button.copyWith(fontSize: 14),
          ),
          child: Text(l.bkUnconfirmedOpenBookings),
        ),
        if (notFound) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: checking ? null : onBookAnyway,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              textStyle: context.homeType.button.copyWith(fontSize: 14),
            ),
            child: Text(l.bkUnconfirmedBookAnyway),
          ),
        ],
      ],
    );
  }
}

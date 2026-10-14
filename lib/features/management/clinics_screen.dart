import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_messages.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/models.dart';
import '../doctors/providers.dart';
import '../home/home_style.dart';
import 'management_widgets.dart';
import 'models.dart';
import 'providers.dart';
import '../../core/theme/app_palette.dart';

/// The doctor's clinics, and — for each — the doctor's own terms there, the
/// clinic's opening hours and (for the clinic's owner) invitations.
///
/// What a doctor may change is the backend's call: terms are theirs at any clinic,
/// hours and invitations belong to the owner. The screen offers those controls to
/// owners only and shows the server's refusal if one still comes back.
class ClinicsScreen extends ConsumerWidget {
  const ClinicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final clinics = ref.watch(myClinicsProvider);

    return Scaffold(
      backgroundColor: context.palette.page,
      appBar: AppBar(title: Text(l.clinicsTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myClinicsProvider);
          await ref.read(myClinicsProvider.future).then((_) {}, onError: (_) {});
        },
        child: AsyncValueView<List<MyClinic>>(
          value: clinics,
          onRetry: () => ref.invalidate(myClinicsProvider),
          isEmpty: (list) => list.isEmpty,
          empty: ListView(
            children: [
              AppEmptyView(
                icon: Icons.local_hospital_outlined,
                title: l.clinicsEmptyTitle,
                hint: l.clinicsEmptyBody,
                action: FilledButton(
                  onPressed: () => showAddClinicSheet(context),
                  child: Text(l.clinicsAdd),
                ),
              ),
            ],
          ),
          data: (list) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              HomeSpacing.top,
              AppSpacing.gutter,
              AppSpacing.xl,
            ),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: () => showAddClinicSheet(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l.clinicsAdd),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: context.homeType.button,
                  ),
                ),
              ),
              const SizedBox(height: HomeSpacing.card),
              for (final c in list) ...[
                _ClinicCard(clinic: c),
                const SizedBox(height: HomeSpacing.card),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClinicCard extends ConsumerWidget {
  const _ClinicCard({required this.clinic});

  final MyClinic clinic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final ready = clinic.setupComplete && clinic.blocking.isEmpty;

    return MgmtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(clinic.nameAr, style: context.homeType.cardTitle.copyWith(fontSize: 16)),
          if (clinic.addressAr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(clinic.addressAr, style: context.homeType.meta),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (clinic.isPrimary)
                MgmtBadge(label: l.clinicBadgePrimary, color: context.palette.primary),
              if (clinic.iOwnIt) MgmtBadge(label: l.clinicBadgeOwner, color: context.palette.muted),
              if (!clinic.isActive || !clinic.clinicIsActive)
                MgmtBadge(label: l.clinicBadgeInactive, color: context.palette.danger),
            ],
          ),
          const SizedBox(height: 10),
          MgmtNotice(
            ok: ready,
            title: ready ? l.clinicReady : l.clinicNotReady,
            lines: ready ? const [] : [for (final b in clinic.blocking) blockingReason(l, b)],
          ),
          const SizedBox(height: 6),
          _Collapsible(
            title: l.clinicTermsTitle,
            icon: Icons.payments_outlined,
            // A new key when the server's values change, so the form shows them
            // (after a save, or a refresh that picked up an edit made on the web).
            child: _TermsForm(
              key: ValueKey((clinic.consultationFee, clinic.followupFee, clinic.bookingEnabled)),
              clinic: clinic,
            ),
          ),
          _Collapsible(
            title: l.clinicHoursTitle,
            icon: Icons.schedule_rounded,
            child: _HoursEditor(
              key: ValueKey([for (final w in clinic.workingHours) (w.weekday, w.open, w.close)]),
              clinic: clinic,
            ),
          ),
          if (clinic.iOwnIt)
            _Collapsible(
              title: l.clinicInviteTitle,
              icon: Icons.person_add_alt_1_outlined,
              child: _InviteSection(clinic: clinic),
            ),
        ],
      ),
    );
  }
}

class _Collapsible extends StatelessWidget {
  const _Collapsible({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        // Collapsing must not throw away what was typed.
        maintainState: true,
        leading: Icon(icon, color: context.palette.primary, size: 20),
        title: Text(title, style: context.homeType.cardTitle),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terms
// ---------------------------------------------------------------------------

class _TermsForm extends ConsumerStatefulWidget {
  const _TermsForm({super.key, required this.clinic});

  final MyClinic clinic;

  @override
  ConsumerState<_TermsForm> createState() => _TermsFormState();
}

class _TermsFormState extends ConsumerState<_TermsForm> {
  late final _fee = TextEditingController(text: widget.clinic.consultationFee ?? '');
  late final _followup = TextEditingController(text: widget.clinic.followupFee ?? '');
  late bool _booking = widget.clinic.bookingEnabled;
  bool _saving = false;
  String? _feeError;
  String? _followupError;

  @override
  void dispose() {
    _fee.dispose();
    _followup.dispose();
    super.dispose();
  }

  /// Empty is "no fee set"; anything else must be a non-negative number.
  (String?, bool) _parse(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return (null, true);
    final n = double.tryParse(t);
    return (t, n != null && n >= 0);
  }

  Future<void> _save() async {
    final l = L.of(context);
    final (fee, feeOk) = _parse(_fee.text);
    final (followup, followupOk) = _parse(_followup.text);
    setState(() {
      _feeError = feeOk ? null : l.managementFailed;
      _followupError = followupOk ? null : l.managementFailed;
    });
    if (!feeOk || !followupOk) return;

    setState(() => _saving = true);
    await runManagementAction(
      context,
      () => ref
          .read(managementRepositoryProvider)
          .updateTerms(
            widget.clinic.id,
            consultationFee: fee,
            followupFee: followup,
            bookingEnabled: _booking,
          ),
      successMessage: l.managementSaved,
      onDone: (c) => c.invalidate(myClinicsProvider),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    const money = TextInputType.numberWithOptions(decimal: true);
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: l.clinicFeeConsult,
          controller: _fee,
          keyboardType: money,
          inputFormatters: digits,
          forceLtr: true,
          errorText: _feeError,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l.clinicFeeFollowup,
          controller: _followup,
          keyboardType: money,
          inputFormatters: digits,
          forceLtr: true,
          errorText: _followupError,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.clinicAcceptBookings, style: context.homeType.doctorSpecialty),
          value: _booking,
          onChanged: (v) => setState(() => _booking = v),
        ),
        MgmtSaveButton(label: l.clinicSaveTerms, saving: _saving, onPressed: _save),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Opening hours
// ---------------------------------------------------------------------------

/// A readable reason a clinic cannot take bookings yet.
///
/// The API reports these as codes (`clinic_hours_not_set`, …). The ones seen so far
/// are translated; any other is shown exactly as the server sent it rather than
/// being guessed at — a reason in the wrong words is better than a hidden one.
String blockingReason(L l, String code) => switch (code) {
  'clinic_hours_not_set' => l.blockClinicHoursNotSet,
  'booking_disabled' => l.blockBookingDisabled,
  'no_availability_windows' => l.blockNoAvailabilityWindows,
  _ => code,
};

String weekdayName(L l, int day) => switch (day) {
  1 => l.weekday1,
  2 => l.weekday2,
  3 => l.weekday3,
  4 => l.weekday4,
  5 => l.weekday5,
  6 => l.weekday6,
  _ => l.weekday7,
};

String formatClock(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay parseClock(String raw) {
  final parts = raw.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 9,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

class _HoursEditor extends ConsumerStatefulWidget {
  const _HoursEditor({super.key, required this.clinic});

  final MyClinic clinic;

  @override
  ConsumerState<_HoursEditor> createState() => _HoursEditorState();
}

class _HoursEditorState extends ConsumerState<_HoursEditor> {
  late final List<WorkingShift> _shifts = [...widget.clinic.workingHours];
  bool _saving = false;

  bool get _editable => widget.clinic.iOwnIt;

  Future<void> _pick(int index, {required bool start}) async {
    final shift = _shifts[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: parseClock(start ? shift.open : shift.close),
    );
    if (picked == null) return;
    setState(() {
      _shifts[index] = start
          ? shift.copyWith(open: formatClock(picked))
          : shift.copyWith(close: formatClock(picked));
    });
  }

  Future<void> _save() async {
    final l = L.of(context);
    setState(() => _saving = true);
    await runManagementAction(
      context,
      () => ref.read(managementRepositoryProvider).setWorkingHours(widget.clinic.id, _shifts),
      successMessage: l.managementSaved,
      onDone: (c) => c.invalidate(myClinicsProvider),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    if (!_editable && _shifts.isEmpty) {
      return Text(l.clinicHoursNone, style: context.homeType.meta);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.clinicHoursHint, style: context.homeType.meta),
        const SizedBox(height: 10),
        if (_shifts.isEmpty) Text(l.clinicHoursNone, style: context.homeType.meta),
        for (var i = 0; i < _shifts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_editable)
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<int>(
                      initialValue: _shifts[i].weekday,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        for (var d = 1; d <= 7; d++)
                          DropdownMenuItem(value: d, child: Text(weekdayName(l, d))),
                      ],
                      onChanged: (d) =>
                          setState(() => _shifts[i] = _shifts[i].copyWith(weekday: d)),
                    ),
                  )
                else
                  SizedBox(
                    width: 90,
                    child: Text(
                      weekdayName(l, _shifts[i].weekday),
                      style: context.homeType.doctorSpecialty,
                    ),
                  ),
                _TimeButton(
                  label: l.clinicHoursFrom,
                  value: _shifts[i].open,
                  onTap: _editable ? () => _pick(i, start: true) : null,
                ),
                _TimeButton(
                  label: l.clinicHoursTo,
                  value: _shifts[i].close,
                  onTap: _editable ? () => _pick(i, start: false) : null,
                ),
                if (_editable)
                  IconButton(
                    tooltip: l.managementDelete,
                    onPressed: () => setState(() => _shifts.removeAt(i)),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: context.palette.danger,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        if (_editable) ...[
          TextButton.icon(
            onPressed: () => setState(
              () => _shifts.add(const WorkingShift(weekday: 6, open: '09:00', close: '17:00')),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l.clinicAddShift),
          ),
          const SizedBox(height: 4),
          MgmtSaveButton(label: l.clinicSaveHours, saving: _saving, onPressed: _save),
        ],
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: context.homeType.button,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: context.homeType.meta),
          Text(value, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invitations
// ---------------------------------------------------------------------------

class _InviteSection extends ConsumerStatefulWidget {
  const _InviteSection({required this.clinic});

  final MyClinic clinic;

  @override
  ConsumerState<_InviteSection> createState() => _InviteSectionState();
}

class _InviteSectionState extends ConsumerState<_InviteSection> {
  final _phone = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = L.of(context);
    final phone = _phone.text.trim();
    if (phone.isEmpty) return;
    setState(() => _sending = true);
    await runManagementAction(
      context,
      () => ref
          .read(managementRepositoryProvider)
          .inviteDoctor(widget.clinic.id, phone: phone, message: _message.text.trim()),
      successMessage: l.clinicInviteSent,
      onDone: (c) {
        c.invalidate(sentInvitationsProvider(widget.clinic.id));
        if (mounted) {
          _phone.clear();
          _message.clear();
        }
      },
    );
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final sent = ref.watch(sentInvitationsProvider(widget.clinic.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: l.clinicInvitePhone,
          controller: _phone,
          keyboardType: TextInputType.phone,
          forceLtr: true,
        ),
        const SizedBox(height: 12),
        AppTextField(label: l.clinicInviteMessage, controller: _message, maxLines: 2),
        const SizedBox(height: 12),
        MgmtSaveButton(label: l.clinicInviteSend, saving: _sending, onPressed: _send),
        const SizedBox(height: 14),
        Text(l.clinicInvitesSent, style: context.homeType.cardTitle),
        const SizedBox(height: 6),
        sent.when(
          loading: () => const Skeleton(height: 36, radius: 10),
          error: (_, __) => Text(l.clinicInvitesNone, style: context.homeType.meta),
          data: (list) => list.isEmpty
              ? Text(l.clinicInvitesNone, style: context.homeType.meta)
              : Column(
                  children: [
                    for (final i in list)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(i.doctorName, style: context.homeType.doctorSpecialty),
                            ),
                            MgmtBadge(
                              label: switch (i.status) {
                                'accepted' => l.invitationAccepted,
                                'declined' => l.invitationDeclined,
                                'cancelled' => l.invitationCancelled,
                                _ => l.invitationPending,
                              },
                              color: i.status == 'accepted'
                                  ? context.palette.success
                                  : (i.status == 'pending'
                                        ? context.palette.star
                                        : context.palette.muted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add a clinic
// ---------------------------------------------------------------------------

Future<void> showAddClinicSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _AddClinicSheet(),
);

class _AddClinicSheet extends ConsumerStatefulWidget {
  const _AddClinicSheet();

  @override
  ConsumerState<_AddClinicSheet> createState() => _AddClinicSheetState();
}

class _AddClinicSheetState extends ConsumerState<_AddClinicSheet> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  City? _city;
  Area? _area;
  bool _saving = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l = L.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = l.managementFailed);
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });
    final navigator = Navigator.of(context);
    final ok = await runManagementAction(
      context,
      () => ref
          .read(managementRepositoryProvider)
          .createClinic(
            nameAr: _name.text.trim(),
            cityId: _city?.id,
            areaId: _area?.id,
            addressAr: _address.text.trim(),
            phone: _phone.text.trim(),
          ),
      successMessage: l.managementSaved,
      onDone: (c) => c.invalidate(myClinicsProvider),
    );
    if (!mounted) return;
    if (ok) {
      navigator.pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cities = ref.watch(citiesProvider).valueOrNull ?? const <City>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.clinicsAdd, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            AppTextField(
              label: l.clinicFormName,
              controller: _name,
              errorText: _nameError,
              required: true,
            ),
            const SizedBox(height: 12),
            AppDropdown<City?>(
              label: l.doctorsFilterCity,
              value: _city,
              items: [for (final c in cities) DropdownMenuItem(value: c, child: Text(c.nameAr))],
              onChanged: (c) => setState(() {
                _city = c;
                _area = null;
              }),
            ),
            const SizedBox(height: 12),
            AppDropdown<Area?>(
              label: l.doctorsFilterArea,
              value: _area,
              enabled: (_city?.areas ?? const []).isNotEmpty,
              items: [
                for (final a in _city?.areas ?? const <Area>[])
                  DropdownMenuItem(value: a, child: Text(a.nameAr)),
              ],
              onChanged: (a) => setState(() => _area = a),
            ),
            const SizedBox(height: 12),
            AppTextField(label: l.clinicFormAddress, controller: _address, maxLines: 2),
            const SizedBox(height: 12),
            AppTextField(
              label: l.clinicFormPhone,
              controller: _phone,
              keyboardType: TextInputType.phone,
              forceLtr: true,
            ),
            const SizedBox(height: 20),
            MgmtSaveButton(label: l.clinicFormCreate, saving: _saving, onPressed: _create),
          ],
        ),
      ),
    );
  }
}

/// A short, user-facing reason for a failed management request.
String managementError(BuildContext context, Object error) => messageForError(context, error);

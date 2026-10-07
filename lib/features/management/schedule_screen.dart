import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../bookings/models.dart';
import '../bookings/widgets/booking_tile.dart';
import '../home/home_style.dart';
import 'clinics_screen.dart' show formatClock, weekdayName;
import 'management_widgets.dart';
import 'models.dart';
import 'repository.dart';
import 'providers.dart';

/// Appointments and weekly availability.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(l.scheduleTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, HomeSpacing.top, AppSpacing.gutter, 4),
            child: Row(
              children: [
                _TabChip(
                  label: l.scheduleTabBookings,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 8),
                _TabChip(
                  label: l.scheduleTabAvailability,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          Expanded(child: _tab == 0 ? const _BookingsTab() : const _AvailabilityTab()),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppColors.bgSoft : AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            label,
            style: HomeType.chip.copyWith(color: selected ? AppColors.primary : AppColors.navy),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Appointments
// ---------------------------------------------------------------------------

class _BookingsTab extends ConsumerStatefulWidget {
  const _BookingsTab();

  @override
  ConsumerState<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends ConsumerState<_BookingsTab> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent * 0.8) {
        ref.read(scheduleProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setFilter(ScheduleFilter f) => ref.read(scheduleFilterProvider.notifier).state = f;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final list = ref.watch(scheduleProvider);
    final filter = ref.watch(scheduleFilterProvider);
    final page = list.valueOrNull;
    final reloading = list.isLoading && page != null;

    return RefreshIndicator(
      onRefresh: () => ref.read(scheduleProvider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 8, AppSpacing.gutter, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterBar(filter: filter, onChanged: _setFilter),
                  const SizedBox(height: 12),
                  if (page != null) Text(l.scheduleCount(page.pagination.count), style: HomeType.meta),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          if (reloading)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
            ),
          if (list.hasError && page == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppErrorView(
                error: list.error!,
                onRetry: () => ref.read(scheduleProvider.notifier).refresh(),
              ),
            )
          else if (page == null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              sliver: SliverList.separated(
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: HomeSpacing.card),
                itemBuilder: (_, __) => const Skeleton(height: 130, radius: homeCardRadius),
              ),
            )
          else if (page.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyView(
                icon: Icons.event_busy_outlined,
                title: l.scheduleEmpty,
                hint: l.scheduleEmptyHint,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, 0),
              sliver: SliverAnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: reloading ? 0.5 : 1,
                sliver: SliverList.list(children: _rows(context, page.items)),
              ),
            ),
          if (page != null && page.hasMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  /// Bookings with a day heading wherever the (local) day changes.
  List<Widget> _rows(BuildContext context, List<StaffBooking> items) {
    final material = MaterialLocalizations.of(context);
    final rows = <Widget>[];
    DateTime? day;
    for (final b in items) {
      final local = b.startAt?.toLocal();
      final d = local == null ? null : DateTime(local.year, local.month, local.day);
      if (d != null && d != day) {
        day = d;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(material.formatFullDate(d), style: HomeType.cardTitle),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: HomeSpacing.card),
          child: _BookingCard(booking: b),
        ),
      );
    }
    return rows;
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final ScheduleFilter filter;
  final ValueChanged<ScheduleFilter> onChanged;

  static const _statuses = [
    'pending',
    'confirmed',
    'completed',
    'no_show',
    'cancelled_by_patient',
    'cancelled_by_clinic',
  ];

  static String statusLabel(L l, String s) => switch (s) {
    'pending' => l.statusPending,
    'confirmed' => l.statusConfirmed,
    'completed' => l.statusCompleted,
    'no_show' => l.statusNoShow,
    'cancelled_by_patient' => l.statusCancelledByPatient,
    'cancelled_by_clinic' => l.statusCancelledByClinic,
    _ => s,
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    Future<void> pickDate() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: filter.date == null ? now : DateTime.tryParse(filter.date!) ?? now,
        firstDate: DateTime(now.year - 2),
        lastDate: DateTime(now.year + 2),
        helpText: l.scheduleDatePick,
      );
      if (picked != null) onChanged(filter.copyWith(date: _isoDate(picked)));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TabChip(
          label: l.scheduleViewUpcoming,
          selected: filter.upcoming,
          onTap: () => onChanged(filter.copyWith(upcoming: true)),
        ),
        _TabChip(
          label: l.scheduleViewAll,
          selected: !filter.upcoming,
          onTap: () => onChanged(filter.copyWith(upcoming: false)),
        ),
        // One day, with a way back to "any day".
        Material(
          color: filter.date == null ? AppColors.surface : AppColors.bgSoft,
          shape: StadiumBorder(
            side: BorderSide(color: filter.date == null ? AppColors.border : AppColors.primary),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: pickDate,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 8, top: 8, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    filter.date ?? l.scheduleDate,
                    textDirection: TextDirection.ltr,
                    style: HomeType.chip,
                  ),
                  if (filter.date != null)
                    InkWell(
                      onTap: () => onChanged(filter.copyWith(date: null)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Semantics(
                          label: l.scheduleDateAny,
                          child: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        PopupMenuButton<String?>(
          tooltip: l.scheduleStatus,
          initialValue: filter.status,
          onSelected: (s) => onChanged(filter.copyWith(status: s == '' ? null : s)),
          itemBuilder: (_) => [
            PopupMenuItem(value: '', child: Text(l.scheduleStatusAll)),
            for (final s in _statuses) PopupMenuItem(value: s, child: Text(statusLabel(l, s))),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: ShapeDecoration(
              color: filter.status == null ? AppColors.surface : AppColors.bgSoft,
              shape: StadiumBorder(
                side: BorderSide(color: filter.status == null ? AppColors.border : AppColors.primary),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  filter.status == null ? l.scheduleStatusAll : statusLabel(l, filter.status!),
                  style: HomeType.chip,
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingCard extends ConsumerStatefulWidget {
  const _BookingCard({required this.booking});

  final StaffBooking booking;

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  /// True while an action is on its way to the server. The buttons are disabled
  /// for that time, so a double tap cannot send the same transition twice (the
  /// second would be refused, or worse, applied to the next state).
  bool _busy = false;

  Future<void> _act(BookingAction action, {String? reason}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final notifier = ref.read(scheduleProvider.notifier);
    final repo = ref.read(managementRepositoryProvider);
    await runManagementAction(
      context,
      () => repo.transition(widget.booking.id, action, reason: reason),
      successMessage: L.of(context).scheduleUpdated,
      onDone: (_) => notifier.refresh(),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel() async {
    // null = dismissed; an empty string = confirmed without a reason.
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelReasonDialog(),
    );
    if (reason == null || !mounted) return;
    await _act(BookingAction.cancel, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final b = widget.booking;

    // Which transitions are offered follows the booking's status. Whether one is
    // *allowed* right now (for example, marking a no-show before the visit) is
    // the server's rule, and its refusal is shown rather than second-guessed here.
    final actions = <Widget>[
      if (b.status == BookingStatus.pending)
        FilledButton(
          onPressed: _busy ? null : () => _act(BookingAction.confirm),
          style: _actionStyle,
          child: Text(l.scheduleConfirm),
        ),
      if (b.status == BookingStatus.confirmed)
        FilledButton(
          onPressed: _busy ? null : () => _act(BookingAction.complete),
          style: _actionStyle,
          child: Text(l.scheduleComplete),
        ),
      if (b.status == BookingStatus.confirmed)
        OutlinedButton(
          onPressed: _busy ? null : () => _act(BookingAction.noShow),
          style: _outlineStyle,
          child: Text(l.scheduleNoShow),
        ),
      if (b.status.isActive)
        OutlinedButton(
          onPressed: _busy ? null : _cancel,
          style: _outlineStyle.copyWith(
            foregroundColor: const WidgetStatePropertyAll(AppColors.danger),
          ),
          child: Text(l.actionCancel),
        ),
    ];

    return MgmtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [
                    Text(
                      b.displayTime,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(b.patientName, style: HomeType.cardTitle.copyWith(fontSize: 15.5)),
                  ],
                ),
              ),
              BookingStatusChip(status: b.status),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              if (b.durationMinutes != null)
                Text(l.scheduleDuration(b.durationMinutes!), style: HomeType.meta),
              if (b.patientPhone.isNotEmpty)
                Text(b.patientPhone, style: HomeType.meta, textDirection: TextDirection.ltr),
              if (b.fee != null)
                Text('${l.homeFeeLabel}: ${l.homeFeeAmount(b.fee!)}', style: HomeType.meta),
            ],
          ),
          if (b.clinicName.isNotEmpty) Text(b.clinicName, style: HomeType.meta),
          if (b.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(b.reason, style: HomeType.doctorSpecialty),
          ],
          if (actions.isNotEmpty) ...[
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }

  static final _actionStyle = FilledButton.styleFrom(
    minimumSize: const Size(0, 38),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: HomeType.button,
  );

  static final _outlineStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(0, 38),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: HomeType.button,
  );
}

/// Asks why an appointment is being cancelled. The reason is optional.
///
/// Its own widget so the text controller lives exactly as long as the dialog —
/// including the exit animation, during which the field is still on screen.
class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog();

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
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
      title: Text(l.scheduleCancel),
      content: TextField(
        controller: _reason,
        maxLines: 2,
        decoration: InputDecoration(hintText: l.scheduleCancelReason),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionClose)),
        TextButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: Text(l.scheduleCancel, style: const TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Availability
// ---------------------------------------------------------------------------

class _AvailabilityTab extends ConsumerWidget {
  const _AvailabilityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final windows = ref.watch(availabilityWindowsProvider);
    final clinics = ref.watch(myClinicsProvider).valueOrNull ?? const <MyClinic>[];

    String clinicName(String clinicId) =>
        clinics.where((c) => c.clinicId == clinicId).firstOrNull?.nameAr ?? '';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(availabilityWindowsProvider);
        await ref.read(availabilityWindowsProvider.future).then((_) {}, onError: (_) {});
      },
      child: AsyncValueView<List<AvailabilityWindow>>(
        value: windows,
        onRetry: () => ref.invalidate(availabilityWindowsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: ListView(
          children: [
            AppEmptyView(
              icon: Icons.schedule_rounded,
              title: l.windowsEmpty,
              hint: l.windowsEmptyHint,
              action: FilledButton(
                onPressed: () => showAddWindowSheet(context),
                child: Text(l.windowsAdd),
              ),
            ),
          ],
        ),
        data: (list) {
          final sorted = [...list]..sort((a, b) {
            final byDay = a.weekday.compareTo(b.weekday);
            return byDay != 0 ? byDay : a.start.compareTo(b.start);
          });
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 8, AppSpacing.gutter, AppSpacing.xl),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: () => showAddWindowSheet(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l.windowsAdd),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40), textStyle: HomeType.button),
                ),
              ),
              const SizedBox(height: HomeSpacing.card),
              for (final w in sorted) ...[
                _WindowCard(window: w, clinicName: clinicName(w.clinicId)),
                const SizedBox(height: HomeSpacing.card),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WindowCard extends ConsumerStatefulWidget {
  const _WindowCard({required this.window, required this.clinicName});

  final AvailabilityWindow window;
  final String clinicName;

  @override
  ConsumerState<_WindowCard> createState() => _WindowCardState();
}

class _WindowCardState extends ConsumerState<_WindowCard> {
  /// A request is in flight: the switch and the delete button wait for it.
  bool _busy = false;

  Future<void> _run(Future<Object?> Function(ManagementRepository repo) call) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(managementRepositoryProvider);
    await runManagementAction(
      context,
      () => call(repo),
      onDone: (c) => c.invalidate(availabilityWindowsProvider),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    final l = L.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.windowDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.managementDelete, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _run((repo) => repo.deleteWindow(widget.window.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final w = widget.window;

    return MgmtCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(weekdayName(l, w.weekday), style: HomeType.cardTitle.copyWith(fontSize: 15.5)),
                Text(
                  '${w.start} – ${w.end}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                if (w.durationMinutes != null)
                  Text(l.windowMinutes(w.durationMinutes!), style: HomeType.meta),
                if (widget.clinicName.isNotEmpty) Text(widget.clinicName, style: HomeType.meta),
              ],
            ),
          ),
          Switch(
            value: w.isActive,
            onChanged: _busy ? null : (v) => _run((repo) => repo.setWindowActive(w.id, v)),
          ),
          IconButton(
            tooltip: l.managementDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
    );
  }
}

Future<void> showAddWindowSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _AddWindowSheet(),
);

class _AddWindowSheet extends ConsumerStatefulWidget {
  const _AddWindowSheet();

  @override
  ConsumerState<_AddWindowSheet> createState() => _AddWindowSheetState();
}

class _AddWindowSheetState extends ConsumerState<_AddWindowSheet> {
  int _weekday = 6;
  String? _clinicId;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  final _duration = TextEditingController(text: '30');
  bool _saving = false;

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _create(List<MyClinic> clinics) async {
    final l = L.of(context);
    final minutes = int.tryParse(_duration.text.trim());
    final clinic = _clinicId ?? clinics.firstOrNull?.clinicId;
    if (minutes == null || minutes <= 0 || clinic == null) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final ok = await runManagementAction(
      context,
      () => ref
          .read(managementRepositoryProvider)
          .addAvailabilityWindow(
            clinicId: clinic,
            weekday: _weekday,
            start: formatClock(_start),
            end: formatClock(_end),
            durationMinutes: minutes,
          ),
      successMessage: l.managementSaved,
      onDone: (c) => c.invalidate(availabilityWindowsProvider),
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
    final clinics = ref.watch(myClinicsProvider).valueOrNull ?? const <MyClinic>[];
    final selected = _clinicId ?? clinics.firstOrNull?.clinicId;

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
            Text(l.windowsAdd, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            AppDropdown<int>(
              label: l.windowFormWeekday,
              value: _weekday,
              items: [
                for (var d = 1; d <= 7; d++) DropdownMenuItem(value: d, child: Text(weekdayName(l, d))),
              ],
              onChanged: (d) => setState(() => _weekday = d ?? _weekday),
            ),
            const SizedBox(height: 12),
            AppDropdown<String>(
              label: l.windowFormClinic,
              value: selected,
              items: [for (final c in clinics) DropdownMenuItem(value: c.clinicId, child: Text(c.nameAr))],
              onChanged: (v) => setState(() => _clinicId = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _pick(start: true),
                  child: Text('${l.clinicHoursFrom} ${formatClock(_start)}', textDirection: TextDirection.ltr),
                ),
                OutlinedButton(
                  onPressed: () => _pick(start: false),
                  child: Text('${l.clinicHoursTo} ${formatClock(_end)}', textDirection: TextDirection.ltr),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: l.windowFormDuration,
              controller: _duration,
              keyboardType: TextInputType.number,
              forceLtr: true,
            ),
            const SizedBox(height: 20),
            MgmtSaveButton(
              label: l.windowCreate,
              saving: _saving,
              onPressed: () => _create(clinics),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_style.dart';
import 'management_widgets.dart';
import 'models.dart';
import 'providers.dart';
import '../../core/theme/app_palette.dart';

/// The label for one of the backend's assistant permission flags.
String flagLabel(L l, String key) => switch (key) {
  'can_view_bookings' => l.flag_can_view_bookings,
  'can_create_bookings' => l.flag_can_create_bookings,
  'can_update_bookings' => l.flag_can_update_bookings,
  'can_cancel_bookings' => l.flag_can_cancel_bookings,
  'can_manage_schedule' => l.flag_can_manage_schedule,
  'can_view_patient_phone' => l.flag_can_view_patient_phone,
  'can_create_patient_next_visit' => l.flag_can_create_patient_next_visit,
  'can_request_duration_verification' => l.flag_can_request_duration_verification,
  'can_review_payment_proofs' => l.flag_can_review_payment_proofs,
  // A permission this build has no wording for is still shown, never hidden.
  _ => key,
};

/// The doctor's assistants: who they are, where they work, and what each may do.
class AssistantsScreen extends ConsumerWidget {
  const AssistantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final assistants = ref.watch(assistantsProvider);

    return Scaffold(
      backgroundColor: context.palette.page,
      appBar: AppBar(title: Text(l.assistantsTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(assistantsProvider);
          await ref.read(assistantsProvider.future).then((_) {}, onError: (_) {});
        },
        child: AsyncValueView<List<AssistantProfile>>(
          value: assistants,
          onRetry: () => ref.invalidate(assistantsProvider),
          isEmpty: (list) => list.isEmpty,
          empty: ListView(
            children: [
              AppEmptyView(
                icon: Icons.groups_2_outlined,
                title: l.assistantsEmptyTitle,
                hint: l.assistantsEmptyBody,
                action: FilledButton(
                  onPressed: () => showAddAssistantSheet(context),
                  child: Text(l.assistantsAdd),
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
                  onPressed: () => showAddAssistantSheet(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l.assistantsAdd),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: context.homeType.button,
                  ),
                ),
              ),
              const SizedBox(height: HomeSpacing.card),
              for (final a in list) ...[
                _AssistantCard(assistant: a),
                const SizedBox(height: HomeSpacing.card),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.assistant});

  final AssistantProfile assistant;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return MgmtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: context.palette.pageSoft,
                child: Text(
                  assistant.fullName.trim().isEmpty
                      ? '؟'
                      : assistant.fullName.trim().characters.first,
                  style: TextStyle(color: context.palette.primary, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assistant.fullName,
                      style: context.homeType.cardTitle.copyWith(fontSize: 15.5),
                    ),
                    Text(
                      assistant.phone,
                      style: context.homeType.meta,
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
              if (!assistant.isActive)
                MgmtBadge(label: l.assistantInactive, color: context.palette.danger),
            ],
          ),
          if (assistant.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(assistant.notes, style: context.homeType.meta),
          ],
          for (final a in assistant.assignments)
            // Keyed by what the server holds, so a refresh that changed the flags
            // (here or on the web) resets the switches to match.
            _AssignmentTile(
              key: ValueKey((
                a.id,
                a.isActive,
                a.flags.entries.map((e) => '${e.key}=${e.value}').join(','),
              )),
              assignment: a,
            ),
        ],
      ),
    );
  }
}

/// One place an assistant works, with the permissions granted there.
class _AssignmentTile extends ConsumerStatefulWidget {
  const _AssignmentTile({super.key, required this.assignment});

  final AssistantAssignment assignment;

  @override
  ConsumerState<_AssignmentTile> createState() => _AssignmentTileState();
}

class _AssignmentTileState extends ConsumerState<_AssignmentTile> {
  late Map<String, bool> _flags = {...widget.assignment.flags};
  bool _saving = false;

  bool get _dirty {
    final saved = widget.assignment.flags;
    return _flags.entries.any((e) => saved[e.key] != e.value);
  }

  Future<void> _save() async {
    final l = L.of(context);
    setState(() => _saving = true);
    await runManagementAction(
      context,
      () => ref.read(managementRepositoryProvider).updatePermissions(widget.assignment.id, _flags),
      successMessage: l.managementSaved,
      onDone: (c) => c.invalidate(assistantsProvider),
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _revoke() async {
    final l = L.of(context);
    final a = widget.assignment;
    final name = a.coversAllClinics ? l.assistantAllClinics : a.clinicName;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.assistantRevokeConfirm(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.assistantRevoke, style: TextStyle(color: context.palette.danger)),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await runManagementAction(
      context,
      () => ref.read(managementRepositoryProvider).revokeAssignment(a.id),
      onDone: (c) => c.invalidate(assistantsProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final a = widget.assignment;
    // Show every flag the backend reports; fall back to the known list so a
    // brand-new assignment still has something to toggle.
    final keys = {...assistantFlagKeys, ..._flags.keys}.toList();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        maintainState: true,
        leading: Icon(Icons.local_hospital_outlined, color: context.palette.primary, size: 20),
        title: Text(
          a.coversAllClinics ? l.assistantAllClinics : a.clinicName,
          style: context.homeType.cardTitle,
        ),
        subtitle: Text(l.assistantPermissionsCount(a.grantedCount), style: context.homeType.meta),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.assistantPermissions, style: context.homeType.cardTitle),
          for (final k in keys)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(flagLabel(l, k), style: context.homeType.doctorSpecialty),
              value: _flags[k] ?? false,
              onChanged: (v) => setState(() => _flags = {..._flags, k: v}),
            ),
          const SizedBox(height: 6),
          MgmtSaveButton(label: l.actionSave, saving: _saving, onPressed: _dirty ? _save : () {}),
          TextButton.icon(
            onPressed: _revoke,
            icon: Icon(Icons.link_off_rounded, size: 18, color: context.palette.danger),
            label: Text(l.assistantRevoke, style: TextStyle(color: context.palette.danger)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add an assistant
// ---------------------------------------------------------------------------

Future<void> showAddAssistantSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _AddAssistantSheet(),
);

class _AddAssistantSheet extends ConsumerStatefulWidget {
  const _AddAssistantSheet();

  @override
  ConsumerState<_AddAssistantSheet> createState() => _AddAssistantSheetState();
}

class _AddAssistantSheetState extends ConsumerState<_AddAssistantSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  /// Null means every clinic.
  String? _clinicId;
  final Map<String, bool> _flags = {for (final k in assistantFlagKeys) k: false};
  bool _saving = false;
  String? _nameError;
  String? _phoneError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l = L.of(context);
    setState(() {
      _nameError = _name.text.trim().isEmpty ? l.managementFailed : null;
      _phoneError = _phone.text.trim().isEmpty ? l.managementFailed : null;
    });
    if (_nameError != null || _phoneError != null) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final ok = await runManagementAction(
      context,
      () => ref
          .read(managementRepositoryProvider)
          .createAssistant(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            notes: _notes.text.trim(),
            clinicId: _clinicId,
            flags: _flags,
          ),
      successMessage: l.managementSaved,
      onDone: (c) => c.invalidate(assistantsProvider),
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
            Text(l.assistantsAdd, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            AppTextField(
              label: l.assistantFormName,
              controller: _name,
              errorText: _nameError,
              required: true,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: l.assistantFormPhone,
              controller: _phone,
              errorText: _phoneError,
              keyboardType: TextInputType.phone,
              forceLtr: true,
              required: true,
            ),
            const SizedBox(height: 12),
            AppTextField(label: l.assistantFormNotes, controller: _notes, maxLines: 2),
            const SizedBox(height: 12),
            AppDropdown<String?>(
              label: l.assistantFormClinic,
              value: _clinicId,
              items: [
                DropdownMenuItem(value: null, child: Text(l.assistantAllClinics)),
                for (final c in clinics) DropdownMenuItem(value: c.clinicId, child: Text(c.nameAr)),
              ],
              onChanged: (v) => setState(() => _clinicId = v),
            ),
            const SizedBox(height: 12),
            Text(l.assistantPermissions, style: context.homeType.cardTitle),
            for (final k in assistantFlagKeys)
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(flagLabel(l, k), style: context.homeType.doctorSpecialty),
                value: _flags[k] ?? false,
                onChanged: (v) => setState(() => _flags[k] = v),
              ),
            const SizedBox(height: 16),
            MgmtSaveButton(label: l.assistantCreate, saving: _saving, onPressed: _create),
          ],
        ),
      ),
    );
  }
}

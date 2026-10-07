import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../auth/phone_verification.dart';
import '../home/home_style.dart';
import 'widgets/account_widgets.dart';

/// Editing the account's own details.
///
/// Only the fields `PATCH /auth/me/` accepts and this screen has always sent:
/// first name, last name and email. The phone is the login identifier and
/// changing it is a verified flow the backend owns, so it is shown read-only
/// rather than offered as an editable field that would be rejected. Validation
/// is the server's: its field errors are shown under the fields they concern.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _email;

  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _first = TextEditingController(text: user?.firstName ?? '');
    _last = TextEditingController(text: user?.lastName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    for (final c in [_first, _last, _email]) {
      c.addListener(_onEdit);
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  void _onEdit() => setState(() {});

  /// Whether anything differs from the account as last loaded.
  bool get _dirty {
    final u = ref.read(currentUserProvider);
    return _first.text.trim() != (u?.firstName ?? '').trim() ||
        _last.text.trim() != (u?.lastName ?? '').trim() ||
        _email.text.trim() != (u?.email ?? '').trim();
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await ref.read(authControllerProvider.notifier).updateProfile({
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        // An empty string clears the address; null would be rejected as invalid.
        'email': _email.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).accountSaved)));
      Navigator.of(context).maybePop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? messageForError(context, e) : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    // Fields on this screen: a soft fill and no outline at rest, the brand
    // colour on focus, red on error. Scoped here, so other forms are unchanged.
    final fieldTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        disabledBorder: border(Colors.transparent),
        focusedBorder: border(AppColors.primary, 1.5),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.5),
      ),
      textTheme: theme.textTheme.copyWith(
        labelLarge: theme.textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l.accountProfile),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Theme(
        data: fieldTheme,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 16, AppSpacing.gutter, 24),
          children: [
            if (user != null) ...[
              _Summary(name: user.displayName, phone: user.phone),
              const SizedBox(height: 16),
            ],
            FormErrorBanner(message: _error),
            _Panel(
              title: l.pfPersonalDetails,
              children: [
                AppTextField(
                  label: l.accountFirstName,
                  controller: _first,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  errorText: _fieldErrors['first_name'],
                  enabled: !_busy,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: l.accountLastName,
                  controller: _last,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  errorText: _fieldErrors['last_name'],
                  enabled: !_busy,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Panel(
              title: l.pfContactDetails,
              children: [
                AppTextField(
                  label: l.authEmail,
                  controller: _email,
                  forceLtr: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  errorText: _fieldErrors['email'],
                  enabled: !_busy,
                  onSubmitted: (_) => _dirty ? _save() : null,
                ),
                if (user != null) ...[
                  const SizedBox(height: 14),
                  _ReadOnlyPhone(
                    phone: user.phone,
                    verified: user.isPhoneVerified,
                    onVerify: user.isPhoneVerified || user.phone.isEmpty
                        ? null
                        : () => startPhoneVerification(
                            context,
                            ref,
                            phone: user.phone,
                            next: Routes.editProfile,
                          ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _SaveBar(
        busy: _busy,
        enabled: _dirty && !_busy,
        label: l.pfSaveChanges,
        onSave: _save,
      ),
    );
  }
}

/// Who is being edited: avatar, name, phone.
class _Summary extends StatelessWidget {
  const _Summary({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(homeCardRadius),
      boxShadow: AppShadows.soft,
    ),
    child: Row(
      children: [
        ProfileAvatar(name: name, size: 54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HomeType.cardTitle.copyWith(fontSize: 16),
              ),
              if (phone.isNotEmpty)
                Text(
                  phone,
                  textDirection: TextDirection.ltr,
                  style: HomeType.meta.copyWith(fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(homeCardRadius),
      boxShadow: AppShadows.soft,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: HomeType.sectionTitle.copyWith(fontSize: 15)),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

/// The phone, shown as information rather than a greyed-out input: a lock says
/// it cannot be edited, and the account's real verification state sits beside
/// it.
class _ReadOnlyPhone extends StatelessWidget {
  const _ReadOnlyPhone({required this.phone, required this.verified, this.onVerify});

  final String phone;
  final bool verified;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Semantics(
      label: '${l.authPhone}، ${l.pfReadOnly}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.authPhone, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      phone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 15, color: AppColors.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          PhoneStatusChip(
            verified: verified,
            label: verified ? l.acPhoneVerified : l.acPhoneUnverified,
            actionLabel: l.acVerifyNow,
            onVerify: onVerify,
          ),
          const SizedBox(height: 6),
          Text(
            l.pfPhoneReadOnly,
            style: HomeType.meta.copyWith(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.busy,
    required this.enabled,
    required this.label,
    required this.onSave,
  });

  final bool busy;
  final bool enabled;
  final String label;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 10, AppSpacing.gutter, 10),
        child: FilledButton(
          onPressed: enabled ? onSave : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            textStyle: HomeType.button.copyWith(fontSize: 15),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: busy
                ? const SizedBox(
                    key: ValueKey('busy'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Text(label, key: const ValueKey('label')),
          ),
        ),
      ),
    ),
  );
}

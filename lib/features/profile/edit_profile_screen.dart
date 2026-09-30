import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';

/// Editing the account's own details.
///
/// Only the fields `/auth/me/` accepts on PATCH: first name, last name, email
/// and preferred language. The phone is the login identifier and changing it is a
/// verified flow the backend owns, so it is shown read-only here rather than
/// offered as an editable field that would be rejected.
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
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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

    return Scaffold(
      appBar: AppBar(title: Text(l.accountProfile)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          FormErrorBanner(message: _error),
          AppTextField(
            label: l.accountFirstName,
            controller: _first,
            textInputAction: TextInputAction.next,
            errorText: _fieldErrors['first_name'],
            enabled: !_busy,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l.accountLastName,
            controller: _last,
            textInputAction: TextInputAction.next,
            errorText: _fieldErrors['last_name'],
            enabled: !_busy,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l.authEmail,
            controller: _email,
            forceLtr: true,
            keyboardType: TextInputType.emailAddress,
            errorText: _fieldErrors['email'],
            enabled: !_busy,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l.authPhone,
            controller: TextEditingController(text: user?.phone ?? ''),
            forceLtr: true,
            enabled: false,
            helper: l.joinPatientUntilApproved,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? l.actionSaving : l.actionSave),
          ),
        ],
      ),
    );
  }
}

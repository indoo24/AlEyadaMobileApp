import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/auth/models.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';

/// Patient registration.
///
/// The consent checkbox is not decoration: the backend requires the ids of the
/// *current* policy versions with the payload and refuses the signup without
/// them, so the versions are fetched rather than assumed.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

final _currentPoliciesProvider = FutureProvider<List<LegalPolicy>>(
  (ref) => ref.watch(authRepositoryProvider).currentPolicies(),
);

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _consent = false;
  bool _busy = false;
  String? _formError;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(List<LegalPolicy> policies) async {
    final l = L.of(context);
    setState(() {
      _formError = null;
      _fieldErrors = const {};
    });

    final local = <String, String>{};
    if (_name.text.trim().isEmpty) local['full_name'] = l.authNameRequired;
    if (_phone.text.trim().isEmpty) local['phone'] = l.authPhoneRequired;
    if (_password.text.isEmpty) local['password'] = l.authPasswordRequired;
    if (local.isNotEmpty) {
      setState(() => _fieldErrors = local);
      return;
    }
    if (!_consent) {
      setState(() => _formError = l.consentRequired);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).registerPatient({
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        'password': _password.text,
        'accepted_policy_versions': policies.map((p) => p.id).toList(),
      });
      if (!mounted) return;
      // The account exists but the phone is unverified. Verifying it is also what
      // signs them in, so the OTP screen is the next step rather than a detour.
      context.push('${Routes.otp}?phone=${Uri.encodeComponent(_phone.text.trim())}&purpose=signup');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.fieldErrors;
        _formError = e.fieldErrors.isEmpty ? messageForError(context, e) : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final policies = ref.watch(_currentPoliciesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(l.authSignUp), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            Text(l.authSignUpSubtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            FormErrorBanner(message: _formError),

            AppTextField(
              label: l.authFullName,
              controller: _name,
              required: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              errorText: _fieldErrors['full_name'],
              enabled: !_busy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l.authPhone,
              controller: _phone,
              hint: l.authPhoneHint,
              required: true,
              forceLtr: true,
              keyboardType: TextInputType.phone,
              inputFormatters: const [DigitsOnlyFormatter()],
              textInputAction: TextInputAction.next,
              errorText: _fieldErrors['phone'],
              enabled: !_busy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l.authEmail,
              controller: _email,
              forceLtr: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              errorText: _fieldErrors['email'],
              enabled: !_busy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l.authPassword,
              controller: _password,
              required: true,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _fieldErrors['password'],
              enabled: !_busy,
            ),

            const SizedBox(height: AppSpacing.lg),
            policies.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => FormErrorBanner(message: messageForError(context, e)),
              data: (list) => CheckboxListTile(
                value: _consent,
                onChanged: _busy ? null : (v) => setState(() => _consent = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(l.consentAccept, style: Theme.of(context).textTheme.bodySmall),
                subtitle: list.isEmpty
                    ? null
                    : Text(
                        list.map((p) => p.titleAr).join(' • '),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy || !policies.hasValue ? null : () => _submit(policies.requireValue),
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(l.authSignUp),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l.authHaveAccount, style: Theme.of(context).textTheme.bodySmall),
                TextButton(
                  onPressed: _busy ? null : () => context.pop(),
                  child: Text(l.authSignIn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

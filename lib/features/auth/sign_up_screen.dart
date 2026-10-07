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
import 'widgets/auth_widgets.dart';

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

  /// Drop a field's error as soon as the user edits that field.
  void _clearError(String key) {
    if (_fieldErrors.containsKey(key) || _formError != null) {
      setState(() {
        _fieldErrors = {..._fieldErrors}..remove(key);
        _formError = null;
      });
    }
  }

  Future<void> _submit(List<LegalPolicy> policies) async {
    // A second tap (or the keyboard's "done") while a request is in flight.
    if (_busy) return;
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
    final canSubmit = policies.hasValue;
    void submit() => canSubmit ? _submit(policies.requireValue) : null;

    return AuthScaffold(
      children: [
        AuthBrandHeader(title: l.authSignUp, subtitle: l.authSignUpSubtitle),
        const SizedBox(height: 22),
        AutofillGroup(
          child: AuthCard(
            children: [
              FormErrorBanner(message: _formError),
              AuthTextField(
                label: l.authFullName,
                controller: _name,
                icon: Icons.person_outline_rounded,
                required: true,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                errorText: _fieldErrors['full_name'],
                onChanged: (_) => _clearError('full_name'),
                enabled: !_busy,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: l.authPhone,
                controller: _phone,
                icon: Icons.phone_iphone_rounded,
                hint: l.authPhoneHint,
                required: true,
                forceLtr: true,
                keyboardType: TextInputType.phone,
                inputFormatters: const [DigitsOnlyFormatter()],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                errorText: _fieldErrors['phone'],
                onChanged: (_) => _clearError('phone'),
                enabled: !_busy,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: l.authEmail,
                controller: _email,
                icon: Icons.mail_outline_rounded,
                forceLtr: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                errorText: _fieldErrors['email'],
                onChanged: (_) => _clearError('email'),
                enabled: !_busy,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: l.authPassword,
                controller: _password,
                icon: Icons.lock_outline_rounded,
                required: true,
                obscure: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                errorText: _fieldErrors['password'],
                onChanged: (_) => _clearError('password'),
                onSubmitted: (_) => submit(),
                enabled: !_busy,
              ),
              const SizedBox(height: 14),
              policies.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
                error: (e, _) =>
                    _PoliciesError(onRetry: () => ref.invalidate(_currentPoliciesProvider)),
                data: (list) => _ConsentRow(
                  value: _consent,
                  policies: list,
                  enabled: !_busy,
                  onChanged: (v) => setState(() {
                    _consent = v;
                    if (v && _formError == l.consentRequired) _formError = null;
                  }),
                ),
              ),
              const SizedBox(height: 14),
              AuthPrimaryButton(
                label: l.authSignUp,
                busy: _busy,
                onPressed: canSubmit ? submit : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AuthFooterLink(
          question: l.authHaveAccount,
          action: l.authSignIn,
          onTap: _busy ? null : () => context.pop(),
        ),
      ],
    );
  }
}

/// The agreement: a real checkbox with its sentence as the tap target, and the
/// current policies — the backend's own titles and text — readable from here.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.policies,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final List<LegalPolicy> policies;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final readable = policies.where((p) => (p.bodyAr ?? '').trim().isNotEmpty).toList();
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 8),
      decoration: BoxDecoration(
        color: value ? AppColors.bgSoft : AppColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? () => onChanged(!value) : null,
              child: Row(
                children: [
                  Checkbox(
                    value: value,
                    onChanged: enabled ? (v) => onChanged(v ?? false) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  Expanded(
                    child: Text(
                      l.consentAccept,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (readable.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 44),
              child: Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  for (final p in readable)
                    _PolicyLink(title: p.titleAr, onTap: () => _showPolicy(context, p)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The policy's own text, as the backend publishes it.
  static Future<void> _showPolicy(BuildContext context, LegalPolicy p) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (ctx, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 12, AppSpacing.gutter, 28),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadii.pillRadius,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  p.titleAr,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p.bodyAr!.trim(),
                style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.8),
              ),
            ],
          ),
        ),
      );
}

class _PoliciesError extends StatelessWidget {
  const _PoliciesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.auPoliciesRetry,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l.actionRetry)),
        ],
      ),
    );
  }
}

/// A compact inline link to one policy's text.
class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: title,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

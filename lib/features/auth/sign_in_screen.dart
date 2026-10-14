import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/safe_redirect.dart';
import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/auth_widgets.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.next});

  /// Where the user was headed before the guard redirected them here.
  final String? next;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _busy = false;
  String? _formError;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// The backend accepts a phone or an email as the identifier and normalises
  /// phone formats itself, so the app just forwards whichever the user typed
  /// rather than guessing and validating a format the server may accept anyway.
  bool get _looksLikeEmail => _identifier.text.contains('@');

  /// Drop a field's error as soon as the user edits that field.
  void _clearError(String key) {
    if (_fieldErrors.containsKey(key) || _formError != null) {
      setState(() {
        _fieldErrors = {..._fieldErrors}..remove(key);
        _formError = null;
      });
    }
  }

  Future<void> _submit() async {
    // A second tap (or the keyboard's "done") while a request is in flight.
    if (_busy) return;
    final l = L.of(context);
    setState(() {
      _formError = null;
      _fieldErrors = const {};
    });

    if (_identifier.text.trim().isEmpty) {
      setState(() => _fieldErrors = {'phone': l.authPhoneRequired});
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _fieldErrors = {'password': l.authPasswordRequired});
      return;
    }

    setState(() => _busy = true);
    try {
      final auth = ref.read(authControllerProvider.notifier);
      // Read before signing in: signing in forgets it.
      final endedAccountId = auth.endedAccountId;
      await auth.signIn(
        phone: _looksLikeEmail ? null : _identifier.text.trim(),
        email: _looksLikeEmail ? _identifier.text.trim() : null,
        password: _password.text,
      );
      if (!mounted) return;
      // The router's guards decide where to land — a doctor belongs in their
      // practice, a patient in the directory — so this only resumes an
      // interrupted destination, and only a safe one of this account's own.
      final next = resumeLocation(
        widget.next,
        endedAccountId: endedAccountId,
        signedInAccountId: ref.read(authControllerProvider).user?.id,
      );
      if (next != null) context.go(next);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.fieldErrors;
        _formError = e.fieldErrors.isEmpty ? messageForError(context, e) : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _formError = L.of(context).errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AuthScaffold(
      children: [
        const SizedBox(height: 8),
        AuthBrandHeader(title: l.authSignIn, subtitle: l.authSignInSubtitle),
        const SizedBox(height: 24),
        AutofillGroup(
          child: AuthCard(
            children: [
              FormErrorBanner(message: _formError),
              AuthTextField(
                label: l.authPhone,
                controller: _identifier,
                icon: Icons.phone_iphone_rounded,
                hint: l.authPhoneHint,
                required: true,
                forceLtr: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.telephoneNumber],
                errorText: _fieldErrors['phone'] ?? _fieldErrors['email'],
                onChanged: (_) {
                  _clearError('phone');
                  _clearError('email');
                },
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: l.authPassword,
                controller: _password,
                focusNode: _passwordFocus,
                icon: Icons.lock_outline_rounded,
                required: true,
                obscure: _obscure,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                errorText: _fieldErrors['password'],
                onChanged: (_) => _clearError('password'),
                onSubmitted: (_) => _submit(),
                enabled: !_busy,
              ),
              // Secondary, and placed where it is needed: under the password.
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _busy ? null : () => _showForgotSheet(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(l.authForgotPassword),
                ),
              ),
              const SizedBox(height: 6),
              AuthPrimaryButton(label: l.authSignIn, busy: _busy, onPressed: _submit),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AuthFooterLink(
          question: l.authNoAccount,
          action: l.authSignUp,
          onTap: _busy ? null : () => context.push(Routes.signUp),
        ),
      ],
    );
  }

  /// Password reset asks for a phone and then an OTP.
  ///
  /// The confirmation wording never says whether the number was registered — the
  /// backend deliberately does not reveal that, and the UI must not undo it by
  /// saying "we sent you a code" only for known numbers.
  Future<void> _showForgotSheet(BuildContext context) async {
    final phone = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ForgotPasswordSheet(),
    );
    if (phone == null || !context.mounted) return;
    context.push('${Routes.otp}?phone=${Uri.encodeComponent(phone)}&purpose=password_reset');
  }
}

/// Asks for the phone, requests the reset code, and closes with the phone.
///
/// It owns its text controller, so the controller lives exactly as long as the
/// sheet — including its closing animation, which still draws the field.
class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  const _ForgotPasswordSheet();

  @override
  ConsumerState<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  final _phone = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final phone = _phone.text.trim();
    try {
      await ref.read(authRepositoryProvider).forgotPassword(phone);
    } on ApiException {
      // Swallowed on purpose: the endpoint is designed not to disclose whether
      // the phone exists, and surfacing a difference here would leak exactly
      // that.
    }
    if (!mounted) return;
    Navigator.of(context).pop(phone);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: AppRadii.pillRadius),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              l.authForgotPassword,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.auForgotBody,
            style: const TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.6),
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: l.authPhone,
            controller: _phone,
            icon: Icons.phone_iphone_rounded,
            hint: l.authPhoneHint,
            forceLtr: true,
            keyboardType: TextInputType.phone,
            inputFormatters: const [DigitsOnlyFormatter()],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _send(),
            enabled: !_sending,
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(label: l.actionNext, busy: _sending, onPressed: _send),
        ],
      ),
    );
  }
}

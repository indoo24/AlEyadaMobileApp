import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';

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

  Future<void> _submit() async {
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
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            phone: _looksLikeEmail ? null : _identifier.text.trim(),
            email: _looksLikeEmail ? _identifier.text.trim() : null,
            password: _password.text,
          );
      if (!mounted) return;
      // The router's guards decide where to land — a doctor belongs in their
      // practice, a patient in the directory — so this only resumes an
      // interrupted destination.
      final next = widget.next;
      if (next != null && next.isNotEmpty) {
        context.go(next);
      }
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: ListView(
          // Keyboard-safe: the list scrolls the focused field into view rather
          // than the keyboard covering the submit button.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            const Center(child: BrandMark(size: 64)),
            const SizedBox(height: AppSpacing.lg),
            Text(l.authSignIn, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l.authSignInSubtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xl),

            FormErrorBanner(message: _formError),

            AppTextField(
              label: l.authPhone,
              controller: _identifier,
              hint: l.authPhoneHint,
              required: true,
              forceLtr: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.telephoneNumber],
              errorText: _fieldErrors['phone'] ?? _fieldErrors['email'],
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              enabled: !_busy,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              label: l.authPassword,
              controller: _password,
              focusNode: _passwordFocus,
              required: true,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              errorText: _fieldErrors['password'],
              onSubmitted: (_) => _busy ? null : _submit(),
              enabled: !_busy,
            ),

            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(l.authSignIn),
            ),

            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l.authNoAccount, style: Theme.of(context).textTheme.bodySmall),
                TextButton(
                  onPressed: _busy ? null : () => context.push(Routes.signUp),
                  child: Text(l.authSignUp),
                ),
              ],
            ),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _showForgotSheet(context),
                child: Text(l.authForgotPassword),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Password reset asks for a phone and then an OTP.
  ///
  /// The confirmation wording never says whether the number was registered — the
  /// backend deliberately does not reveal that, and the UI must not undo it by
  /// saying "we sent you a code" only for known numbers.
  Future<void> _showForgotSheet(BuildContext context) async {
    final l = L.of(context);
    final phone = TextEditingController();
    var sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.gutter,
          right: AppSpacing.gutter,
          top: AppSpacing.xl,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.xl,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.authForgotPassword, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: l.authPhone,
                controller: phone,
                hint: l.authPhoneHint,
                forceLtr: true,
                keyboardType: TextInputType.phone,
                inputFormatters: const [DigitsOnlyFormatter()],
                enabled: !sending,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        setSheetState(() => sending = true);
                        try {
                          await ref.read(authRepositoryProvider).forgotPassword(phone.text.trim());
                        } on ApiException {
                          // Swallowed on purpose: the endpoint is designed not to
                          // disclose whether the phone exists, and surfacing a
                          // difference here would leak exactly that.
                        }
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        if (!context.mounted) return;
                        context.push(
                          '${Routes.otp}?phone=${Uri.encodeComponent(phone.text.trim())}'
                          '&purpose=password_reset',
                        );
                      },
                child: Text(l.actionNext),
              ),
            ],
          ),
        ),
      ),
    );
    phone.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/safe_redirect.dart';
import '../../core/api/api_error.dart';
import '../../core/auth/guest_mode.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/auth_widgets.dart';
import '../../core/theme/app_palette.dart';

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

  /// Look around without an account. Nothing about the session changes: no
  /// tokens, no user — only the choice, so the router lets them into Home.
  Future<void> _continueAsGuest() async {
    await ref.read(guestModeProvider.notifier).enter();
    if (!mounted) return;
    // Sent here from a page (a protected action): go back to it.
    if (context.canPop()) {
      context.pop();
      return;
    }
    // The welcome screen itself: into the app, at a public page they were on,
    // or Home. Never a protected one — that would only bring them back here.
    final next = safeNextLocation(widget.next);
    context.go(next != null && !isProtectedLocation(next) ? next : Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final guest = ref.watch(guestModeProvider) == true;
    final next = safeNextLocation(widget.next);
    final signUp = next == null
        ? Routes.signUp
        : '${Routes.signUp}?next=${Uri.encodeComponent(next)}';

    // A guest sent here by a protected tab has nothing beneath this screen:
    // back returns them to Home rather than closing the app.
    return PopScope(
      canPop: !guest || context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: _form(context, l, guest: guest, signUp: signUp),
    );
  }

  Widget _form(
    BuildContext context,
    L l, {
    required bool guest,
    required String signUp,
  }) {
    return AuthScaffold(
      children: [
        const SizedBox(height: 8),
        AuthBrandHeader(title: l.authSignIn, subtitle: l.authSignInSubtitle),
        const SizedBox(height: 24),
        // Why a guest is here: what they tried needs an account.
        if (guest && widget.next != null) ...[
          const _SignInRequiredNote(),
          const SizedBox(height: 14),
        ],
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
          onTap: _busy ? null : () => context.push(signUp),
        ),
        const SizedBox(height: 10),
        _GuestAction(onPressed: _busy ? null : _continueAsGuest),
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
      backgroundColor: context.palette.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ForgotPasswordSheet(),
    );
    if (phone == null || !context.mounted) return;
    context.push('${Routes.otp}?phone=${Uri.encodeComponent(phone)}&purpose=password_reset');
  }
}

/// "Sign-in required" — shown to a guest whose action needs an account.
class _SignInRequiredNote extends StatelessWidget {
  const _SignInRequiredNote();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.pageSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 20, color: p.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.authLoginRequired,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: p.heading,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.authSignInToContinue,
                    style: TextStyle(fontSize: 13, color: p.muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Continue as guest": set apart from signing in and creating an account —
/// outlined rather than filled, with a line on what a guest can do.
class _GuestAction extends StatelessWidget {
  const _GuestAction({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.explore_outlined, size: 20),
          label: Text(l.authContinueAsGuest),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: p.heading,
            side: BorderSide(color: p.border),
            textStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.authGuestHint,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.5),
        ),
      ],
    );
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
              decoration: BoxDecoration(
                color: context.palette.border,
                borderRadius: AppRadii.pillRadius,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              l.authForgotPassword,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: context.palette.heading,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.auForgotBody,
            style: TextStyle(fontSize: 13.5, color: context.palette.muted, height: 1.6),
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

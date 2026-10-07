import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/auth_widgets.dart';

/// Phone verification.
///
/// Verifying a signup or login code returns a token pair, so a successful
/// verification also signs the user in — which is why this screen adopts the
/// session rather than sending the user back to sign in.
///
/// A caveat worth knowing while reading this: the backend has no SMS provider
/// wired up yet (only a console delivery that writes the code to the service
/// log). The flow here is the real one and will work unchanged the moment a
/// provider is configured, but until then nobody receives a code by SMS. The app
/// deliberately does not fake it, and deliberately has no bypass.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, required this.purpose, this.next});

  final String phone;

  /// `signup`, `login` or `password_reset`.
  final String purpose;
  final String? next;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  final _newPassword = TextEditingController();

  bool _busy = false;
  bool _resending = false;
  String? _formError;
  Map<String, String> _fieldErrors = const {};

  bool get _isReset => widget.purpose == 'password_reset';

  @override
  void dispose() {
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final l = L.of(context);
    setState(() {
      _formError = null;
      _fieldErrors = const {};
    });
    if (_code.text.trim().isEmpty) {
      setState(() => _fieldErrors = {'code': l.otpCodeRequired});
      return;
    }
    if (_isReset && _newPassword.text.isEmpty) {
      setState(() => _fieldErrors = {'new_password': l.authPasswordRequired});
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = ref.read(authRepositoryProvider);

      if (_isReset) {
        await repo.resetPassword(
          phone: widget.phone,
          code: _code.text.trim(),
          newPassword: _newPassword.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).accountSaved)));
        context.go('/sign-in');
        return;
      }

      final result = await repo.verifyOtp(
        phone: widget.phone,
        purpose: widget.purpose,
        code: _code.text.trim(),
      );
      if (result.tokens != null) {
        await ref
            .read(authControllerProvider.notifier)
            .adoptSession(result.tokens!, user: result.user);
        if (!mounted) return;
        // The router's guards take it from here.
        final next = widget.next;
        context.go(next != null && next.isNotEmpty ? next : '/');
      } else if (!mounted) {
        return;
      } else {
        // Verified but no session issued — send them to sign in rather than
        // pretending they are logged in.
        context.go('/sign-in');
      }
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

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _formError = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestOtp(phone: widget.phone, purpose: widget.purpose);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.of(context).otpResend)));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Resending is rate-limited server-side; say so rather than silently doing
      // nothing.
      setState(() => _formError = messageForError(context, e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AuthScaffold(
      children: [
        const SizedBox(height: 8),
        AuthBrandHeader(
          title: l.otpTitle,
          // The number reads left to right inside the Arabic sentence.
          subtitle: l.otpSentTo('\u2066${widget.phone}\u2069'),
        ),
        const SizedBox(height: 24),
        AuthCard(
          children: [
            FormErrorBanner(message: _formError),
            AuthTextField(
              label: l.otpCode,
              controller: _code,
              icon: Icons.password_rounded,
              required: true,
              forceLtr: true,
              keyboardType: TextInputType.number,
              inputFormatters: const [DigitsOnlyFormatter(maxLength: 8)],
              textInputAction: _isReset ? TextInputAction.next : TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              errorText: _fieldErrors['code'],
              enabled: !_busy,
              onSubmitted: (_) => _isReset || _busy ? null : _verify(),
            ),
            if (_isReset) ...[
              const SizedBox(height: 14),
              AuthTextField(
                label: l.authPassword,
                controller: _newPassword,
                icon: Icons.lock_outline_rounded,
                required: true,
                obscure: true,
                autofillHints: const [AutofillHints.newPassword],
                errorText: _fieldErrors['new_password'],
                enabled: !_busy,
              ),
            ],
            const SizedBox(height: 20),
            AuthPrimaryButton(label: l.otpVerify, busy: _busy, onPressed: _verify),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: _busy || _resending ? null : _resend,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l.otpResend),
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

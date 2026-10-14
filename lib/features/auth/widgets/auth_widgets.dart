import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/home_style.dart';
import '../../../core/theme/app_palette.dart';

/// The shared pieces of sign-in, sign-up and phone verification, so the three
/// read as one flow: the logo and a centred title, a white form surface on the
/// app's soft background, filled fields, and one primary action.

/// The AlEyada logo, exactly as supplied in `assets/logo.png`.
///
/// The file is a square with wide *transparent* margins around the logo tile
/// (the tile spans roughly the middle 58%). To show the tile at [size] without
/// cropping or altering the image, the whole picture is painted larger than its
/// layout slot with nothing clipped: only transparent pixels fall outside.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.size = 80});

  /// The visible size of the logo tile.
  final double size;

  /// The tile's share of the file's width (pixels 222–841 of 1063).
  static const _tileFraction = 619 / 1063;

  @override
  Widget build(BuildContext context) {
    final full = size / _tileFraction;
    return Semantics(
      image: true,
      label: L.of(context).auLogoLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: OverflowBox(
          maxWidth: full,
          maxHeight: full,
          child: Image.asset(
            'assets/logo.png',
            width: full,
            height: full,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// Logo, title and one line of context, centred.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AuthLogo(),
      const SizedBox(height: 18),
      Semantics(
        header: true,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: context.palette.heading,
            height: 1.3,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: context.palette.muted, height: 1.6),
      ),
    ],
  );
}

/// The page frame: soft background, a back button only when there is somewhere
/// to go back to, and a scrolling body that keeps the focused field above the
/// keyboard.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.page,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // A thin bar: just the back arrow, which flips with the reading direction.
      toolbarHeight: 48,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          // Comfortable on a tablet or a landscape phone too.
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, 28),
            children: children,
          ),
        ),
      ),
    ),
  );
}

/// The white form surface.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(22),
      boxShadow: context.palette.shadowSoft,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

/// A labelled, filled field with a leading icon: soft fill and no outline at
/// rest, the brand colour on focus, red with the message underneath on error.
///
/// Latin inputs (phone, email, password, codes) are typed left-to-right with
/// [forceLtr] while the field itself stays aligned to the reading start.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.errorText,
    this.required = false,
    this.obscure = false,
    this.onToggleObscure,
    this.forceLtr = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.private = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final String? errorText;
  final bool required;
  final bool obscure;

  /// Shows the visibility button when set.
  final VoidCallback? onToggleObscure;
  final bool forceLtr;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final TextCapitalization textCapitalization;

  /// Keep what is typed out of the keyboard: no suggestions, no autocorrect, and
  /// no personalised learning (the keyboard's own dictionary, which can outlive
  /// the app and sync to the keyboard vendor). For health notes, reasons and
  /// codes. Password fields — [obscure], or with a visibility toggle — are
  /// always private, shown or hidden.
  final bool private;

  static OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hasError = (errorText ?? '').isNotEmpty;
    final isPrivate = private || obscure || onToggleObscure != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: context.palette.danger),
                  ),
              ],
            ),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.palette.body,
            ),
          ),
        ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscure,
          enableSuggestions: !isPrivate,
          autocorrect: !isPrivate,
          enableIMEPersonalizedLearning: !isPrivate,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textDirection: forceLtr ? TextDirection.ltr : null,
          textAlign: TextAlign.start,
          style: TextStyle(fontSize: 15, color: context.palette.body),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14, color: context.palette.muted),
            errorText: hasError ? errorText : null,
            errorMaxLines: 3,
            filled: true,
            fillColor: hasError
                ? context.palette.danger.withValues(alpha: 0.04)
                : context.palette.page,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: hasError ? context.palette.danger : context.palette.muted,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 48),
            // Named for screen readers with Semantics rather than a tooltip: a
            // tooltip inside a text field's suffix trips a framework assertion
            // (two tickers on one tooltip) when its message changes on toggle.
            suffixIcon: onToggleObscure == null
                ? null
                : Semantics(
                    button: true,
                    label: obscure ? l.auShowPassword : l.auHidePassword,
                    excludeSemantics: true,
                    child: IconButton(
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                        color: context.palette.muted,
                      ),
                    ),
                  ),
            border: _border(Colors.transparent),
            enabledBorder: _border(Colors.transparent),
            disabledBorder: _border(Colors.transparent),
            focusedBorder: _border(context.palette.primary, 1.5),
            errorBorder: _border(context.palette.danger.withValues(alpha: 0.6)),
            focusedErrorBorder: _border(context.palette.danger, 1.5),
          ),
        ),
      ],
    );
  }
}

/// The one primary action: full width, a spinner while [busy] (and no second
/// tap), disabled when [onPressed] is null.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      textStyle: context.homeType.button.copyWith(fontSize: 15.5),
    ),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: busy
          ? const SizedBox(
              key: ValueKey('busy'),
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
            )
          : Text(label, key: const ValueKey('label')),
    ),
  );
}

/// "No account yet? Create one" — the question quiet, the action emphasised.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(question, style: TextStyle(fontSize: 14, color: context.palette.muted)),
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          textStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Text(action),
      ),
    ],
  );
}

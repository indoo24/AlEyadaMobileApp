import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// A labelled text field with the product's shape and RTL-aware alignment.
///
/// Latin-only inputs (phone, email, password) are forced to LTR with their text
/// aligned to the reading start of the surrounding direction — an Egyptian phone
/// number typed into an RTL form should read `01012345678`, not reverse as the
/// user types.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.onToggleObscure,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.autofillHints,
    this.inputFormatters,
    this.forceLtr = false,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.required = false,
    this.textCapitalization = TextCapitalization.none,
    this.private = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;

  /// Server-supplied field error, already mapped out of the envelope.
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final int maxLines;
  final int? minLines;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool forceLtr;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool required;
  final TextCapitalization textCapitalization;

  /// Keep what is typed out of the keyboard: no suggestions, no autocorrect, and
  /// no personalised learning (the keyboard's own dictionary, which can outlive
  /// the app and sync to the keyboard vendor). For health notes, reasons and
  /// codes. Password fields — [obscure], or with a visibility toggle — are
  /// always private, shown or hidden.
  final bool private;

  @override
  Widget build(BuildContext context) {
    final isPrivate = private || obscure || onToggleObscure != null;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscure,
      enableSuggestions: !isPrivate,
      autocorrect: !isPrivate,
      enableIMEPersonalizedLearning: !isPrivate,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: obscure ? 1 : maxLines,
      minLines: minLines,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      // Numbers and Latin identifiers read left to right regardless of the app's
      // direction; `textAlign: start` keeps the field itself laid out correctly.
      textDirection: forceLtr ? TextDirection.ltr : null,
      textAlign: TextAlign.start,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        helperText: helper,
        helperMaxLines: 3,
        errorMaxLines: 3,
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                tooltip: obscure ? 'Show' : 'Hide',
              ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              // Flexible: a long label wraps instead of overflowing at large text.
              Flexible(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
              if (required)
                const Text(' *', style: TextStyle(color: AppColors.danger, fontSize: 15)),
            ],
          ),
        ),
        field,
      ],
    );
  }
}

/// A labelled dropdown that matches the text fields.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.errorText,
    this.required = false,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? errorText;
  final bool required;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              if (required)
                const Text(' *', style: TextStyle(color: AppColors.danger, fontSize: 15)),
            ],
          ),
        ),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          hint: hint == null ? null : Text(hint!),
          decoration: InputDecoration(errorText: errorText, errorMaxLines: 3),
          borderRadius: AppRadii.inputRadius,
        ),
      ],
    );
  }
}

/// The top-of-form error banner, for failures the backend did not attribute to
/// any single field.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: AppRadii.inputRadius,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message!,
              // Announced to a screen reader, because a form that fails silently
              // for a blind user has not reported anything at all.
              semanticsLabel: message,
              style: const TextStyle(color: AppColors.danger, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// A short informational note, used for the onboarding-scope explanation and
/// similar "here is why this list is short" messages.
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: AppRadii.inputRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline_rounded, size: 18, color: AppColors.muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Egyptian mobile numbers only ever need digits. Stripping everything else as
/// it is typed means a pasted "+20 101 234 5678" still arrives usable.
class DigitsOnlyFormatter extends TextInputFormatter {
  const DigitsOnlyFormatter({this.maxLength = 15});

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > maxLength ? digits.substring(0, maxLength) : digits;
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }
}

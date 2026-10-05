import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/models.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';

final _policiesProvider = FutureProvider<List<LegalPolicy>>(
  (ref) => ref.watch(authRepositoryProvider).currentPolicies(),
);

/// Shown when `/auth/me/` reports outstanding policy re-acceptance.
///
/// The backend refuses every write until this clears, so the router holds the
/// user here. Not a nag screen the app invented — `requires_reacceptance` is a
/// server decision and the app is only the surface for it.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _accepted = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept(List<LegalPolicy> policies) async {
    if (!_accepted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .acceptPolicies(policies.map((p) => p.id).toList());
      // The router redirects away as soon as requires_reacceptance clears.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// This screen has no inputs, so an error the backend pins on a field means
  /// the app built the request wrong — nothing the user can fix. Its bare
  /// detail ("هذا الحقل مطلوب") would read as blaming the checkbox, so it is
  /// logged for us and replaced with a sentence that says what actually failed.
  String _messageFor(ApiException e) {
    if (e.fieldErrors.isEmpty) return messageForError(context, e);
    developer.log('consent rejected: ${e.fieldErrors}', name: 'aleyada.consent');
    return L.of(context).consentSubmitRejected;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final policies = ref.watch(_policiesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(l.consentReacceptTitle), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: AsyncValueView<List<LegalPolicy>>(
          value: policies,
          onRetry: () => ref.invalidate(_policiesProvider),
          data: (list) => ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              Text(l.consentReacceptBody, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              FormErrorBanner(message: _error),
              for (final p in list)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ExpansionTile(
                    title: Text(p.titleAr, style: Theme.of(context).textTheme.titleSmall),
                    subtitle: Text(p.version, style: Theme.of(context).textTheme.labelMedium),
                    shape: const Border(),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [Text(p.bodyAr ?? '', style: Theme.of(context).textTheme.bodySmall)],
                  ),
                ),
              CheckboxListTile(
                value: _accepted,
                onChanged: _busy ? null : (v) => setState(() => _accepted = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(l.consentAccept, style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: !_accepted || _busy ? null : () => _accept(list),
                child: Text(_busy ? l.actionSaving : l.actionConfirm),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => ref.read(authControllerProvider.notifier).signOut(),
                  child: Text(l.authSignOut),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

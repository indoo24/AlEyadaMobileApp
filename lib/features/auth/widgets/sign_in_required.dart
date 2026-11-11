import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/home_style.dart';

/// The two ways in a guest is offered.
enum AuthEntry { signIn, signUp }

/// Tells a guest that what they tried needs an account, and offers to sign in
/// or create one. Resolves to their choice, or null if they dismiss it.
///
/// Opens over the tab shell (on the root navigator) so the floating dock is
/// never painted over it.
Future<AuthEntry?> askToSignIn(BuildContext context) =>
    showModalBottomSheet<AuthEntry>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.palette.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SignInRequiredSheet(),
    );

/// Opens [entry], to return to [next] once signed in.
///
/// Creating an account is reached through sign-in, as it always is, so backing
/// out of it lands on sign-in rather than skipping it.
void openAuthEntry(GoRouter router, AuthEntry entry, {String? next}) {
  final query = next == null ? '' : '?next=${Uri.encodeComponent(next)}';
  router.push('${Routes.signIn}$query');
  if (entry == AuthEntry.signUp) router.push('${Routes.signUp}$query');
}

class _SignInRequiredSheet extends StatelessWidget {
  const _SignInRequiredSheet();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.palette;
    final button = context.homeType.button.copyWith(fontSize: 15);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        10,
        AppSpacing.gutter,
        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
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
                color: p.border,
                borderRadius: AppRadii.pillRadius,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: p.pageSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.lock_outline_rounded, color: p.primary),
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              l.authLoginRequired,
              textAlign: TextAlign.center,
              style: context.homeType.sectionTitle.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.authSignInToContinue,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.muted, height: 1.6),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(AuthEntry.signIn),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: button,
            ),
            child: Text(l.authSignIn),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(AuthEntry.signUp),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: button,
            ),
            child: Text(l.authSignUp),
          ),
        ],
      ),
    );
  }
}

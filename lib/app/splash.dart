import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_controller.dart';
import '../core/providers.dart';
import '../core/theme/tokens.dart';
import '../core/widgets/brand_mark.dart';
import '../l10n/app_localizations.dart';

/// Shown while the session is being restored.
///
/// It also handles the awkward third case: a session exists but could not be
/// confirmed because the network is down. That is not a logout, so the user is
/// offered a retry rather than being dropped at a sign-in screen and made to
/// type a password they did not need.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final auth = ref.watch(authControllerProvider);
    final offline = auth.status == AuthStatus.offlineWithSession;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandMark(size: 72),
                const SizedBox(height: AppSpacing.lg),
                Text(l.appName, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.appTagline,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.section),
                if (offline) ...[
                  const Icon(Icons.wifi_off_rounded, color: AppColors.muted),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l.stateOfflineBody,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(
                    onPressed: () => ref.read(authControllerProvider.notifier).restore(),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(180, 48)),
                    child: Text(l.actionRetry),
                  ),
                ] else
                  const CircularProgressIndicator(strokeWidth: 2.5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/locale_controller.dart';
import '../../app/router.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(currentUserProvider);
    final locale = ref.watch(localeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          if (user == null) ...[
            InfoNote(text: l.authGuestPrompt, icon: Icons.login_rounded),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: () => context.push(Routes.signIn), child: Text(l.authSignIn)),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: () => context.push(Routes.signUp), child: Text(l.authSignUp)),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.bgSoft,
                        borderRadius: AppRadii.pillRadius,
                      ),
                      child: Center(
                        child: Text(
                          user.displayName.characters.first,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName, style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            user.phone,
                            style: Theme.of(context).textTheme.bodySmall,
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (user.doctorApplication != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ApplicationStatusCard(application: user.doctorApplication!),
            ],

            const SizedBox(height: AppSpacing.lg),
            _Tile(
              icon: Icons.person_outline_rounded,
              label: l.accountProfile,
              onTap: () => context.push(Routes.editProfile),
            ),
            _Tile(
              icon: Icons.notifications_none_rounded,
              label: l.navNotifications,
              onTap: () => context.push(Routes.notifications),
            ),
            if (user.isActiveDoctor)
              _Tile(
                icon: Icons.event_note_outlined,
                label: l.navDashboard,
                onTap: () => context.go(Routes.management),
              ),
            if (!user.isActiveDoctor && !user.hasOpenApplication)
              _Tile(
                icon: Icons.medical_services_outlined,
                label: l.joinTitle,
                onTap: () => context.push(Routes.join),
              ),
          ],

          const SizedBox(height: AppSpacing.lg),
          Text(l.accountLanguage, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'ar', label: Text(l.accountLanguageArabic)),
              ButtonSegment(value: 'en', label: Text(l.accountLanguageEnglish)),
            ],
            selected: {locale?.languageCode ?? 'ar'},
            onSelectionChanged: (s) =>
                ref.read(localeControllerProvider.notifier).setLocale(Locale(s.first)),
          ),

          if (user != null) ...[
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: Text(l.authSignOut),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.accountSignOutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(100, 44),
            ),
            child: Text(l.authSignOut),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: Theme.of(context).textTheme.titleSmall),
        // Directional icon: flips automatically under RTL rather than pointing
        // the wrong way in Arabic.
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}

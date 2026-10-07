import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/locale_controller.dart';
import '../../app/router.dart';
import '../../core/auth/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth/phone_verification.dart';
import '../doctors/widgets/doctor_profile_sections.dart' show profileNavy;
import '../home/home_screen.dart' show ApplicationStatusCard;
import '../home/home_style.dart';
import '../home/widgets/pressable.dart';
import '../notifications/notifications_data.dart';
import 'widgets/account_widgets.dart';

/// My Account: who is signed in, where their details and notifications are,
/// joining as a doctor, the language, and signing out.
///
/// Everything shown is the account from `/auth/me/` (already in the auth
/// state — nothing is fetched again here) plus the bell's unread count.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(currentUserProvider);
    final unread = user == null ? 0 : (ref.watch(unreadCountProvider).valueOrNull ?? 0);
    const gap = SizedBox(height: 20);

    final sections = <Widget>[
      if (user?.doctorApplication != null &&
          user!.doctorApplication!.status != ApplicationStatus.approved)
        ApplicationStatusCard(application: user.doctorApplication!),
      if (user != null)
        SettingsGroup(
          title: l.acSectionAccount,
          children: [
            SettingsRow(
              icon: Icons.person_outline_rounded,
              label: l.accountProfile,
              onTap: () => context.push(Routes.editProfile),
            ),
            SettingsRow(
              icon: Icons.notifications_none_rounded,
              label: l.navNotifications,
              badge: unread > 0 ? l.acUnreadBadge(unread > 99 ? 99 : unread) : null,
              onTap: () => context.push(Routes.notifications),
            ),
            if (user.isActiveDoctor)
              SettingsRow(
                icon: Icons.space_dashboard_outlined,
                label: l.navDashboard,
                onTap: () => context.go(Routes.management),
              ),
          ],
        ),
      // Joining is offered to a signed-in account that is not a doctor and has
      // no request in flight — the same rule as before.
      if (user != null && !user.isActiveDoctor && !user.hasOpenApplication) const _JoinCard(),
      SettingsGroup(
        title: l.acSectionSettings,
        children: [
          SettingsRow(
            icon: Icons.translate_rounded,
            label: l.accountLanguage,
            value: Localizations.localeOf(context).languageCode == 'en'
                ? l.accountLanguageEnglish
                : l.accountLanguageArabic,
            onTap: () => showLanguageSheet(context),
          ),
        ],
      ),
      if (user != null)
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.logout_rounded,
              label: l.authSignOut,
              destructive: true,
              onTap: () => _confirmSignOut(context, ref),
            ),
          ],
        ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            Container(color: profileNavy, height: MediaQuery.paddingOf(context).top),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ListView(
                  padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 28),
                  children: [
                    _Header(user: user),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                      child: _Entrance(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < sections.length; i++) ...[
                              if (i > 0) gap,
                              sections[i],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
        content: Text(l.accountSignOutConfirm, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(100, 44),
              textStyle: HomeType.button.copyWith(fontSize: 14),
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

/// The navy profile header — the same identity as Home's.
class _Header extends ConsumerWidget {
  const _Header({required this.user});

  final Me? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final u = user;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 14, AppSpacing.gutter, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [profileNavy, Color(0xFF0A3F86)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l.accountTitle, style: HomeType.heroTagline.copyWith(fontSize: 14)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ProfileAvatar(name: u?.displayName ?? '', size: 66, onDark: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u?.displayName ?? l.acGuestTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HomeType.heroGreeting.copyWith(fontSize: 18),
                    ),
                    if (u != null && u.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        u.phone,
                        textDirection: TextDirection.ltr,
                        style: HomeType.heroTagline.copyWith(fontSize: 13.5),
                      ),
                    ],
                    if (u != null) ...[
                      const SizedBox(height: 8),
                      PhoneStatusChip(
                        verified: u.isPhoneVerified,
                        label: u.isPhoneVerified ? l.acPhoneVerified : l.acPhoneUnverified,
                        actionLabel: l.acVerifyNow,
                        onVerify: u.isPhoneVerified || u.phone.isEmpty
                            ? null
                            : () => startPhoneVerification(
                                context,
                                ref,
                                phone: u.phone,
                                next: Routes.account,
                              ),
                        onDark: true,
                      ),
                    ],
                    if (u == null) ...[
                      const SizedBox(height: 2),
                      Text(l.authGuestPrompt, style: HomeType.heroTagline),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (u == null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push(Routes.signIn),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(0, 46),
                      textStyle: HomeType.button.copyWith(fontSize: 14),
                    ),
                    child: Text(l.authSignIn),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(Routes.signUp),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                      minimumSize: const Size(0, 46),
                      textStyle: HomeType.button.copyWith(fontSize: 14),
                    ),
                    child: Text(l.authSignUp),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Joining as a doctor, given a card of its own: it is a product action, not
/// a setting. The copy is the join flow's own.
class _JoinCard extends StatelessWidget {
  const _JoinCard();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Pressable(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(homeCardRadius),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.bgSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.medical_services_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.joinTitle, style: HomeType.cardTitle.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(l.joinIntro, style: HomeType.meta.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => context.push(Routes.join),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: HomeType.button.copyWith(fontSize: 13),
              ),
              child: Text(l.acJoinNow),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short rise-and-fade the first time the page builds.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOut,
    builder: (_, t, c) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: c),
    ),
    child: child,
  );
}

/// The language picker: the two languages, the current one marked.
Future<void> showLanguageSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => const _LanguageSheet(),
);

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final current = Localizations.localeOf(context).languageCode;

    Widget option(String code, String label) {
      final selected = current == code;
      return Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.bgSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              ref.read(localeControllerProvider.notifier).setLocale(Locale(code));
              Navigator.of(context).pop();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: HomeType.cardTitle.copyWith(
                          fontSize: 15,
                          color: selected ? AppColors.primary : AppColors.navy,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              key: ValueKey('on'),
                              color: AppColors.primary,
                            )
                          : const Icon(
                              Icons.radio_button_unchecked_rounded,
                              key: ValueKey('off'),
                              color: AppColors.border,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 10, AppSpacing.gutter, 20),
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
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              l.acLanguageSheetTitle,
              style: HomeType.sectionTitle.copyWith(fontSize: 17),
            ),
          ),
          const SizedBox(height: 12),
          option('ar', l.accountLanguageArabic),
          const SizedBox(height: 6),
          option('en', l.accountLanguageEnglish),
        ],
      ),
    );
  }
}

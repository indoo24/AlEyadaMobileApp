import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/locale_controller.dart';
import '../../app/theme_mode_controller.dart';
import '../../app/router.dart';
import '../../core/auth/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth/phone_verification.dart';
import '../home/home_screen.dart' show ApplicationStatusCard;
import '../home/home_style.dart';
import '../home/widgets/pressable.dart';
import '../notifications/notifications_data.dart';
import 'widgets/account_widgets.dart';
import 'widgets/choice_sheet.dart';
import '../../core/theme/app_palette.dart';

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
          SettingsRow(
            icon: Icons.brightness_6_outlined,
            label: l.accountAppearance,
            value: themeModeLabel(l, ref.watch(themeModeControllerProvider)),
            onTap: () => showAppearanceSheet(context),
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
        backgroundColor: context.palette.page,
        body: Column(
          children: [
            Container(color: context.palette.heroStart, height: MediaQuery.paddingOf(context).top),
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
        icon: Icon(Icons.logout_rounded, color: context.palette.danger),
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
              backgroundColor: context.palette.dangerFill,
              minimumSize: const Size(100, 44),
              textStyle: context.homeType.button.copyWith(fontSize: 14),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.palette.heroStart, context.palette.heroEnd],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        border: context.palette.isDark ? Border.all(color: context.palette.heroEdge) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(l.accountTitle, style: context.homeType.heroTagline.copyWith(fontSize: 14)),
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
                      style: context.homeType.heroGreeting.copyWith(fontSize: 18),
                    ),
                    if (u != null && u.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        u.phone,
                        textDirection: TextDirection.ltr,
                        style: context.homeType.heroTagline.copyWith(fontSize: 13.5),
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
                      Text(l.authGuestPrompt, style: context.homeType.heroTagline),
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
                      foregroundColor: context.palette.primaryFill,
                      minimumSize: const Size(0, 46),
                      textStyle: context.homeType.button.copyWith(fontSize: 14),
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
                      textStyle: context.homeType.button.copyWith(fontSize: 14),
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
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(homeCardRadius),
          border: Border.all(color: context.palette.primary.withValues(alpha: 0.22)),
          boxShadow: context.palette.shadowSoft,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.palette.pageSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.medical_services_outlined, color: context.palette.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.joinTitle, style: context.homeType.cardTitle.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(l.joinIntro, style: context.homeType.meta.copyWith(fontSize: 12.5)),
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
                textStyle: context.homeType.button.copyWith(fontSize: 13),
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
Future<void> showLanguageSheet(BuildContext context) =>
    showChoiceSheetFrame(context, (_) => const _LanguageSheet());

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return ChoiceSheet<String>(
      title: l.acLanguageSheetTitle,
      current: Localizations.localeOf(context).languageCode,
      options: [
        ChoiceOption('ar', l.accountLanguageArabic),
        ChoiceOption('en', l.accountLanguageEnglish),
      ],
      onSelected: (code) => ref.read(localeControllerProvider.notifier).setLocale(Locale(code)),
    );
  }
}

/// The appearance picker: follow the device, or force light or dark.
Future<void> showAppearanceSheet(BuildContext context) =>
    showChoiceSheetFrame(context, (_) => const _AppearanceSheet());

/// What a theme mode is called, in the current language.
String themeModeLabel(L l, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l.accountThemeSystem,
  ThemeMode.light => l.accountThemeLight,
  ThemeMode.dark => l.accountThemeDark,
};

class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return ChoiceSheet<ThemeMode>(
      title: l.acAppearanceSheetTitle,
      current: ref.watch(themeModeControllerProvider),
      options: [for (final m in ThemeMode.values) ChoiceOption(m, themeModeLabel(l, m))],
      onSelected: (mode) => ref.read(themeModeControllerProvider.notifier).setMode(mode),
    );
  }
}

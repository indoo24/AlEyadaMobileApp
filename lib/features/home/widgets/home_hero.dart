import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/greeting.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../doctors/providers.dart';
import '../../doctors/widgets/doctor_profile_sections.dart' show profileNavy;
import '../../doctors/widgets/filter_sheet.dart';
import '../../notifications/notifications_screen.dart';
import '../home_style.dart';
import 'location_picker.dart';
import 'pressable.dart';

/// The navy top of Home: greeting, city, notifications, and search.
///
/// The same deep navy as the doctor profile's header and the booking cards, so
/// Home opens on the app's own identity rather than a generic white bar.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [profileNavy, Color(0xFF0A3F86)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 10, AppSpacing.gutter, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopRow(),
            SizedBox(height: 4),
            _Tagline(),
            SizedBox(height: AppSpacing.lg),
            HomeSearchField(),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends ConsumerWidget {
  const _TopRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(currentUserProvider);
    // "Dr." comes from the account's role (see [welcomeGreeting]) — never from
    // the name.
    final greeting = user == null ? l.homeGreetingGuest : welcomeGreeting(l, user);
    final unread = user == null ? 0 : (ref.watch(unreadCountProvider).valueOrNull ?? 0);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  greeting,
                  style: HomeType.heroGreeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              _CityChip(label: homeLocationLabel(context, ref)),
            ],
          ),
        ),
        if (user != null) ...[
          const SizedBox(width: AppSpacing.sm),
          _HeroIconButton(
            tooltip: l.navNotifications,
            onTap: () => context.push(Routes.notifications),
            child: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              backgroundColor: AppColors.danger,
              child: const Icon(Icons.notifications_none_rounded, size: 23, color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) => Text(
    L.of(context).appTagline,
    style: HomeType.heroTagline,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}

class _CityChip extends StatelessWidget {
  const _CityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Semantics(
      button: true,
      label: '${l.homeLocationPickerTitle}: $label',
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showCityPicker(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeType.locationChip.copyWith(color: Colors.white),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.tooltip, required this.onTap, required this.child});

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 48, height: 48, child: Center(child: child)),
        ),
      ),
    ),
  );
}

/// The search field. Tapping it opens the directory's own search with the
/// cursor in the box — one search implementation, not two. The filter button
/// opens the directory's filter sheet and, if anything changed, the results.
class HomeSearchField extends ConsumerWidget {
  const HomeSearchField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hasFilters = ref.watch(doctorQueryProvider.select((q) => q.hasFilters));

    Future<void> openFilters() async {
      final before = ref.read(doctorQueryProvider);
      await showDoctorFilterSheet(context);
      if (!context.mounted) return;
      if (ref.read(doctorQueryProvider) != before) context.go(Routes.doctors);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.float,
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              child: Semantics(
                button: true,
                label: l.hmSearchHint,
                excludeSemantics: true,
                child: InkWell(
                  // `focus=1`: arrive with the cursor in the search box.
                  onTap: () => context.go('${Routes.doctors}?focus=1'),
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.hmSearchHint,
                              style: HomeType.heroSearch,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: l.actionFilter,
            child: Semantics(
              button: true,
              label: l.actionFilter,
              excludeSemantics: true,
              child: Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: openFilters,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Badge(
                        isLabelVisible: hasFilters,
                        backgroundColor: AppColors.star,
                        smallSize: 8,
                        child: const Icon(Icons.tune_rounded, color: Colors.white, size: 21),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

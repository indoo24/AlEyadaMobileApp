import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/widgets/doctor_rating.dart';
import '../home/home_style.dart';
import '../home/widgets/home_section_header.dart';
import '../practice/practice_screen.dart';
import 'providers.dart';

/// The approved doctor's management hub: how the practice is doing, a link to the
/// web system, and the three places the practice is run from — clinics,
/// assistants and the schedule.
///
/// Reached only by an approved doctor: the router redirects anyone else, and every
/// endpoint behind it is doctor-gated regardless, so a guard failure would
/// produce a 403, not exposed data.
class ManagementScreen extends ConsumerWidget {
  const ManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);

    Future<void> refresh() async {
      ref
        ..invalidate(activationProvider)
        ..invalidate(doctorStatsProvider);
      await ref.read(authControllerProvider.notifier).refreshUser();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _Header(title: l.managementTitle),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  HomeSpacing.top,
                  AppSpacing.gutter,
                  AppSpacing.xl,
                ),
                children: const [
                  _ActivationBanner(),
                  SizedBox(height: HomeSpacing.section),
                  _StatisticsSection(),
                  SizedBox(height: HomeSpacing.section),
                  _ModulesSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surface, boxShadow: AppShadows.soft),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 14, AppSpacing.gutter, 14),
          child: Row(
            children: [
              const Icon(Icons.space_dashboard_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: HomeType.sectionTitle.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Publication state
// ---------------------------------------------------------------------------

/// Whether the doctor's public page is live, straight from the activation
/// report, and what is still missing when it is not.
class _ActivationBanner extends ConsumerWidget {
  const _ActivationBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final activation = ref.watch(activationProvider);

    return activation.when(
      loading: () => const Skeleton(height: 56, radius: homeCardRadius),
      // Secondary information: a failure here must not hide the stats below.
      error: (_, __) => const SizedBox.shrink(),
      data: (a) {
        final live = a.isPublished;
        final color = live ? AppColors.success : AppColors.star;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(homeCardRadius),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    live ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      live ? l.dashboardPublished : l.dashboardNotPublished,
                      style: HomeType.cardTitle,
                    ),
                  ),
                ],
              ),
              if (!a.isComplete && a.missing.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(l.dashboardActivationMissing, style: HomeType.meta),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in a.missing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadii.pillRadius,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(activationFieldLabel(context, m), style: HomeType.pill),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Statistics
// ---------------------------------------------------------------------------

class _StatisticsSection extends ConsumerWidget {
  const _StatisticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final stats = ref.watch(doctorStatsProvider);
    final portal = ref.watch(managementUrlProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: HomeSectionHeader(title: l.managementStatsTitle)),
            if (stats.valueOrNull != null && stats.requireValue.periodDays > 0)
              Text(l.managementStatsPeriod(stats.requireValue.periodDays), style: HomeType.meta),
          ],
        ),
        const SizedBox(height: HomeSpacing.heading),
        stats.when(
          loading: () => const _StatsSkeleton(),
          error: (e, _) => Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(homeCardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: AppErrorView(error: e, onRetry: () => ref.invalidate(doctorStatsProvider)),
          ),
          data: (s) => _StatsGrid(stats: s),
        ),
        if (portal != null) ...[
          const SizedBox(height: HomeSpacing.card),
          _PortalButton(url: portal),
        ],
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final DoctorStats stats;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final rated = stats.reviewsCount > 0 && parseRating(stats.avgRating) != null;

    final cards = [
      _StatCard(icon: Icons.people_alt_outlined, label: l.statPatients, value: '${stats.uniquePatients}'),
      _StatCard(icon: Icons.task_alt_rounded, label: l.statCompletedVisits, value: '${stats.completedVisits}'),
      _StatCard(
        icon: Icons.star_rounded,
        iconColor: AppColors.star,
        label: l.statRating,
        value: rated ? formatRating(parseRating(stats.avgRating)!) : '—',
        sub: stats.reviewsCount > 0 ? l.doctorReviewsCount(stats.reviewsCount) : null,
      ),
      _StatCard(
        icon: Icons.touch_app_outlined,
        label: l.statContactRate,
        value: formatPercent(stats.contactRate),
        sub: l.statViewsSub(stats.profileViews),
      ),
      _StatCard(icon: Icons.visibility_outlined, label: l.statViews, value: '${stats.profileViews}'),
      _StatCard(icon: Icons.call_outlined, label: l.statContacts, value: '${stats.contacts}'),
      _StatCard(icon: Icons.event_note_outlined, label: l.statBookings, value: '${stats.bookingsCreated}'),
      _StatCard(icon: Icons.check_circle_outline_rounded, label: l.statBookingsDone, value: '${stats.bookingsCompleted}'),
    ];

    // Two columns, each row as tall as its taller card — a fixed aspect ratio
    // would overflow at large text sizes.
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: HomeSpacing.card),
                Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
          if (i + 2 < cards.length) const SizedBox(height: HomeSpacing.card),
        ],
      ],
    );
  }
}

/// `"4.60"` → 4.6, or null when the backend sent no usable rating.
double? parseRating(String raw) => double.tryParse(raw.trim());

/// The backend's `contact_rate` with a percent sign: `0` → `0%`, `12.5` → `12.5%`.
///
/// The API describes the value only as a double; it is treated as already being a
/// percentage, which is how the web dashboard shows it.
String formatPercent(double v) {
  final text = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  return '$text%';
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value${sub == null ? '' : ', $sub'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(homeCardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 8),
                // Scales down rather than overflowing a narrow card at large text.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      value,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: HomeType.doctorSpecialty.copyWith(fontWeight: FontWeight.w600)),
            if (sub != null) Text(sub!, style: HomeType.meta.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 4; i++) ...[
        const Row(
          children: [
            Expanded(child: Skeleton(height: 84, radius: homeCardRadius)),
            SizedBox(width: HomeSpacing.card),
            Expanded(child: Skeleton(height: 84, radius: homeCardRadius)),
          ],
        ),
        if (i < 3) const SizedBox(height: HomeSpacing.card),
      ],
    ],
  );
}

/// Opens the web management system. Shown only when this build knows its address.
class _PortalButton extends StatelessWidget {
  const _PortalButton({required this.url});

  final Uri url;

  Future<void> _open(BuildContext context) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(l.managementPortalFailed)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: Text(L.of(context).managementPortalButton),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: HomeType.button.copyWith(fontSize: 13.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

class _ModulesSection extends StatelessWidget {
  const _ModulesSection();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: l.managementModulesTitle),
        const SizedBox(height: HomeSpacing.heading),
        ManagementModuleCard(
          icon: Icons.local_hospital_outlined,
          title: l.managementClinicsTitle,
          description: l.managementClinicsDesc,
          onTap: () => context.push(Routes.managementClinics),
        ),
        const SizedBox(height: HomeSpacing.card),
        ManagementModuleCard(
          icon: Icons.groups_2_outlined,
          title: l.managementAssistantsTitle,
          description: l.managementAssistantsDesc,
          onTap: () => context.push(Routes.managementAssistants),
        ),
        const SizedBox(height: HomeSpacing.card),
        ManagementModuleCard(
          icon: Icons.calendar_month_outlined,
          title: l.managementScheduleTitle,
          description: l.managementScheduleDesc,
          onTap: () => context.push(Routes.managementSchedule),
        ),
      ],
    );
  }
}

/// One management area: icon, title, what it is for, and a chevron.
class ManagementModuleCard extends StatelessWidget {
  const ManagementModuleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      label: '$title. $description',
      excludeSemantics: true,
      // The card owns its fill, border and shadow; a transparent Material on top
      // lets the InkWell show its ripple. (A shadow painted over a separate white
      // Material shows through as grey.)
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(homeCardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(homeCardRadius),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.bgSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: HomeType.cardTitle.copyWith(fontSize: 15.5)),
                        const SizedBox(height: 2),
                        Text(description, style: HomeType.meta, maxLines: 2),
                      ],
                    ),
                  ),
                  Icon(
                    rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

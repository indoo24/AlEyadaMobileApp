import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/auth/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../articles/providers.dart';
import '../clinics/providers.dart';
import '../doctors/providers.dart';
import '../doctors/repository.dart';
import '../notifications/notifications_screen.dart';
import 'home_providers.dart';
import 'home_style.dart';
import 'widgets/article_card.dart';
import 'widgets/home_doctor_card.dart';
import 'widgets/home_hero.dart';
import 'widgets/home_section_header.dart';
import 'widgets/home_section_message.dart';
import 'widgets/horizontal_strip.dart';
import 'widgets/medical_center_card.dart';
import 'widgets/pressable.dart';
import 'widgets/quick_discovery.dart';
import 'widgets/specialty_section.dart';
import '../../core/theme/app_palette.dart';

/// Home: greeting and search, shortcuts into the directory, specialties,
/// recommended doctors, clinics and — when there are any — articles.
///
/// Every list is the API's own data, each section loads, fails and empties on
/// its own, and a section with nothing to show takes no space. Only when every
/// primary section has failed does the screen show one full error instead.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final city = ref.watch(homeCitySlugProvider);
    final featured = featuredDoctorQuery(city);

    Future<void> refresh() async {
      ref
        ..invalidate(specializationsProvider)
        ..invalidate(doctorPageProvider(featured))
        ..invalidate(homeClinicsProvider(city))
        ..invalidate(homeArticlesProvider)
        ..invalidate(unreadCountProvider);
      await ref.read(authControllerProvider.notifier).refreshUser();
    }

    final failures = [
      ref.watch(specializationsProvider),
      ref.watch(doctorPageProvider(featured)),
      ref.watch(homeClinicsProvider(city)),
    ];
    final allFailed = failures.every((v) => v.hasError && !v.isLoading);
    final offline = failures.any(
      (v) => v.error is ApiException && (v.error as ApiException).isNetworkFailure,
    );

    final sections = <Widget>[
      if (user?.doctorApplication != null &&
          user!.doctorApplication!.status != ApplicationStatus.approved)
        _Padded(ApplicationStatusCard(application: user.doctorApplication!)),
      const _Padded(QuickDiscovery()),
      // Sections that can have nothing to show are left out entirely, so they
      // leave no gap behind.
      if (!(ref.watch(specializationsProvider).valueOrNull?.isEmpty ?? false))
        const SpecialtySection(),
      const _DoctorsSection(),
      const _ClinicsSection(),
      if (ref.watch(homeArticlesProvider).valueOrNull?.items.isNotEmpty ?? false)
        const _ArticlesSection(),
      if (user == null) const _Padded(_GuestCard()),
      // The join entry point, for anyone not already a doctor and with no
      // request in flight.
      if (user == null || (!user.isActiveDoctor && !user.hasOpenApplication))
        const _Padded(_JoinCard()),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status-bar icons over the navy strip.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.palette.page,
        body: Column(
          children: [
            // The status bar always sits on navy, even after the header has
            // scrolled away under it.
            Container(color: context.palette.heroStart, height: MediaQuery.paddingOf(context).top),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: RefreshIndicator(
                  onRefresh: refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(child: HomeHero()),
                      if (allFailed)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _HomeError(offline: offline, onRetry: refresh),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(top: AppSpacing.lg),
                          sliver: SliverList.list(
                            children: [for (final s in sections) _Gap(child: s)],
                          ),
                        ),
                      // Clears the floating nav dock: under the shell the body's
                      // bottom padding is the dock's height, and 0 anywhere else.
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page gutter, for sections that do not run edge to edge.
class _Padded extends StatelessWidget {
  const _Padded(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
    child: child,
  );
}

/// The rhythm between sections.
class _Gap extends StatelessWidget {
  const _Gap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    child: child,
  );
}

/// Recommended doctors, in the Home city.
class _DoctorsSection extends ConsumerWidget {
  const _DoctorsSection();

  static const _shown = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final city = ref.watch(homeCitySlugProvider);
    final query = featuredDoctorQuery(city);
    final featured = ref.watch(doctorPageProvider(query));
    final width = (MediaQuery.sizeOf(context).width * 0.66).clamp(224.0, 272.0);

    final page = featured.valueOrNull;
    final remaining = page == null ? 0 : page.pagination.count - page.items.take(_shown).length;
    void seeAll() => openDirectory(context, ref, const DoctorQuery());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Padded(
          HomeSectionHeader(
            title: l.hmRecommendedTitle,
            onSeeAll: seeAll,
            seeAllLabel: remaining > 0 ? l.homeSeeAllCount(remaining) : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: featured.when(
            loading: () => HorizontalStrip(
              key: const ValueKey('loading'),
              scrollable: false,
              children: [for (var i = 0; i < 3; i++) HomeDoctorCardSkeleton(width: width)],
            ),
            error: (_, __) => _Padded(
              HomeSectionMessage(
                key: const ValueKey('error'),
                icon: Icons.error_outline_rounded,
                message: l.homeSectionError,
                onRetry: () => ref.invalidate(doctorPageProvider(query)),
              ),
            ),
            data: (page) => page.items.isEmpty
                ? _Padded(
                    HomeSectionMessage(
                      key: const ValueKey('empty'),
                      icon: Icons.person_search_outlined,
                      message: l.homeNoDoctors,
                    ),
                  )
                : HorizontalStrip(
                    key: const ValueKey('data'),
                    children: [
                      for (final d in page.items.take(_shown))
                        HomeDoctorCard(doctor: d, width: width),
                      if (page.pagination.count > _shown || page.items.length > _shown)
                        SeeAllDoctorsTile(label: l.hmSeeAllDoctors, onTap: seeAll),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Clinics and medical centers in the Home city. Each opens its doctors.
class _ClinicsSection extends ConsumerWidget {
  const _ClinicsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final city = ref.watch(homeCitySlugProvider);
    final clinics = ref.watch(homeClinicsProvider(city));
    final width = (MediaQuery.sizeOf(context).width * 0.74).clamp(240.0, 300.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Padded(HomeSectionHeader(title: l.homeCentersTitle)),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: clinics.when(
            loading: () => HorizontalStrip(
              key: const ValueKey('loading'),
              scrollable: false,
              children: [for (var i = 0; i < 2; i++) MedicalCenterSkeleton(width: width)],
            ),
            error: (_, __) => _Padded(
              HomeSectionMessage(
                key: const ValueKey('error'),
                icon: Icons.error_outline_rounded,
                message: l.homeSectionError,
                onRetry: () => ref.invalidate(homeClinicsProvider(city)),
              ),
            ),
            data: (page) => page.items.isEmpty
                ? _Padded(
                    HomeSectionMessage(
                      key: const ValueKey('empty'),
                      icon: Icons.local_hospital_outlined,
                      message: l.homeNoCenters,
                    ),
                  )
                : HorizontalStrip(
                    key: const ValueKey('data'),
                    children: [
                      for (final c in page.items)
                        MedicalCenterCard(
                          clinic: c,
                          width: width,
                          onTap: () => openDirectory(
                            context,
                            ref,
                            DoctorQuery(clinic: c.slug, clinicName: c.nameAr),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// The newest published articles — only when there are some. A secondary
/// section: while loading, on failure or with nothing published, it takes no
/// space rather than leaving a placeholder at the bottom of the feed.
class _ArticlesSection extends ConsumerWidget {
  const _ArticlesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final page = ref.watch(homeArticlesProvider).valueOrNull;
    if (page == null || page.items.isEmpty) return const SizedBox.shrink();
    final width = (MediaQuery.sizeOf(context).width * 0.78).clamp(250.0, 320.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Padded(HomeSectionHeader(title: l.homeArticlesTitle)),
        const SizedBox(height: AppSpacing.md),
        HorizontalStrip(
          children: [
            for (final a in page.items)
              SizedBox(
                width: width,
                child: ArticleCard(article: a),
              ),
          ],
        ),
      ],
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.palette.pageSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.person_outline_rounded, color: context.palette.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.hmGuestTitle, style: context.homeType.cardTitle),
                Text(l.authGuestPrompt, style: context.homeType.meta.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.push(Routes.signIn),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: context.homeType.button.copyWith(fontSize: 13),
            ),
            child: Text(l.authSignIn),
          ),
        ],
      ),
    );
  }
}

class _JoinCard extends StatelessWidget {
  const _JoinCard();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Pressable(
      child: Material(
        color: context.palette.pageSoft,
        borderRadius: BorderRadius.circular(homeCardRadius),
        child: InkWell(
          onTap: () => context.push(Routes.join),
          borderRadius: BorderRadius.circular(homeCardRadius),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.medical_services_outlined, color: context.palette.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.hmJoinCta, style: context.homeType.cardTitle),
                      Text(l.joinIntro, style: context.homeType.meta.copyWith(fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.palette.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown only when every primary section failed to load.
class _HomeError extends StatelessWidget {
  const _HomeError({required this.offline, required this.onRetry});

  final bool offline;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: context.palette.pageSoft, shape: BoxShape.circle),
            child: Icon(
              offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
              size: 38,
              color: context.palette.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.hmLoadErrorTitle,
            textAlign: TextAlign.center,
            style: context.homeType.sectionTitle,
          ),
          const SizedBox(height: 6),
          Text(
            // A fixed, friendly sentence — never the server's wording.
            l.hmLoadErrorBody,
            textAlign: TextAlign.center,
            style: context.homeType.articleBody.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(l.actionRetry),
            style: FilledButton.styleFrom(
              minimumSize: const Size(170, 48),
              textStyle: context.homeType.button.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells someone who asked to join where their request stands.
///
/// Four distinct messages, because they are four distinct pieces of news: a new
/// application, an ownership claim, a rejection, and a request for changes. The
/// backend's `kind`, `status` and `needs_doctor_action` decide which — none of it
/// is inferred from the presence of a profile.
class ApplicationStatusCard extends StatelessWidget {
  const ApplicationStatusCard({super.key, required this.application});

  final DoctorApplication application;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (application.status == ApplicationStatus.approved) return const SizedBox.shrink();

    final (title, body) = switch (application) {
      final a when a.needsDoctorAction => (l.applicationChangesTitle, l.applicationChangesBody),
      final a when a.status == ApplicationStatus.rejected => (
        l.applicationRejectedTitle,
        l.applicationRejectedBody,
      ),
      final a when a.kind == ApplicationKind.claim => (
        l.applicationClaimPendingTitle,
        l.applicationClaimPendingBody(a.doctorName),
      ),
      _ => (l.applicationPendingTitle, l.applicationPendingBody),
    };

    final open = application.isOpen;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: open ? context.palette.surface : context.palette.star.withValues(alpha: 0.06),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(
          color: open ? context.palette.border : context.palette.star.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                open ? Icons.hourglass_top_rounded : Icons.info_outline_rounded,
                color: open ? context.palette.primary : context.palette.star,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: Theme.of(context).textTheme.bodySmall),
          if (application.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.palette.input,
                borderRadius: AppRadii.inputRadius,
                border: Border.all(color: context.palette.border),
              ),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall,
                  children: [
                    TextSpan(
                      text: '${l.applicationReviewerNote} ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: application.rejectionReason),
                  ],
                ),
              ),
            ),
          ],
          if (open) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l.joinPatientUntilApproved, style: Theme.of(context).textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}

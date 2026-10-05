import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/auth/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../articles/providers.dart';
import '../clinics/providers.dart';
import '../doctors/providers.dart';
import '../doctors/repository.dart';
import '../notifications/notifications_screen.dart';
import 'home_providers.dart';
import 'home_style.dart';
import 'widgets/article_card.dart';
import 'widgets/doctor_recommendation_card.dart';
import 'widgets/greeting_section.dart';
import 'widgets/home_header.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/home_section_header.dart';
import 'widgets/home_section_message.dart';
import 'widgets/medical_center_card.dart';
import 'widgets/specialty_section.dart';

/// The patient home: a header, the greeting and city, search, specialties, top
/// doctors, clinics and articles — plus, when relevant, where a join request
/// stands.
///
/// Every list is the API's own data. A section that fails or comes back empty
/// says so in place; it never takes the rest of the screen down with it.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(currentUserProvider);
    final city = ref.watch(homeCitySlugProvider);

    Future<void> refresh() async {
      final featured = featuredDoctorQuery(city);
      ref
        ..invalidate(specializationsProvider)
        ..invalidate(doctorPageProvider(featured))
        ..invalidate(homeClinicsProvider(city))
        ..invalidate(homeArticlesProvider)
        ..invalidate(unreadCountProvider);
      await ref.read(authControllerProvider.notifier).refreshUser();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const HomeHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  HomeSpacing.top,
                  AppSpacing.gutter,
                  // Clears the floating nav dock: under the shell the body's bottom
                  // padding is the dock's height, and 0 anywhere else.
                  MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
                ),
                children: [
                  const GreetingSection(),
                  const SizedBox(height: HomeSpacing.afterGreeting),
                  const HomeSearchBar(),

                  // Where a doctor application or ownership claim stands. Shown
                  // only when the backend reports one; approved doctors get their
                  // practice instead and see nothing here.
                  if (user?.doctorApplication != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    ApplicationStatusCard(application: user!.doctorApplication!),
                  ],

                  const SizedBox(height: HomeSpacing.section),
                  const SpecialtySection(),

                  const SizedBox(height: HomeSpacing.section),
                  const _TopDoctorsSection(),

                  const SizedBox(height: HomeSpacing.section),
                  const _CentersSection(),

                  const SizedBox(height: HomeSpacing.section),
                  const _ArticlesSection(),

                  if (user == null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    InfoNote(text: l.authGuestPrompt, icon: Icons.login_rounded),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => context.push(Routes.signIn),
                      child: Text(l.authSignIn),
                    ),
                  ],

                  // The join entry point, for anyone who is not already a doctor
                  // and has no request in flight.
                  if (user == null || (!user.isActiveDoctor && !user.hasOpenApplication)) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.medical_services_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(l.joinTitle, style: Theme.of(context).textTheme.titleSmall),
                        subtitle: Text(l.joinIntro, style: Theme.of(context).textTheme.bodySmall),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => context.push(Routes.join),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Highest-rated doctors, scoped to the chosen city.
class _TopDoctorsSection extends ConsumerWidget {
  const _TopDoctorsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final city = ref.watch(homeCitySlugProvider);
    final query = featuredDoctorQuery(city);
    final featured = ref.watch(doctorPageProvider(query));

    const shown = 5;
    final page = featured.valueOrNull;
    final remaining = page == null ? 0 : page.pagination.count - page.items.take(shown).length;

    void seeAll() {
      ref.read(doctorQueryProvider.notifier).state = DoctorQuery(city: city);
      context.go(Routes.doctors);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: l.homeTopDoctorsTitle,
          onSeeAll: seeAll,
          seeAllLabel: remaining > 0 ? l.homeSeeAllCount(remaining) : null,
        ),
        const SizedBox(height: HomeSpacing.heading),
        featured.when(
          loading: () => const Column(
            children: [
              Skeleton(height: 150, radius: homeCardRadius),
              SizedBox(height: HomeSpacing.card),
              Skeleton(height: 150, radius: homeCardRadius),
            ],
          ),
          error: (_, __) => HomeSectionMessage(
            icon: Icons.error_outline_rounded,
            message: l.homeSectionError,
            onRetry: () => ref.invalidate(doctorPageProvider(query)),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return HomeSectionMessage(
                icon: Icons.person_search_outlined,
                message: l.homeNoDoctors,
              );
            }
            return Column(
              children: [
                for (final d in page.items.take(shown))
                  Padding(
                    padding: const EdgeInsets.only(bottom: HomeSpacing.card),
                    child: DoctorRecommendationCard(
                      doctor: d,
                      onTap: () => context.push(Routes.doctorPath(d.slug)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Clinics and medical centers, scoped to the chosen city.
///
/// The cards are not tappable: the app has no clinic page yet. They become so
/// when that screen exists.
class _CentersSection extends ConsumerWidget {
  const _CentersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final city = ref.watch(homeCitySlugProvider);
    final clinics = ref.watch(homeClinicsProvider(city));
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.8).clamp(240.0, 320.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: l.homeCentersTitle),
        const SizedBox(height: HomeSpacing.heading),
        clinics.when(
          loading: () => Skeleton(height: 110, width: cardWidth, radius: homeCardRadius),
          error: (_, __) => HomeSectionMessage(
            icon: Icons.error_outline_rounded,
            message: l.homeSectionError,
            onRetry: () => ref.invalidate(homeClinicsProvider(city)),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return HomeSectionMessage(
                icon: Icons.local_hospital_outlined,
                message: l.homeNoCenters,
              );
            }
            // Natural height, so a larger text size grows the cards instead of
            // overflowing a fixed-height strip.
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in page.items) ...[
                      MedicalCenterCard(clinic: c, width: cardWidth),
                      const SizedBox(width: HomeSpacing.card),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The newest published articles.
///
/// Not tappable yet: the app has no article reader. See [ArticleCard].
class _ArticlesSection extends ConsumerWidget {
  const _ArticlesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final articles = ref.watch(homeArticlesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: l.homeArticlesTitle),
        const SizedBox(height: HomeSpacing.heading),
        articles.when(
          loading: () => const Skeleton(height: 150, radius: homeCardRadius),
          error: (_, __) => HomeSectionMessage(
            icon: Icons.error_outline_rounded,
            message: l.homeSectionError,
            onRetry: () => ref.invalidate(homeArticlesProvider),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return HomeSectionMessage(
                icon: Icons.article_outlined,
                message: l.homeNoArticles,
              );
            }
            return Column(
              children: [
                for (final a in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: HomeSpacing.card),
                    child: ArticleCard(article: a),
                  ),
              ],
            );
          },
        ),
      ],
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
        color: open ? AppColors.surface : AppColors.star.withValues(alpha: 0.06),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: open ? AppColors.border : AppColors.star.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                open ? Icons.hourglass_top_rounded : Icons.info_outline_rounded,
                color: open ? AppColors.primary : AppColors.star,
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
                color: AppColors.input,
                borderRadius: AppRadii.inputRadius,
                border: Border.all(color: AppColors.border),
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

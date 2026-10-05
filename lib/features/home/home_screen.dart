import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/auth/greeting.dart';
import '../../core/auth/models.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/providers.dart';
import '../doctors/repository.dart';
import '../doctors/widgets/doctor_card_tile.dart';

/// The patient home: search entry, specialties, and — when relevant — where a
/// join request stands.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(currentUserProvider);
    final specs = ref.watch(specializationsProvider);
    final featured = ref.watch(doctorPageProvider(const DoctorQueryFeatured().query));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(specializationsProvider);
            await ref.read(authControllerProvider.notifier).refreshUser();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.xl,
            ),
            children: [
              Row(
                children: [
                  const BrandMark(size: 40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user == null ? l.appName : welcomeGreeting(l, user),
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l.appTagline,
                          style: Theme.of(context).textTheme.labelMedium,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  if (user != null)
                    IconButton(
                      tooltip: l.navNotifications,
                      onPressed: () => context.push(Routes.notifications),
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Search entry. Tapping goes to the directory rather than searching
              // in place — one search implementation, not two.
              InkWell(
                onTap: () => context.go(Routes.doctors),
                borderRadius: AppRadii.inputRadius,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.inputRadius,
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.muted),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l.doctorsSearchHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Where a doctor application or ownership claim stands. Shown only
              // when the backend reports one; approved doctors get their practice
              // instead and see nothing here.
              if (user?.doctorApplication != null) ...[
                const SizedBox(height: AppSpacing.lg),
                ApplicationStatusCard(application: user!.doctorApplication!),
              ],

              const SizedBox(height: AppSpacing.xl),
              Text(l.doctorsFilterSpecialty, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              specs.when(
                loading: () => const Skeleton(height: 96, radius: AppRadii.card),
                error: (_, __) => const SizedBox.shrink(),
                data: (tree) => Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final s in tree.take(8))
                      ActionChip(
                        label: Text(s.nameAr),
                        backgroundColor: AppColors.surface,
                        onPressed: () {
                          ref.read(doctorQueryProvider.notifier).state = DoctorQuery(
                            specialization: s.slug,
                          );
                          context.go(Routes.doctors);
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Text(l.doctorsTitle, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => context.go(Routes.doctors),
                    child: Text(l.actionSeeAll),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              featured.when(
                loading: () => Column(
                  children: List.generate(
                    2,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: Skeleton(height: 116, radius: AppRadii.card),
                    ),
                  ),
                ),
                // A failed secondary section must not take the whole screen down.
                error: (_, __) => const SizedBox.shrink(),
                data: (page) => Column(
                  children: [
                    for (final d in page.items.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: DoctorCardTile(
                          doctor: d,
                          onTap: () => context.push(Routes.doctorPath(d.slug)),
                        ),
                      ),
                  ],
                ),
              ),

              if (user == null) ...[
                const SizedBox(height: AppSpacing.lg),
                InfoNote(text: l.authGuestPrompt, icon: Icons.login_rounded),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => context.push(Routes.signIn),
                  child: Text(l.authSignIn),
                ),
              ],

              // The join entry point, for anyone who is not already a doctor and
              // has no request in flight.
              if (user == null || (!user.isActiveDoctor && !user.hasOpenApplication)) ...[
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.medical_services_outlined, color: AppColors.primary),
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
    );
  }
}

/// The featured slice on the home screen: highest-rated first, as the backend
/// orders it.
class DoctorQueryFeatured {
  const DoctorQueryFeatured();

  DoctorQuery get query => const DoctorQuery(ordering: '-avg_rating');
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

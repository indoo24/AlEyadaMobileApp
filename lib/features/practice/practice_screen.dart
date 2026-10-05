import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/envelope.dart';
import '../../core/auth/greeting.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';

/// What a doctor still owes before their page can be published.
///
/// The backend computes this; the app lists it. Which fields are required is a
/// server rule (`REQUIRED_ACTIVATION_FIELDS` plus a specialization and a live
/// clinic) and duplicating the list here would let the two disagree.
class ActivationReport {
  const ActivationReport({
    required this.isComplete,
    required this.missing,
    required this.isPublished,
    required this.verificationStatus,
  });

  final bool isComplete;
  final List<String> missing;
  final bool isPublished;
  final String verificationStatus;

  factory ActivationReport.fromJson(Map<String, dynamic> j) {
    final missing = j['missing'];
    return ActivationReport(
      isComplete: j['is_complete'] == true,
      isPublished: j['is_published'] == true,
      verificationStatus: parseString(j['verification_status']),
      missing: missing is List ? missing.map((e) => e.toString()).toList() : const [],
    );
  }
}

class DoctorStats {
  const DoctorStats({
    required this.uniquePatients,
    required this.completedVisits,
    required this.avgRating,
    required this.profileViews,
  });

  final int uniquePatients;
  final int completedVisits;
  final String avgRating;
  final int profileViews;

  factory DoctorStats.fromJson(Map<String, dynamic> j) => DoctorStats(
    uniquePatients: parseInt(j['unique_patients']) ?? 0,
    completedVisits: parseInt(j['total_completed_visits']) ?? 0,
    avgRating: parseString(j['avg_rating']),
    profileViews: parseInt(j['profile_views']) ?? 0,
  );
}

class PracticeRepository {
  PracticeRepository(this._api);

  final ApiClient _api;

  Future<ActivationReport> activation() async =>
      ActivationReport.fromJson(unwrapObject(await _api.get(Endpoints.doctorActivation)));

  Future<DoctorStats> stats() async =>
      DoctorStats.fromJson(unwrapObject(await _api.get(Endpoints.doctorStats)));

  /// The doctor's own clinics.
  Future<List<Map<String, dynamic>>> clinics() async =>
      unwrapList(await _api.get(Endpoints.doctorClinics));

  /// Today's and upcoming appointments from the doctor's side.
  Future<Paginated<Map<String, dynamic>>> bookings() async => unwrapPaginated(
    await _api.get(Endpoints.doctorBookings, query: {'scope': 'upcoming'}),
    (m) => m,
  );
}

final practiceRepositoryProvider = Provider(
  (ref) => PracticeRepository(ref.watch(apiClientProvider)),
);

final activationProvider = FutureProvider<ActivationReport>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(practiceRepositoryProvider).activation();
});

final doctorStatsProvider = FutureProvider<DoctorStats>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(practiceRepositoryProvider).stats();
});

final doctorBookingsProvider = FutureProvider<Paginated<Map<String, dynamic>>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(practiceRepositoryProvider).bookings();
});

/// The approved doctor's own area: publication state, numbers, upcoming visits.
///
/// Reached only by an approved doctor — the router redirects anyone else, and
/// every endpoint behind it is `IsDoctor`-gated regardless, so a guard failure
/// would produce a 403 rather than exposed data.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(currentUserProvider);
    final activation = ref.watch(activationProvider);
    final stats = ref.watch(doctorStatsProvider);
    final bookings = ref.watch(doctorBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.dashboardTitle),
        actions: [
          IconButton(
            tooltip: l.navNotifications,
            onPressed: () => context.push(Routes.notifications),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activationProvider);
          ref.invalidate(doctorStatsProvider);
          ref.invalidate(doctorBookingsProvider);
          await ref.read(authControllerProvider.notifier).refreshUser();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            if (user != null)
              Text(
                welcomeGreeting(l, user),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            const SizedBox(height: AppSpacing.lg),

            // Publication state, straight from the activation report.
            activation.when(
              loading: () => const Skeleton(height: 72, radius: AppRadii.card),
              error: (_, __) => const SizedBox.shrink(),
              data: (a) => Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: a.isPublished
                      ? AppColors.whatsapp.withValues(alpha: 0.08)
                      : AppColors.star.withValues(alpha: 0.08),
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(
                    color: (a.isPublished ? AppColors.whatsapp : AppColors.star).withValues(
                      alpha: 0.35,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          a.isPublished
                              ? Icons.check_circle_outline_rounded
                              : Icons.pending_outlined,
                          // Availability green is one of the two places the
                          // identity rules permit it.
                          color: a.isPublished ? AppColors.whatsapp : AppColors.star,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            a.isPublished ? l.dashboardPublished : l.dashboardNotPublished,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    if (!a.isComplete && a.missing.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l.dashboardActivationMissing,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: 6,
                        children: [
                          for (final m in a.missing)
                            Chip(
                              label: Text(_fieldLabel(context, m)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppColors.surface,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            stats.when(
              loading: () => const Skeleton(height: 100, radius: AppRadii.card),
              error: (_, __) => const SizedBox.shrink(),
              data: (s) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 2.1,
                children: [
                  _StatTile(label: l.dashboardStatPatients, value: '${s.uniquePatients}'),
                  _StatTile(label: l.dashboardStatVisits, value: '${s.completedVisits}'),
                  _StatTile(label: l.dashboardStatRating, value: s.avgRating),
                  _StatTile(label: l.dashboardStatViews, value: '${s.profileViews}'),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            Text(l.dashboardTodayBookings, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            bookings.when(
              loading: () => const Skeleton(height: 90, radius: AppRadii.card),
              error: (e, _) =>
                  AppErrorView(error: e, onRetry: () => ref.invalidate(doctorBookingsProvider)),
              data: (page) => page.isEmpty
                  ? InfoNote(text: l.dashboardNoBookings)
                  : Column(
                      children: [
                        for (final b in page.items.take(10))
                          Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: ListTile(
                              leading: const Icon(Icons.event_outlined, color: AppColors.primary),
                              title: Text(
                                parseString(
                                  (b['patient'] is Map
                                          ? (b['patient'] as Map)['full_name']
                                          : null) ??
                                      b['patient_name'],
                                ),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              subtitle: Text(
                                '${parseString(b['display_date'])}  •  '
                                '${parseString(b['display_time'])}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The activation report returns backend field names. Translate the ones we
  /// know and fall back to the raw name rather than hiding an unknown
  /// requirement — a doctor needs to know *something* is missing even if this
  /// build has no label for it.
  String _fieldLabel(BuildContext context, String field) {
    final l = L.of(context);
    return switch (field) {
      'photo' => l.uploadChoosePhoto,
      'bio_ar' => l.doctorAbout,
      'years_of_experience' => l.doctorYearsExperience(0).replaceAll('0 ', ''),
      'professional_title_ar' => l.joinSpecialty,
      'specialization' => l.joinSpecialty,
      'clinic' => l.doctorClinics,
      'full_name_ar' => l.joinNameAr,
      _ => field,
    };
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

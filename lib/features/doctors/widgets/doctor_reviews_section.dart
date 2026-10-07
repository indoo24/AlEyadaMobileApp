import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/home_style.dart';
import '../doctor_detail_logic.dart';
import '../models.dart';
import '../providers.dart';
import '../repository.dart';
import 'doctor_profile_sections.dart';
import 'doctor_rating.dart';

/// Published reviews from `/doctors/{slug}/reviews/`, a page at a time.
///
/// The summary at the top is the doctor's own `avg_rating` / `reviews_count`
/// from the profile — never an average recomputed from the loaded page.
class DoctorReviewsSection extends ConsumerWidget {
  const DoctorReviewsSection({super.key, required this.detail});

  final DoctorDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final state = ref.watch(doctorReviewsProvider(detail.slug));
    final controller = ref.read(doctorReviewsProvider(detail.slug).notifier);
    final card = detail.card;

    Widget body;
    if (state.loading) {
      body = const Column(
        children: [
          Skeleton(height: 84, radius: AppRadii.input),
          SizedBox(height: 10),
          Skeleton(height: 84, radius: AppRadii.input),
        ],
      );
    } else if (state.error != null) {
      body = _Message(
        icon: Icons.cloud_off_rounded,
        text: l.ddReviewsFailed,
        action: TextButton(onPressed: controller.reload, child: Text(l.actionRetry)),
      );
    } else if (state.items.isEmpty) {
      body = _Message(icon: Icons.rate_review_outlined, text: l.doctorNoReviews);
    } else {
      body = Column(
        children: [
          for (var i = 0; i < state.items.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: AppColors.border),
            _ReviewTile(review: state.items[i]),
          ],
          if (state.moreError != null) ...[
            const SizedBox(height: 8),
            Text(l.ddReviewsMoreFailed, style: HomeType.meta.copyWith(color: AppColors.danger)),
          ],
          if (state.hasMore) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: state.loadingMore ? null : controller.loadMore,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  textStyle: HomeType.button.copyWith(fontSize: 13),
                ),
                child: state.loadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(state.moreError != null ? l.actionRetry : l.ddReviewsMore),
              ),
            ),
          ],
        ],
      );
    }

    return ProfileSection(
      title: l.doctorReviews,
      icon: Icons.reviews_outlined,
      trailing: card.hasRating ? DoctorRating(doctor: card, fontSize: 13) : null,
      child: body,
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PublicReview review;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = review.reviewerName.isEmpty ? l.ddReviewPatient : review.reviewerName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.bgSoft,
              child: Text(
                name.characters.first,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: HomeType.cardTitle.copyWith(fontSize: 14)),
                  Row(
                    children: [
                      Semantics(
                        label: '${review.rating}/5',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= review.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 14,
                                color: i <= review.rating ? AppColors.star : AppColors.border,
                              ),
                          ],
                        ),
                      ),
                      if (review.createdAt != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            reviewDateLabel(review.createdAt!, locale),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HomeType.meta,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (review.verifiedVisit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  // Green is the tokens' availability colour; a confirmed visit is
                  // the one place a review gets it.
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: AppRadii.pillRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      l.ddReviewVerified,
                      style: HomeType.pill.copyWith(color: AppColors.success, fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            review.comment,
            style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.7),
          ),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.muted),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: HomeType.meta.copyWith(fontSize: 13))),
      ?action,
    ],
  );
}

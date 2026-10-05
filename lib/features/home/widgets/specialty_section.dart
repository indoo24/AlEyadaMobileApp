import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../doctors/models.dart';
import '../../doctors/providers.dart';
import '../../doctors/repository.dart';
import '../home_providers.dart';
import '../home_style.dart';
import 'home_section_header.dart';
import 'home_section_message.dart';

/// How many specialties the strip offers before "see all" (the directory filter
/// has the full tree).
const _maxChips = 10;

/// The horizontal specialty strip.
///
/// Specialties are the API's tree, not a fixed list. The highlighted one is the
/// directory's current specialty filter, so coming back from the directory shows
/// what is applied.
class SpecialtySection extends ConsumerWidget {
  const SpecialtySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final specs = ref.watch(specializationsProvider);
    final active = ref.watch(doctorQueryProvider.select((q) => q.specialization));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: l.homeSpecialtiesTitle,
          onSeeAll: () => context.go(Routes.doctors),
        ),
        const SizedBox(height: HomeSpacing.heading),
        specs.when(
          loading: () => const _ChipSkeletons(),
          error: (_, __) => HomeSectionMessage(
            icon: Icons.error_outline_rounded,
            message: l.homeSectionError,
            onRetry: () => ref.invalidate(specializationsProvider),
          ),
          data: (tree) {
            if (tree.isEmpty) return const SizedBox.shrink();
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // Bleed to the screen edge so the strip reads as scrollable.
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final s in tree.take(_maxChips)) ...[
                    _SpecialtyChip(
                      label: s.nameAr,
                      icon: specialtyIcon(s),
                      selected: s.slug == active,
                      onTap: () {
                        ref.read(doctorQueryProvider.notifier).state = DoctorQuery(
                          specialization: s.slug,
                          city: ref.read(homeCitySlugProvider),
                        );
                        context.go(Routes.doctors);
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.navy;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.border)),
        elevation: 0,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: HomeType.chip.copyWith(color: fg)),
                const SizedBox(width: 6),
                Icon(icon, size: 17, color: selected ? Colors.white : AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipSkeletons extends StatelessWidget {
  const _ChipSkeletons();

  @override
  // Scrollable (but not by touch) so the placeholders clip at the edge on a
  // narrow screen instead of overflowing it.
  Widget build(BuildContext context) => const SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: NeverScrollableScrollPhysics(),
    child: Row(
      children: [
        Skeleton(height: 36, width: 100, radius: AppRadii.pill),
        SizedBox(width: AppSpacing.sm),
        Skeleton(height: 36, width: 120, radius: AppRadii.pill),
        SizedBox(width: AppSpacing.sm),
        Skeleton(height: 36, width: 100, radius: AppRadii.pill),
      ],
    ),
  );
}

/// A Material glyph for a specialty.
///
/// The API's `icon` field is not populated yet, so this matches on the slug and
/// English name for the common specialties and falls back to a generic medical
/// mark. Swap in `Specialization.icon` here when the backend starts sending it.
IconData specialtyIcon(Specialization s) {
  final key = '${s.slug} ${s.nameEn}'.toLowerCase();
  bool has(List<String> words) => words.any(key.contains);

  if (has(['dent', 'teeth', 'tooth'])) return Icons.sentiment_satisfied_alt_outlined;
  if (has(['cardio', 'heart'])) return Icons.favorite_border_rounded;
  if (has(['pediat', 'child'])) return Icons.child_care_rounded;
  if (has(['chest', 'pulmon', 'lung', 'respir'])) return Icons.air_rounded;
  if (has(['eye', 'ophthal'])) return Icons.visibility_outlined;
  if (has(['ortho', 'bone'])) return Icons.accessibility_new_rounded;
  if (has(['neuro', 'psych', 'mental'])) return Icons.psychology_outlined;
  if (has(['derma', 'skin'])) return Icons.face_retouching_natural_outlined;
  if (has(['obstet', 'gyn', 'women'])) return Icons.pregnant_woman_rounded;
  if (has(['ear', 'ent', 'otolary'])) return Icons.hearing_rounded;
  return Icons.medical_services_outlined;
}

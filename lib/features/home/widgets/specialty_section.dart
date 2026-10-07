import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../doctors/models.dart';
import '../../doctors/providers.dart';
import '../../doctors/repository.dart';
import '../home_style.dart';
import 'home_section_header.dart';
import 'home_section_message.dart';
import 'horizontal_strip.dart';
import 'quick_discovery.dart';

/// How many specialties the strip shows; "see all" opens every one.
const _stripCount = 10;

/// The specialties, most doctors first.
///
/// Ordered by the API's own `doctors_count`, so the strip leads with the
/// specialties a patient can actually book; ties keep the API's order.
List<Specialization> rankSpecialties(List<Specialization> tree) {
  final indexed = [for (var i = 0; i < tree.length; i++) (i, tree[i])];
  indexed.sort((a, b) {
    final byCount = b.$2.doctorsCount.compareTo(a.$2.doctorsCount);
    return byCount != 0 ? byCount : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// The horizontal strip of specialty tiles.
class SpecialtySection extends ConsumerWidget {
  const SpecialtySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final specs = ref.watch(specializationsProvider);

    // Nothing to offer and nothing to retry: no section at all.
    if (specs.valueOrNull?.isEmpty ?? false) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: HomeSectionHeader(
            title: l.homeSpecialtiesTitle,
            onSeeAll: specs.hasValue ? () => showAllSpecialties(context) : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: specs.when(
            loading: () => HorizontalStrip(
              key: ValueKey('loading'),
              scrollable: false,
              children: [for (var i = 0; i < 5; i++) const _TileSkeleton()],
            ),
            error: (_, __) => Padding(
              key: const ValueKey('error'),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: HomeSectionMessage(
                icon: Icons.error_outline_rounded,
                message: l.homeSectionError,
                onRetry: () => ref.invalidate(specializationsProvider),
              ),
            ),
            data: (tree) => HorizontalStrip(
              key: const ValueKey('data'),
              children: [
                for (final s in rankSpecialties(tree).take(_stripCount))
                  SpecialtyTile(
                    specialty: s,
                    onTap: () => openDirectory(context, ref, DoctorQuery(specialization: s.slug)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One specialty: a consistent icon, its name, and how many doctors it has.
class SpecialtyTile extends StatelessWidget {
  const SpecialtyTile({super.key, required this.specialty, required this.onTap, this.width = 96});

  final Specialization specialty;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final count = specialty.doctorsCount;
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: count > 0 ? '${specialty.nameAr}، ${l.hmSpecialtyDoctors(count)}' : specialty.nameAr,
        excludeSemantics: true,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(homeCardRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(homeCardRadius),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(homeCardRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.bgSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(specialtyIcon(specialty), color: AppColors.primary, size: 23),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    specialty.nameAr,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HomeType.tileLabel,
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      l.hmSpecialtyDoctors(count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeType.tileMeta,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) =>
      const Skeleton(height: 118, width: 96, radius: homeCardRadius);
}

/// Every specialty in a sheet, for "see all" and the Specialties shortcut.
Future<void> showAllSpecialties(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => const _AllSpecialtiesSheet(),
);

class _AllSpecialtiesSheet extends ConsumerWidget {
  const _AllSpecialtiesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final specs = ref.watch(specializationsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: AppRadii.pillRadius),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.gutter, 10, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.hmAllSpecialties,
                      style: HomeType.sectionTitle.copyWith(fontSize: 17),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.bkClose,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: specs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  AppErrorView(error: e, onRetry: () => ref.invalidate(specializationsProvider)),
              data: (tree) {
                final all = rankSpecialties(tree);
                return LayoutBuilder(
                  builder: (context, c) {
                    final columns = c.maxWidth >= 380 ? 4 : 3;
                    return GridView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        6,
                        AppSpacing.gutter,
                        24,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        // Taller as the text grows, so two-line names never clip.
                        mainAxisExtent: MediaQuery.textScalerOf(context).scale(84) + 50,
                      ),
                      itemCount: all.length,
                      itemBuilder: (_, i) => SpecialtyTile(
                        specialty: all[i],
                        width: null,
                        onTap: () {
                          Navigator.of(context).pop();
                          openDirectory(context, ref, DoctorQuery(specialization: all[i].slug));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A Material glyph for a specialty, from one outlined family.
///
/// The API's `icon` field is empty for every specialty today (and `name_en`
/// too), so this matches on the slug — a stable identifier — and falls back to
/// one generic medical mark. Swap in `Specialization.icon` here when the
/// backend starts sending it.
IconData specialtyIcon(Specialization s) {
  final key = '${s.slug} ${s.nameEn}'.toLowerCase();
  bool has(List<String> words) => words.any(key.contains);

  if (has(['dent', 'teeth', 'tooth'])) return Icons.sentiment_satisfied_alt_outlined;
  if (has(['vascular'])) return Icons.bloodtype_outlined;
  if (has(['cardio', 'heart'])) return Icons.favorite_border_rounded;
  if (has(['pediat', 'child'])) return Icons.child_care_outlined;
  if (has(['chest', 'pulmon', 'lung', 'respir'])) return Icons.air_rounded;
  if (has(['eye', 'ophthal'])) return Icons.visibility_outlined;
  if (has(['ortho', 'bone'])) return Icons.accessibility_new_rounded;
  if (has(['neuro', 'psych', 'mental'])) return Icons.psychology_outlined;
  if (has(['derma', 'skin', 'cosmetic', 'plastic'])) return Icons.face_retouching_natural_outlined;
  if (has(['obstet', 'gyn', 'women'])) return Icons.pregnant_woman_rounded;
  if (has(['ear', 'ent', 'otolary'])) return Icons.hearing_outlined;
  if (has(['urolog', 'kidney', 'nephro'])) return Icons.water_drop_outlined;
  if (has(['analysis', 'lab', 'patholog'])) return Icons.biotech_outlined;
  if (has(['nutrition', 'physio', 'diet'])) return Icons.restaurant_outlined;
  if (has(['surgery', 'endoscop'])) return Icons.healing_outlined;
  if (has(['internal', 'medicine'])) return Icons.medication_outlined;
  return Icons.medical_services_outlined;
}

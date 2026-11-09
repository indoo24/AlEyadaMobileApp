import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/paged_list_view.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/repository.dart';
import '../home/home_providers.dart';
import '../home/home_style.dart';
import '../home/widgets/location_picker.dart';
import '../home/widgets/medical_center_card.dart';
import '../home/widgets/quick_discovery.dart';
import 'models.dart';
import 'providers.dart';

/// Every clinic and medical center — Home's "see all" for its centers strip.
///
/// Scoped to the Home city like the strip it continues, and says which city
/// that is. A center opens its doctors, as it does on Home.
class MedicalCentersScreen extends ConsumerWidget {
  const MedicalCentersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final city = ref.watch(homeCitySlugProvider);
    final provider = allClinicsProvider(city);
    final controller = ref.read(provider.notifier);

    return Scaffold(
      backgroundColor: context.palette.page,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.homeCentersTitle),
            Text(
              homeLocationLabel(context, ref),
              style: context.homeType.meta.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
      body: PagedListView<ClinicListItem>(
        state: ref.watch(provider),
        onReload: controller.reload,
        onLoadMore: controller.loadMore,
        loading: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              const MedicalCenterSkeleton(width: double.infinity),
            ],
          ],
        ),
        empty: AppEmptyView(
          icon: Icons.local_hospital_outlined,
          title: l.homeNoCenters,
        ),
        // The card is the Home strip's; as there, it is laid out at its natural
        // height.
        itemBuilder: (context, c) => IntrinsicHeight(
          child: MedicalCenterCard(
            clinic: c,
            width: double.infinity,
            onTap: () => openDirectory(
              context,
              ref,
              DoctorQuery(clinic: c.slug, clinicName: c.nameAr),
            ),
          ),
        ),
      ),
    );
  }
}

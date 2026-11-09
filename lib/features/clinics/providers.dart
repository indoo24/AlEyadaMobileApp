import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/envelope.dart';
import '../../core/paging/paged_list.dart';
import '../../core/providers.dart';
import 'models.dart';
import 'repository.dart';

final clinicRepositoryProvider = Provider<ClinicRepository>(
  (ref) => ClinicRepository(ref.watch(apiClientProvider)),
);

/// The clinics shown on the home screen, for a city slug (null = everywhere).
final homeClinicsProvider = FutureProvider.family<Paginated<ClinicListItem>, String?>((
  ref,
  city,
) async {
  return ref.watch(clinicRepositoryProvider).clinics(city: city, pageSize: 8);
});

/// Every active clinic for a city slug (null = everywhere), a page at a time.
final allClinicsProvider = StateNotifierProvider.autoDispose
    .family<
      PagedListController<ClinicListItem>,
      PagedListState<ClinicListItem>,
      String?
    >((ref, city) {
      final repo = ref.watch(clinicRepositoryProvider);
      return PagedListController(
        (page) => repo.clinics(city: city, page: page, pageSize: 20),
        idOf: (c) => c.id,
      );
    });

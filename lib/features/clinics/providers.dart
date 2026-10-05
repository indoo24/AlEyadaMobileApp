import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/envelope.dart';
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

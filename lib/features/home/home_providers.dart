import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../doctors/models.dart';
import '../doctors/providers.dart';
import '../doctors/repository.dart';

/// The city the home feed is scoped to, by slug. Null means every city.
///
/// Held in memory for the session. It narrows what Home *shows* (featured
/// doctors, clinics) and is carried into the directory when the user searches or
/// picks a specialty from here; it does not rewrite the directory's own filters
/// on its own.
final homeCitySlugProvider = StateProvider<String?>((ref) => null);

/// Highest-rated first, as the backend orders it, within the chosen city.
DoctorQuery featuredDoctorQuery(String? city) => DoctorQuery(sort: DoctorSort.rating, city: city);

/// The selected city as a full object (for its name), once the city list loads.
final homeCityProvider = Provider<City?>((ref) {
  final slug = ref.watch(homeCitySlugProvider);
  if (slug == null) return null;
  return ref.watch(citiesProvider).valueOrNull?.where((c) => c.slug == slug).firstOrNull;
});

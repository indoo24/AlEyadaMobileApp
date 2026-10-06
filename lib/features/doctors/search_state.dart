import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/arabic_text.dart';
import '../clinics/models.dart';
import '../clinics/providers.dart';
import 'models.dart';
import 'repository.dart';

// ---------------------------------------------------------------------------
// Recent searches
// ---------------------------------------------------------------------------

/// What the person searched for before, newest first, kept on the device.
///
/// SharedPreferences is the project's existing store for non-secret UI state (the
/// chosen language lives there too). Nothing here is sensitive, but it is also
/// not synced — it is a convenience, not an account feature.
class RecentSearchesController extends StateNotifier<List<String>> {
  RecentSearchesController() : super(const []) {
    _restore();
  }

  static const storageKey = 'recent_doctor_searches';
  static const maxEntries = 8;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(storageKey);
      if (saved != null && mounted) {
        // Anything added before the disk read finished is newer; keep it first.
        state = [...state, ...saved.where((s) => !state.contains(s))].take(maxEntries).toList();
      }
    } catch (_) {
      // No storage (a test, a locked-down profile): recents simply start empty.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(storageKey, state);
    } catch (_) {
      // Losing the history is not worth surfacing.
    }
  }

  /// Record a search. Too-short text is not worth remembering, and a repeat moves
  /// to the front rather than being listed twice.
  Future<void> add(String raw) async {
    final text = raw.trim();
    if (text.length < kMinSearchChars) return;
    final key = foldForSearch(text);
    state = [text, ...state.where((s) => foldForSearch(s) != key)].take(maxEntries).toList();
    await _persist();
  }

  Future<void> remove(String text) async {
    state = state.where((s) => s != text).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _persist();
  }
}

final recentSearchesProvider = StateNotifierProvider<RecentSearchesController, List<String>>(
  (ref) => RecentSearchesController(),
);

// ---------------------------------------------------------------------------
// Suggestions
// ---------------------------------------------------------------------------

enum SuggestionKind { specialty, city, area, clinic }

/// One tappable suggestion, and what applying it does to the query.
class SearchSuggestion {
  const SearchSuggestion({
    required this.kind,
    required this.label,
    required this.apply,
    this.subtitle,
  });

  final SuggestionKind kind;
  final String label;
  final String? subtitle;

  /// The query to run when it is chosen.
  final DoctorQuery Function(DoctorQuery current) apply;
}

const _maxSpecialties = 3;
const _maxCities = 2;
const _maxAreas = 2;

/// Suggestions drawn from reference data the app has already loaded — the
/// specialty tree and the city/area list. No request, nothing invented: if the
/// text matches no real specialty or place, there is simply nothing to suggest.
List<SearchSuggestion> localSuggestions(
  String text, {
  required List<Specialization> specialties,
  required List<City> cities,
}) {
  final needle = text.trim();
  if (needle.isEmpty) return const [];

  bool matches(String ar, String en) => foldedContains(ar, needle) || foldedContains(en, needle);

  final out = <SearchSuggestion>[];

  for (final s in specialties.expand((s) => s.flattened).where((s) => matches(s.nameAr, s.nameEn)).take(_maxSpecialties)) {
    out.add(
      SearchSuggestion(
        kind: SuggestionKind.specialty,
        label: s.nameAr,
        apply: (q) => q.copyWith(specialization: s.slug, search: null, page: 1),
      ),
    );
  }

  for (final c in cities.where((c) => matches(c.nameAr, c.nameEn)).take(_maxCities)) {
    out.add(
      SearchSuggestion(
        kind: SuggestionKind.city,
        label: c.nameAr,
        apply: (q) => q.copyWith(city: c.slug, area: null, search: null, page: 1),
      ),
    );
  }

  var areas = 0;
  for (final c in cities) {
    for (final a in c.areas) {
      if (areas >= _maxAreas) break;
      if (!matches(a.nameAr, a.nameEn)) continue;
      areas++;
      out.add(
        SearchSuggestion(
          kind: SuggestionKind.area,
          label: a.nameAr,
          subtitle: c.nameAr,
          apply: (q) => q.copyWith(city: c.slug, area: a.slug, search: null, page: 1),
        ),
      );
    }
  }

  return out;
}

/// Clinics matching the text, from the real `/clinics/?q=` endpoint.
///
/// Keyed by the *debounced* text the screen passes in, so typing does not send a
/// request per keystroke. Auto-disposed: a stale suggestion list is worthless.
final clinicSuggestionsProvider = FutureProvider.autoDispose.family<List<ClinicListItem>, String>((
  ref,
  text,
) async {
  final page = await ref.watch(clinicRepositoryProvider).clinics(q: text, pageSize: 3);
  return page.items;
});

/// A clinic suggestion: "doctors at this clinic".
SearchSuggestion clinicSuggestion(ClinicListItem c) => SearchSuggestion(
  kind: SuggestionKind.clinic,
  label: c.nameAr,
  subtitle: c.locationLabel.isEmpty ? null : c.locationLabel,
  apply: (q) => q.copyWith(clinic: c.slug, clinicName: c.nameAr, search: null, page: 1),
);

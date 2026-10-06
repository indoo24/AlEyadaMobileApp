import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';

/// A favourite doctor: the stable id the favourite is keyed on, and the slug the
/// profile endpoint needs. Nothing else is stored — the doctor's name, fee and
/// rating are fetched when shown, so they are never stale.
class FavoriteEntry {
  const FavoriteEntry({required this.id, required this.slug});

  final String id;
  final String slug;

  Map<String, String> toJson() => {'id': id, 'slug': slug};

  static FavoriteEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final slug = raw['slug'];
    if (id is! String || id.isEmpty || slug is! String || slug.isEmpty) return null;
    return FavoriteEntry(id: id, slug: slug);
  }
}

enum FavoritesStatus { loading, ready, error }

class FavoritesState {
  const FavoritesState({this.entries = const [], this.status = FavoritesStatus.loading});

  /// Newest first.
  final List<FavoriteEntry> entries;
  final FavoritesStatus status;

  bool contains(String doctorId) => entries.any((e) => e.id == doctorId);

  FavoritesState copyWith({List<FavoriteEntry>? entries, FavoritesStatus? status}) =>
      FavoritesState(entries: entries ?? this.entries, status: status ?? this.status);
}

/// Where favourites live on the device. A seam so tests (and a future server
/// implementation) can replace the storage without touching the controller.
abstract class FavoritesStore {
  Future<List<String>?> read(String key);
  Future<void> write(String key, List<String> value);
}

/// The default store: SharedPreferences, the project's existing home for
/// non-secret per-device state.
class PrefsFavoritesStore implements FavoritesStore {
  const PrefsFavoritesStore();

  @override
  Future<List<String>?> read(String key) async =>
      (await SharedPreferences.getInstance()).getStringList(key);

  @override
  Future<void> write(String key, List<String> value) async {
    final ok = await (await SharedPreferences.getInstance()).setStringList(key, value);
    if (!ok) throw StateError('favourites could not be saved');
  }
}

final favoritesStoreProvider = Provider<FavoritesStore>((ref) => const PrefsFavoritesStore());

/// The single source of truth for which doctors are favourites.
///
/// The backend has no favourites endpoint, so this is local. It is keyed by the
/// signed-in account's id: a different account on the same phone gets its own
/// list, never someone else's. Signed out, there is a separate guest list —
/// nothing is merged into an account at sign-in, so a guest's picks never leak
/// into an account that did not make them.
///
/// Updates are optimistic: the state changes first and the write follows, so a
/// heart responds in the same frame. Writes are queued one after another, and a
/// failed write undoes only its own change.
class FavoritesController extends StateNotifier<FavoritesState> {
  FavoritesController(this._store, {String? userId})
    : _key = storageKey(userId),
      super(const FavoritesState()) {
    _loaded = _load();
  }

  final FavoritesStore _store;
  final String _key;
  late Future<void> _loaded;
  Future<void> _writes = Future.value();

  static String storageKey(String? userId) => 'favorite_doctors_v1:${userId ?? 'guest'}';

  Future<void> _load() async {
    try {
      final raw = await _store.read(_key) ?? const <String>[];
      final seen = <String>{};
      final entries = <FavoriteEntry>[];
      for (final item in raw) {
        Object? decoded;
        try {
          decoded = jsonDecode(item);
        } catch (_) {
          continue; // a corrupt row is skipped, not fatal
        }
        final e = FavoriteEntry.tryParse(decoded);
        if (e != null && seen.add(e.id)) entries.add(e);
      }
      if (mounted) state = FavoritesState(entries: entries, status: FavoritesStatus.ready);
    } catch (_) {
      if (mounted) state = const FavoritesState(status: FavoritesStatus.error);
    }
  }

  /// Read the list again after a failed load.
  Future<void> retry() {
    state = const FavoritesState();
    return _loaded = _load();
  }

  /// Add the doctor if absent, remove it if present. Returns whether the change
  /// was saved; on `false` the state has already been put back.
  Future<bool> toggle({required String id, required String slug}) async {
    await _loaded;
    if (!mounted || state.status != FavoritesStatus.ready) return false;

    final wasFavorite = state.contains(id);
    state = state.copyWith(
      entries: wasFavorite
          ? state.entries.where((e) => e.id != id).toList()
          : [FavoriteEntry(id: id, slug: slug), ...state.entries],
    );

    final snapshot = [for (final e in state.entries) jsonEncode(e.toJson())];
    final write = _writes.then((_) => _store.write(_key, snapshot));
    _writes = write.then((_) {}, onError: (_) {});
    try {
      await write;
      return true;
    } catch (_) {
      // Undo just this change — later taps may already have built on top of it.
      if (mounted) {
        state = state.copyWith(
          entries: wasFavorite
              ? [FavoriteEntry(id: id, slug: slug), ...state.entries.where((e) => e.id != id)]
              : state.entries.where((e) => e.id != id).toList(),
        );
      }
      return false;
    }
  }
}

/// Rebuilt when the signed-in account changes, so each account (and the signed-out
/// guest) reads and writes its own list.
final favoritesProvider = StateNotifierProvider<FavoritesController, FavoritesState>((ref) {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  return FavoritesController(ref.watch(favoritesStoreProvider), userId: userId);
});

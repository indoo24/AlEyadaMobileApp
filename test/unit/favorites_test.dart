import 'dart:convert';

import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:aleyada_mobile/features/doctors/widgets/doctor_rating.dart';
import 'package:aleyada_mobile/features/favorites/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/api_fixtures.dart';
import '../widget/harness.dart';

/// A store in memory, whose reads and writes the test can make fail.
class MemoryStore implements FavoritesStore {
  MemoryStore([Map<String, List<String>>? seed]) : data = {...?seed};

  final Map<String, List<String>> data;
  bool failReads = false;
  bool failWrites = false;
  int writes = 0;

  @override
  Future<List<String>?> read(String key) async {
    if (failReads) throw StateError('unreadable');
    return data[key];
  }

  @override
  Future<void> write(String key, List<String> value) async {
    if (failWrites) throw StateError('disk full');
    writes++;
    data[key] = value;
  }
}

String row(String id, [String? slug]) => jsonEncode({'id': id, 'slug': slug ?? 'slug-$id'});

void main() {
  late MemoryStore store;

  FavoritesController make({String? userId}) => FavoritesController(store, userId: userId);

  Future<FavoritesController> ready({String? userId}) async {
    final c = make(userId: userId);
    await c.toggle(id: '__probe__', slug: '__probe__'); // waits for the load…
    await c.toggle(id: '__probe__', slug: '__probe__'); // …and puts things back
    store.writes = 0;
    return c;
  }

  setUp(() => store = MemoryStore());

  group('favourite state', () {
    test('a doctor is not a favourite to begin with', () async {
      final c = await ready();
      expect(c.state.status, FavoritesStatus.ready);
      expect(c.state.contains('d1'), isFalse);
      expect(c.state.entries, isEmpty);
    });

    test('adding and removing', () async {
      final c = await ready();
      expect(await c.toggle(id: 'd1', slug: 's1'), isTrue);
      expect(c.state.contains('d1'), isTrue);
      expect(await c.toggle(id: 'd1', slug: 's1'), isTrue);
      expect(c.state.contains('d1'), isFalse);
    });

    test('the heart responds before the write finishes', () async {
      final c = await ready();
      final saving = c.toggle(id: 'd1', slug: 's1');
      await Future<void>.delayed(Duration.zero);
      expect(c.state.contains('d1'), isTrue, reason: 'optimistic');
      await saving;
    });

    test('newest first', () async {
      final c = await ready();
      await c.toggle(id: 'a', slug: 'sa');
      await c.toggle(id: 'b', slug: 'sb');
      expect(c.state.entries.map((e) => e.id), ['b', 'a']);
    });

    test('toggling never creates a duplicate, however fast', () async {
      final c = await ready();
      final taps = [for (var i = 0; i < 5; i++) c.toggle(id: 'd1', slug: 's1')];
      await Future.wait(taps);
      expect(c.state.entries.where((e) => e.id == 'd1'), hasLength(1), reason: 'odd taps: favourite');
      expect(store.data[FavoritesController.storageKey(null)], [row('d1', 's1')]);

      await c.toggle(id: 'd1', slug: 's1');
      expect(c.state.entries, isEmpty);
    });

    test('duplicates already on disk are collapsed, corrupt rows skipped', () async {
      store = MemoryStore({
        FavoritesController.storageKey(null): [
          row('d1'),
          'not json at all',
          row('d1'),
          jsonEncode({'id': '', 'slug': 'x'}),
          jsonEncode({'slug': 'only-slug'}),
          row('d2'),
        ],
      });
      final c = make();
      await c.toggle(id: 'probe', slug: 'p');
      expect(c.state.entries.map((e) => e.id), ['probe', 'd1', 'd2']);
    });

    test('only the id and slug are stored, not the doctor', () async {
      final c = await ready();
      await c.toggle(id: 'd1', slug: 's1');
      expect(jsonDecode(store.data[FavoritesController.storageKey(null)]!.single), {
        'id': 'd1',
        'slug': 's1',
      });
    });
  });

  group('persistence', () {
    test('survives closing and reopening the app', () async {
      final first = await ready();
      await first.toggle(id: 'd1', slug: 's1');
      await first.toggle(id: 'd2', slug: 's2');

      final reopened = make(); // a new controller over the same storage
      await reopened.toggle(id: 'probe', slug: 'p'); // waits for the load
      expect(reopened.state.contains('d1'), isTrue);
      expect(reopened.state.contains('d2'), isTrue);
    });

    test('works through the real SharedPreferences store', () async {
      SharedPreferences.setMockInitialValues({});
      final a = FavoritesController(const PrefsFavoritesStore());
      await a.toggle(id: 'd1', slug: 's1');

      final b = FavoritesController(const PrefsFavoritesStore());
      await b.toggle(id: 'd2', slug: 's2');
      expect(b.state.entries.map((e) => e.id), ['d2', 'd1']);
    });

    test('a failed save puts the heart back and says so', () async {
      final c = await ready();
      store.failWrites = true;
      expect(await c.toggle(id: 'd1', slug: 's1'), isFalse);
      expect(c.state.contains('d1'), isFalse, reason: 'add undone');

      store.failWrites = false;
      await c.toggle(id: 'd1', slug: 's1');
      store.failWrites = true;
      expect(await c.toggle(id: 'd1', slug: 's1'), isFalse);
      expect(c.state.contains('d1'), isTrue, reason: 'remove undone');
    });

    test('a failed save undoes only its own change', () async {
      final c = await ready();
      await c.toggle(id: 'keep', slug: 'k');
      store.failWrites = true;
      final failing = c.toggle(id: 'new', slug: 'n');
      store.failWrites = false;
      final fine = c.toggle(id: 'other', slug: 'o');
      // The first write was already queued to fail; the second must stand.
      await Future.wait([failing, fine]);
      expect(c.state.contains('keep'), isTrue);
      expect(c.state.contains('other'), isTrue);
    });

    test('an unreadable store is an error state that can be retried', () async {
      store.failReads = true;
      final c = make();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.status, FavoritesStatus.error);
      expect(await c.toggle(id: 'd1', slug: 's1'), isFalse, reason: 'will not overwrite what it cannot read');

      store.failReads = false;
      await c.retry();
      expect(c.state.status, FavoritesStatus.ready);
    });
  });

  group('accounts', () {
    test('each account, and the guest, has a separate list', () async {
      final alice = await ready(userId: 'alice');
      await alice.toggle(id: 'd1', slug: 's1');

      final bob = make(userId: 'bob');
      await bob.toggle(id: 'probe', slug: 'p');
      expect(bob.state.contains('d1'), isFalse, reason: 'Bob never sees Alice\'s doctors');

      final guest = make();
      await guest.toggle(id: 'probe', slug: 'p');
      expect(guest.state.contains('d1'), isFalse);

      final aliceAgain = make(userId: 'alice');
      await aliceAgain.toggle(id: 'probe', slug: 'p');
      expect(aliceAgain.state.contains('d1'), isTrue);
    });

    test('the provider follows who is signed in', () async {
      final h = TestHarness();
      final container = ProviderContainer(
        overrides: [...h.overrides, favoritesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      container.listen(favoritesProvider, (_, __) {});

      Me user(String id) => Me.fromJson({...meResponseData, 'id': id, 'patient_profile': null});
      AuthTokens tokens() => const AuthTokens(access: 'a', refresh: 'r');
      final auth = container.read(authControllerProvider.notifier);

      await auth.adoptSession(tokens(), user: user('alice'));
      await container.read(favoritesProvider.notifier).toggle(id: 'd1', slug: 's1');
      expect(container.read(favoritesProvider).contains('d1'), isTrue);

      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();
      expect(container.read(favoritesProvider).contains('d1'), isFalse, reason: 'signed out: guest list');

      await auth.adoptSession(tokens(), user: user('bob'));
      await pumpEventQueue();
      expect(container.read(favoritesProvider).contains('d1'), isFalse, reason: 'another account');

      await auth.adoptSession(tokens(), user: user('alice'));
      await pumpEventQueue();
      expect(container.read(favoritesProvider).contains('d1'), isTrue, reason: 'Alice is back');
    });
  });

  group('rating', () {
    DoctorCard doctor({Object? avg, Object? count}) => DoctorCard.fromJson({
      ...doctorCardData,
      'avg_rating': avg,
      'reviews_count': count,
    });

    test('the real value is kept, never rounded up', () {
      expect(formatRating(4.95), '4.95');
      expect(formatRating(4.6), '4.6');
      expect(formatRating(5), '5.0');
      expect(formatRating(4.0), '4.0');
      expect(formatRating(3.5), '3.5');
    });

    test('a rating with reviews is shown', () {
      final d = doctor(avg: '4.95', count: 142);
      expect(d.hasRating, isTrue);
      expect(d.ratingValue, 4.95);
    });

    test('a rating without a review count is still a rating', () {
      expect(doctor(avg: '4.50', count: null).hasRating, isTrue);
      expect(doctor(avg: '4.50', count: 0).hasRating, isTrue);
    });

    test('an unrated doctor has no rating — not a 0.0', () {
      expect(doctor(avg: '0.00', count: 0).hasRating, isFalse);
      expect(doctor(avg: '', count: 0).hasRating, isFalse);
      expect(doctor(avg: null, count: 3).hasRating, isFalse, reason: 'no value to show');
      expect(doctor(avg: null, count: 3).ratingValue, isNull, reason: 'missing is not zero');
    });

    test('0.0 is shown only when the backend sends it with reviews behind it', () {
      expect(doctor(avg: '0.00', count: 4).hasRating, isTrue);
    });
  });
}

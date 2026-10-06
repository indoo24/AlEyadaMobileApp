import 'dart:async';

import 'package:aleyada_mobile/core/api/envelope.dart';
import 'package:aleyada_mobile/core/utils/arabic_text.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:aleyada_mobile/features/doctors/providers.dart';
import 'package:aleyada_mobile/features/doctors/repository.dart';
import 'package:aleyada_mobile/features/doctors/search_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/api_fixtures.dart';
import '../fixtures/search_fakes.dart';
import '../widget/harness.dart';

void main() {
  group('DoctorQuery', () {
    test('speaks the backend\'s names: q and sort, not search and ordering', () {
      final q = const DoctorQuery(search: ' عيون ', sort: DoctorSort.feeAsc).toQuery();
      expect(q['q'], 'عيون');
      expect(q['sort'], 'fee_asc');
      expect(q.containsKey('search'), isFalse);
      expect(q.containsKey('ordering'), isFalse);
    });

    test('the default sort is not sent', () {
      expect(const DoctorQuery(sort: DoctorSort.featured).toQuery().containsKey('sort'), isFalse);
      expect(const DoctorQuery().toQuery().containsKey('sort'), isFalse);
    });

    test('every supported filter maps to its parameter', () {
      final q = const DoctorQuery(
        specialization: 'eyes',
        city: 'cairo',
        area: 'maadi',
        gender: 'female',
        minRating: 4.5,
        maxFee: '300',
        bookingEnabled: true,
        clinic: 'dar-al-fouad',
      ).toQuery();
      expect(q, {
        'specialization': 'eyes',
        'city': 'cairo',
        'area': 'maadi',
        'gender': 'female',
        'min_rating': 4.5,
        'max_fee': '300',
        'booking_enabled': true,
        'clinic': 'dar-al-fouad',
        'page': 1,
      });
    });

    test('typed text: whitespace clears, a lone letter is ignored, real text is applied', () {
      const withSearch = DoctorQuery(search: 'قلب', gender: 'male');
      expect(withSearch.withSearchText('   ').search, isNull);
      expect(withSearch.withSearchText('   ').gender, 'male', reason: 'filters survive');
      expect(withSearch.withSearchText('ع'), withSearch, reason: 'too short to send');
      expect(withSearch.withSearchText(' عيون ').search, 'عيون');
      expect(withSearch.withSearchText('قلب'), same(withSearch), reason: 'unchanged is a no-op');
      expect(const DoctorQuery().withSearchText(''), const DoctorQuery());
    });

    test('filter count ignores search text and sort', () {
      expect(const DoctorQuery(search: 'x', sort: DoctorSort.rating).activeFilterCount, 0);
      expect(const DoctorQuery(city: 'a', area: 'b', minRating: 4).activeFilterCount, 3);
      expect(const DoctorQuery(bookingEnabled: false).activeFilterCount, 1);
    });

    test('removing all filters keeps the text and the sort', () {
      final q = const DoctorQuery(
        search: 'قلب',
        sort: DoctorSort.rating,
        city: 'a',
        minRating: 4,
        clinic: 'c',
        clinicName: 'C',
      ).withoutFilters();
      expect(q, const DoctorQuery(search: 'قلب', sort: DoctorSort.rating));
    });
  });

  group('doctor list controller', () {
    late TestHarness h;
    late FakeDirectory dir;
    late ProviderContainer container;
    late Map<String, Completer<Paginated<DoctorCard>>> pending;

    setUp(() {
      h = TestHarness();
      pending = {};
      // Each query waits on its own completer, keyed by its search text, so the
      // test chooses the order the answers arrive in.
      dir = FakeDirectory(
        h.client,
        handler: (q) => (pending['${q.search}#${q.page}'] ??= Completer()).future,
      );
      container = ProviderContainer(
        overrides: [...h.overrides, directoryRepositoryProvider.overrideWithValue(dir)],
      );
      addTearDown(container.dispose);
    });

    Completer<Paginated<DoctorCard>> answer(String? search, [int page = 1]) =>
        pending['$search#$page'] ??= Completer();

    DoctorListController start() {
      container.listen(doctorListProvider, (_, __) {});
      return container.read(doctorListProvider.notifier);
    }

    void setSearch(String? s) => container.read(doctorQueryProvider.notifier).state = container
        .read(doctorQueryProvider)
        .copyWith(search: s, page: 1);

    List<String> ids() =>
        container.read(doctorListProvider).valueOrNull!.items.map((d) => d.id).toList();

    test('the latest query wins even when an older answer arrives last', () async {
      start();
      answer(null).complete(pageOf());
      await pumpEventQueue();

      setSearch('احمد');
      setSearch('احمد جمال');
      expect(dir.searches, [null, 'احمد', 'احمد جمال']);

      final newer = pageOf(total: 1);
      answer('احمد جمال').complete(newer);
      await pumpEventQueue();
      expect(ids(), ['doctor-1']);

      // The slow answer for the superseded query lands afterwards…
      answer('احمد').complete(pageOf(page: 3, total: 40));
      await pumpEventQueue();

      // …and must not replace the newer results.
      expect(container.read(doctorListProvider).valueOrNull!.pagination.count, 1);
      expect(ids(), ['doctor-1']);
    });

    test('a superseded request is cancelled', () async {
      start();
      answer(null).complete(pageOf());
      await pumpEventQueue();
      setSearch('احمد');
      setSearch('احمد جمال');
      expect(dir.tokens[1]!.isCancelled, isTrue, reason: 'احمد was superseded');
      expect(dir.tokens[2]!.isCancelled, isFalse);
    });

    test('setting an identical query sends no request', () async {
      start();
      answer(null).complete(pageOf());
      await pumpEventQueue();
      setSearch('قلب');
      answer('قلب').complete(pageOf());
      await pumpEventQueue();
      expect(dir.calls, hasLength(2));

      setSearch('قلب');
      container.read(doctorQueryProvider.notifier).state = container.read(doctorQueryProvider);
      await pumpEventQueue();
      expect(dir.calls, hasLength(2));
    });

    test('previous results stay visible while the next query loads', () async {
      start();
      answer(null).complete(pageOf());
      await pumpEventQueue();

      setSearch('قلب');
      final loading = container.read(doctorListProvider);
      expect(loading.isLoading, isTrue);
      expect(loading.valueOrNull, isNotNull, reason: 'old rows are kept, not blanked');
      expect(ids(), ['doctor-1', 'doctor-2']);
    });

    test('an API error keeps the query, and retry runs the same query', () async {
      final c = start();
      answer(null).complete(pageOf());
      await pumpEventQueue();

      container.read(doctorQueryProvider.notifier).state = const DoctorQuery(
        search: 'قلب',
        city: 'cairo',
        minRating: 4,
      );
      answer('قلب').completeError(Exception('boom'));
      await pumpEventQueue();

      expect(container.read(doctorListProvider).hasError, isTrue);
      expect(
        container.read(doctorQueryProvider),
        const DoctorQuery(search: 'قلب', city: 'cairo', minRating: 4),
        reason: 'nothing the person chose is lost',
      );

      pending.remove('قلب#1');
      final retry = c.refresh();
      expect(dir.calls.last.city, 'cairo');
      answer('قلب').complete(pageOf(total: 4));
      await retry;
      expect(container.read(doctorListProvider).hasError, isFalse);
    });

    test('loadMore appends the next page once, and ignores a repeat while in flight', () async {
      final c = start();
      answer(null).complete(pageOf());
      await pumpEventQueue();

      final a = c.loadMore();
      final b = c.loadMore();
      expect(dir.calls.where((q) => q.page == 2), hasLength(1), reason: 'no duplicate request');

      answer(null, 2).complete(pageOf(page: 2));
      await a;
      await b;
      expect(ids(), ['doctor-1', 'doctor-2', 'doctor-3', 'doctor-4']);
    });

    test('a repeated doctor on a later page is not shown twice', () async {
      final c = start();
      answer(null).complete(pageOf());
      await pumpEventQueue();

      final load = c.loadMore();
      // Page 2 repeats doctor-2 (the list shifted while paging).
      answer(null, 2).complete(
        Paginated(
          items: [doctorNo(2), doctorNo(3)],
          pagination: const Pagination(count: 17, page: 2, pages: 9, pageSize: 2),
        ),
      );
      await load;
      expect(ids(), ['doctor-1', 'doctor-2', 'doctor-3']);
    });

    test('a page that arrives after the query changed is discarded', () async {
      final c = start();
      answer(null).complete(pageOf());
      await pumpEventQueue();

      final load = c.loadMore();
      setSearch('قلب');
      answer('قلب').complete(pageOf(perPage: 3, total: 3));
      await pumpEventQueue();
      answer(null, 2).complete(pageOf(page: 2));
      await load;

      expect(ids(), ['doctor-1', 'doctor-2', 'doctor-3'], reason: 'the stale page 2 is dropped');
      expect(container.read(doctorListProvider).valueOrNull!.pagination.count, 3);
    });

    test('loadMore does nothing on the last page', () async {
      final c = start();
      answer(null).complete(pageOf(total: 2));
      await pumpEventQueue();
      await c.loadMore();
      expect(dir.calls, hasLength(1));
    });

    test('sorting reloads from page one with the sort sent', () async {
      start();
      answer(null).complete(pageOf());
      await pumpEventQueue();
      container.read(doctorQueryProvider.notifier).state = const DoctorQuery(sort: DoctorSort.feeAsc);
      expect(dir.calls.last.toQuery()['sort'], 'fee_asc');
      expect(dir.calls.last.page, 1);
    });
  });

  group('recent searches', () {
    Future<(ProviderContainer, RecentSearchesController)> make([Map<String, Object> seed = const {}]) async {
      SharedPreferences.setMockInitialValues(seed);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ctl = c.read(recentSearchesProvider.notifier);
      await pumpEventQueue();
      return (c, ctl);
    }

    test('newest first, no duplicates (spelling variants count as the same)', () async {
      final (c, ctl) = await make();
      await ctl.add('احمد');
      await ctl.add('طب العيون');
      await ctl.add('أحمد');
      expect(c.read(recentSearchesProvider), ['أحمد', 'طب العيون']);
    });

    test('too-short and blank entries are not kept', () async {
      final (c, ctl) = await make();
      await ctl.add('ع');
      await ctl.add('   ');
      expect(c.read(recentSearchesProvider), isEmpty);
    });

    test('keeps only the most recent eight', () async {
      final (c, ctl) = await make();
      for (var i = 0; i < 12; i++) {
        await ctl.add('بحث $i');
      }
      final list = c.read(recentSearchesProvider);
      expect(list, hasLength(8));
      expect(list.first, 'بحث 11');
    });

    test('remove one, clear all', () async {
      final (c, ctl) = await make();
      await ctl.add('قلب');
      await ctl.add('عيون');
      await ctl.remove('قلب');
      expect(c.read(recentSearchesProvider), ['عيون']);
      await ctl.clear();
      expect(c.read(recentSearchesProvider), isEmpty);
    });

    test('survives a restart', () async {
      final (_, ctl) = await make();
      await ctl.add('باطنة');

      final prefs = await SharedPreferences.getInstance();
      SharedPreferences.setMockInitialValues({
        RecentSearchesController.storageKey: prefs.getStringList(RecentSearchesController.storageKey)!,
      });
      final (c2, _) = await make({
        RecentSearchesController.storageKey: ['باطنة'],
      });
      expect(c2.read(recentSearchesProvider), ['باطنة']);
    });
  });

  group('suggestions come only from real data', () {
    final specs = (specializationsResponse['data'] as List)
        .map((e) => Specialization.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final cities = [
      City.fromJson({
        'id': '1',
        'slug': 'cairo',
        'name_ar': 'القاهرة',
        'name_en': 'Cairo',
        'areas': [
          {'id': 'a', 'slug': 'maadi', 'name_ar': 'المعادي', 'name_en': 'Maadi'},
        ],
      }),
    ];

    List<SearchSuggestion> run(String t) => localSuggestions(t, specialties: specs, cities: cities);

    test('a specialty matches regardless of hamza and ta marbuta spelling', () {
      final s = run('اسنان'); // typed without the hamza on أسنان
      expect(s.map((e) => e.kind), contains(SuggestionKind.specialty));
      expect(s.first.label, 'أسنان');
    });

    test('a sub-specialty is found too', () {
      expect(run('تقويم').first.label, 'تقويم الأسنان');
    });

    test('cities and areas, with the city as the area\'s subtitle', () {
      expect(run('القاهره').single.kind, SuggestionKind.city);
      final area = run('معادي').single;
      expect(area.kind, SuggestionKind.area);
      expect(area.subtitle, 'القاهرة');
    });

    test('applying one sets the right filter and drops the text', () {
      const start = DoctorQuery(search: 'قل', gender: 'female');
      final applied = run('قلب').first.apply(start);
      expect(applied.specialization, 'cardiology');
      expect(applied.search, isNull);
      expect(applied.gender, 'female', reason: 'other filters are kept');

      final area = run('معادي').single.apply(start);
      expect((area.city, area.area), ('cairo', 'maadi'));
    });

    test('nothing matches, nothing is suggested', () {
      expect(run('zzzz'), isEmpty);
      expect(run('   '), isEmpty);
    });
  });

  group('foldForSearch', () {
    test('folds the common Arabic spelling variants', () {
      expect(foldForSearch('أحمد'), foldForSearch('احمد'));
      expect(foldForSearch('مستشفى'), foldForSearch('مستشفي'));
      expect(foldForSearch('العيادة'), foldForSearch('العياده'));
      expect(foldForSearch('مُحَمَّد'), foldForSearch('محمد'), reason: 'diacritics');
    });

    test('lower-cases Latin and leaves different words different', () {
      expect(foldForSearch('Dr. AHMED'), 'dr. ahmed');
      expect(foldForSearch('عيون'), isNot(foldForSearch('عبون')));
    });
  });
}

import 'dart:async';

import 'package:aleyada_mobile/core/api/envelope.dart';
import 'package:aleyada_mobile/features/management/models.dart';
import 'package:aleyada_mobile/features/management/providers.dart';
import 'package:aleyada_mobile/features/management/repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/management_fixtures.dart';
import '../widget/harness.dart';

/// Records what the schedule asks for and answers when the test says so.
class _FakeManagement extends ManagementRepository {
  _FakeManagement(super.api);

  final calls = <({bool upcoming, String? date, String? status, int page})>[];
  final answers = <String, Completer<Paginated<StaffBooking>>>{};

  String _key(String? status, int page) => '${status ?? '*'}#$page';

  Completer<Paginated<StaffBooking>> answer(String? status, [int page = 1]) =>
      answers.putIfAbsent(_key(status, page), Completer.new);

  @override
  Future<Paginated<StaffBooking>> bookings({
    bool upcoming = false,
    String? date,
    String? status,
    int page = 1,
  }) {
    calls.add((upcoming: upcoming, date: date, status: status, page: page));
    return answer(status, page).future;
  }
}

StaffBooking _b(String id) => StaffBooking.fromJson(booking(id, startAt: '2030-01-01T08:00:00Z'));

Paginated<StaffBooking> _page(List<String> ids, {int page = 1, int pages = 2, int count = 10}) =>
    Paginated(
      items: [for (final id in ids) _b(id)],
      pagination: Pagination(count: count, page: page, pages: pages, pageSize: ids.length),
    );

void main() {
  late _FakeManagement repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeManagement(TestHarness().client);
    container = ProviderContainer(
      overrides: [managementRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  ScheduleController start() {
    container.listen(scheduleProvider, (_, __) {});
    return container.read(scheduleProvider.notifier);
  }

  List<String> ids() => container.read(scheduleProvider).valueOrNull!.items.map((b) => b.id).toList();

  void filter(ScheduleFilter f) => container.read(scheduleFilterProvider.notifier).state = f;

  test('starts with the doctor\'s working list: upcoming, nothing else', () async {
    start();
    expect(repo.calls.single, (upcoming: true, date: null, status: null, page: 1));
  });

  test('the answer to the latest filter wins, whatever order answers arrive in', () async {
    start();
    repo.answer(null).complete(_page(['a']));
    await pumpEventQueue();

    filter(const ScheduleFilter(status: 'pending'));
    filter(const ScheduleFilter(status: 'confirmed'));

    repo.answer('confirmed').complete(_page(['new']));
    await pumpEventQueue();
    repo.answer('pending').complete(_page(['old']));
    await pumpEventQueue();

    expect(ids(), ['new']);
  });

  test('a chosen day is a view of its own: "upcoming" is not sent with it', () async {
    start();
    repo.answer(null).complete(_page(['a']));
    await pumpEventQueue();

    filter(const ScheduleFilter(date: '2026-10-01'));
    expect(repo.calls.last, (upcoming: false, date: '2026-10-01', status: null, page: 1));

    filter(const ScheduleFilter(upcoming: false, status: 'completed'));
    expect(repo.calls.last, (upcoming: false, date: null, status: 'completed', page: 1));
  });

  test('changing the filter starts again from page 1 and drops the pages loaded so far', () async {
    final c = start();
    repo.answer(null).complete(_page(['a', 'b']));
    await pumpEventQueue();
    final more = c.loadMore();
    repo.answer(null, 2).complete(_page(['c'], page: 2));
    await more;
    expect(ids(), ['a', 'b', 'c']);

    filter(const ScheduleFilter(status: 'pending'));
    expect(repo.calls.last.page, 1);
    repo.answer('pending').complete(_page(['p']));
    await pumpEventQueue();
    expect(ids(), ['p']);
  });

  test('scrolling cannot send the same page twice', () async {
    final c = start();
    repo.answer(null).complete(_page(['a', 'b']));
    await pumpEventQueue();

    final first = c.loadMore();
    final second = c.loadMore();
    final third = c.loadMore();
    expect(repo.calls.where((x) => x.page == 2), hasLength(1));

    repo.answer(null, 2).complete(_page(['c'], page: 2));
    await Future.wait([first, second, third]);
    expect(ids(), ['a', 'b', 'c']);
  });

  test('an appointment repeated on a later page is shown once', () async {
    final c = start();
    repo.answer(null).complete(_page(['a', 'b']));
    await pumpEventQueue();
    final more = c.loadMore();
    repo.answer(null, 2).complete(_page(['b', 'c'], page: 2));
    await more;
    expect(ids(), ['a', 'b', 'c']);
  });

  test('a page that arrives after the filter changed is discarded', () async {
    final c = start();
    repo.answer(null).complete(_page(['a', 'b']));
    await pumpEventQueue();

    final more = c.loadMore();
    filter(const ScheduleFilter(status: 'pending'));
    repo.answer('pending').complete(_page(['p']));
    await pumpEventQueue();
    repo.answer(null, 2).complete(_page(['stale'], page: 2));
    await more;

    expect(ids(), ['p']);
  });

  test('no more pages: loadMore does nothing', () async {
    final c = start();
    repo.answer(null).complete(_page(['a'], pages: 1));
    await pumpEventQueue();
    await c.loadMore();
    expect(repo.calls, hasLength(1));
  });

  test('the old list stays on screen while the next filter loads', () async {
    start();
    repo.answer(null).complete(_page(['a']));
    await pumpEventQueue();
    filter(const ScheduleFilter(status: 'pending'));
    final state = container.read(scheduleProvider);
    expect(state.isLoading, isTrue);
    expect(state.valueOrNull, isNotNull);
  });

  test('an error keeps the filter, and a refresh repeats the same request', () async {
    final c = start();
    repo.answer(null).complete(_page(['a']));
    await pumpEventQueue();

    filter(const ScheduleFilter(status: 'confirmed', date: '2026-10-01'));
    repo.answer('confirmed').completeError(Exception('down'));
    await pumpEventQueue();
    expect(container.read(scheduleProvider).hasError, isTrue);
    expect(container.read(scheduleFilterProvider).status, 'confirmed');
    expect(container.read(scheduleFilterProvider).date, '2026-10-01');

    repo.answers.remove('confirmed#1');
    final retry = c.refresh();
    expect(repo.calls.last, (upcoming: false, date: '2026-10-01', status: 'confirmed', page: 1));
    repo.answer('confirmed').complete(_page(['x']));
    await retry;
    expect(ids(), ['x']);
  });

  test('an answer that arrives after the list was disposed does not throw', () async {
    final sub = container.listen(scheduleProvider, (_, __) {});
    expect(repo.calls, hasLength(1));
    sub.close(); // the screen is left: auto-disposed
    await pumpEventQueue();

    // An error thrown inside the notifier would fail this test as an uncaught
    // async error; reaching the end means the late answer was simply dropped.
    repo.answer(null).complete(_page(['late']));
    await pumpEventQueue();
    expect(container.read(scheduleFilterProvider), const ScheduleFilter());
  });
}

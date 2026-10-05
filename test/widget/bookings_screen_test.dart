import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/bookings/bookings_screen.dart';
import 'package:aleyada_mobile/features/bookings/providers.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_fixtures.dart';
import 'harness.dart';

void main() {
  late TestHarness h;
  late ProviderContainer container;
  late List<String?> scopes;

  setUp(() {
    h = TestHarness(refreshToken: 'r');
    // One container across pumps, so a remount sees the same tab state the
    // app's long-lived ProviderScope would keep.
    container = ProviderContainer(overrides: h.overrides);
    scopes = [];
    h.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/bookings/') scopes.add(options.queryParameters['scope'] as String?);
          handler.next(options);
        },
      ),
    );
    h.adapter.onGet('/bookings/', (s) => s.reply(200, bookingListResponse));
    h.adapter.onGet('/auth/me/', (s) => s.reply(200, meResponse));
  });

  tearDown(() => container.dispose());

  Widget app(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('ar'),
      theme: AppTheme.light(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: child,
    ),
  );

  TabController tabController(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!;

  Future<L> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(app(const BookingsScreen()));
    await tester.pumpAndSettle();
    return L.of(tester.element(find.byType(BookingsScreen)));
  }

  testWidgets('mounts with a controller sized to its tabs', (tester) async {
    await pumpScreen(tester);

    expect(tester.takeException(), isNull, reason: 'No TabController for TabBar');
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabs.controller, isNotNull);
    expect(tabs.controller!.length, tabs.tabs.length);
    expect(tabs.controller!.index, 0);
    expect(scopes, ['upcoming']);
  });

  testWidgets('tapping a tab moves the indicator, the provider and the query together', (
    tester,
  ) async {
    final l = await pumpScreen(tester);

    await tester.tap(find.text(l.bookingsPast));
    await tester.pumpAndSettle();

    expect(tabController(tester).index, 1);
    expect(container.read(bookingsTabProvider), BookingsTab.past);
    expect(scopes.last, 'all');

    await tester.tap(find.text(l.bookingsUpcoming));
    await tester.pumpAndSettle();

    expect(tabController(tester).index, 0);
    expect(container.read(bookingsTabProvider), BookingsTab.upcoming);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selection survives leaving the screen and coming back', (tester) async {
    final l = await pumpScreen(tester);
    await tester.tap(find.text(l.bookingsPast));
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpWidget(app(const BookingsScreen()));
    await tester.pumpAndSettle();

    expect(tabController(tester).index, 1);
    expect(tester.takeException(), isNull, reason: 'the old controller was disposed cleanly');
  });

  testWidgets('the indicator follows the provider when something else moves it', (tester) async {
    await pumpScreen(tester);

    container.read(bookingsTabProvider.notifier).state = BookingsTab.past;
    await tester.pumpAndSettle();

    expect(tabController(tester).index, 1);
    expect(scopes.last, 'all');
  });
}

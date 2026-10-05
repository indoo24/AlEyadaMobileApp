import 'package:aleyada_mobile/app/bottom_nav.dart';
import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/app/shell.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/home/home_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/api_fixtures.dart';
import 'harness.dart';

void main() {
  late TestHarness h;
  late GoRouter router;

  setUp(() {
    h = TestHarness();
    h.adapter
      ..onGet('/specializations/', (s) => s.reply(200, specializationsResponse))
      ..onGet('/doctors/', (s) => s.reply(200, doctorListResponse));
    // The real AppShell and the real Home; the other tabs are stand-ins, since
    // only the dock's behaviour is under test.
    Widget tab(String name) => Scaffold(body: Center(child: Text('page:$name')));
    router = GoRouter(
      initialLocation: Routes.home,
      routes: [
        ShellRoute(
          builder: (_, __, child) => AppShell(child: child),
          routes: [
            GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
            GoRoute(path: Routes.doctors, builder: (_, __) => tab('doctors')),
            GoRoute(path: Routes.bookings, builder: (_, __) => tab('bookings')),
            GoRoute(path: Routes.account, builder: (_, __) => tab('account')),
          ],
        ),
      ],
    );
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('ar'),
    Size size = const Size(360, 800),
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2
      ..padding = FakeViewPadding(bottom: viewPadding.bottom * 2)
      ..viewPadding = FakeViewPadding(bottom: viewPadding.bottom * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: h.overrides,
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder dock() => find.byType(GlassBottomNav);

  testWidgets('every tab is reachable and the dock stays put', (tester) async {
    await pumpApp(tester);

    for (final (label, page) in [
      ('الأطباء', 'page:doctors'),
      ('حجوزاتي', 'page:bookings'),
      ('حسابي', 'page:account'),
    ]) {
      await tester.tap(find.descendant(of: dock(), matching: find.text(label)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(page), findsOneWidget, reason: label);
      expect(dock(), findsOneWidget);
    }

    await tester.tap(find.descendant(of: dock(), matching: find.text('الرئيسية')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('RTL: Home is on the right, and the pill sits under the selected tab', (
    tester,
  ) async {
    await pumpApp(tester);

    double centreOf(String label) =>
        tester.getCenter(find.descendant(of: dock(), matching: find.text(label))).dx;

    // Arabic reads right to left: first tab rightmost, last leftmost.
    expect(centreOf('الرئيسية'), greaterThan(centreOf('الأطباء')));
    expect(centreOf('الأطباء'), greaterThan(centreOf('حجوزاتي')));
    expect(centreOf('حجوزاتي'), greaterThan(centreOf('حسابي')));

    double pillCentre() => tester.getCenter(find.byType(AnimatedPositionedDirectional)).dx;
    expect(pillCentre(), closeTo(centreOf('الرئيسية'), 1));

    await tester.tap(find.descendant(of: dock(), matching: find.text('حجوزاتي')));
    await tester.pump(); // the route change lands, the slide starts
    await tester.pump(const Duration(milliseconds: 140));
    final mid = pillCentre();
    expect(mid, lessThan(centreOf('الرئيسية')), reason: 'it is travelling, not jumping');
    expect(mid, greaterThan(centreOf('حجوزاتي')));

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(pillCentre(), closeTo(centreOf('حجوزاتي'), 1));
  });

  testWidgets('LTR mirrors it', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    double centreOf(String label) =>
        tester.getCenter(find.descendant(of: dock(), matching: find.text(label))).dx;
    expect(centreOf('Home'), lessThan(centreOf('Doctors')));
  });

  testWidgets('the dock floats inside the screen edges and above the bottom inset', (
    tester,
  ) async {
    await pumpApp(tester, viewPadding: const EdgeInsets.only(bottom: 34)); // home indicator
    final rect = tester.getRect(
      find.descendant(of: dock(), matching: find.byType(BackdropFilter)),
    );
    expect(rect.left, greaterThanOrEqualTo(16));
    expect(360 - rect.right, greaterThanOrEqualTo(16));
    expect(800 - rect.bottom, greaterThanOrEqualTo(34), reason: 'clear of the home indicator');
  });

  testWidgets('Home can be scrolled until its last item sits above the dock', (tester) async {
    await pumpApp(tester, size: const Size(360, 640));

    final feed = find.byType(Scrollable).first;
    final last = find.text('انضم كطبيب'); // the final card on a guest's Home
    await tester.scrollUntilVisible(last, 300, scrollable: feed);
    await tester.drag(feed, const Offset(0, -2000)); // all the way down
    await tester.pump(const Duration(milliseconds: 300));

    final dockTop = tester.getRect(find.descendant(of: dock(), matching: find.byType(BackdropFilter))).top;
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(dockTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow on a small phone with large text', (tester) async {
    await pumpApp(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
  });
}

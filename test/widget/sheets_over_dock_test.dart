import 'package:aleyada_mobile/app/bottom_nav.dart';
import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/app/shell.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/bookings/booking_sheet.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:aleyada_mobile/features/doctors/widgets/filter_sheet.dart';
import 'package:aleyada_mobile/features/home/home_providers.dart';
import 'package:aleyada_mobile/features/home/widgets/location_picker.dart';
import 'package:aleyada_mobile/features/home/widgets/specialty_section.dart';
import 'package:aleyada_mobile/features/profile/account_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/api_fixtures.dart';
import 'harness.dart';

/// Twenty cities: more than the city sheet can show at once.
final _manyCities = {
  'data': [
    for (var i = 1; i <= 20; i++)
      {
        'id': 'c$i',
        'slug': 'city-$i',
        'name_ar': 'مدينة $i',
        'name_en': 'City $i',
        'areas': <dynamic>[],
      },
  ],
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

/// Thirty specialties, ranked by doctor count: "تخصص 30" comes last.
final _manySpecialties = {
  'data': [
    for (var i = 1; i <= 30; i++)
      {
        'id': 's$i',
        'slug': 'specialty-$i',
        'name_ar': 'تخصص $i',
        'name_en': 'Specialty $i',
        'description': '',
        'icon': null,
        'parent': null,
        'sort_order': i,
        'doctors_count': 31 - i,
        'children': <dynamic>[],
      },
  ],
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

final _doctor = DoctorDetail.fromJson({
  ...doctorCardData,
  'clinics': <dynamic>[],
  'specializations': <dynamic>[],
  'services': <dynamic>[],
  'education': <dynamic>[],
  'certificates': <dynamic>[],
});

/// The height of the system navigation bar under the app (edge to edge).
const _systemBar = 48.0;

void main() {
  late TestHarness h;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    h.adapter
      ..onGet('/locations/cities/', (s) => s.reply(200, _manyCities))
      ..onGet('/specializations/', (s) => s.reply(200, _manySpecialties));
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The real shell and dock, with a Home tab that opens each sheet the way
  /// the app's tabs do: from a context inside the shell.
  Future<void> pumpShell(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    final openers = <String, void Function(BuildContext)>{
      'city': showCityPicker,
      'specialties': showAllSpecialties,
      'filter': showDoctorFilterSheet,
      'language': showLanguageSheet,
      'appearance': showAppearanceSheet,
      'booking': (context) => showBookingSheet(context, _doctor),
    };
    Widget stub(String name) => Scaffold(body: Text('page:$name'));
    final router = GoRouter(
      initialLocation: Routes.home,
      routes: [
        ShellRoute(
          builder: (_, __, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (_, __) => Scaffold(
                body: Builder(
                  builder: (context) => ListView(
                    children: [
                      for (final MapEntry(:key, :value) in openers.entries)
                        TextButton(
                          onPressed: () => value(context),
                          child: Text('open:$key'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            GoRoute(path: Routes.doctors, builder: (_, __) => stub('doctors')),
            GoRoute(
              path: Routes.bookings,
              builder: (_, __) => stub('bookings'),
            ),
            GoRoute(
              path: Routes.favorites,
              builder: (_, __) => stub('favorites'),
            ),
            GoRoute(path: Routes.account, builder: (_, __) => stub('account')),
          ],
        ),
      ],
    );
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2
      ..padding = const FakeViewPadding(bottom: _systemBar * 2)
      ..viewPadding = const FakeViewPadding(bottom: _systemBar * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Rect glass(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byType(GlassBottomNav),
      matching: find.byType(BackdropFilter),
    ),
  );

  /// Whether a tap at the centre of [f] reaches it, rather than whatever is
  /// painted over it.
  bool reachable(WidgetTester tester, Finder f) {
    final target = tester.renderObject(f);
    final hit = tester.hitTestOnBinding(tester.getCenter(f));
    return hit.path.any((e) => e.target == target);
  }

  /// Opens [sheet] and checks it is laid over the shell, dock included: the
  /// dock is the same as before, and a tap where it is never reaches it.
  Future<Finder> open(WidgetTester tester, String sheet) async {
    final dock = glass(tester);
    await tester.tap(find.text('open:$sheet'));
    await settle(tester);

    final bottomSheet = find.byType(BottomSheet);
    expect(bottomSheet, findsOneWidget);
    expect(
      find.ancestor(of: bottomSheet, matching: find.byType(AppShell)),
      findsNothing,
      reason: 'presented over the shell, not inside it under the dock',
    );
    expect(find.byType(GlassBottomNav), findsOneWidget);
    expect(glass(tester), dock, reason: 'the dock itself is untouched');
    final nav = tester.renderObject(find.byType(GlassBottomNav));
    expect(
      tester.hitTestOnBinding(dock.center).path.any((e) => e.target == nav),
      isFalse,
      reason: 'a tap where the dock is lands on the sheet, not the dock',
    );
    return bottomSheet;
  }

  /// Scrolls whatever scrolls in [sheet] to its end.
  Future<void> scrollToEnd(WidgetTester tester, Finder sheet) async {
    final scrollable = find.descendant(
      of: sheet,
      matching: find.byType(Scrollable),
    );
    if (scrollable.evaluate().isEmpty) return;
    for (var i = 0; i < 3; i++) {
      await tester.drag(scrollable.first, const Offset(0, -2000));
      await settle(tester);
    }
  }

  const sizes = {'short phone': Size(360, 568), 'tall phone': Size(412, 915)};

  for (final MapEntry(key: phone, value: size) in sizes.entries) {
    for (final (sheet, last) in [
      ('city', find.text('مدينة 20')),
      ('specialties', find.text('تخصص 30')),
      ('filter', find.text('تطبيق')),
      ('language', find.text('English')),
      ('appearance', find.text('داكن')),
    ]) {
      testWidgets('$sheet sheet: over the dock, its last option reachable and '
          'clear of the system bar ($phone)', (tester) async {
        await pumpShell(tester, size);
        final bottomSheet = await open(tester, sheet);
        await scrollToEnd(tester, bottomSheet);

        // The whole tappable option, not just its label.
        final option = find.ancestor(
          of: last.last,
          matching: find.byType(InkWell),
        );
        expect(
          tester.getRect(option.first).bottom,
          lessThanOrEqualTo(size.height - _systemBar),
          reason: 'above the system navigation bar',
        );
        expect(reachable(tester, last.last), isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'booking sheet: opened from a Home card, it is over the dock too',
    (tester) async {
      await pumpShell(tester, sizes['short phone']!);
      final sheet = await open(tester, 'booking');

      // With the keyboard up (for the notes field) the sheet's content sits on
      // top of it. The keyboard covers the system bar, so that inset reads zero.
      const keyboard = 260.0;
      tester.view
        ..viewInsets = const FakeViewPadding(bottom: keyboard * 2)
        ..padding = FakeViewPadding.zero;
      await settle(tester);
      final content = find.descendant(
        of: sheet,
        matching: find.byType(DraggableScrollableSheet),
      );
      expect(
        tester.getRect(content).bottom,
        lessThanOrEqualTo(sizes['short phone']!.height - keyboard),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('with large text the choices scroll, the last one reachable', (
    tester,
  ) async {
    const size = Size(360, 568);
    await pumpShell(tester, size, textScale: 2);
    final sheet = await open(tester, 'appearance');
    expect(tester.takeException(), isNull, reason: 'no overflow');
    await scrollToEnd(tester, sheet);

    final last = find.text('داكن');
    final option = find.ancestor(of: last, matching: find.byType(InkWell));
    expect(
      tester.getRect(option.first).bottom,
      lessThanOrEqualTo(size.height - _systemBar),
    );
    expect(reachable(tester, last), isTrue);
  });

  testWidgets('the last city can be chosen, and the dock works after', (
    tester,
  ) async {
    await pumpShell(tester, sizes['short phone']!);
    final sheet = await open(tester, 'city');
    await scrollToEnd(tester, sheet);
    await tester.tap(find.text('مدينة 20'));
    await settle(tester);

    expect(container.read(homeCitySlugProvider), 'city-20');
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(GlassBottomNav),
        matching: find.text('حسابي'),
      ),
    );
    await settle(tester);
    expect(find.text('page:account'), findsOneWidget);
  });
}

import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/bookings/booking_detail_screen.dart';
import 'package:aleyada_mobile/features/bookings/bookings_screen.dart';
import 'package:aleyada_mobile/features/bookings/providers.dart';
import 'package:aleyada_mobile/features/doctors/widgets/doctor_card_tile.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/booking_fixtures.dart';
import '../fixtures/doctor_detail_fixtures.dart' as dd;
import '../fixtures/management_fixtures.dart';
import 'harness.dart';

/// A booking whose nested `doctor` carries the slug but no usable name or photo —
/// what made Booking Details show an empty "Doctor" row and a "؟" avatar.
Map<String, dynamic> nameless({
  required String id,
  required DateTime start,
  String status = 'confirmed',
  Object? name = '',
  Object? photo,
  Map<String, dynamic> extra = const {},
}) => patientBooking(
  id: id,
  start: start,
  status: status,
  overrides: {
    'doctor': {'slug': dd.slug, 'display_name': name, 'photo': photo, ...extra},
  },
);

void main() {
  late TestHarness h;
  late BookingsServer server;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    server = BookingsServer(h.dio);
    container = ProviderContainer(
      overrides: [...h.overrides, bookingsClockProvider.overrideWithValue(() => testNow)],
    );
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Locale locale = const Locale('ar'),
    Size size = const Size(390, 2400),
  }) async {
    await container
        .read(authControllerProvider.notifier)
        .adoptSession(
          const AuthTokens(access: 'a', refresh: 'r'),
          user: Me.fromJson(patientUser()),
        );
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => screen),
        GoRoute(path: Routes.doctors, builder: (_, __) => const Scaffold()),
        GoRoute(path: Routes.bookingDetail, builder: (_, __) => const Scaffold()),
        GoRoute(path: Routes.doctor, builder: (_, __) => const Scaffold()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
        ),
      ),
    );
    await settle(tester);
  }

  /// What an avatar shows: its letter, or its icon.
  Finder letter(String s) => find.descendant(of: find.byType(DoctorAvatar), matching: find.text(s));
  Finder personIcon() =>
      find.descendant(of: find.byType(DoctorAvatar), matching: find.byIcon(Icons.person_rounded));

  /// The address each avatar is loading its photo from.
  List<String> photoUrls(WidgetTester tester) => [
    for (final img in tester.widgetList<Image>(
      find.descendant(of: find.byType(DoctorAvatar), matching: find.byType(Image)),
    ))
      switch (img.image) {
        final ResizeImage r => (r.imageProvider as NetworkImage).url,
        final NetworkImage n => n.url,
        _ => 'not a network image',
      },
  ];

  const sara = 'د. سارة محمود'; // the public profile's display_name (fixture)
  final soon = DateTime.utc(2030, 1, 5, 7);
  final later = DateTime.utc(2030, 2, 1, 10);

  // ==========================================================================
  group('My bookings', () {
    setUp(() {
      // The next appointment (the hero card) and a later one (a list card), both
      // from a doctor whose booking payload has no name or photo.
      server.all = [
        nameless(id: 'next', start: soon),
        nameless(id: 'later', start: later, status: 'pending'),
      ];
    });

    testWidgets('the doctor\'s name comes from the profile when the booking has none', (
      tester,
    ) async {
      await pump(tester, const BookingsScreen());
      // Once on the featured card and once on the list card.
      expect(find.text(sara), findsNWidgets(2));
      expect(find.text('؟'), findsNothing, reason: 'no question-mark avatar');
      // The specialty still shows, from the same profile.
      expect(find.text('طب الأطفال'), findsWidgets);
    });

    testWidgets('each avatar shows the doctor\'s initial, not "?"', (tester) async {
      await pump(tester, const BookingsScreen());
      expect(find.byType(DoctorAvatar), findsNWidgets(2));
      expect(letter('د'), findsNWidgets(2));
      expect(personIcon(), findsNothing);
    });

    testWidgets('the profile\'s photo is used, as an absolute URL, when the booking has none', (
      tester,
    ) async {
      server.doctors = {
        dd.slug: dd.publicDoctor(overrides: {'photo': 'https://aleyada.test/media/sara.webp'}),
      };
      await pump(tester, const BookingsScreen());
      expect(photoUrls(tester), everyElement('https://aleyada.test/media/sara.webp'));
      expect(photoUrls(tester), hasLength(2));
    });

    testWidgets('a relative photo on the booking is resolved against the API host', (tester) async {
      server.all = [
        nameless(id: 'next', start: soon, photo: '/media/doctors/photos/sara.webp'),
        nameless(
          id: 'later',
          start: later,
          status: 'pending',
          photo: '/media/doctors/photos/sara.webp',
        ),
      ];
      await pump(tester, const BookingsScreen());
      expect(
        photoUrls(tester),
        everyElement('https://aleyada.scenariomnchnl.tech/media/doctors/photos/sara.webp'),
      );
    });

    testWidgets('a booking that carries its own name keeps it over the profile\'s', (tester) async {
      server.all = [
        nameless(id: 'next', start: soon, name: 'د. من الحجز'),
        nameless(id: 'later', start: later, status: 'pending', name: 'د. من الحجز'),
      ];
      await pump(tester, const BookingsScreen());
      expect(find.text('د. من الحجز'), findsNWidgets(2));
      expect(find.text(sara), findsNothing);
    });

    testWidgets('a name only in the Arabic field shows — in the English UI too', (tester) async {
      server.all = [
        nameless(id: 'next', start: soon, name: '', extra: {'full_name_ar': 'أحمد جمال'}),
        nameless(
          id: 'later',
          start: later,
          status: 'pending',
          name: null,
          extra: {'full_name_ar': 'أحمد جمال'},
        ),
      ];
      await pump(tester, const BookingsScreen(), locale: const Locale('en'));
      expect(
        find.text('أحمد جمال'),
        findsNWidgets(2),
        reason: 'Arabic-only, English UI: never blank',
      );
      expect(find.text('؟'), findsNothing);
    });

    testWidgets('when not even the profile has a name: a person icon, never "?"', (tester) async {
      server.doctors = {}; // the profile request fails (404)
      await pump(tester, const BookingsScreen());
      expect(find.text('؟'), findsNothing);
      expect(find.byType(DoctorAvatar), findsNWidgets(2));
      expect(personIcon(), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  // ==========================================================================
  group('Booking details', () {
    setUp(() {
      server.all = [nameless(id: 'b1', start: soon)];
    });

    testWidgets('the header and the "Doctor" row carry the name', (tester) async {
      await pump(tester, const BookingDetailScreen(id: 'b1'));

      // The header card and the Booking information row.
      expect(find.text(sara), findsNWidgets(2));
      expect(find.text('الطبيب'), findsOneWidget, reason: 'the row exists');
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('الطبيب'), matching: find.byType(Row)).first,
          matching: find.text(sara),
        ),
        findsOneWidget,
        reason: 'and its value is the name, not blank',
      );
      expect(find.text('؟'), findsNothing);
      expect(find.text('طب الأطفال'), findsWidgets, reason: 'specialty still shown');
    });

    testWidgets('the avatar shows the initial', (tester) async {
      await pump(tester, const BookingDetailScreen(id: 'b1'));
      expect(letter('د'), findsOneWidget);
      expect(personIcon(), findsNothing);
    });

    testWidgets('a relative photo on the booking is resolved', (tester) async {
      server.all = [nameless(id: 'b1', start: soon, photo: '/media/doctors/photos/sara.webp')];
      await pump(tester, const BookingDetailScreen(id: 'b1'));
      expect(photoUrls(tester), [
        'https://aleyada.scenariomnchnl.tech/media/doctors/photos/sara.webp',
      ]);
    });

    testWidgets('the profile\'s photo is the fallback', (tester) async {
      server.doctors = {
        dd.slug: dd.publicDoctor(overrides: {'photo': 'https://aleyada.test/media/sara.webp'}),
      };
      await pump(tester, const BookingDetailScreen(id: 'b1'));
      expect(photoUrls(tester), ['https://aleyada.test/media/sara.webp']);
    });

    testWidgets('Arabic-only name in the English UI is shown, in both places', (tester) async {
      server.all = [
        nameless(id: 'b1', start: soon, name: null, extra: {'full_name_ar': 'أحمد جمال'}),
      ];
      await pump(tester, const BookingDetailScreen(id: 'b1'), locale: const Locale('en'));
      expect(find.text('أحمد جمال'), findsNWidgets(2));
      expect(find.text('Doctor'), findsOneWidget);
    });

    testWidgets('with no name anywhere there is no empty "Doctor" row, and an icon avatar', (
      tester,
    ) async {
      server.doctors = {};
      await pump(tester, const BookingDetailScreen(id: 'b1'));
      expect(find.text('الطبيب'), findsNothing, reason: 'no row with a blank value');
      expect(find.text('؟'), findsNothing);
      expect(personIcon(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a named booking is unchanged', (tester) async {
      server.all = [patientBooking(id: 'b1', start: soon, doctorName: 'د. خالد')];
      await pump(tester, const BookingDetailScreen(id: 'b1'));
      expect(find.text('د. خالد'), findsNWidgets(2));
      expect(find.text(sara), findsNothing);
    });
  });
}

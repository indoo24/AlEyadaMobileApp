import 'package:aleyada_mobile/app/app.dart';
import 'package:aleyada_mobile/app/bottom_nav.dart';
import 'package:aleyada_mobile/app/locale_controller.dart';
import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/auth/guest_mode.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/features/auth/sign_in_screen.dart';
import 'package:aleyada_mobile/features/auth/sign_up_screen.dart';
import 'package:aleyada_mobile/features/doctors/doctor_detail_screen.dart';
import 'package:aleyada_mobile/features/home/home_screen.dart';
import 'package:aleyada_mobile/features/splash/al_eyada_splash.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/api_fixtures.dart';
import '../fixtures/management_fixtures.dart' show envelope, paged;
import 'harness.dart';

/// A patient with nothing left to accept.
final _patient = {...meResponseData, 'requires_reacceptance': <String>[]};

/// The backend, as far as launching and leaving the app touch it.
class _Server {
  _Server(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) {
          Response<dynamic> reply(Object? body, [int status = 200]) =>
              Response(requestOptions: o, statusCode: status, data: body);
          void reject(int status) => handler.reject(
            DioException.badResponse(
              statusCode: status,
              requestOptions: o,
              response: reply({
                'data': null,
                'meta': <String, dynamic>{},
                'errors': [
                  {'code': 'token_not_valid', 'detail': 'no', 'field': null},
                ],
              }, status),
            ),
            true,
          );

          calls.add(o.path);
          switch (o.path) {
            case '/auth/token/refresh/':
              if (!refreshValid) return reject(401);
              return handler.resolve(
                reply(envelope({'access': 'fresh', 'refresh': 'r2'})),
              );
            case '/auth/me/':
              if (meOffline) {
                return handler.reject(
                  DioException.connectionError(
                    requestOptions: o,
                    reason: 'offline',
                  ),
                  true,
                );
              }
              if (o.headers['Authorization'] != 'Bearer $validAccess') {
                return reject(401);
              }
              return handler.resolve(reply(envelope(_patient)));
            case '/auth/logout/':
              return handler.resolve(reply(envelope(null)));
            case '/specializations/':
              return handler.resolve(reply(specializationsResponse));
            case '/doctors/':
              return handler.resolve(reply(doctorListResponse));
            case '/clinics/':
            case '/articles/':
              return handler.resolve(reply(paged(const [])));
            case '/locations/cities/':
              return handler.resolve(reply(citiesResponse));
          }
          // Anything else a screen asks for on the way: an empty answer.
          return handler.resolve(reply(paged(const [])));
        },
      ),
    );
  }

  /// The access token `/auth/me/` accepts. The harness starts with `access`.
  String validAccess = 'access';
  bool refreshValid = true;
  bool meOffline = false;
  final calls = <String>[];
}

void main() {
  late TestHarness h;
  late _Server server;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
    // The launch splash's lock-up.
    final poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
    await poppins.load();
  });

  /// [refreshToken] is a session left on the device; [guest] a saved choice.
  void device({String? refreshToken, bool guest = false}) {
    SharedPreferences.setMockInitialValues({
      if (guest) GuestModeController.storageKey: true,
    });
    h = TestHarness(refreshToken: refreshToken);
    server = _Server(h.dio);
  }

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 10]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Launches the app as `main` does — the saved choices read first, the
  /// session restored in the background — and waits out the splash.
  Future<void> launch(
    WidgetTester tester, {
    Locale locale = const Locale('ar'),
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final guest = await GuestModeController.load();
    container = ProviderContainer(
      overrides: [
        ...h.overrides,
        preloadedGuestModeProvider.overrideWithValue(guest),
        preloadedLocaleProvider.overrideWithValue((locale: locale)),
      ],
    );
    container.read(authControllerProvider.notifier).restore();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AlEyadaApp(),
      ),
    );
    // 3.2s animation + 0.4s hold, then the route change.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await settle(tester);
    expect(find.byType(AlEyadaSplash), findsNothing);
  }

  String location() => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  Finder inDock(String label) => find.descendant(
    of: find.byType(GlassBottomNav),
    matching: find.text(label),
  );

  Future<bool?> savedGuest() async => (await SharedPreferences.getInstance())
      .getBool(GuestModeController.storageKey);

  group('launch', () {
    testWidgets('first launch: the welcome screen, with all three ways in', (
      tester,
    ) async {
      device();
      await launch(tester);

      expect(location(), Routes.signIn);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
      expect(find.text('إنشاء حساب'), findsOneWidget);
      expect(find.text('المتابعة كضيف'), findsOneWidget);
      // It is the root: nothing behind it to go back to.
      expect(find.byType(BackButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a session on the device opens Home directly', (tester) async {
      device(refreshToken: 'r');
      await launch(tester);

      expect(location(), Routes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    });

    testWidgets('an expired access token is refreshed, then Home', (
      tester,
    ) async {
      device(refreshToken: 'r');
      server.validAccess = 'fresh'; // `access` is refused; refreshing fixes it
      await launch(tester);

      expect(
        server.calls,
        containsAllInOrder(['/auth/me/', '/auth/token/refresh/', '/auth/me/']),
      );
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
      expect(h.store.accessToken, 'fresh');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a refresh token that is refused: back to the welcome screen', (
      tester,
    ) async {
      device(refreshToken: 'r');
      server
        ..validAccess = 'fresh'
        ..refreshValid = false;
      await launch(tester);

      expect(container.read(authControllerProvider).hasSession, isFalse);
      expect(
        h.store.refreshToken,
        isNull,
        reason: 'the dead session is cleared',
      );
      expect(location(), Routes.signIn);
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('offline at launch with a session: Home, never the welcome '
        'screen and never a guest', (tester) async {
      device(refreshToken: 'r');
      server.meOffline = true;
      await launch(tester);

      expect(container.read(authControllerProvider).hasSession, isTrue);
      expect(h.store.refreshToken, 'r', reason: 'a good session is kept');
      expect(container.read(guestModeProvider), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a returning guest goes straight to Home', (tester) async {
      device(guest: true);
      await launch(tester);

      expect(location(), Routes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(container.read(authControllerProvider).hasSession, isFalse);
    });
  });

  group('guest', () {
    testWidgets('continuing as a guest opens Home with no session, no tokens '
        'and no user', (tester) async {
      device();
      await launch(tester);
      await tap(tester, find.text('المتابعة كضيف'));

      expect(location(), Routes.home);
      expect(find.byType(HomeScreen), findsOneWidget);
      final auth = container.read(authControllerProvider);
      expect(auth.hasSession, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.user, isNull);
      expect(h.store.accessToken, isNull);
      expect(h.store.refreshToken, isNull);
      expect(container.read(guestModeProvider), isTrue);
      expect(await savedGuest(), isTrue);
      // Public content loads, without any authorisation.
      expect(server.calls, contains('/doctors/'));
      expect(server.calls, isNot(contains('/auth/token/refresh/')));
    });

    testWidgets('back from Home does not return to the welcome screen', (
      tester,
    ) async {
      device();
      await launch(tester);
      await tap(tester, find.text('المتابعة كضيف'));

      final handled = await tester.binding.handlePopRoute();
      await settle(tester);
      expect(handled, isFalse, reason: 'nothing beneath Home: the app closes');
      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a guest browses public pages freely', (tester) async {
      device(guest: true);
      await launch(tester);

      for (final tab in ['الأطباء', 'المفضلة', 'الرئيسية']) {
        await tap(tester, inDock(tab));
        expect(find.byType(SignInScreen), findsNothing, reason: tab);
      }
      container.read(routerProvider).push(Routes.doctorPath('dr-sample'));
      await settle(tester);
      expect(find.byType(DoctorDetailScreen), findsOneWidget);
      for (final path in [Routes.clinics, Routes.articles]) {
        container.read(routerProvider).go(path);
        await settle(tester);
        expect(location(), path);
      }
    });

    testWidgets('a protected tab says sign-in is required; back returns Home', (
      tester,
    ) async {
      device(guest: true);
      await launch(tester);
      await tap(tester, inDock('حجوزاتي'));

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(location(), '${Routes.signIn}?next=%2Fbookings');
      expect(find.text('تسجيل الدخول مطلوب'), findsOneWidget);
      expect(find.text('سجّل الدخول أو أنشئ حساباً للمتابعة.'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(location(), Routes.home);
      expect(container.read(authControllerProvider).hasSession, isFalse);
    });

    testWidgets('typing a protected address leads to sign-in, never the '
        'screen', (tester) async {
      device(guest: true);
      await launch(tester);
      for (final path in [
        Routes.account,
        Routes.bookings,
        Routes.notifications,
        Routes.editProfile,
        Routes.management,
        Routes.bookingPath('42'),
      ]) {
        container.read(routerProvider).go(path);
        await settle(tester);
        expect(location(), startsWith(Routes.signIn), reason: path);
        expect(find.byType(SignInScreen), findsOneWidget, reason: path);
      }
    });

    testWidgets('from that sign-in screen, "continue as guest" goes Home, '
        'not back to the protected page', (tester) async {
      device(guest: true);
      await launch(tester);
      await tap(tester, inDock('حسابي'));
      await tap(tester, find.text('المتابعة كضيف'));
      expect(location(), Routes.home);
    });

    testWidgets('signing in ends guest mode, and resumes where they were '
        'headed', (tester) async {
      device(guest: true);
      await launch(tester);
      await tap(tester, inDock('حجوزاتي'));

      // A session arrives (the form's own submit is covered elsewhere).
      h.store.save(access: 'access', refresh: 'r');
      final refreshed = container
          .read(authControllerProvider.notifier)
          .refreshUser();
      await settle(tester);
      await refreshed;
      await settle(tester);
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
      expect(container.read(guestModeProvider), isFalse);
      expect(await savedGuest(), isNull);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets('create account from the welcome screen, and back to it', (
      tester,
    ) async {
      device();
      await launch(tester);
      await tap(tester, find.text('إنشاء حساب'));
      expect(find.byType(SignUpScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('signing out', () {
    testWidgets('returns to the welcome screen, with no way back in', (
      tester,
    ) async {
      device(refreshToken: 'r');
      await launch(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      final signedOut = container
          .read(authControllerProvider.notifier)
          .signOut();
      await settle(tester);
      await signedOut;
      await settle(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(container.read(guestModeProvider), isFalse);
      expect(h.store.refreshToken, isNull);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('a session that expires mid-use: the welcome screen', (
      tester,
    ) async {
      device(refreshToken: 'r');
      await launch(tester);
      container.read(authControllerProvider.notifier).onSessionExpired();
      await settle(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('layout', () {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      testWidgets('${locale.languageCode}: small phone, large text, keyboard '
          'up — no overflow, and the guest action can be reached', (
        tester,
      ) async {
        device();
        await launch(
          tester,
          locale: locale,
          size: const Size(320, 568),
          textScale: 1.6,
        );
        final guest = locale.languageCode == 'ar'
            ? 'المتابعة كضيف'
            : 'Continue as guest';

        tester.view.viewInsets = const FakeViewPadding(bottom: 260 * 2);
        addTearDown(tester.view.resetViewInsets);
        await settle(tester);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.text(guest),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.getRect(find.text(guest)).bottom,
          lessThanOrEqualTo(568 - 260),
          reason: 'above the keyboard',
        );
        await tap(tester, find.text(guest));
        expect(location(), Routes.home);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('English reads left to right', (tester) async {
      device();
      await launch(tester, locale: const Locale('en'));
      expect(find.text('Continue as guest'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('Continue as guest'))),
        TextDirection.ltr,
      );
      await tap(tester, find.text('Create account'));
      expect(find.byType(SignUpScreen), findsOneWidget);
    });
  });
}

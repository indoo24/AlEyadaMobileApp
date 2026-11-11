import 'package:aleyada_mobile/app/app.dart';
import 'package:aleyada_mobile/core/auth/guest_mode.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/features/auth/sign_in_screen.dart';
import 'package:aleyada_mobile/features/home/home_screen.dart';
import 'package:aleyada_mobile/features/splash/al_eyada_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

void main() {
  testWidgets('the splash outlasts a fast restore, then hands over to the app', (tester) async {
    // Nothing saved; and, unlike `main`, nothing preloaded: the guest choice is
    // read while the splash plays.
    SharedPreferences.setMockInitialValues({});
    final h = TestHarness(); // no tokens: restore settles to signed-out at once
    final container = ProviderContainer(overrides: h.overrides);
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restore();
    expect(container.read(authControllerProvider).isRestoring, isFalse);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AlEyadaApp()),
    );
    await tester.pump(const Duration(seconds: 1));

    // Restore is long done, but the animation is not.
    expect(find.byType(AlEyadaSplash), findsOneWidget);

    // 3.2s animation + 0.4s hold.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(); // router rebuilds
    await tester.pump(const Duration(seconds: 1)); // route transition

    expect(find.byType(AlEyadaSplash), findsNothing);
    // No session and no guest choice: the welcome screen, not Home.
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('a returning guest\'s saved choice is waited for, then Home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      GuestModeController.storageKey: true,
    });
    final h = TestHarness();
    final container = ProviderContainer(overrides: h.overrides);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.notifier).restore();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AlEyadaApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AlEyadaSplash), findsNothing);
    expect(
      find.byType(SignInScreen),
      findsNothing,
      reason: 'never shown by mistake',
    );
    expect(find.byType(HomeScreen), findsOneWidget);

    // Home starts its own requests on arrival; let them finish so no timer is
    // left pending when the test ends.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  });
}

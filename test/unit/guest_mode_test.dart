import 'package:aleyada_mobile/core/auth/auth_controller.dart';
import 'package:aleyada_mobile/core/auth/guest_mode.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widget/harness.dart';

Future<bool?> saved() async => (await SharedPreferences.getInstance()).getBool(
  GuestModeController.storageKey,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing saved: not a guest', () async {
    expect(await GuestModeController.load(), isFalse);
  });

  test('choosing guest is saved; leaving removes it', () async {
    final c = GuestModeController(initial: false);
    await c.enter();
    expect(c.state, isTrue);
    expect(await saved(), isTrue);
    expect(await GuestModeController.load(), isTrue);

    await c.leave();
    expect(c.state, isFalse);
    expect(await saved(), isNull);
  });

  test(
    'without a preload it reads the saved choice, starting unknown',
    () async {
      SharedPreferences.setMockInitialValues({
        GuestModeController.storageKey: true,
      });
      final c = GuestModeController();
      expect(c.state, isNull, reason: 'the splash waits on this');
      await pumpEventQueue();
      expect(c.state, isTrue);
    },
  );

  test('a choice made while the disk was answering is not undone', () async {
    SharedPreferences.setMockInitialValues({
      GuestModeController.storageKey: true,
    });
    final c = GuestModeController();
    await c.leave();
    await pumpEventQueue();
    expect(c.state, isFalse);
  });

  test(
    'a real session ends guest mode, and never touches the tokens',
    () async {
      SharedPreferences.setMockInitialValues({
        GuestModeController.storageKey: true,
      });
      final h = TestHarness();
      final container = ProviderContainer(
        overrides: [
          ...h.overrides,
          preloadedGuestModeProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(guestModeProvider), isTrue);
      expect(h.store.refreshToken, isNull, reason: 'a guest has no tokens');

      container.read(authControllerProvider.notifier).state = const AuthState(
        status: AuthStatus.offlineWithSession,
      );
      await pumpEventQueue();
      expect(container.read(guestModeProvider), isFalse);
      expect(await saved(), isNull);
    },
  );

  test('signing out does not make anyone a guest', () async {
    final h = TestHarness();
    final container = ProviderContainer(
      overrides: [
        ...h.overrides,
        preloadedGuestModeProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    container.read(guestModeProvider);
    container.read(authControllerProvider.notifier).state = const AuthState(
      status: AuthStatus.authenticated,
    );
    container.read(authControllerProvider.notifier).state =
        const AuthState.signedOut();
    await pumpEventQueue();
    expect(container.read(guestModeProvider), isFalse);
  });
}

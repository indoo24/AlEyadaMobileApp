import 'package:aleyada_mobile/app/app.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/features/splash/al_eyada_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  testWidgets('the splash outlasts a fast restore, then hands over to the app', (tester) async {
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
  });
}

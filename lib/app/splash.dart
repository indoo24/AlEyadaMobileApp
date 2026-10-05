import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/splash/al_eyada_splash.dart';

/// Whether the launch animation has finished playing.
///
/// The router leaves the splash only when this *and* session restoration are
/// both done, so the animation and the startup work run in parallel and the app
/// waits for whichever is slower.
final splashAnimationDoneProvider = StateProvider<bool>((ref) => false);

/// The first screen. Plays the animated logo while the session is restored
/// (see `main.dart`).
///
/// This screen never navigates itself. When the animation ends it flips
/// [splashAnimationDoneProvider]; the router's redirect then replaces `/splash`
/// with wherever the user belongs, which is also what keeps the splash out of
/// the back stack.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The splash is dark navy edge to edge: light status-bar icons.
      value: SystemUiOverlayStyle.light,
      child: AlEyadaSplash(
        onFinished: () => ref.read(splashAnimationDoneProvider.notifier).state = true,
      ),
    );
  }
}

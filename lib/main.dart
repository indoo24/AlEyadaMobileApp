import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Start restoring the session before the first frame. The router holds on the
  // splash until this settles, so nothing flashes a sign-in screen at a user who
  // is already signed in.
  container.read(authControllerProvider.notifier).restore();

  runApp(UncontrolledProviderScope(container: container, child: const AlEyadaApp()));
}

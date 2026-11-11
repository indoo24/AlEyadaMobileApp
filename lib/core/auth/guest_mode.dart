import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';

/// Whether the person chose to look around without an account.
///
/// This is a navigation choice, not a session: it holds no tokens, never touches
/// the token store, and never makes anyone authenticated. The router reads it
/// only when there is no session at all — a signed-in user, or one whose
/// session is merely unconfirmed because the network is down, is never treated
/// as a guest because of it.
///
/// It survives a restart (a guest who comes back lands on Home, not on the
/// welcome screen again), so it is kept in SharedPreferences like the other
/// display preferences. It is forgotten the moment a real session exists, so
/// signing out — or a session that expires — leads back to the welcome screen.
///
/// The state is null until the saved choice has been read; the splash waits for
/// it so a returning guest is never shown the welcome screen by mistake.
class GuestModeController extends StateNotifier<bool?> {
  GuestModeController({bool? initial}) : super(initial) {
    if (initial == null) _restore();
  }

  static const storageKey = 'aleyada.guest_mode';

  /// The saved choice, read once at launch. Never throws.
  static Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(storageKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _restore() async {
    final saved = await load();
    // A choice made while the disk was still answering wins.
    if (mounted && state == null) state = saved;
  }

  /// Continue as a guest.
  Future<void> enter() => _set(true);

  /// Stop being a guest: a session now exists.
  Future<void> leave() => _set(false);

  Future<void> _set(bool guest) async {
    state = guest;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (guest) {
        await prefs.setBool(storageKey, true);
      } else {
        await prefs.remove(storageKey);
      }
    } catch (_) {
      // The choice applies to this run regardless.
    }
  }
}

/// The choice read at launch, or null when nothing was preloaded.
final preloadedGuestModeProvider = Provider<bool?>((ref) => null);

final guestModeProvider = StateNotifierProvider<GuestModeController, bool?>((
  ref,
) {
  final controller = GuestModeController(
    initial: ref.watch(preloadedGuestModeProvider),
  );
  // A real session ends guest mode, however it arrived — sign-in, sign-up's
  // phone verification, or a restored session.
  ref.listen<bool>(authControllerProvider.select((s) => s.hasSession), (
    _,
    hasSession,
  ) {
    if (hasSession) controller.leave();
  }, fireImmediately: true);
  return controller;
});

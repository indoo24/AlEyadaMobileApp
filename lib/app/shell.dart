import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../l10n/app_localizations.dart';
import 'bottom_nav.dart';
import 'router.dart';

/// The tabbed frame.
///
/// The tabs a user gets depend on their role, the same way the website's do:
/// a patient browses and tracks bookings; an approved doctor gets their practice
/// instead. Route guards enforce this too — the bar only decides what is
/// *offered*, never what is *permitted*.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final isDoctor = user?.isActiveDoctor ?? false;

    final tabs = <_Tab>[
      _Tab(Routes.home, Icons.home_outlined, Icons.home_rounded, l.navHome),
      _Tab(Routes.doctors, Icons.search_outlined, Icons.search_rounded, l.navDoctors),
      if (isDoctor)
        _Tab(Routes.practice, Icons.event_note_outlined, Icons.event_note_rounded, l.navSchedule)
      else
        _Tab(
          Routes.bookings,
          Icons.calendar_today_outlined,
          Icons.calendar_today_rounded,
          l.navBookings,
        ),
      _Tab(Routes.account, Icons.person_outline_rounded, Icons.person_rounded, l.navAccount),
    ];

    final location = GoRouterState.of(context).matchedLocation;
    var index = tabs.indexWhere((t) => t.path == location);
    if (index < 0) index = 0;

    return Scaffold(
      // The dock floats over Home's feed (which pads itself to clear it). The
      // other tabs have their own Scaffolds and list padding, so for them the
      // dock keeps a strip of its own rather than covering their last rows.
      extendBody: location == Routes.home,
      body: child,
      bottomNavigationBar: GlassBottomNav(
        selectedIndex: index,
        onSelected: (i) {
          final target = tabs[i].path;
          if (target != location) context.go(target);
        },
        items: [
          for (final t in tabs)
            BottomNavItem(icon: t.icon, activeIcon: t.activeIcon, label: t.label),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab(this.path, this.icon, this.activeIcon, this.label);

  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

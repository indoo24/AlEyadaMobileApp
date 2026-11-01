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
/// a patient browses and tracks bookings; an approved doctor gets management
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
      // An approved doctor manages their practice here; everyone else tracks
      // their own appointments. The role comes from the backend, via the auth state.
      if (isDoctor)
        _Tab(
          Routes.management,
          Icons.space_dashboard_outlined,
          Icons.space_dashboard_rounded,
          l.navManagement,
        )
      else
        _Tab(
          Routes.bookings,
          Icons.calendar_today_outlined,
          Icons.calendar_today_rounded,
          l.navBookings,
        ),
      // Public: a guest keeps a favourites list of their own on this device.
      _Tab(Routes.favorites, Icons.favorite_border_rounded, Icons.favorite_rounded, l.navFavorites),
      _Tab(Routes.account, Icons.person_outline_rounded, Icons.person_rounded, l.navAccount),
    ];

    final location = GoRouterState.of(context).matchedLocation;
    var index = tabs.indexWhere((t) => t.path == location);
    if (index < 0) index = 0;

    return Scaffold(
      // Every tab runs under the dock, so it is the same floating glass over
      // each page's own content, not over a solid strip of the shell. The
      // Scaffold then reports the dock's height as the body's bottom padding, and
      // each tab adds that to the end of its scrolling content
      // (`MediaQuery.paddingOf(context).bottom`) so its last row can scroll clear.
      extendBody: true,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../l10n/app_localizations.dart';
import 'providers.dart';
import 'widgets/booking_tile.dart';

/// The patient's appointments, split upcoming/past by the **server's** scope
/// filter rather than by comparing timestamps on the phone.
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final tab = ref.watch(bookingsTabProvider);
    final bookings = ref.watch(myBookingsProvider(tab));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.bookingsTitle),
        bottom: TabBar(
          // A controller-free TabBar driven by the provider, so the selection
          // survives navigating away and back.
          controller: null,
          onTap: (i) => ref.read(bookingsTabProvider.notifier).state = i == 0
              ? BookingsTab.upcoming
              : BookingsTab.past,
          tabs: [
            Tab(text: l.bookingsUpcoming),
            Tab(text: l.bookingsPast),
          ],
        ),
      ),
      body: DefaultTabController(
        length: 2,
        initialIndex: tab == BookingsTab.upcoming ? 0 : 1,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(myBookingsProvider(tab)),
          child: AsyncValueView(
            value: bookings,
            loading: const SkeletonList(itemHeight: 130),
            onRetry: () => ref.invalidate(myBookingsProvider(tab)),
            isEmpty: (page) => page.isEmpty,
            empty: AppEmptyView(
              icon: Icons.event_available_outlined,
              title: l.bookingsEmpty,
              hint: l.bookingsEmptyHint,
              action: OutlinedButton(
                onPressed: () => context.go(Routes.doctors),
                child: Text(l.navDoctors),
              ),
            ),
            data: (page) => ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final b = page.items[i];
                return BookingTile(booking: b, onTap: () => context.push(Routes.bookingPath(b.id)));
              },
            ),
          ),
        ),
      ),
    );
  }
}

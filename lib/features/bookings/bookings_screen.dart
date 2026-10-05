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
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen>
    with SingleTickerProviderStateMixin {
  // [bookingsTabProvider] owns the selection, so it survives navigating away
  // and back; this controller only mirrors it for the TabBar. There is no
  // TabBarView — the body is one list re-queried per tab — so a
  // DefaultTabController would be a second, unsynchronised owner.
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: BookingsTab.values.length,
      initialIndex: ref.read(bookingsTabProvider).index,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tab = ref.watch(bookingsTabProvider);
    final bookings = ref.watch(myBookingsProvider(tab));

    // Follow the provider if anything other than a tap moves it.
    ref.listen(bookingsTabProvider, (_, next) {
      if (_tabs.index != next.index) _tabs.animateTo(next.index);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l.bookingsTitle),
        bottom: TabBar(
          controller: _tabs,
          onTap: (i) => ref.read(bookingsTabProvider.notifier).state = BookingsTab.values[i],
          tabs: [
            Tab(text: l.bookingsUpcoming),
            Tab(text: l.bookingsPast),
          ],
        ),
      ),
      body: RefreshIndicator(
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
    );
  }
}

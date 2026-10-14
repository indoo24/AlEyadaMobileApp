import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_style.dart';
import 'models.dart';
import 'providers.dart';
import 'widgets/booking_tile.dart';
import '../../core/theme/app_palette.dart';

/// The patient's appointments: upcoming, past and cancelled.
///
/// All three sections come from one list (`myBookingsProvider`), split by each
/// booking's own server-reported status — so switching sections is instant and
/// asks nothing of the server, and a pull-to-refresh is one reload that keeps
/// the section the patient was looking at.
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(bookingsTabProvider);
    final groups = ref.watch(bookingGroupsProvider);
    final counts = groups.valueOrNull;

    return Scaffold(
      backgroundColor: context.palette.page,
      body: Column(
        children: [
          _Header(
            selected: tab,
            counts: counts == null
                ? null
                : {for (final t in BookingsTab.values) t: counts.of(t).length},
            onSelect: (t) => ref.read(bookingsTabProvider.notifier).state = t,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              child: groups.when(
                // A refresh keeps the list on screen; only the first load shows
                // placeholders.
                skipLoadingOnRefresh: true,
                loading: () => const _LoadingList(key: ValueKey('loading')),
                error: (e, _) => _ErrorState(
                  key: const ValueKey('error'),
                  error: e,
                  onRetry: () => ref.invalidate(myBookingsProvider),
                ),
                data: (g) => RefreshIndicator(
                  key: const ValueKey('data'),
                  onRefresh: () => ref.refresh(myBookingsProvider.future),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.02),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _Section(
                      key: ValueKey(tab),
                      tab: tab,
                      bookings: g.of(tab),
                      nowUtc: ref.watch(bookingsClockProvider)(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.selected, required this.counts, required this.onSelect});

  final BookingsTab selected;
  final Map<BookingsTab, int>? counts;
  final ValueChanged<BookingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.surface,
        boxShadow: context.palette.shadowSoft,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 14, AppSpacing.gutter, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: context.palette.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.bookingsTitle,
                        style: context.homeType.sectionTitle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(l.mbSubtitle, style: context.homeType.tagline),
              const SizedBox(height: 12),
              _SegmentedTabs(selected: selected, counts: counts, onSelect: onSelect),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three segments with a sliding indicator. The indicator is positioned with
/// directional alignment, so it starts on the right in Arabic and on the left in
/// English without any special-casing.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.counts, required this.onSelect});

  final BookingsTab selected;
  final Map<BookingsTab, int>? counts;
  final ValueChanged<BookingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final labels = {
      BookingsTab.upcoming: l.bookingsUpcoming,
      BookingsTab.past: l.bookingsPast,
      BookingsTab.cancelled: l.mbTabCancelled,
    };
    const n = 3;
    final x = -1.0 + 2.0 * selected.index / (n - 1);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.page,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional(x, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: context.palette.shadowCard,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final t in BookingsTab.values)
                Expanded(
                  child: _Segment(
                    label: labels[t]!,
                    count: counts?[t],
                    selected: t == selected,
                    onTap: () => onSelect(t),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? context.palette.primary : context.palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label ($count)',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      // Merged onto the inherited style: this widget *replaces*
                      // the default text style, and on its own would drop the
                      // app's font family.
                      style: DefaultTextStyle.of(context).style
                          .merge(context.homeType.chip)
                          .copyWith(
                            fontSize: 13.5,
                            color: fg,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                      child: Text(label, maxLines: 1),
                    ),
                    if (count != null && count! > 0) ...[
                      const SizedBox(width: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: selected ? context.palette.primary : context.palette.border,
                          borderRadius: AppRadii.pillRadius,
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : context.palette.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One section's list, or its empty state.
class _Section extends StatelessWidget {
  const _Section({super.key, required this.tab, required this.bookings, required this.nowUtc});

  final BookingsTab tab;
  final List<PatientBooking> bookings;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return _EmptyState(tab: tab);

    final l = L.of(context);
    void open(PatientBooking b) => context.push(Routes.bookingPath(b.id));
    final featured = tab == BookingsTab.upcoming ? bookings.first : null;
    final rest = featured == null ? bookings : bookings.skip(1).toList();

    final items = <Widget>[
      if (featured != null)
        NextBookingCard(booking: featured, nowUtc: nowUtc, onOpen: () => open(featured)),
      if (featured != null && rest.isNotEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
          child: Text(
            l.mbMoreUpcoming,
            style: context.homeType.sectionTitle.copyWith(fontSize: 15),
          ),
        ),
      for (final b in rest) BookingTile(booking: b, onTap: () => open(b)),
    ];

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 16, AppSpacing.gutter, 28),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _Appear(index: i, child: items[i]),
    );
  }
}

/// A quick fade-and-rise for cards as a section first shows.
class _Appear extends StatelessWidget {
  const _Appear({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 180 + 40 * index.clamp(0, 5)),
    curve: Curves.easeOut,
    builder: (_, t, c) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: c),
    ),
    child: child,
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList({super.key});

  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 16, AppSpacing.gutter, 28),
    itemCount: 3,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (_, __) => const BookingCardSkeleton(),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});

  final BookingsTab tab;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final (icon, title, body) = switch (tab) {
      BookingsTab.upcoming => (
        Icons.event_available_outlined,
        l.mbEmptyUpcomingTitle,
        l.mbEmptyUpcomingBody,
      ),
      BookingsTab.past => (Icons.history_rounded, l.mbEmptyPastTitle, l.mbEmptyPastBody),
      BookingsTab.cancelled => (
        Icons.event_busy_outlined,
        l.mbEmptyCancelledTitle,
        l.mbEmptyCancelledBody,
      ),
    };
    return _Centered(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: context.palette.pageSoft, shape: BoxShape.circle),
          child: Icon(icon, size: 38, color: context.palette.primary),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: context.homeType.sectionTitle),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: context.homeType.articleBody.copyWith(fontSize: 13),
        ),
        if (tab != BookingsTab.cancelled) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.go(Routes.doctors),
            icon: const Icon(Icons.search_rounded, size: 20),
            label: Text(l.mbFindDoctor),
            style: FilledButton.styleFrom(
              minimumSize: const Size(180, 48),
              textStyle: context.homeType.button.copyWith(fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final offline = error is ApiException && (error as ApiException).isNetworkFailure;
    return _Centered(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: context.palette.toneDanger.bg, shape: BoxShape.circle),
          child: Icon(
            offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
            size: 36,
            color: context.palette.toneDanger.fg,
          ),
        ),
        const SizedBox(height: 16),
        Text(l.mbErrorTitle, textAlign: TextAlign.center, style: context.homeType.sectionTitle),
        const SizedBox(height: 6),
        Text(
          // Never the server's raw wording: a fixed, friendly sentence.
          offline ? l.mbOfflineBody : l.mbErrorBody,
          textAlign: TextAlign.center,
          style: context.homeType.articleBody.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          label: Text(l.actionRetry),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(160, 48),
            textStyle: context.homeType.button.copyWith(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// A centred column that still scrolls — so pull-to-refresh works on empty and
/// error states, and large text never overflows a short screen.
class _Centered extends StatelessWidget {
  const _Centered({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: children),
        ),
      ),
    ),
  );
}

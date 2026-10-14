import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/api/api_error.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_style.dart';
import 'notification_kinds.dart';
import 'notifications_data.dart';
import '../../core/theme/app_palette.dart';

export 'notifications_data.dart';

/// The day group a notification falls in, by the *device's* calendar — these
/// are the reader's own "today" and "yesterday", when they received it.
enum NotificationDay { today, yesterday, earlier }

NotificationDay dayOf(DateTime? utc, DateTime now) {
  if (utc == null) return NotificationDay.earlier;
  final local = utc.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return NotificationDay.today;
  if (day == today.subtract(const Duration(days: 1))) return NotificationDay.yesterday;
  return NotificationDay.earlier;
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    Future<void> markAll() async {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await controller.markAllRead();
      if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.ntUpdateFailed)));
    }

    Widget body;
    if (state.loading) {
      body = const _Skeleton(key: ValueKey('loading'));
    } else if (state.error != null) {
      body = _Message(
        key: const ValueKey('error'),
        icon: state.error is ApiException && (state.error as ApiException).isNetworkFailure
            ? Icons.wifi_off_rounded
            : Icons.cloud_off_rounded,
        title: l.ntErrorTitle,
        body: state.error is ApiException && (state.error as ApiException).isNetworkFailure
            ? l.ntOffline
            : l.ntErrorBody,
        action: OutlinedButton.icon(
          onPressed: controller.reload,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          label: Text(l.actionRetry),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(160, 48),
            textStyle: context.homeType.button.copyWith(fontSize: 14),
          ),
        ),
      );
    } else if (state.items.isEmpty) {
      body = _Message(
        key: const ValueKey('empty'),
        icon: Icons.notifications_none_rounded,
        title: l.ntEmptyTitle,
        body: l.ntEmptyBody,
      );
    } else {
      body = _List(key: const ValueKey('list'), state: state, unread: unread);
    }

    return Scaffold(
      backgroundColor: context.palette.page,
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        backgroundColor: context.palette.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (state.hasUnread)
            TextButton(
              onPressed: markAll,
              style: TextButton.styleFrom(
                textStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l.notificationsMarkAllRead),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final messenger = ScaffoldMessenger.of(context);
          ref.invalidate(unreadCountProvider);
          final ok = await controller.reload();
          if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.ntRefreshFailed)));
        },
        child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: body),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({super.key, required this.state, required this.unread});

  final NotificationsState state;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final now = DateTime.now();
    final groups = <NotificationDay, List<AppNotification>>{};
    for (final n in state.items) {
      groups.putIfAbsent(dayOf(n.createdAt, now), () => []).add(n);
    }
    String title(NotificationDay d) => switch (d) {
      NotificationDay.today => l.ntToday,
      NotificationDay.yesterday => l.ntYesterday,
      NotificationDay.earlier => l.ntEarlier,
    };

    final children = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
        child: Text(
          unread > 0 ? l.ntUnreadCount(unread) : l.ntAllRead,
          style: context.homeType.meta.copyWith(fontSize: 12.5),
        ),
      ),
      for (final d in NotificationDay.values)
        if (groups[d] != null) _Group(title: title(d), items: groups[d]!),
      if (state.hasMore || state.moreError != null)
        Center(
          child: TextButton(
            onPressed: state.loadingMore
                ? null
                : () => ref.read(notificationsControllerProvider.notifier).loadMore(),
            child: state.loadingMore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(state.moreError != null ? l.actionRetry : l.ntLoadOlder),
          ),
        ),
    ];

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 14, AppSpacing.gutter, 28),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => children[i],
    );
  }
}

/// One day's notifications on a single surface, divided — not a card each.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.items});

  final String title;
  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Semantics(
          header: true,
          child: Text(title, style: context.homeType.sectionTitle.copyWith(fontSize: 14.5)),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(homeCardRadius),
          boxShadow: context.palette.shadowSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, indent: 68, color: context.palette.border),
                NotificationTile(notification: items[i]),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

/// One notification: a type icon, the title (bolder while unread), the body,
/// and when it arrived. Unread is also a dot and a spoken "unread" — never
/// colour alone.
class NotificationTile extends ConsumerWidget {
  const NotificationTile({super.key, required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final n = notification;
    final style = notificationStyle(n.type, palette: context.palette);
    final user = ref.watch(currentUserProvider);
    final destination = notificationDestination(n, user);
    final when = _timeLabel(context, n.createdAt);

    Future<void> open() async {
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      if (!n.isRead) {
        final ok = await ref.read(notificationsControllerProvider.notifier).markRead(n.id);
        if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.ntUpdateFailed)));
      }
      if (destination != null) router.push(destination);
    }

    return Semantics(
      // Its own node: each notification is announced on its own, not folded
      // into the day heading above it.
      container: true,
      button: destination != null || !n.isRead,
      label: [
        if (!n.isRead) l.ntUnread,
        n.title,
        n.body,
        ?when,
      ].where((s) => s.isNotEmpty).join('، '),
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        color: n.isRead ? Colors.transparent : context.palette.primary.withValues(alpha: 0.04),
        child: InkWell(
          onTap: destination != null || !n.isRead ? open : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: style.bg, shape: BoxShape.circle),
                  child: Icon(style.icon, size: 20, color: style.fg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: context.homeType.cardTitle.copyWith(
                                fontSize: 14,
                                fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                                color: n.isRead ? context.palette.body : context.palette.heading,
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: n.isRead ? 0 : 1,
                            child: Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsetsDirectional.only(start: 8, top: 6),
                              decoration: BoxDecoration(
                                color: context.palette.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (n.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          n.body,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: context.palette.body, height: 1.55),
                        ),
                      ],
                      if (when != null) ...[
                        const SizedBox(height: 4),
                        Text(when, style: context.homeType.meta.copyWith(fontSize: 11.5)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "14:05" today; "10 أكتوبر • 14:05" otherwise — in the device's time, since
  /// it is when *this reader* was told. Western digits, like the rest of the app.
  static String? _timeLabel(BuildContext context, DateTime? utc) {
    if (utc == null) return null;
    final d = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(d.hour)}:${two(d.minute)}';
    if (dayOf(utc, DateTime.now()) == NotificationDay.today) return time;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.now();
    final month = DateFormat.MMMM(locale).format(d);
    final date = d.year == now.year ? '${d.day} $month' : '${d.day} $month ${d.year}';
    return '$date  •  $time';
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 14, AppSpacing.gutter, 28),
    children: [
      const Skeleton(height: 12, width: 120),
      const SizedBox(height: 18),
      const Skeleton(height: 14, width: 60),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(homeCardRadius),
        ),
        child: Column(
          children: [
            for (var i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 40, width: 40, radius: 20),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(height: 13, width: 140),
                          SizedBox(height: 8),
                          Skeleton(height: 11),
                          SizedBox(height: 6),
                          Skeleton(height: 10, width: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

/// Empty and error states: centred, compact, and still scrollable so
/// pull-to-refresh works on them.
class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ),
    ),
  );
}

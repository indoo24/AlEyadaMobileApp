import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/envelope.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../l10n/app_localizations.dart';

/// An in-app notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: parseString(j['id']),
    title: parseString(j['title'] ?? j['title_ar']),
    body: parseString(j['body'] ?? j['body_ar'] ?? j['message']),
    isRead: j['is_read'] == true || j['read_at'] != null,
    createdAt: parseUtc(j['created_at']),
  );
}

class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  Future<Paginated<AppNotification>> list({int page = 1}) async => unwrapPaginated(
    await _api.get(Endpoints.notifications, query: {'page': page}),
    AppNotification.fromJson,
  );

  Future<int> unreadCount() async {
    final data = unwrapObjectOrNull(await _api.get(Endpoints.notificationsUnreadCount));
    return parseInt(data?['count'] ?? data?['unread']) ?? 0;
  }

  Future<void> markRead(String id) => _api.post(Endpoints.notificationRead(id));

  Future<void> markAllRead() => _api.post(Endpoints.notificationsReadAll);

  /// Register this device for push.
  ///
  /// The endpoint exists and accepts tokens, but no sender is configured on the
  /// server, so nothing is called here yet — wiring a token provider in without
  /// a sender would just collect dead tokens. See PUSH NOTIFICATIONS in the README.
  Future<void> registerDevice({required String token, required String platform}) =>
      _api.post(Endpoints.notificationDevices, body: {'token': token, 'platform': platform});
}

final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);

final notificationsProvider = FutureProvider<Paginated<AppNotification>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(notificationRepositoryProvider).list();
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  ref.watch(authControllerProvider);
  try {
    return await ref.watch(notificationRepositoryProvider).unreadCount();
  } catch (_) {
    // A badge is not worth an error state.
    return 0;
  }
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final items = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [
          if ((items.valueOrNull?.items.any((n) => !n.isRead)) ?? false)
            TextButton(
              onPressed: () async {
                await ref.read(notificationRepositoryProvider).markAllRead();
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadCountProvider);
              },
              child: Text(l.notificationsMarkAllRead),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: AsyncValueView(
          value: items,
          loading: const SkeletonList(itemHeight: 84),
          onRetry: () => ref.invalidate(notificationsProvider),
          isEmpty: (p) => p.isEmpty,
          empty: AppEmptyView(icon: Icons.notifications_off_outlined, title: l.notificationsEmpty),
          data: (page) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            itemCount: page.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final n = page.items[i];
              return Card(
                color: n.isRead ? AppColors.surface : AppColors.bgSoft,
                child: ListTile(
                  leading: Icon(
                    n.isRead
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_active_rounded,
                    color: n.isRead ? AppColors.muted : AppColors.primary,
                  ),
                  title: Text(n.title, style: Theme.of(context).textTheme.titleSmall),
                  subtitle: n.body.isEmpty
                      ? null
                      : Text(n.body, style: Theme.of(context).textTheme.bodySmall),
                  onTap: n.isRead
                      ? null
                      : () async {
                          await ref.read(notificationRepositoryProvider).markRead(n.id);
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(unreadCountProvider);
                        },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

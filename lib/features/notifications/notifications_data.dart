import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/envelope.dart';
import '../../core/providers.dart';

/// An in-app notification — the spec's `Notification`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    this.type = '',
    this.bookingId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;

  /// `NotificationEventEnum`, e.g. `booking_confirmed`. Empty if absent.
  final String type;

  /// The booking it is about, when it is about one.
  final String? bookingId;
  final DateTime? createdAt;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    body: body,
    isRead: isRead ?? this.isRead,
    type: type,
    bookingId: bookingId,
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final booking = parseString(j['booking']).trim();
    return AppNotification(
      id: parseString(j['id']),
      title: parseString(j['title'] ?? j['title_ar']).trim(),
      body: parseString(j['body'] ?? j['body_ar'] ?? j['message']).trim(),
      isRead: j['is_read'] == true || j['read_at'] != null,
      type: parseString(j['type']).trim(),
      bookingId: booking.isEmpty ? null : booking,
      createdAt: parseUtc(j['created_at']),
    );
  }
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

/// The bell's badge: the backend's own cheap count.
final unreadCountProvider = FutureProvider<int>((ref) async {
  ref.watch(authControllerProvider);
  try {
    return await ref.watch(notificationRepositoryProvider).unreadCount();
  } catch (_) {
    // A badge is not worth an error state.
    return 0;
  }
});

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.moreError,
  });

  final List<AppNotification> items;
  final int page;
  final bool hasMore;

  /// The first page is on its way and nothing is shown yet.
  final bool loading;
  final bool loadingMore;

  /// The first page failed.
  final Object? error;

  /// A further page failed; what is loaded stays.
  final Object? moreError;

  bool get hasUnread => items.any((n) => !n.isRead);

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    Object? error = _keep,
    Object? moreError = _keep,
  }) => NotificationsState(
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: identical(error, _keep) ? this.error : error,
    moreError: identical(moreError, _keep) ? this.moreError : moreError,
  );

  static const _keep = Object();
}

/// The notification list, a page at a time.
///
/// Reading one or all marks them in place — the list is not refetched for a
/// change the app already knows the outcome of — and only the bell's count is
/// re-asked. A failed mark is put back.
class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._repo, this._onUnreadChanged)
    : super(const NotificationsState(loading: true)) {
    reload();
  }

  final NotificationRepository _repo;
  final void Function() _onUnreadChanged;

  /// Bumped by each reload so an older answer is dropped.
  int _generation = 0;

  /// Reload the first page. A refresh keeps the current list on screen until
  /// the new one arrives — and keeps it if the refresh fails. Returns whether it
  /// succeeded, so a pull-to-refresh can say so.
  Future<bool> reload() async {
    final gen = ++_generation;
    if (state.items.isEmpty) state = const NotificationsState(loading: true);
    try {
      final page = await _repo.list();
      if (!mounted || gen != _generation) return true;
      state = NotificationsState(items: page.items, page: 1, hasMore: page.hasMore);
      return true;
    } catch (e) {
      if (!mounted || gen != _generation) return true;
      if (state.items.isEmpty) state = NotificationsState(error: e);
      return false;
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s.loading || s.loadingMore || !s.hasMore) return;
    final gen = _generation;
    state = s.copyWith(loadingMore: true, moreError: null);
    try {
      final page = await _repo.list(page: s.page + 1);
      if (!mounted || gen != _generation) return;
      final seen = {for (final n in state.items) n.id};
      state = state.copyWith(
        items: [...state.items, ...page.items.where((n) => seen.add(n.id))],
        page: s.page + 1,
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } catch (e) {
      if (!mounted || gen != _generation) return;
      state = state.copyWith(loadingMore: false, moreError: e);
    }
  }

  void _setRead(bool Function(AppNotification) which, bool read) {
    state = state.copyWith(
      items: [for (final n in state.items) which(n) ? n.copyWith(isRead: read) : n],
    );
  }

  /// Mark one read. Returns whether the server agreed.
  Future<bool> markRead(String id) async {
    final target = state.items.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return true;
    _setRead((n) => n.id == id, true);
    try {
      await _repo.markRead(id);
      _onUnreadChanged();
      return true;
    } catch (_) {
      if (mounted) _setRead((n) => n.id == id, false);
      return false;
    }
  }

  /// Mark everything read. Returns whether the server agreed.
  Future<bool> markAllRead() async {
    final unread = {
      for (final n in state.items)
        if (!n.isRead) n.id,
    };
    if (unread.isEmpty) return true;
    _setRead((n) => unread.contains(n.id), true);
    try {
      await _repo.markAllRead();
      _onUnreadChanged();
      return true;
    } catch (_) {
      if (mounted) _setRead((n) => unread.contains(n.id), false);
      return false;
    }
  }
}

final notificationsControllerProvider =
    StateNotifierProvider.autoDispose<NotificationsController, NotificationsState>((ref) {
      // A different account never sees the previous one's notifications.
      ref.watch(authControllerProvider.select((s) => s.user?.id));
      return NotificationsController(
        ref.watch(notificationRepositoryProvider),
        () => ref.invalidate(unreadCountProvider),
      );
    });

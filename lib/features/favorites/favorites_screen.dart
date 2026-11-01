import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/providers.dart';
import '../doctors/widgets/doctor_result_card.dart';
import '../home/home_style.dart';
import 'providers.dart';
import '../../core/theme/app_palette.dart';

/// The doctors the person has marked as favourites.
///
/// The list comes from [favoritesProvider] (ids and slugs only); each doctor's
/// details are loaded through the same [doctorDetailProvider] the profile page
/// uses, so a favourite shows the *current* fee, rating and booking status
/// rather than whatever was true when it was saved — and a profile already
/// opened in this session appears instantly.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: context.palette.page,
      body: Column(
        children: [
          _Header(
            count: favorites.status == FavoritesStatus.ready ? favorites.entries.length : null,
          ),
          Expanded(
            child: switch (favorites.status) {
              FavoritesStatus.loading => const _LoadingList(),
              FavoritesStatus.error => AppErrorView(
                error: StateError('favourites unreadable'),
                onRetry: () => ref.read(favoritesProvider.notifier).retry(),
              ),
              FavoritesStatus.ready => const _FavoritesList(),
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int? count;

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
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 14, AppSpacing.gutter, 14),
          child: Row(
            children: [
              Icon(Icons.favorite_rounded, color: context.palette.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.favoritesTitle,
                  style: context.homeType.sectionTitle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (count != null && count! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.palette.pageSoft,
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Text(
                    l.favoritesCount(count!),
                    style: context.homeType.pill.copyWith(color: context.palette.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.gutter,
      AppSpacing.gutter,
      AppSpacing.gutter + MediaQuery.paddingOf(context).bottom,
    ),
    children: const [
      Skeleton(height: 200, radius: homeCardRadius),
      SizedBox(height: HomeSpacing.card),
      Skeleton(height: 200, radius: homeCardRadius),
    ],
  );
}

const _removeDuration = Duration(milliseconds: 280);

/// The list itself, kept in step with [favoritesProvider] so a removal slides
/// out instead of the list jumping.
class _FavoritesList extends ConsumerStatefulWidget {
  const _FavoritesList();

  @override
  ConsumerState<_FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends ConsumerState<_FavoritesList> {
  final _listKey = GlobalKey<AnimatedListState>();

  /// What the [AnimatedList] currently holds. It must be edited in lock-step with
  /// the list's own insert/remove calls, which is why it is not just read from
  /// the provider.
  late final List<FavoriteEntry> _shown = [...ref.read(favoritesProvider).entries];

  /// The empty state waits for the last removal to finish sliding out.
  late bool _showEmpty = _shown.isEmpty;
  Timer? _emptyTimer;

  @override
  void dispose() {
    _emptyTimer?.cancel();
    super.dispose();
  }

  void _sync(List<FavoriteEntry> next) {
    final wanted = {for (final e in next) e.id};

    for (var i = _shown.length - 1; i >= 0; i--) {
      if (wanted.contains(_shown[i].id)) continue;
      final gone = _shown.removeAt(i);
      _listKey.currentState?.removeItem(
        i,
        (context, animation) => _Animated(
          animation: animation,
          child: _FavoriteTile(entry: gone),
        ),
        duration: _removeDuration,
      );
    }

    final have = {for (final e in _shown) e.id};
    for (final e in next.reversed) {
      if (have.contains(e.id)) continue;
      _shown.insert(0, e);
      _listKey.currentState?.insertItem(0, duration: _removeDuration);
    }

    _emptyTimer?.cancel();
    if (_shown.isEmpty) {
      _emptyTimer = Timer(_removeDuration, () {
        if (mounted) setState(() => _showEmpty = true);
      });
    } else if (_showEmpty) {
      setState(() => _showEmpty = false);
    }
  }

  Future<void> _refresh() async {
    for (final e in _shown) {
      ref.invalidate(doctorDetailProvider(e.slug));
    }
    await Future.wait([
      for (final e in _shown)
        ref.read(doctorDetailProvider(e.slug).future).then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FavoritesState>(favoritesProvider, (_, next) => _sync(next.entries));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _showEmpty
          ? const _EmptyFavorites(key: ValueKey('empty'))
          : RefreshIndicator(
              key: const ValueKey('list'),
              onRefresh: _refresh,
              child: AnimatedList(
                key: _listKey,
                physics: const AlwaysScrollableScrollPhysics(),
                // The bottom clears the floating nav dock as well (its height is
                // the body's bottom padding under the shell, 0 anywhere else).
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  HomeSpacing.top,
                  AppSpacing.gutter,
                  AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
                ),
                initialItemCount: _shown.length,
                itemBuilder: (context, i, animation) => _Animated(
                  animation: animation,
                  child: _FavoriteTile(key: ValueKey(_shown[i].id), entry: _shown[i]),
                ),
              ),
            ),
    );
  }
}

/// Fade and collapse, driven by the list's own insert/remove animation.
class _Animated extends StatelessWidget {
  const _Animated({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    child: FadeTransition(opacity: animation, child: child),
  );
}

/// One favourite: the shared result card once the doctor's details arrive.
class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({super.key, required this.entry});

  final FavoriteEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final detail = ref.watch(doctorDetailProvider(entry.slug));

    return Padding(
      padding: const EdgeInsets.only(bottom: HomeSpacing.card),
      child: detail.when(
        loading: () => const Skeleton(height: 200, radius: homeCardRadius),
        error: (_, __) => _UnavailableCard(
          message: l.favoritesDoctorError,
          onRetry: () => ref.invalidate(doctorDetailProvider(entry.slug)),
          onRemove: () =>
              ref.read(favoritesProvider.notifier).toggle(id: entry.id, slug: entry.slug),
        ),
        data: (d) =>
            DoctorResultCard(doctor: d.card, onOpen: () => context.push(Routes.doctorPath(d.slug))),
      ),
    );
  }
}

/// A favourite whose profile could not be loaded — offline, or the doctor is no
/// longer listed. It can be retried, and it can always be removed.
class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.message, required this.onRetry, required this.onRemove});

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: context.palette.muted, size: 30),
          const SizedBox(height: 8),
          Text(message, style: context.homeType.doctorSpecialty, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton(onPressed: onRetry, child: Text(l.actionRetry)),
              TextButton(onPressed: onRemove, child: Text(l.favoriteRemove)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Center(
      child: SingleChildScrollView(
        // Centred in what the floating nav dock leaves visible.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: context.palette.pageSoft, shape: BoxShape.circle),
              child: Icon(Icons.favorite_border_rounded, size: 40, color: context.palette.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.favoritesEmptyTitle,
              style: context.homeType.sectionTitle.copyWith(fontSize: 17),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.favoritesEmptyBody,
              style: context.homeType.tagline.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => context.go('${Routes.doctors}?focus=1'),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(l.favoritesFindDoctor),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: context.homeType.button.copyWith(fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

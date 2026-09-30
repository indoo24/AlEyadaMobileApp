import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../api/api_error.dart';
import '../errors/error_messages.dart';
import '../theme/tokens.dart';

/// Renders the four states every async screen has, so no screen invents its own
/// and none of them can forget one.
///
/// The empty case is separated from the data case deliberately: "loaded, and
/// there is nothing" is a different message from "loaded, here it is", and
/// collapsing them is how you end up shipping a blank screen.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.loading,
    this.padding,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Called by the error state's retry button. Usually `ref.invalidate(...)`.
  final VoidCallback? onRetry;

  /// Whether loaded data should be treated as empty.
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final Widget? loading;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => loading ?? const AppLoading(),
      error: (err, _) => AppErrorView(error: err, onRetry: onRetry, padding: padding),
      data: (d) {
        if (isEmpty?.call(d) == true) {
          return empty ?? const AppEmptyView();
        }
        return data(d);
      },
    );
  }
}

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Center(
      child: Semantics(
        label: label ?? l.stateLoading,
        liveRegion: true,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// A failure, phrased for the person reading it, with a way forward.
///
/// Network failures get their own wording and icon: telling someone "something
/// went wrong" when their train just entered a tunnel is unhelpful, and it makes
/// them think the app is broken.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.error, this.onRetry, this.padding});

  final Object error;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final isNetwork = error is ApiException && (error as ApiException).isNetworkFailure;
    final title = isNetwork ? l.stateOfflineTitle : l.stateErrorTitle;
    final body = isNetwork ? l.stateOfflineBody : messageForError(context, error);
    final retryable =
        onRetry != null &&
        (error is! ApiException || (error as ApiException).isRetryable || isNetwork);

    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            if (retryable) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
                child: Text(l.actionRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({super.key, this.title, this.hint, this.icon, this.action});

  final String? title;
  final String? hint;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.inbox_outlined, size: 44, color: AppColors.muted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title ?? l.stateEmpty,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                hint!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// A grey block standing in for content that has not arrived.
///
/// Preferred over a spinner for lists: it keeps the layout from jumping when the
/// real rows land, which on a slow connection is most of the perceived quality.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.bgSoft, AppColors.border, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A list of card-shaped skeletons, for the doctor list and bookings list.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.itemHeight = 116});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => Skeleton(height: itemHeight, radius: AppRadii.card),
    );
  }
}

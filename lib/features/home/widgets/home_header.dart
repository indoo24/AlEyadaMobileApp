import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../l10n/app_localizations.dart';
import '../../notifications/notifications_screen.dart';
import '../home_style.dart';
import 'location_picker.dart';

/// The compact top bar: brand, current city, and (signed in) the bell.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final user = ref.watch(currentUserProvider);
    final unread = user == null ? 0 : (ref.watch(unreadCountProvider).valueOrNull ?? 0);

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surface, boxShadow: AppShadows.soft),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: 10),
          child: Row(
            children: [
              const BrandMark(size: 38),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.appName,
                      style: HomeType.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    InkWell(
                      onTap: () => showCityPicker(context),
                      borderRadius: AppRadii.inputRadius,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              homeLocationLabel(context, ref),
                              style: HomeType.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (user != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l.navNotifications,
                  onPressed: () => context.push(Routes.notifications),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 99 ? '99+' : '$unread'),
                    backgroundColor: AppColors.danger,
                    child: const Icon(Icons.notifications_none_rounded, size: 24),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/ui/app_design_system.dart';
import '../shared/ui/brand_identity.dart';
import 'app_routes.dart';

class MaumBottomNavigation extends StatelessWidget {
  const MaumBottomNavigation({
    required this.routes,
    required this.currentRoute,
    required this.onRouteSelected,
    super.key = const ValueKey('app-bottom-navigation'),
  });

  final List<AuthenticatedRoute> routes;
  final AuthenticatedRoute currentRoute;
  final ValueChanged<AuthenticatedRoute> onRouteSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    // 알림/설정 같은 보조 화면에서는 primary 탭을 임의로 선택하지 않는다.
    final selectedRoute = routes.contains(currentRoute) ? currentRoute : null;

    return DecoratedBox(
      key: const ValueKey('app-bottom-navigation-surface'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.32)
                : AppBrandColors.primaryBlue.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.xs,
            bottom: AppSpacing.xxs,
          ),
          child: Row(
            children: [
              for (var index = 0; index < routes.length; index++)
                Expanded(
                  child: _MaumBottomNavigationItem(
                    key: ValueKey('route-tab-${routes[index].key}'),
                    route: routes[index],
                    index: index,
                    totalCount: routes.length,
                    isSelected: routes[index] == selectedRoute,
                    onSelected: onRouteSelected,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaumBottomNavigationItem extends StatelessWidget {
  const _MaumBottomNavigationItem({
    required this.route,
    required this.index,
    required this.totalCount,
    required this.isSelected,
    required this.onSelected,
    super.key,
  });

  final AuthenticatedRoute route;
  final int index;
  final int totalCount;
  final bool isSelected;
  final ValueChanged<AuthenticatedRoute> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final selectedForeground =
        isDark ? colorScheme.primary : AppBrandColors.primaryBluePressed;
    final iconForeground =
        isSelected ? selectedForeground : colorScheme.onSurfaceVariant;
    final labelForeground = iconForeground;
    void handleTap() {
      HapticFeedback.selectionClick();
      onSelected(route);
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${route.navLabel} Tab ${index + 1} of $totalCount',
      onTap: handleTap,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              canRequestFocus: false,
              enableFeedback: false,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              onTap: handleTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Center(
                  heightFactor: 1,
                  child: AnimatedContainer(
                    key: ValueKey('route-tab-${route.key}-surface'),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 58,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? route.selectedIcon : route.icon,
                          size: isSelected ? 26 : 24,
                          color: iconForeground,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          route.navLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                                color: labelForeground,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ) ??
                              TextStyle(
                                color: labelForeground,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

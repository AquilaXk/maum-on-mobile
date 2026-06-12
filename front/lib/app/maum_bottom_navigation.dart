import 'package:flutter/material.dart';

import '../shared/ui/app_design_system.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final selectedRoute =
        routes.contains(currentRoute) ? currentRoute : routes.first;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: DecoratedBox(
        key: const ValueKey('app-bottom-navigation-surface'),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
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
    final colorScheme = theme.colorScheme;
    final iconForeground =
        isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final labelForeground =
        isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant;
    final selectedSurfaceColor =
        colorScheme.primaryContainer.withValues(alpha: 0.24);
    const visualSurfaceWidth = 68.0;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${route.navLabel} Tab ${index + 1} of $totalCount',
      onTap: () => onSelected(route),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelected(route),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Center(
                  heightFactor: 1,
                  child: AnimatedContainer(
                    key: ValueKey('route-tab-${route.key}-surface'),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: visualSurfaceWidth,
                    constraints: const BoxConstraints(minHeight: 52),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? selectedSurfaceColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            key: ValueKey('route-tab-${route.key}-indicator'),
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: 24,
                            height: 3,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Icon(
                            isSelected ? route.selectedIcon : route.icon,
                            size: isSelected ? 23 : 22,
                            color: iconForeground,
                          ),
                          const SizedBox(height: 2),
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
      ),
    );
  }
}

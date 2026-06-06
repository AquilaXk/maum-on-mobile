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
        AppSpacing.md,
        AppSpacing.xxs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: DecoratedBox(
        key: const ValueKey('app-bottom-navigation-surface'),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: AppRadii.card,
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
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
    final foreground = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final selectedBackground = Color.lerp(
      colorScheme.surface,
      colorScheme.primaryContainer,
      0.82,
    )!;

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
            borderRadius: AppRadii.card,
            child: InkWell(
              borderRadius: AppRadii.card,
              onTap: () => onSelected(route),
              child: AnimatedContainer(
                key: ValueKey('route-tab-${route.key}-indicator'),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                constraints: const BoxConstraints(minHeight: 64),
                decoration: BoxDecoration(
                  color: isSelected ? selectedBackground : Colors.transparent,
                  borderRadius: AppRadii.card,
                  border: isSelected
                      ? Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.16),
                        )
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected ? route.selectedIcon : route.icon,
                        size: 24,
                        color: foreground,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        route.navLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                              color: foreground,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ) ??
                            TextStyle(
                              color: foreground,
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
    );
  }
}

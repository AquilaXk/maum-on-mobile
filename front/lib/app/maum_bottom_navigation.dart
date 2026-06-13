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
    final selectedRoute =
        routes.contains(currentRoute) ? currentRoute : routes.first;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: DecoratedBox(
        key: const ValueKey('app-bottom-navigation-surface'),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE6E6E6)),
          ),
        ),
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
    final iconForeground =
        isSelected ? const Color(0xFF111111) : const Color(0xFF777777);
    final labelForeground = iconForeground;
    const visualSurfaceWidth = 64.0;

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
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 68),
                child: Center(
                  heightFactor: 1,
                  child: AnimatedContainer(
                    key: ValueKey('route-tab-${route.key}-surface'),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: visualSurfaceWidth,
                    // 사진형 탭바는 배경 캡슐 없이 아이콘과 라벨 색상으로만 선택을 드러낸다.
                    constraints: const BoxConstraints(minHeight: 62),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? route.selectedIcon : route.icon,
                            size: isSelected ? 27 : 26,
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
      ),
    );
  }
}

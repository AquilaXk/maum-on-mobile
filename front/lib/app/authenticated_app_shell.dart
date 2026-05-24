import 'package:flutter/material.dart';

import 'app_routes.dart';

class AuthenticatedAppShell extends StatelessWidget {
  const AuthenticatedAppShell({
    required this.currentRoute,
    required this.onRouteSelected,
    required this.child,
    super.key,
  });

  final AuthenticatedRoute currentRoute;
  final ValueChanged<AuthenticatedRoute> onRouteSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = authenticatedPrimaryRoutes.contains(currentRoute)
        ? authenticatedPrimaryRoutes.indexOf(currentRoute)
        : authenticatedPrimaryRoutes.indexOf(AuthenticatedRoute.home);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (index) {
          final selectedRoute = authenticatedPrimaryRoutes[index];
          if (selectedRoute != currentRoute) {
            onRouteSelected(selectedRoute);
          }
        },
        destinations: [
          for (final route in authenticatedPrimaryRoutes)
            NavigationDestination(
              key: ValueKey('route-tab-${route.key}'),
              icon: Icon(route.icon),
              selectedIcon: Icon(route.selectedIcon),
              label: '${route.navLabel} 탭',
            ),
        ],
      ),
    );
  }
}

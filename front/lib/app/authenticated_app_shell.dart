import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'maum_bottom_navigation.dart';

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
    return Scaffold(
      body: child,
      bottomNavigationBar: MaumBottomNavigation(
        routes: authenticatedPrimaryRoutes,
        currentRoute: currentRoute,
        onRouteSelected: (route) {
          if (route != currentRoute) {
            onRouteSelected(route);
          }
        },
      ),
    );
  }
}

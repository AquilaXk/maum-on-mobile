import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/app/app_routes.dart';
import 'package:maum_on_mobile_front/app/maum_bottom_navigation.dart';
import 'package:maum_on_mobile_front/shared/ui/brand_identity.dart';
import 'package:maum_on_mobile_front/theme/app_theme.dart';

void main() {
  final primaryRoutes = AuthenticatedRoute.values
      .where((route) => route.primaryTab)
      .toList(growable: false);

  testWidgets('preserves exact light theme tokens and tab semantics',
      (tester) async {
    AuthenticatedRoute? selected;
    final lightTheme = buildAppTheme();

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          bottomNavigationBar: MaumBottomNavigation(
            routes: primaryRoutes,
            currentRoute: AuthenticatedRoute.home,
            onRouteSelected: (route) => selected = route,
          ),
        ),
      ),
    );

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('app-bottom-navigation-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.border?.top.color, lightTheme.colorScheme.outlineVariant);
    expect(decoration.boxShadow, isNotEmpty);

    final activeSurface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('route-tab-home-surface')),
    );
    final activeDecoration = activeSurface.decoration as BoxDecoration;
    expect(
      activeDecoration.color,
      lightTheme.colorScheme.primary.withValues(alpha: 0.14),
    );
    expect(activeDecoration.borderRadius, BorderRadius.circular(14));

    final activeIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('route-tab-home-surface')),
        matching: find.byType(Icon),
      ),
    );
    final inactiveIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('route-tab-diary-surface')),
        matching: find.byType(Icon),
      ),
    );
    expect(activeIcon.color, AppBrandColors.primaryBluePressed);
    expect(inactiveIcon.color, lightTheme.colorScheme.onSurfaceVariant);
    expect(find.bySemanticsLabel('홈 Tab 1 of 5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('route-tab-diary')));
    await tester.pump();
    expect(selected, AuthenticatedRoute.diary);
  });

  testWidgets('switches surface, border, and foreground to dark colorScheme',
      (tester) async {
    final darkTheme = buildDarkAppTheme();

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          bottomNavigationBar: MaumBottomNavigation(
            routes: primaryRoutes,
            currentRoute: AuthenticatedRoute.diary,
            onRouteSelected: (_) {},
          ),
        ),
      ),
    );

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('app-bottom-navigation-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color, darkTheme.colorScheme.surface);
    expect(decoration.color, isNot(Colors.white));
    expect(decoration.border?.top.color, darkTheme.colorScheme.outlineVariant);
    expect(decoration.boxShadow, isNotEmpty);

    final activeSurface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('route-tab-diary-surface')),
    );
    final activeDecoration = activeSurface.decoration as BoxDecoration;
    expect(
      activeDecoration.color,
      darkTheme.colorScheme.primary.withValues(alpha: 0.14),
    );
    expect(activeDecoration.borderRadius, BorderRadius.circular(14));

    final activeIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('route-tab-diary-surface')),
        matching: find.byType(Icon),
      ),
    );
    final inactiveIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('route-tab-home-surface')),
        matching: find.byType(Icon),
      ),
    );
    expect(activeIcon.color, darkTheme.colorScheme.primary);
    expect(inactiveIcon.color, darkTheme.colorScheme.onSurfaceVariant);
  });
}

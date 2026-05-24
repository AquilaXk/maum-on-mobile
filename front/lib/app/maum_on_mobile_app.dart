import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../theme/app_theme.dart';
import 'app_routes.dart';

class MaumOnMobileApp extends StatelessWidget {
  const MaumOnMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final initialRoute = getInitialRoute();

    return MaterialApp(
      title: 'Maum On',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(routeTitle: initialRoute.title),
    );
  }
}

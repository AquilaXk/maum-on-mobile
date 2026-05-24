class AppRoute {
  const AppRoute({
    required this.key,
    required this.path,
    required this.title,
    this.initial = false,
  });

  final String key;
  final String path;
  final String title;
  final bool initial;
}

const appRoutes = <AppRoute>[
  AppRoute(
    key: 'home',
    path: '/',
    title: '홈',
    initial: true,
  ),
];

AppRoute getInitialRoute() {
  return appRoutes.firstWhere((route) => route.initial);
}

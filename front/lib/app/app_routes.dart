import 'package:flutter/material.dart';

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

enum AuthenticatedRoute {
  home(
    key: 'home',
    path: '/',
    title: '홈',
    navLabel: '홈',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    primaryTab: true,
  ),
  diary(
    key: 'diary',
    path: '/diary',
    title: '기록',
    navLabel: '기록',
    icon: Icons.edit_note_outlined,
    selectedIcon: Icons.edit_note,
    primaryTab: true,
  ),
  story(
    key: 'story',
    path: '/stories',
    title: '스토리',
    navLabel: '스토리',
    icon: Icons.forum_outlined,
    selectedIcon: Icons.forum,
    primaryTab: true,
  ),
  letter(
    key: 'letter',
    path: '/letters',
    title: '편지',
    navLabel: '편지',
    icon: Icons.mail_outline,
    selectedIcon: Icons.mail,
    primaryTab: true,
  ),
  consultation(
    key: 'consultation',
    path: '/consultation',
    title: 'AI 상담',
    navLabel: 'AI 상담',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    primaryTab: true,
  ),
  notifications(
    key: 'notifications',
    path: '/notifications',
    title: '알림/신고',
    navLabel: '알림',
    icon: Icons.notifications_none,
    selectedIcon: Icons.notifications,
  ),
  operations(
    key: 'operations',
    path: '/operations',
    title: '운영 검수',
    navLabel: '운영',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
  ),
  settings(
    key: 'settings',
    path: '/settings',
    title: '설정',
    navLabel: '설정',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  );

  const AuthenticatedRoute({
    required this.key,
    required this.path,
    required this.title,
    required this.navLabel,
    required this.icon,
    required this.selectedIcon,
    this.primaryTab = false,
  });

  final String key;
  final String path;
  final String title;
  final String navLabel;
  final IconData icon;
  final IconData selectedIcon;
  final bool primaryTab;
}

const authenticatedPrimaryRoutes = <AuthenticatedRoute>[
  AuthenticatedRoute.home,
  AuthenticatedRoute.diary,
  AuthenticatedRoute.story,
  AuthenticatedRoute.letter,
  AuthenticatedRoute.consultation,
];

final appRoutes = <AppRoute>[
  for (final route in AuthenticatedRoute.values)
    AppRoute(
      key: route.key,
      path: route.path,
      title: route.title,
      initial: route == AuthenticatedRoute.home,
    ),
];

AppRoute getInitialRoute() {
  return appRoutes.firstWhere(
    (route) => route.initial,
    orElse: () => appRoutes.first,
  );
}

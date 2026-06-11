import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/app/app_routes.dart';

void main() {
  test('authenticated routes expose stable keys and paths', () {
    expect(
      AuthenticatedRoute.values.map((route) => route.key),
      [
        'home',
        'diary',
        'story',
        'letter',
        'consultation',
        'notifications',
        'operations',
        'settings',
      ],
    );
    expect(
      AuthenticatedRoute.values.map((route) => route.path),
      [
        '/',
        '/diary',
        '/stories',
        '/letters',
        '/consultation',
        '/notifications',
        '/operations',
        '/settings',
      ],
    );
    expect(AuthenticatedRoute.consultation.title, 'AI 상담');
    expect(AuthenticatedRoute.consultation.navLabel, 'AI 상담');
  });
}

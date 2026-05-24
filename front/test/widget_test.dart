import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/app/maum_on_mobile_app.dart';
import 'package:maum_on_mobile_front/app/supported_platforms.dart';

void main() {
  testWidgets('renders the initial home screen contract', (tester) async {
    await tester.pumpWidget(const MaumOnMobileApp());

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('Maum On'), findsOneWidget);
    expect(find.text('체크인 대기 중'), findsOneWidget);
    expect(find.text('체크인 시작'), findsOneWidget);
  });

  test('supports only Android and iOS at bootstrap', () {
    expect(supportedPlatforms, <String>['android', 'ios']);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/qa/auth_qa_app.dart';
import 'package:maum_on_mobile_front/shared/ui/brand_identity.dart';

void main() {
  testWidgets('인증 QA 앱은 카카오 간편 로그인과 이메일 회원가입 흐름을 렌더링한다', (tester) async {
    await tester.pumpWidget(buildAuthQaApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-blue-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-form-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-submit-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quick-login-provider-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('external-login-kakao-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('external-login-google-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('external-login-apple-button')),
      findsNothing,
    );

    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('signup-email-verification-request-button')),
        findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'qa@example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-email-verification-request-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('인증번호를 이메일로 보냈습니다.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('signup-email-verification-code-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('signup-nickname-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('signup-submit-button')), findsOneWidget);
  });

  testWidgets('시스템 다크 모드에서도 하늘색 라이트 인증 테마를 유지한다', (tester) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    await tester.pumpWidget(buildAuthQaApp());
    await tester.pumpAndSettle();

    final shell = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('auth-blue-shell')),
    );
    final shellDecoration = shell.decoration as BoxDecoration;
    final panelTheme = Theme.of(
      tester.element(find.byKey(const ValueKey('auth-form-panel'))),
    );

    expect(shellDecoration.color, AppBrandColors.backgroundBlue);
    expect(panelTheme.colorScheme.brightness, Brightness.light);
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/qa/auth_qa_app.dart';

void main() {
  testWidgets('renders the auth QA app through signup verification',
      (tester) async {
    await tester.pumpWidget(buildAuthQaApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-blue-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-form-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-submit-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-login-provider-row')),
        findsNothing);

    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('signup-email-verification-request-button')),
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
}

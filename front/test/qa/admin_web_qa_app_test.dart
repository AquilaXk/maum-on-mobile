import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/qa/admin_web_qa_app.dart';

void main() {
  testWidgets('renders the admin web QA app without network', (tester) async {
    await tester.pumpWidget(buildAdminWebQaApp());
    await tester.pumpAndSettle();

    expect(find.text('관리자 콘솔'), findsOneWidget);
    expect(find.text('운영 대시보드'), findsOneWidget);
    expect(find.text('신고 관리'), findsOneWidget);
    expect(find.text('회원 관리'), findsOneWidget);
    expect(find.text('편지 관리'), findsOneWidget);
    expect(find.text('AI 필터 상태'), findsOneWidget);
  });
}

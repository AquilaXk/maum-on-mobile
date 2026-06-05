import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/qa/mobile_qa_app.dart';

void main() {
  testWidgets('renders the authenticated QA app without network',
      (tester) async {
    await tester.pumpWidget(buildMobileQaApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-primary-panel')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-primary-actions-panel')),
      findsOneWidget,
    );
    expect(find.text('이어쓸 내용이 없습니다.'), findsNothing);
    expect(
      find.text('새 기록, 편지, 스토리, 상담을 바로 시작할 수 있습니다.'),
      findsNothing,
    );
    expect(find.textContaining('오늘의 마음'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const ValueKey('home-category-daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-category-daily')));
    await tester.pumpAndSettle();
    expect(find.text('일상 QA 스토리'), findsOneWidget);

    await tester.tap(find.byKey(mobileQaRouteKey('consultation')));
    await tester.pumpAndSettle();
    expect(find.text('실시간 상담'), findsOneWidget);
    expect(find.text('상담 연결됨'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '요즘 마음이 무거워요',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('QA'), findsNothing);
    expect(find.textContaining('테스트'), findsNothing);
    expect(
        find.text(
            '말해줘서 고마워요. 지금 마음이 무거운 상태라면, 먼저 숨을 천천히 고르고 가장 크게 남은 감정 하나만 짚어봐요. 지금 제일 크게 느껴지는 감정은 무엇인가요?'),
        findsOneWidget);
    expect(find.text('상담 연결됨'), findsOneWidget);

    await tester.tap(find.byKey(mobileQaRouteKey('home')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('home-action-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await tester.pumpAndSettle();
    expect(find.text('계정 설정'), findsOneWidget);
  });
}

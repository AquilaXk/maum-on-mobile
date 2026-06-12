import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/qa/mobile_qa_app.dart';

void main() {
  testWidgets('renders the authenticated QA app without network',
      (tester) async {
    await tester.pumpWidget(buildMobileQaApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('관리자'), findsNothing);
    expect(find.textContaining('운영 공간'), findsNothing);
    expect(find.textContaining('관리자 콘솔'), findsNothing);
    expect(find.textContaining('신고 관리'), findsNothing);
    expect(find.textContaining('회원 관리'), findsNothing);
    expect(find.textContaining('편지 관리'), findsNothing);
    expect(find.textContaining('/api/v1/admin'), findsNothing);
    expect(find.byKey(const ValueKey('home-primary-panel')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-primary-actions-panel')),
      findsOneWidget,
    );
    expect(find.text('이어쓸 내용이 없습니다.'), findsNothing);
    expect(
      find.text('새 기록, 편지, 스토리, AI 상담을 바로 시작할 수 있습니다.'),
      findsNothing,
    );
    expect(find.text('오늘 마음 정리'), findsNothing);
    expect(find.text('조용히 전하기'), findsNothing);
    expect(find.text('함께 읽기'), findsNothing);
    expect(find.text('지금 대화하기'), findsNothing);
    expect(find.textContaining('오늘의 마음'), findsNothing);
    expect(find.text('최근 마음 나눔이 차분히 이어지고 있어요.'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('home-category-daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-category-daily')));
    await tester.pumpAndSettle();
    expect(find.text('작은 산책이 남긴 여유'), findsOneWidget);
    expect(find.textContaining('QA'), findsNothing);
    expect(find.textContaining('테스트'), findsNothing);

    await tester.tap(find.byKey(mobileQaRouteKey('consultation')));
    await tester.pumpAndSettle();
    expect(find.text('AI 상담'), findsWidgets);
    expect(find.text('AI 상담 연결됨'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('consultation-message-field')),
      findsOneWidget,
    );

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
    expect(find.text('AI 상담 연결됨'), findsOneWidget);

    await tester.tap(find.byKey(mobileQaRouteKey('home')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('home-action-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await tester.pumpAndSettle();
    expect(find.text('계정 설정'), findsOneWidget);
    expect(find.textContaining('관리자'), findsNothing);
    expect(find.textContaining('운영 공간'), findsNothing);
    expect(find.textContaining('관리자 콘솔'), findsNothing);
  });

  testWidgets('filters QA stories into the empty state without helper copy',
      (tester) async {
    await tester.pumpWidget(buildMobileQaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mobileQaRouteKey('story')));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 스토리'), findsOneWidget);
    expect(find.text('마음을 천천히 꺼내 놓는 연습을 하고 있어요.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('story-search-field')),
      '없는 이야기',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-search-button')));
    await tester.pumpAndSettle();

    expect(find.text('조건에 맞는 스토리가 없습니다.'), findsOneWidget);
    expect(find.text('검색어 또는 카테고리를 바꿔 다시 확인해 주세요.'), findsNothing);
  });

  testWidgets('opens QA story detail with comment context', (tester) async {
    await tester.pumpWidget(buildMobileQaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mobileQaRouteKey('story')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('story-card-1')));
    await tester.tap(find.byKey(const ValueKey('story-card-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('story-comment-section-header')),
        findsOneWidget);
    expect(find.text('댓글 1개'), findsOneWidget);
    expect(find.text('천천히 들어줄게요.'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/moderation/domain/content_moderation_models.dart';
import 'package:maum_on_mobile_front/features/moderation/presentation/content_moderation_feedback_panel.dart';

void main() {
  testWidgets('renders moderation guidance with accessible retry actions',
      (tester) async {
    var retryCount = 0;
    var dismissCount = 0;
    final feedback = ContentModerationFeedback.blocked(
      targetType: ContentModerationTarget.comment,
      result: const ContentModerationResult(
        allowed: false,
        riskLevel: ContentModerationRiskLevel.high,
        message: '위험도가 높은 표현이 포함되어 수정이 필요합니다.',
        categories: [
          ContentModerationCategory.personalInfo,
          ContentModerationCategory.spam,
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: ContentModerationFeedbackPanel(
                  feedback: feedback,
                  onRetry: () => retryCount += 1,
                  onDismiss: () => dismissCount += 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp('콘텐츠 검수 차단 안내: 댓글 표현을 수정해 주세요.'),
      ),
      findsOneWidget,
    );
    expect(find.text('수정 후 다시 검수'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.textContaining('입력 내용은 그대로 유지됩니다'), findsOneWidget);

    await tester.ensureVisible(find.text('수정 후 다시 검수'));
    await tester.tap(find.text('수정 후 다시 검수'));
    await tester.pump();
    await tester.ensureVisible(find.text('취소'));
    await tester.tap(find.text('취소'));

    expect(retryCount, 1);
    expect(dismissCount, 1);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/moderation/domain/content_moderation_models.dart';

void main() {
  group('ContentModerationFeedback', () {
    test('maps blocked categories to correction guidance', () {
      final feedback = ContentModerationFeedback.blocked(
        targetType: ContentModerationTarget.story,
        result: const ContentModerationResult(
          allowed: false,
          riskLevel: ContentModerationRiskLevel.high,
          message: '위험도가 높은 표현이 포함되어 수정이 필요합니다.',
          categories: [
            ContentModerationCategory.personalInfo,
            ContentModerationCategory.profanity,
          ],
        ),
      );

      expect(feedback.status, ContentModerationFeedbackStatus.policyBlocked);
      expect(feedback.title, '스토리 표현을 수정해 주세요.');
      expect(feedback.message, contains('입력 내용은 그대로 유지됩니다'));
      expect(feedback.guidanceItems,
          contains('전화번호, 이메일, 주소처럼 개인을 특정할 수 있는 표현을 지워 주세요.'));
      expect(feedback.guidanceItems,
          contains('비난, 욕설, 위협으로 읽힐 수 있는 표현을 부드럽게 바꿔 주세요.'));
      expect(feedback.primaryActionLabel, '수정 후 다시 검수');
      expect(feedback.dismissActionLabel, '취소');
    });

    test('separates network and model failure copy', () {
      final networkFeedback = ContentModerationFeedback.failure(
        targetType: ContentModerationTarget.comment,
        error: const ApiClientException(
          kind: ApiErrorKind.network,
          message: '네트워크 연결을 확인해 주세요.',
        ),
      );
      final modelFeedback = ContentModerationFeedback.failure(
        targetType: ContentModerationTarget.letter,
        error: const ApiClientException(
          kind: ApiErrorKind.server,
          message: '검수 결과를 확인하지 못했습니다.',
        ),
      );

      expect(
          networkFeedback.status, ContentModerationFeedbackStatus.networkError);
      expect(networkFeedback.title, '연결 후 다시 검수해 주세요.');
      expect(networkFeedback.guidanceItems.single, contains('네트워크'));
      expect(modelFeedback.status,
          ContentModerationFeedbackStatus.modelUnavailable);
      expect(modelFeedback.title, '검수 결과를 불러오지 못했습니다.');
      expect(modelFeedback.guidanceItems.single, contains('잠시 후'));
    });
  });
}

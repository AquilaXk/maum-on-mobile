import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/moderation/data/content_moderation_repository.dart';
import 'package:maum_on_mobile_front/features/moderation/domain/content_moderation_models.dart';
import 'package:maum_on_mobile_front/features/report/application/report_controller.dart';
import 'package:maum_on_mobile_front/features/report/data/report_repository.dart';
import 'package:maum_on_mobile_front/features/report/domain/report_models.dart';

void main() {
  group('ReportController', () {
    test('submits a valid report and exposes duplicate submission state',
        () async {
      final repository = _FakeReportRepository();
      final controller = ReportController(repository: repository);

      controller
        ..selectTarget(
          const ReportTarget(
            type: ReportTargetType.post,
            id: 11,
            label: '오늘의 스토리',
          ),
        )
        ..selectReason(ReportReasonCode.spam)
        ..updateContent('반복 광고입니다.');

      await controller.submit();
      await controller.submit();

      expect(repository.drafts, hasLength(1));
      expect(controller.state.isSubmitted, isTrue);
      expect(controller.state.canSubmit, isFalse);
      expect(controller.state.noticeMessage, '신고가 접수되었습니다.');
    });

    test('requires a detailed reason when OTHER is selected', () async {
      final repository = _FakeReportRepository();
      final controller = ReportController(repository: repository);

      controller
        ..selectTarget(
          const ReportTarget(
            type: ReportTargetType.comment,
            id: 3,
            label: '댓글',
          ),
        )
        ..selectReason(ReportReasonCode.other)
        ..updateContent('짧음');

      await controller.submit();

      expect(repository.drafts, isEmpty);
      expect(controller.state.validationMessage, '기타 사유는 5자 이상 입력해 주세요.');
    });

    test('validates required target before submitting', () async {
      final repository = _FakeReportRepository();
      final controller = ReportController(repository: repository)
        ..selectReason(ReportReasonCode.profanity);

      await controller.submit();

      expect(repository.drafts, isEmpty);
      expect(controller.state.validationMessage, '신고 대상을 선택해 주세요.');
    });

    test('blocks high-risk report content before submitting', () async {
      final repository = _FakeReportRepository();
      final moderationRepository = _FakeContentModerationRepository(
        result: const ContentModerationResult(
          allowed: false,
          riskLevel: ContentModerationRiskLevel.high,
          message: '위험도가 높은 표현이 포함되어 수정이 필요합니다.',
          categories: [ContentModerationCategory.profanity],
        ),
      );
      final controller = ReportController(
        repository: repository,
        moderationRepository: moderationRepository,
      );

      controller
        ..selectTarget(
          const ReportTarget(
            type: ReportTargetType.comment,
            id: 5,
            label: '댓글',
          ),
        )
        ..selectReason(ReportReasonCode.other)
        ..updateContent('너 죽어 버려');

      await controller.submit();

      expect(repository.drafts, isEmpty);
      expect(moderationRepository.requests.single.targetType,
          ContentModerationTarget.report);
      expect(controller.state.errorMessage, '위험도가 높은 표현이 포함되어 수정이 필요합니다.');
      expect(controller.state.content, '너 죽어 버려');
      expect(controller.state.moderationFeedback?.status,
          ContentModerationFeedbackStatus.policyBlocked);
      expect(controller.state.moderationFeedback?.targetType,
          ContentModerationTarget.report);
      expect(
        controller.state.moderationFeedback?.guidanceItems,
        contains('비난, 욕설, 위협으로 읽힐 수 있는 표현을 부드럽게 바꿔 주세요.'),
      );
    });

    test('keeps report text when moderation network fails', () async {
      final repository = _FakeReportRepository();
      final moderationRepository = _FakeContentModerationRepository(
        error: const ApiClientException(
          kind: ApiErrorKind.network,
          message: '네트워크 연결을 확인해 주세요.',
        ),
      );
      final controller = ReportController(
        repository: repository,
        moderationRepository: moderationRepository,
      )
        ..selectTarget(
          const ReportTarget(
            type: ReportTargetType.comment,
            id: 7,
            label: '댓글',
          ),
        )
        ..updateContent('연결 뒤 다시 보낼 신고 내용');

      await controller.submit();

      expect(repository.drafts, isEmpty);
      expect(controller.state.content, '연결 뒤 다시 보낼 신고 내용');
      expect(controller.state.moderationFeedback?.status,
          ContentModerationFeedbackStatus.networkError);
      expect(controller.state.moderationFeedback?.title, '연결 후 다시 검수해 주세요.');
    });
  });
}

class _FakeReportRepository implements ReportRepository {
  final List<ReportDraft> drafts = [];

  @override
  Future<int> createReport(ReportDraft draft) async {
    drafts.add(draft);
    return drafts.length;
  }
}

class _FakeContentModerationRepository implements ContentModerationRepository {
  _FakeContentModerationRepository({
    ContentModerationResult? result,
    List<ContentModerationResult>? results,
    this.error,
  }) : results = results ?? [if (result != null) result];

  final List<ContentModerationResult> results;
  final Object? error;
  final List<ContentModerationRequest> requests = [];

  @override
  Future<ContentModerationResult> reviewText({
    required ContentModerationTarget targetType,
    required String text,
  }) async {
    requests.add(ContentModerationRequest(targetType: targetType, text: text));
    final nextError = error;
    if (nextError != null) {
      throw nextError;
    }
    if (results.isEmpty) {
      throw StateError('No moderation result configured.');
    }
    return results.length == 1 ? results.single : results.removeAt(0);
  }
}

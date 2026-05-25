import 'package:flutter_test/flutter_test.dart';
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

  @override
  Future<List<AdminReportSummary>> fetchAdminReports() {
    throw UnimplementedError();
  }

  @override
  Future<AdminReportDetail> fetchAdminReport(int id) {
    throw UnimplementedError();
  }

  @override
  Future<AdminReportActionResult> updateAdminReportStatus(
    int id,
    AdminReportActionDraft draft,
  ) {
    throw UnimplementedError();
  }
}

class _FakeContentModerationRepository implements ContentModerationRepository {
  _FakeContentModerationRepository({required this.result});

  final ContentModerationResult result;
  final List<ContentModerationRequest> requests = [];

  @override
  Future<ContentModerationResult> reviewText({
    required ContentModerationTarget targetType,
    required String text,
  }) async {
    requests.add(ContentModerationRequest(targetType: targetType, text: text));
    return result;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/operations/application/operations_controller.dart';
import 'package:maum_on_mobile_front/features/operations/presentation/operations_screen.dart';
import 'package:maum_on_mobile_front/features/report/data/report_repository.dart';
import 'package:maum_on_mobile_front/features/report/domain/report_models.dart';

void main() {
  testWidgets('reviews a report and stores an action reason', (tester) async {
    final repository = _FakeReportRepository();
    final controller = OperationsController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: OperationsScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('운영 검수 대상'), findsWidgets);
    expect(find.text('신고자 · reporter@example.com · ACTIVE'), findsOneWidget);
    expect(find.byKey(const ValueKey('operations-action-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('operations-reason-field')),
      '개인정보 노출로 숨김 처리',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('operations-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('operations-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.actions.single.reason, '개인정보 노출로 숨김 처리');
    expect(find.text('운영 조치가 저장되었습니다.'), findsOneWidget);
    expect(find.textContaining('관리자'), findsWidgets);
  });
}

class _FakeReportRepository implements ReportRepository {
  final List<AdminReportActionDraft> actions = [];
  AdminReportActionResult? lastResult;

  @override
  Future<int> createReport(ReportDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<List<AdminReportSummary>> fetchAdminReports() async {
    return [
      AdminReportSummary(
        id: 1,
        targetId: 10,
        targetType: ReportTargetType.post,
        reason: 'PERSONAL_INFO',
        content: '전화번호가 노출되어 있습니다.',
        status: lastResult?.status ?? 'RECEIVED',
        createdAt: '2026-05-25T09:00:00',
        targetTitle: '운영 검수 대상',
        targetPreview: '확인이 필요한 글입니다.',
        reporter: _member(
          id: 2,
          email: 'reporter@example.com',
          nickname: '신고자',
        ),
        targetOwner: _member(
          id: 3,
          email: 'owner@example.com',
          nickname: '작성자',
        ),
        actionReason: lastResult?.actionReason,
        handledBy: lastResult?.handledBy,
        handledAt: lastResult?.handledAt,
      ),
    ];
  }

  @override
  Future<AdminReportDetail> fetchAdminReport(int id) async {
    return AdminReportDetail(
      id: id,
      targetId: 10,
      targetType: ReportTargetType.post,
      reason: 'PERSONAL_INFO',
      content: '전화번호가 노출되어 있습니다.',
      status: lastResult?.status ?? 'RECEIVED',
      createdAt: '2026-05-25T09:00:00',
      target: const AdminReportTarget(
        id: 10,
        type: ReportTargetType.post,
        title: '운영 검수 대상',
        preview: '확인이 필요한 글입니다.',
        ownerId: 3,
      ),
      reporter: _member(
        id: 2,
        email: 'reporter@example.com',
        nickname: '신고자',
      ),
      targetOwner: _member(
        id: 3,
        email: 'owner@example.com',
        nickname: '작성자',
      ),
      actionReason: lastResult?.actionReason,
      handledBy: lastResult?.handledBy,
      handledAt: lastResult?.handledAt,
    );
  }

  @override
  Future<AdminReportActionResult> updateAdminReportStatus(
    int id,
    AdminReportActionDraft draft,
  ) async {
    actions.add(draft);
    return lastResult = AdminReportActionResult(
      id: id,
      status: draft.action.apiValue,
      actionReason: draft.reason,
      handledBy: _member(
        id: 1,
        email: 'admin@example.com',
        nickname: '관리자',
      ),
      handledAt: '2026-05-25T09:05:00',
    );
  }
}

AdminReportMember _member({
  required int id,
  required String email,
  required String nickname,
}) {
  return AdminReportMember(
    id: id,
    email: email,
    nickname: nickname,
    role: 'USER',
    status: 'ACTIVE',
  );
}

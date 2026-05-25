import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/operations/application/operations_controller.dart';
import 'package:maum_on_mobile_front/features/operations/presentation/operations_screen.dart';
import 'package:maum_on_mobile_front/features/report/data/report_repository.dart';
import 'package:maum_on_mobile_front/features/report/domain/report_models.dart';

void main() {
  testWidgets('confirms a report action before storing it', (tester) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    final repository = _FakeReportRepository();
    final controller = OperationsController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: OperationsScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('운영 검수 대상'), findsWidgets);
    expect(
      find.bySemanticsLabel('신고자, 신고자 · reporter@example.com · ACTIVE'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('operations-action-field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('operations-reason-field')),
      '개인정보 노출로 숨김 처리',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('operations-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('operations-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.actions, isEmpty);
    expect(find.text('조치 저장 확인'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('operations-confirm-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.actions.single.reason, '개인정보 노출로 숨김 처리');
    expect(find.text('운영 조치가 저장되었습니다.'), findsOneWidget);
    expect(find.textContaining('관리자'), findsWidgets);
  });

  testWidgets('labels report rows and avoids narrow screen overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    final repository = _FakeReportRepository(
      reporterEmail: 'very.long.reporter.email.address@example-service.test',
      targetTitle: '작은 화면에서 겹치면 안 되는 아주 긴 운영 검수 대상 제목',
    );
    final controller = OperationsController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.45),
            ),
            child: child!,
          );
        },
        home: OperationsScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('신고 대기열'), findsOneWidget);
    expect(find.text('신고 queue'), findsNothing);
    expect(
      find.bySemanticsLabel(
        RegExp('신고 항목: 게시글, 작은 화면에서 겹치면 안 되는'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp('신고자, 신고자, very.long.reporter.email.address'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository({
    this.reporterEmail = 'reporter@example.com',
    this.targetTitle = '운영 검수 대상',
  });

  final List<AdminReportActionDraft> actions = [];
  AdminReportActionResult? lastResult;
  final String reporterEmail;
  final String targetTitle;

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
        targetTitle: targetTitle,
        targetPreview: '확인이 필요한 글입니다.',
        reporter: _member(
          id: 2,
          email: reporterEmail,
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
      target: AdminReportTarget(
        id: 10,
        type: ReportTargetType.post,
        title: targetTitle,
        preview: '확인이 필요한 글입니다.',
        ownerId: 3,
      ),
      reporter: _member(
        id: 2,
        email: reporterEmail,
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

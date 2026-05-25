import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/operations/application/operations_controller.dart';
import 'package:maum_on_mobile_front/features/operations/data/operations_repository.dart';
import 'package:maum_on_mobile_front/features/operations/domain/operations_models.dart';
import 'package:maum_on_mobile_front/features/operations/presentation/operations_screen.dart';
import 'package:maum_on_mobile_front/features/report/data/report_repository.dart';
import 'package:maum_on_mobile_front/features/report/domain/report_models.dart';

void main() {
  testWidgets('confirms a report action before storing it', (tester) async {
    final repository = _FakeReportRepository();
    final controller = OperationsController(
      reportRepository: repository,
      operationsRepository: _FakeOperationsRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperationsScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('operations-view-reports')));
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

    final repository = _FakeReportRepository(
      reporterEmail: 'very.long.reporter.email.address@example-service.test',
      targetTitle: '작은 화면에서 겹치면 안 되는 아주 긴 운영 검수 대상 제목',
    );
    final controller = OperationsController(
      reportRepository: repository,
      operationsRepository: _FakeOperationsRepository(),
    );

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

    await tester.tap(find.byKey(const ValueKey('operations-view-reports')));
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
        RegExp('신고자, 신고자 · very.long.reporter.email.address'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows dashboard and confirms member risk actions',
      (tester) async {
    final operationsRepository = _FakeOperationsRepository();
    final controller = OperationsController(
      reportRepository: _FakeReportRepository(),
      operationsRepository: operationsRepository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperationsScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('운영 대시보드'), findsOneWidget);
    expect(find.text('미처리 신고'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('operations-view-members')));
    await tester.pumpAndSettle();
    expect(find.text('회원 관리'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '회원 항목: 회원, member@example.com, 상태 활성',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('operations-member-search-field')),
      'member',
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.memberQueries.last, 'member');

    await tester.tap(find.byKey(const ValueKey('operations-member-7')));
    await tester.pumpAndSettle();

    expect(find.text('회원 상세'), findsOneWidget);
    expect(find.text('작성글'), findsWidgets);
    expect(find.text('STATUS_CHANGE'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('operations-member-action-reason-field')),
      '반복 신고로 차단',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('operations-member-block-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('operations-member-block-button')),
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.statusActions, isEmpty);
    expect(find.text('회원 차단 확인'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('operations-confirm-member-action-button')),
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.statusActions.single.status, 'BLOCKED');
    expect(find.text('회원 조치가 저장되었습니다.'), findsOneWidget);
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

class _FakeOperationsRepository implements OperationsRepository {
  final List<String?> memberQueries = [];
  final List<_StatusAction> statusActions = [];

  @override
  Future<OperationsDashboard> fetchDashboard() async {
    return const OperationsDashboard(
      todayReportCount: 2,
      openReportCount: 1,
      processedReportCount: 1,
      todayLetterCount: 3,
      todayDiaryCount: 4,
      receivableMemberCount: 5,
    );
  }

  @override
  Future<AdminMemberPage> fetchMembers({
    String? query,
    String? status,
    String? role,
    bool? socialAccount,
    int page = 0,
    int size = 20,
  }) async {
    memberQueries.add(query);
    return AdminMemberPage(
      content: [
        _member(),
      ],
      page: page,
      size: size,
      totalElements: 1,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<AdminMemberDetail> fetchMemberDetail(int id) async {
    return AdminMemberDetail(
      member: _member(),
      reports: const [],
      posts: const [
        AdminMemberContent(
          id: 10,
          title: '작성글',
          status: 'ONGOING',
          createdAt: '2026-05-25T09:00:00',
        ),
      ],
      letters: const [],
      diaries: const [],
      auditEvents: const [
        AdminAuditEvent(
          id: 3,
          targetMemberId: 7,
          actorMemberId: 1,
          action: 'STATUS_CHANGE',
          previousValue: 'ACTIVE',
          newValue: 'BLOCKED',
          reason: '반복 신고로 차단',
          createdAt: '2026-05-25T09:10:00',
        ),
      ],
    );
  }

  @override
  Future<AdminMemberActionResult> updateMemberStatus({
    required int memberId,
    required String status,
    required String reason,
  }) async {
    statusActions.add(_StatusAction(memberId, status, reason));
    return AdminMemberActionResult(
      member: _member(status: status),
      status: status,
      role: 'USER',
      latestAudit: const AdminAuditEvent(
        id: 4,
        targetMemberId: 7,
        actorMemberId: 1,
        action: 'STATUS_CHANGE',
        previousValue: 'ACTIVE',
        newValue: 'BLOCKED',
        reason: '반복 신고로 차단',
        createdAt: '2026-05-25T09:11:00',
      ),
    );
  }

  @override
  Future<AdminMemberActionResult> updateMemberRole({
    required int memberId,
    required String role,
    required String reason,
  }) async {
    return AdminMemberActionResult(
      member: _member(role: role),
      status: 'ACTIVE',
      role: role,
      latestAudit: const AdminAuditEvent(
        id: 5,
        targetMemberId: 7,
        actorMemberId: 1,
        action: 'ROLE_CHANGE',
        previousValue: 'USER',
        newValue: 'ADMIN',
        reason: '운영 지원 권한 부여',
        createdAt: '2026-05-25T09:12:00',
      ),
    );
  }

  @override
  Future<AdminSessionRevokeResult> revokeMemberSessions({
    required int memberId,
    required String reason,
  }) async {
    return const AdminSessionRevokeResult(
      revokedRefreshTokenCount: 1,
      disabledDeviceTokenCount: 1,
      latestAudit: AdminAuditEvent(
        id: 6,
        targetMemberId: 7,
        actorMemberId: 1,
        action: 'SESSION_REVOKE',
        previousValue: 'refreshTokens=1,deviceTokens=1',
        newValue: 'revoked',
        reason: '분실 기기 세션 회수',
        createdAt: '2026-05-25T09:13:00',
      ),
    );
  }

  AdminMemberSummary _member({
    String status = 'ACTIVE',
    String role = 'USER',
  }) {
    return AdminMemberSummary(
      id: 7,
      email: 'member@example.com',
      nickname: '회원',
      role: role,
      status: status,
      socialAccount: false,
      randomReceiveAllowed: true,
      reportCount: 1,
      postCount: 1,
      letterCount: 0,
      diaryCount: 0,
    );
  }
}

class _StatusAction {
  const _StatusAction(this.memberId, this.status, this.reason);

  final int memberId;
  final String status;
  final String reason;
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

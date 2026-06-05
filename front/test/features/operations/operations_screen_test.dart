import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
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

  testWidgets('filters report queue by target and status', (tester) async {
    final controller = OperationsController(
      reportRepository: _FakeReportRepository(includeClosedLetterReport: true),
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

    expect(find.byKey(const ValueKey('operations-report-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('operations-report-4')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('operations-report-target-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('편지').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('operations-report-1')), findsNothing);
    expect(find.byKey(const ValueKey('operations-report-4')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('operations-report-status-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('접수').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('operations-report-4')), findsNothing);
    expect(find.text('처리할 신고가 없습니다.'), findsOneWidget);
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

    expect(find.byKey(const ValueKey('operations-flow-panel')), findsNothing);
    expect(find.text('운영 검수 흐름'), findsNothing);
    expect(find.text('상태를 먼저 보고 필요한 조치 화면으로 이동하세요.'), findsNothing);
    expect(find.text('운영 대시보드'), findsOneWidget);
    expect(find.text('미처리 신고'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('operations-view-members')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('operations-flow-panel')), findsNothing);
    expect(find.text('회원 조치 흐름'), findsNothing);
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

  testWidgets('prioritizes dashboard queues on compact screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = OperationsController(
      reportRepository: _FakeReportRepository(),
      operationsRepository: _FakeOperationsRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.35),
            ),
            child: child!,
          );
        },
        home: OperationsScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('우선 확인'), findsOneWidget);
    expect(find.text('미처리 신고 1건을 먼저 확인합니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('operations-priority-reports-button')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('operations-priority-letters-button')),
        findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('operations-priority-reports-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('operations-priority-reports-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('신고 대기열'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('operations-view-dashboard')),
    );
    await tester.tap(find.byKey(const ValueKey('operations-view-dashboard')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('operations-priority-letters-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('operations-priority-letters-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('편지 검수'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows observability metrics without narrow screen overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final operationsRepository = _FakeOperationsRepository();
    final controller = OperationsController(
      reportRepository: _FakeReportRepository(),
      operationsRepository: operationsRepository,
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.35),
            ),
            child: child!,
          );
        },
        home: OperationsScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('operations-view-observability')),
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.metricsFetchCount, greaterThanOrEqualTo(1));
    expect(find.text('운영 관측'), findsOneWidget);
    expect(find.text('API endpoint 품질'), findsOneWidget);
    expect(find.text('최근 장애 원인'), findsOneWidget);
    expect(find.text('Crash signal · CRASH_SIGNAL · 1'), findsOneWidget);
    expect(find.text('ANR signal · ANR_SIGNAL · 1'), findsOneWidget);
    expect(
      find.text('Push permanent failure · IOS.permanent_failure · 2'),
      findsOneWidget,
    );
    expect(
      find.text('AI fallback · consultation.fallback · 1'),
      findsOneWidget,
    );
    expect(find.textContaining('stats'), findsWidgets);
    expect(find.text('위험'), findsWidgets);
    expect(find.text('앱 이벤트 집계'), findsOneWidget);
    expect(find.text('쓰기 복구'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows empty observability state', (tester) async {
    final controller = OperationsController(
      reportRepository: _FakeReportRepository(),
      operationsRepository: _FakeOperationsRepository(
        metrics: const MobileApiMetricsSnapshot(
          sampleCount: 0,
          endpoints: [],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperationsScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('operations-view-observability')),
    );
    await tester.pumpAndSettle();

    expect(find.text('수집된 관측 지표가 없습니다.'), findsOneWidget);
    expect(find.text('새로고침'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows observability permission errors separately',
      (tester) async {
    final controller = OperationsController(
      reportRepository: _FakeReportRepository(),
      operationsRepository: _FakeOperationsRepository(
        metricsError: const ApiClientException(
          kind: ApiErrorKind.forbidden,
          message: '운영 관측 권한이 없습니다.',
          statusCode: 403,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperationsScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('operations-view-observability')),
    );
    await tester.pumpAndSettle();

    expect(find.text('관측 지표 권한이 없습니다.'), findsOneWidget);
    expect(find.text('운영 관측 권한이 없습니다.'), findsOneWidget);
    expect(find.text('운영 대시보드 정보가 없습니다.'), findsNothing);
  });

  testWidgets('shows admin system tools and routes system actions',
      (tester) async {
    var settingsTaps = 0;
    var logoutTaps = 0;
    final openedUris = <Uri>[];
    final environment = _systemEnvironment();
    final operationsRepository = _FakeOperationsRepository(
      systemStatus: OperationsSystemStatus.connected(environment),
    );
    final controller = OperationsController(
      reportRepository: _FakeReportRepository(),
      operationsRepository: operationsRepository,
      systemEnvironment: environment,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperationsScreen(
          controller: controller,
          onBack: () {},
          adminProfile: _adminProfile(),
          onOpenSettings: () => settingsTaps += 1,
          onLogout: () => logoutTaps += 1,
          onOpenExternalUri: (uri) async {
            openedUris.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('operations-view-system')));
    await tester.pumpAndSettle();

    expect(operationsRepository.systemStatusFetchCount, 1);
    expect(find.text('시스템 도구'), findsOneWidget);
    expect(find.text('관리자 계정'), findsOneWidget);
    expect(find.bySemanticsLabel('이메일, admin@example.com'), findsOneWidget);
    expect(find.text('운영자'), findsOneWidget);
    expect(find.text('API endpoint'), findsOneWidget);
    expect(
      find.bySemanticsLabel('API endpoint, https://api.maum-on.test'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('앱 버전, 0.1.0'), findsOneWidget);
    expect(find.bySemanticsLabel('플랫폼, Android'), findsOneWidget);
    expect(find.text('관측 도구 연결됨'), findsWidgets);
    expect(
      find.byKey(const ValueKey('operations-review-support-card')),
      findsOneWidget,
    );
    expect(find.text('심사 대응'), findsOneWidget);
    expect(find.text('App Store review'), findsOneWidget);
    expect(find.text('Google Play review'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('operations-system-risk-panel')),
      findsOneWidget,
    );
    expect(find.text('주의 작업'), findsOneWidget);
    expect(
      find.bySemanticsLabel('지원 연락처, support@maum-on.app'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('개인정보 연락처, privacy@maum-on.app'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('장애 공지, https://maum-on.app/status'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('응답 SLA, 24시간 이내'), findsOneWidget);

    final openButton = find.byKey(
      const ValueKey('operations-system-open-observability-button'),
    );
    await tester.ensureVisible(openButton);
    await tester.tap(openButton);
    await tester.pumpAndSettle();
    final settingsButton =
        find.byKey(const ValueKey('operations-system-settings-button'));
    await tester.ensureVisible(settingsButton);
    await tester.tap(settingsButton);
    final logoutButton =
        find.byKey(const ValueKey('operations-system-logout-button'));
    await tester.ensureVisible(logoutButton);
    await tester.tap(logoutButton);

    expect(openedUris.single.toString(), 'https://observe.maum-on.test/mobile');
    expect(settingsTaps, 1);
    expect(logoutTaps, 1);
  });

  testWidgets('shows unconfigured system status without external action',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final environment = _systemEnvironment(observabilityToolUrl: '');
    final controller = OperationsController(
      reportRepository: _FakeReportRepository(),
      operationsRepository: _FakeOperationsRepository(
        systemStatus: OperationsSystemStatus.unconfigured(environment),
      ),
      systemEnvironment: environment,
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.35),
            ),
            child: child!,
          );
        },
        home: OperationsScreen(
          controller: controller,
          onBack: () {},
          adminProfile: _adminProfile(),
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('operations-view-system')));
    await tester.pumpAndSettle();

    expect(find.text('관측 도구 미구성'), findsWidgets);
    expect(find.text('관측 도구 주소가 설정되지 않았습니다.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('operations-system-open-observability-button')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows system permission errors separately', (tester) async {
    final environment = _systemEnvironment();
    final controller = OperationsController(
      reportRepository: _FakeReportRepository(),
      operationsRepository: _FakeOperationsRepository(
        systemStatus: OperationsSystemStatus.permissionDenied(
          environment,
          message: '운영 시스템 권한이 없습니다.',
        ),
      ),
      systemEnvironment: environment,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OperationsScreen(
          controller: controller,
          onBack: () {},
          adminProfile: _adminProfile(),
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('operations-view-system')));
    await tester.pumpAndSettle();

    expect(find.text('관측 도구 권한 없음'), findsWidgets);
    expect(find.text('운영 시스템 권한이 없습니다.'), findsOneWidget);
    expect(find.text('운영 대시보드 정보가 없습니다.'), findsNothing);
  });

  testWidgets('shows letter review and confirms reassign and block actions',
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

    await tester.tap(find.byKey(const ValueKey('operations-view-letters')));
    await tester.pumpAndSettle();

    expect(find.text('편지 검수'), findsOneWidget);
    expect(find.text('운영 편지'), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp('편지 항목: 운영 편지')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('operations-letter-search-field')),
      '운영',
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.letterQueries.last, '운영');

    await tester.tap(find.byKey(const ValueKey('operations-letter-12')));
    await tester.pumpAndSettle();

    expect(find.text('편지 상세'), findsOneWidget);
    expect(find.text('원문 요약'), findsOneWidget);
    expect(find.text('LETTER_NOTE'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('operations-letter-action-reason-field')),
      '운영 메모 저장',
    );
    await tester.enterText(
      find.byKey(const ValueKey('operations-letter-note-field')),
      '상담 이관',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('operations-letter-note-button')),
    );
    await tester
        .tap(find.byKey(const ValueKey('operations-letter-note-button')));
    await tester.pumpAndSettle();

    expect(operationsRepository.letterNotes, isEmpty);
    expect(find.text('편지 메모 저장 확인'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('operations-confirm-letter-note-button')),
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.letterNotes.single.note, '상담 이관');

    await tester.enterText(
      find.byKey(const ValueKey('operations-letter-action-reason-field')),
      '수신자 변경',
    );
    await tester.enterText(
      find.byKey(const ValueKey('operations-letter-receiver-search-field')),
      'receiver',
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.memberQueries.last, 'receiver');

    await tester.tap(
      find.byKey(const ValueKey('operations-letter-receiver-8')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('operations-letter-reassign-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('operations-letter-reassign-button')),
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.reassignActions, isEmpty);
    expect(find.text('편지 재배정 확인'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('operations-confirm-letter-reassign-button')),
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.reassignActions.single.receiverMemberId, 8);
    expect(find.text('편지 조치가 저장되었습니다.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('operations-letter-action-reason-field')),
      '반복 악용 차단',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('operations-letter-block-sender-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('operations-letter-block-sender-button')),
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.blockedLetterIds, isEmpty);
    expect(find.text('발신자 차단 확인'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('operations-confirm-letter-block-button')),
    );
    await tester.pumpAndSettle();

    expect(operationsRepository.blockedLetterIds.single, 12);
  });
}

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository({
    this.reporterEmail = 'reporter@example.com',
    this.targetTitle = '운영 검수 대상',
    this.includeClosedLetterReport = false,
  });

  final List<AdminReportActionDraft> actions = [];
  AdminReportActionResult? lastResult;
  final String reporterEmail;
  final String targetTitle;
  final bool includeClosedLetterReport;

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
      if (includeClosedLetterReport)
        AdminReportSummary(
          id: 4,
          targetId: 12,
          targetType: ReportTargetType.letter,
          reason: 'SPAM',
          content: '반복 신고된 편지입니다.',
          status: 'RESOLVED',
          createdAt: '2026-05-24T09:00:00',
          targetTitle: '완료된 편지 신고',
          targetPreview: '처리된 편지입니다.',
          reporter: _member(
            id: 5,
            email: 'letter-reporter@example.com',
            nickname: '편지신고자',
          ),
          targetOwner: _member(
            id: 6,
            email: 'letter-owner@example.com',
            nickname: '편지작성자',
          ),
          actionReason: '검수 완료',
          handledBy: _member(
            id: 1,
            email: 'admin@example.com',
            nickname: '관리자',
          ),
          handledAt: '2026-05-24T09:10:00',
        ),
    ];
  }

  @override
  Future<AdminReportDetail> fetchAdminReport(int id) async {
    if (id == 4) {
      return AdminReportDetail(
        id: id,
        targetId: 12,
        targetType: ReportTargetType.letter,
        reason: 'SPAM',
        content: '반복 신고된 편지입니다.',
        status: 'RESOLVED',
        createdAt: '2026-05-24T09:00:00',
        target: const AdminReportTarget(
          id: 12,
          type: ReportTargetType.letter,
          title: '완료된 편지 신고',
          preview: '처리된 편지입니다.',
          ownerId: 6,
        ),
        reporter: _member(
          id: 5,
          email: 'letter-reporter@example.com',
          nickname: '편지신고자',
        ),
        targetOwner: _member(
          id: 6,
          email: 'letter-owner@example.com',
          nickname: '편지작성자',
        ),
        actionReason: '검수 완료',
        handledBy: _member(
          id: 1,
          email: 'admin@example.com',
          nickname: '관리자',
        ),
        handledAt: '2026-05-24T09:10:00',
      );
    }

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
  _FakeOperationsRepository({
    MobileApiMetricsSnapshot? metrics,
    this.metricsError,
    this.systemStatus,
  }) : metrics = metrics ?? _metrics();

  final List<String?> memberQueries = [];
  final List<String?> letterQueries = [];
  final List<_StatusAction> statusActions = [];
  final List<_LetterNoteAction> letterNotes = [];
  final List<_LetterReassignAction> reassignActions = [];
  final List<int> blockedLetterIds = [];
  final MobileApiMetricsSnapshot metrics;
  final Object? metricsError;
  final OperationsSystemStatus? systemStatus;
  int currentReceiverId = 7;
  int metricsFetchCount = 0;
  int systemStatusFetchCount = 0;

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
  Future<MobileApiMetricsSnapshot> fetchApiMetrics() async {
    metricsFetchCount += 1;
    final error = metricsError;
    if (error != null) {
      throw error;
    }
    return metrics;
  }

  @override
  Future<OperationsSystemStatus> fetchSystemStatus(
    OperationsSystemEnvironment environment,
  ) async {
    systemStatusFetchCount += 1;
    return systemStatus ?? OperationsSystemStatus.connected(environment);
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
    final content = query == 'receiver'
        ? [
            _member(
              id: 8,
              email: 'receiver@example.com',
              nickname: '새 수신자',
            ),
          ]
        : [_member()];
    return AdminMemberPage(
      content: content,
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

  @override
  Future<AdminLetterPage> fetchLetters({
    String? status,
    String? query,
    int page = 0,
    int size = 20,
  }) async {
    letterQueries.add(query);
    return AdminLetterPage(
      content: [_letterSummary()],
      page: page,
      size: size,
      totalElements: 1,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<AdminLetterDetail> fetchLetterDetail(int id) async {
    return _letterDetail(id: id);
  }

  @override
  Future<AdminLetterActionResult> addLetterNote({
    required int letterId,
    required String note,
    required String reason,
  }) async {
    letterNotes.add(_LetterNoteAction(letterId, note, reason));
    return AdminLetterActionResult(
      letter: _letterDetail(id: letterId),
      latestAudit: _letterAudit('LETTER_NOTE', reason),
      revokedRefreshTokenCount: 0,
      disabledDeviceTokenCount: 0,
    );
  }

  @override
  Future<AdminLetterActionResult> reassignLetterReceiver({
    required int letterId,
    required int receiverMemberId,
    required String reason,
  }) async {
    reassignActions.add(
      _LetterReassignAction(letterId, receiverMemberId, reason),
    );
    currentReceiverId = receiverMemberId;
    return AdminLetterActionResult(
      letter: _letterDetail(id: letterId),
      latestAudit: _letterAudit('LETTER_REASSIGN', reason),
      revokedRefreshTokenCount: 0,
      disabledDeviceTokenCount: 0,
    );
  }

  @override
  Future<AdminLetterActionResult> blockLetterSender({
    required int letterId,
    required String reason,
  }) async {
    blockedLetterIds.add(letterId);
    return AdminLetterActionResult(
      letter: _letterDetail(id: letterId),
      latestAudit: _letterAudit('LETTER_SENDER_BLOCK', reason),
      revokedRefreshTokenCount: 1,
      disabledDeviceTokenCount: 1,
    );
  }

  AdminMemberSummary _member({
    int id = 7,
    String email = 'member@example.com',
    String nickname = '회원',
    String status = 'ACTIVE',
    String role = 'USER',
  }) {
    return AdminMemberSummary(
      id: id,
      email: email,
      nickname: nickname,
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

  AdminLetterSummary _letterSummary() {
    return AdminLetterSummary(
      id: 12,
      title: '운영 편지',
      sender: _memberLabel(
        id: 3,
        email: 'sender@example.com',
        nickname: '발신자',
      ),
      receiver: _memberLabel(
        id: currentReceiverId,
        email: 'receiver@example.com',
        nickname: '수신자',
      ),
      status: 'SENT',
      createdAt: '2026-05-25T09:20:00',
      originalSummary: '검수가 필요한 편지 요약입니다.',
      replySummary: null,
      availableReceiverCount: 3,
      actionCount: 1,
    );
  }

  AdminLetterDetail _letterDetail({required int id}) {
    return AdminLetterDetail(
      id: id,
      title: '운영 편지',
      sender: _memberLabel(
        id: 3,
        email: 'sender@example.com',
        nickname: '발신자',
      ),
      receiver: _memberLabel(
        id: currentReceiverId,
        email: 'receiver@example.com',
        nickname: '수신자',
      ),
      receivers: [
        _memberLabel(
          id: currentReceiverId,
          email: 'receiver@example.com',
          nickname: '수신자',
        ),
      ],
      status: 'SENT',
      createdAt: '2026-05-25T09:20:00',
      replyCreatedAt: null,
      originalSummary: '검수가 필요한 편지 요약입니다.',
      replySummary: null,
      auditEvents: [_letterAudit('LETTER_NOTE', '운영 확인')],
    );
  }

  AdminAuditEvent _letterAudit(String action, String reason) {
    return AdminAuditEvent(
      id: 10,
      targetMemberId: 3,
      actorMemberId: 1,
      action: action,
      previousValue: 'SENT',
      newValue: 'SENT',
      reason: reason,
      createdAt: '2026-05-25T09:30:00',
    );
  }
}

OperationsAdminProfile _adminProfile() {
  return const OperationsAdminProfile(
    id: 1,
    email: 'admin@example.com',
    nickname: '운영자',
    role: 'ADMIN',
    status: 'ACTIVE',
  );
}

OperationsSystemEnvironment _systemEnvironment({
  String observabilityToolUrl = 'https://observe.maum-on.test/mobile',
}) {
  return OperationsSystemEnvironment(
    apiEndpoint: 'https://api.maum-on.test',
    appVersion: '0.1.0',
    buildNumber: '1',
    platform: 'Android',
    observabilityToolUrl: observabilityToolUrl,
  );
}

MobileApiMetricsSnapshot _metrics() {
  return const MobileApiMetricsSnapshot(
    sampleCount: 5,
    endpoints: [
      MobileApiEndpointMetrics(
        endpoint: 'GET /api/v1/home/stats',
        requestCount: 3,
        successRate: 0.66,
        p95LatencyMs: 1320,
        errorCodes: {'500': 1},
      ),
      MobileApiEndpointMetrics(
        endpoint: 'POST /api/v1/telemetry/events',
        requestCount: 2,
        successRate: 1,
        p95LatencyMs: 210,
        errorCodes: {},
      ),
    ],
    writeRecovery: MobileWriteRecoveryMetrics(
      duplicatePreventions: {'diary': 1},
      imageLifecycle: {'compressed': 2},
    ),
    notifications: MobileNotificationMetrics(
      pushDelivery: {'ANDROID.delivered': 3, 'IOS.permanent_failure': 2},
    ),
    ai: MobileAiMetrics(
      model: {'consultation.success': 2, 'consultation.fallback': 1},
      contentModeration: {'POST.HIGH.blocked': 1},
      consultationSafety: {'SELF_HARM.ESCALATE': 1},
    ),
    client: MobileClientTelemetryMetrics(
      events: {
        'APP_START': 1,
        'SCREEN_VIEW': 3,
        'API_ERROR': 1,
        'CRASH_SIGNAL': 1,
        'ANR_SIGNAL': 1,
        'WRITE_RECOVERY': 2,
      },
      routes: {'/home': 3, '/letter': 2},
      platforms: {'ANDROID': 3, 'IOS': 2},
      appVersions: {'1.0.0': 5},
      networkStatus: {'WIFI': 4, 'CELLULAR': 1},
      p95DurationMs: {'APP_START': 420, 'SCREEN_VIEW': 180},
      dropped: {'sampled_out': 1},
    ),
  );
}

class _StatusAction {
  const _StatusAction(this.memberId, this.status, this.reason);

  final int memberId;
  final String status;
  final String reason;
}

class _LetterNoteAction {
  const _LetterNoteAction(this.letterId, this.note, this.reason);

  final int letterId;
  final String note;
  final String reason;
}

class _LetterReassignAction {
  const _LetterReassignAction(
    this.letterId,
    this.receiverMemberId,
    this.reason,
  );

  final int letterId;
  final int receiverMemberId;
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

AdminReportMember _memberLabel({
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

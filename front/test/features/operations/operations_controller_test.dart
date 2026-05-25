import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/operations/application/operations_controller.dart';
import 'package:maum_on_mobile_front/features/operations/data/operations_repository.dart';
import 'package:maum_on_mobile_front/features/operations/domain/operations_models.dart';
import 'package:maum_on_mobile_front/features/report/data/report_repository.dart';
import 'package:maum_on_mobile_front/features/report/domain/report_models.dart';

void main() {
  test('refreshes observability metrics without changing the current view',
      () async {
    final repository = _MetricsOperationsRepository(metrics: _metrics());
    final controller = OperationsController(
      reportRepository: _NoopReportRepository(),
      operationsRepository: repository,
    );
    addTearDown(controller.dispose);

    await controller.refreshObservability();

    expect(repository.metricsCalls, 1);
    expect(controller.state.view, OperationsView.dashboard);
    expect(controller.state.hasMetricsLoaded, isTrue);
    expect(controller.state.apiMetrics?.sampleCount, 3);
    expect(controller.state.apiMetrics?.apiErrorCount, 1);
    expect(controller.state.metricsErrorMessage, isNull);
  });

  test('marks empty observability metrics as a loaded empty state', () async {
    final controller = OperationsController(
      reportRepository: _NoopReportRepository(),
      operationsRepository: _MetricsOperationsRepository(
        metrics: const MobileApiMetricsSnapshot(
          sampleCount: 0,
          endpoints: [],
        ),
      ),
    );
    addTearDown(controller.dispose);

    await controller.refreshObservability();

    expect(controller.state.hasMetricsLoaded, isTrue);
    expect(controller.state.isMetricsEmpty, isTrue);
    expect(controller.state.isMetricsLoading, isFalse);
  });

  test('keeps observability errors separate from global operation errors',
      () async {
    final controller = OperationsController(
      reportRepository: _NoopReportRepository(),
      operationsRepository: _MetricsOperationsRepository(
        error: const ApiClientException(
          kind: ApiErrorKind.forbidden,
          message: '운영 지표 권한이 없습니다.',
          statusCode: 403,
        ),
      ),
    );
    addTearDown(controller.dispose);

    await controller.refreshObservability();

    expect(controller.state.hasMetricsLoaded, isTrue);
    expect(controller.state.errorMessage, isNull);
    expect(controller.state.metricsErrorMessage, '운영 지표 권한이 없습니다.');
    expect(controller.state.isMetricsPermissionError, isTrue);
  });
}

MobileApiMetricsSnapshot _metrics() {
  return const MobileApiMetricsSnapshot(
    sampleCount: 3,
    endpoints: [
      MobileApiEndpointMetrics(
        endpoint: 'GET /api/v1/home/stats',
        requestCount: 3,
        successRate: 0.66,
        p95LatencyMs: 1300,
        errorCodes: {'500': 1},
      ),
    ],
    client: MobileClientTelemetryMetrics(
      events: {
        'APP_START': 1,
        'SCREEN_VIEW': 2,
        'API_ERROR': 1,
        'WRITE_RECOVERY': 1,
      },
      routes: {'/home': 2},
      platforms: {'ANDROID': 2},
      networkStatus: {'WIFI': 2},
      p95DurationMs: {'APP_START': 400},
    ),
  );
}

class _MetricsOperationsRepository implements OperationsRepository {
  _MetricsOperationsRepository({this.metrics, this.error});

  final MobileApiMetricsSnapshot? metrics;
  final Object? error;
  int metricsCalls = 0;

  @override
  Future<MobileApiMetricsSnapshot> fetchApiMetrics() async {
    metricsCalls += 1;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return metrics!;
  }

  @override
  Future<OperationsDashboard> fetchDashboard() {
    throw UnimplementedError();
  }

  @override
  Future<AdminMemberPage> fetchMembers({
    String? query,
    String? status,
    String? role,
    bool? socialAccount,
    int page = 0,
    int size = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminMemberDetail> fetchMemberDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<AdminMemberActionResult> updateMemberStatus({
    required int memberId,
    required String status,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminMemberActionResult> updateMemberRole({
    required int memberId,
    required String role,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminSessionRevokeResult> revokeMemberSessions({
    required int memberId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminLetterPage> fetchLetters({
    String? status,
    String? query,
    int page = 0,
    int size = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminLetterDetail> fetchLetterDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<AdminLetterActionResult> addLetterNote({
    required int letterId,
    required String note,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminLetterActionResult> reassignLetterReceiver({
    required int letterId,
    required int receiverMemberId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminLetterActionResult> blockLetterSender({
    required int letterId,
    required String reason,
  }) {
    throw UnimplementedError();
  }
}

class _NoopReportRepository implements ReportRepository {
  @override
  Future<int> createReport(ReportDraft draft) {
    throw UnimplementedError();
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

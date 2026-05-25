import '../../../core/network/api_client.dart';
import '../domain/report_models.dart';

abstract interface class ReportRepository {
  Future<int> createReport(ReportDraft draft);

  Future<List<AdminReportSummary>> fetchAdminReports();

  Future<AdminReportDetail> fetchAdminReport(int id);

  Future<AdminReportActionResult> updateAdminReportStatus(
    int id,
    AdminReportActionDraft draft,
  );
}

class ApiReportRepository implements ReportRepository {
  const ApiReportRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<int> createReport(ReportDraft draft) {
    return _apiClient.post<int>(
      '/api/v1/reports',
      body: draft.toJson(),
      parser: _parseReportId,
    );
  }

  @override
  Future<List<AdminReportSummary>> fetchAdminReports() {
    return _apiClient.get<List<AdminReportSummary>>(
      '/api/v1/admin/reports',
      parser: (json) {
        if (json is! List) {
          throw const FormatException('Expected admin report list.');
        }

        return json.map(AdminReportSummary.fromJson).toList(growable: false);
      },
    );
  }

  @override
  Future<AdminReportDetail> fetchAdminReport(int id) {
    return _apiClient.get<AdminReportDetail>(
      '/api/v1/admin/reports/$id',
      parser: AdminReportDetail.fromJson,
    );
  }

  @override
  Future<AdminReportActionResult> updateAdminReportStatus(
    int id,
    AdminReportActionDraft draft,
  ) {
    return _apiClient.patch<AdminReportActionResult>(
      '/api/v1/admin/reports/$id/status',
      body: draft.toJson(),
      parser: AdminReportActionResult.fromJson,
    );
  }
}

int _parseReportId(Object? json) {
  if (json is int) {
    return json;
  }

  if (json is num) {
    return json.toInt();
  }

  final parsed = int.tryParse(json?.toString() ?? '');
  if (parsed == null) {
    throw const FormatException('Expected report id.');
  }

  return parsed;
}

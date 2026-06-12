import '../../../core/network/api_client.dart';
import '../domain/report_models.dart';

abstract interface class ReportRepository {
  Future<int> createReport(ReportDraft draft);
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

import '../../../core/network/api_client.dart';
import '../domain/admin_models.dart';

abstract interface class AdminRepository {
  Future<AdminDashboard> fetchDashboard();

  Future<List<AdminReportSummary>> fetchReports({
    String? status,
    String? targetType,
    String? sort,
  });

  Future<AdminMemberPage> fetchMembers({
    String? query,
    String? status,
    String? role,
    bool? socialAccount,
    int page = 0,
    int size = 20,
  });

  Future<AdminLetterPage> fetchLetters({
    String? status,
    String? query,
    int page = 0,
    int size = 20,
  });

  Future<AdminModerationSummary> fetchModerationSummary();
}

class ApiAdminRepository implements AdminRepository {
  const ApiAdminRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<AdminDashboard> fetchDashboard() {
    return _apiClient.get<AdminDashboard>(
      '/api/v1/admin/dashboard',
      parser: AdminDashboard.fromJson,
    );
  }

  @override
  Future<List<AdminReportSummary>> fetchReports({
    String? status,
    String? targetType,
    String? sort,
  }) {
    return _apiClient.get<List<AdminReportSummary>>(
      '/api/v1/admin/reports',
      queryParameters: _withoutNulls({
        'status': status,
        'targetType': targetType,
        'sort': sort,
      }),
      parser: (json) => _asList(json)
          .map(AdminReportSummary.fromJson)
          .toList(growable: false),
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
  }) {
    return _apiClient.get<AdminMemberPage>(
      '/api/v1/admin/members',
      queryParameters: _withoutNulls({
        'query': query,
        'status': status,
        'role': role,
        'socialAccount': socialAccount,
        'page': page,
        'size': size,
      }),
      parser: AdminMemberPage.fromJson,
    );
  }

  @override
  Future<AdminLetterPage> fetchLetters({
    String? status,
    String? query,
    int page = 0,
    int size = 20,
  }) {
    return _apiClient.get<AdminLetterPage>(
      '/api/v1/admin/letters',
      queryParameters: _withoutNulls({
        'status': status,
        'query': query,
        'page': page,
        'size': size,
      }),
      parser: AdminLetterPage.fromJson,
    );
  }

  @override
  Future<AdminModerationSummary> fetchModerationSummary() {
    return _apiClient.get<AdminModerationSummary>(
      '/api/v1/admin/moderation/summary',
      parser: AdminModerationSummary.fromJson,
    );
  }
}

Map<String, Object?> _withoutNulls(Map<String, Object?> values) {
  return {
    for (final entry in values.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}

List<Object?> _asList(Object? json) {
  if (json == null) {
    return const [];
  }
  if (json is List<Object?>) {
    return json;
  }
  if (json is List) {
    return json.cast<Object?>();
  }
  throw FormatException('Expected list, got ${json.runtimeType}');
}

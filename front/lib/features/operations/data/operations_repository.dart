import '../../../core/network/api_client.dart';
import '../domain/operations_models.dart';

abstract interface class OperationsRepository {
  Future<OperationsDashboard> fetchDashboard();

  Future<AdminMemberPage> fetchMembers({
    String? query,
    String? status,
    String? role,
    bool? socialAccount,
    int page = 0,
    int size = 20,
  });

  Future<AdminMemberDetail> fetchMemberDetail(int id);

  Future<AdminMemberActionResult> updateMemberStatus({
    required int memberId,
    required String status,
    required String reason,
  });

  Future<AdminMemberActionResult> updateMemberRole({
    required int memberId,
    required String role,
    required String reason,
  });

  Future<AdminSessionRevokeResult> revokeMemberSessions({
    required int memberId,
    required String reason,
  });
}

class ApiOperationsRepository implements OperationsRepository {
  const ApiOperationsRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<OperationsDashboard> fetchDashboard() {
    return _apiClient.get<OperationsDashboard>(
      '/api/v1/admin/dashboard',
      parser: OperationsDashboard.fromJson,
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
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (role != null && role.isNotEmpty) 'role': role,
        if (socialAccount != null) 'socialAccount': socialAccount,
        'page': page,
        'size': size,
      },
      parser: AdminMemberPage.fromJson,
    );
  }

  @override
  Future<AdminMemberDetail> fetchMemberDetail(int id) {
    return _apiClient.get<AdminMemberDetail>(
      '/api/v1/admin/members/$id',
      parser: AdminMemberDetail.fromJson,
    );
  }

  @override
  Future<AdminMemberActionResult> updateMemberStatus({
    required int memberId,
    required String status,
    required String reason,
  }) {
    return _apiClient.patch<AdminMemberActionResult>(
      '/api/v1/admin/members/$memberId/status',
      body: {'status': status, 'reason': reason},
      parser: AdminMemberActionResult.fromJson,
    );
  }

  @override
  Future<AdminMemberActionResult> updateMemberRole({
    required int memberId,
    required String role,
    required String reason,
  }) {
    return _apiClient.patch<AdminMemberActionResult>(
      '/api/v1/admin/members/$memberId/role',
      body: {'role': role, 'reason': reason},
      parser: AdminMemberActionResult.fromJson,
    );
  }

  @override
  Future<AdminSessionRevokeResult> revokeMemberSessions({
    required int memberId,
    required String reason,
  }) {
    return _apiClient.post<AdminSessionRevokeResult>(
      '/api/v1/admin/members/$memberId/sessions/revoke',
      body: {'reason': reason},
      parser: AdminSessionRevokeResult.fromJson,
    );
  }
}

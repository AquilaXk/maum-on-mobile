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

  Future<AdminLetterPage> fetchLetters({
    String? status,
    String? query,
    int page = 0,
    int size = 20,
  });

  Future<AdminLetterDetail> fetchLetterDetail(int id);

  Future<AdminLetterActionResult> addLetterNote({
    required int letterId,
    required String note,
    required String reason,
  });

  Future<AdminLetterActionResult> reassignLetterReceiver({
    required int letterId,
    required int receiverMemberId,
    required String reason,
  });

  Future<AdminLetterActionResult> blockLetterSender({
    required int letterId,
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

  @override
  Future<AdminLetterPage> fetchLetters({
    String? status,
    String? query,
    int page = 0,
    int size = 20,
  }) {
    return _apiClient.get<AdminLetterPage>(
      '/api/v1/admin/letters',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        'page': page,
        'size': size,
      },
      parser: AdminLetterPage.fromJson,
    );
  }

  @override
  Future<AdminLetterDetail> fetchLetterDetail(int id) {
    return _apiClient.get<AdminLetterDetail>(
      '/api/v1/admin/letters/$id',
      parser: AdminLetterDetail.fromJson,
    );
  }

  @override
  Future<AdminLetterActionResult> addLetterNote({
    required int letterId,
    required String note,
    required String reason,
  }) {
    return _apiClient.post<AdminLetterActionResult>(
      '/api/v1/admin/letters/$letterId/notes',
      body: {'note': note, 'reason': reason},
      parser: AdminLetterActionResult.fromJson,
    );
  }

  @override
  Future<AdminLetterActionResult> reassignLetterReceiver({
    required int letterId,
    required int receiverMemberId,
    required String reason,
  }) {
    return _apiClient.post<AdminLetterActionResult>(
      '/api/v1/admin/letters/$letterId/reassign',
      body: {'receiverMemberId': receiverMemberId, 'reason': reason},
      parser: AdminLetterActionResult.fromJson,
    );
  }

  @override
  Future<AdminLetterActionResult> blockLetterSender({
    required int letterId,
    required String reason,
  }) {
    return _apiClient.post<AdminLetterActionResult>(
      '/api/v1/admin/letters/$letterId/sender/block',
      body: {'reason': reason},
      parser: AdminLetterActionResult.fromJson,
    );
  }
}

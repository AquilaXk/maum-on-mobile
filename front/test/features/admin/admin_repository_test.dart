import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/admin/data/admin_repository.dart';

void main() {
  group('ApiAdminRepository', () {
    test('loads the admin dashboard through the admin API boundary', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'todayReportCount': 2,
            'openReportCount': 3,
            'processedReportCount': 5,
            'todayLetterCount': 7,
            'todayDiaryCount': 11,
            'receivableMemberCount': 13,
            'blockedMemberCount': 17,
            'adminMemberCount': 19,
            'unassignedLetterCount': 23,
            'todayAdminActionCount': 29,
          },
        }),
      ]);
      final repository = ApiAdminRepository(
        apiClient: ApiClient(
          transport: transport,
          tokenStore: MemoryAuthTokenStore(
            initialTokens: const TokenPair(
              accessToken: 'admin-access',
              refreshToken: 'admin-refresh',
            ),
          ),
        ),
      );

      final dashboard = await repository.fetchDashboard();

      expect(dashboard.todayReportCount, 2);
      expect(dashboard.openReportCount, 3);
      expect(dashboard.todayAdminActionCount, 29);
      expect(transport.requests.single.path, '/api/v1/admin/dashboard');
      expect(transport.requests.single.requiresAuth, isTrue);
      expect(
        transport.requests.single.headers['Authorization'],
        'Bearer admin-access',
      );
    });

    test('requests each admin collection from the dedicated admin paths',
        () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': [
            _reportJson(id: 1),
          ],
        }),
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'content': [
              _memberJson(id: 7),
            ],
            'page': 0,
            'size': 20,
            'totalElements': 1,
            'totalPages': 1,
            'last': true,
          },
        }),
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'content': [
              _letterJson(id: 9),
            ],
            'page': 0,
            'size': 20,
            'totalElements': 1,
            'totalPages': 1,
            'last': true,
          },
        }),
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'totalCount': 10,
            'blockedCount': 4,
            'modelFailureCount': 1,
            'failureRate': 0.1,
            'highRiskCategories': {'abuse': 3},
            'modelStatuses': {'ALLOW': 6, 'BLOCK': 4},
            'targets': {'LETTER': 5, 'STORY': 5},
            'recentFailures': [],
          },
        }),
      ]);
      final repository = ApiAdminRepository(
        apiClient: ApiClient(
          transport: transport,
          tokenStore: MemoryAuthTokenStore(
            initialTokens: const TokenPair(
              accessToken: 'admin-access',
              refreshToken: 'admin-refresh',
            ),
          ),
        ),
      );

      final reports = await repository.fetchReports(status: 'OPEN');
      final members = await repository.fetchMembers(query: 'maum');
      final letters = await repository.fetchLetters(status: 'UNASSIGNED');
      final moderation = await repository.fetchModerationSummary();

      expect(reports.single.targetTitle, '신고된 글');
      expect(members.content.single.email, 'member7@example.com');
      expect(letters.content.single.title, '확인할 편지');
      expect(moderation.blockedCount, 4);
      expect(
        transport.requests.map((request) => request.path),
        [
          '/api/v1/admin/reports',
          '/api/v1/admin/members',
          '/api/v1/admin/letters',
          '/api/v1/admin/moderation/summary',
        ],
      );
      expect(transport.requests[0].queryParameters['status'], 'OPEN');
      expect(transport.requests[1].queryParameters['query'], 'maum');
      expect(transport.requests[2].queryParameters['status'], 'UNASSIGNED');
      expect(
        transport.requests.every((request) => request.requiresAuth),
        isTrue,
      );
    });

    test('parses reports whose target owner is absent', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': [
            _reportJson(id: 1, targetOwner: null),
          ],
        }),
      ]);
      final repository = ApiAdminRepository(
        apiClient: ApiClient(
          transport: transport,
          tokenStore: MemoryAuthTokenStore(
            initialTokens: const TokenPair(
              accessToken: 'admin-access',
              refreshToken: 'admin-refresh',
            ),
          ),
        ),
      );

      final reports = await repository.fetchReports();

      expect(reports.single.targetOwner, isNull);
      expect(reports.single.targetTitle, '신고된 글');
    });
  });
}

const _defaultTargetOwnerJson = {
  'id': 2,
  'email': 'owner@example.com',
  'nickname': '작성자',
};

Map<String, Object?> _reportJson({
  required int id,
  Object? targetOwner = _defaultTargetOwnerJson,
}) {
  return {
    'id': id,
    'targetType': 'POST',
    'targetId': 33,
    'targetTitle': '신고된 글',
    'targetOwner': targetOwner,
    'reporter': {
      'id': 3,
      'email': 'reporter@example.com',
      'nickname': '신고자',
    },
    'reason': 'ABUSE',
    'status': 'OPEN',
    'createdAt': '2026-06-12T09:00:00Z',
    'actionCount': 0,
  };
}

Map<String, Object?> _memberJson({required int id}) {
  return {
    'id': id,
    'email': 'member$id@example.com',
    'nickname': '회원$id',
    'role': 'USER',
    'status': 'ACTIVE',
    'socialAccount': false,
    'randomReceiveAllowed': true,
    'reportCount': 1,
    'postCount': 2,
    'letterCount': 3,
    'diaryCount': 4,
  };
}

Map<String, Object?> _letterJson({required int id}) {
  return {
    'id': id,
    'title': '확인할 편지',
    'sender': {
      'id': 4,
      'email': 'sender@example.com',
      'nickname': '보낸이',
    },
    'receiver': null,
    'status': 'UNASSIGNED',
    'createdAt': '2026-06-12T09:10:00Z',
    'originalSummary': '편지 본문 요약',
    'replySummary': null,
    'availableReceiverCount': 8,
    'actionCount': 1,
  };
}

class _FakeApiTransport implements ApiTransport {
  _FakeApiTransport(this._responses);

  final List<ApiTransportResponse> _responses;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiTransportResponse> send(ApiRequest request) async {
    requests.add(request);

    if (_responses.isEmpty) {
      throw const ApiTransportException('No fake response configured');
    }

    return _responses.removeAt(0);
  }
}

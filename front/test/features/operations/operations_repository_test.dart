import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/operations/data/operations_repository.dart';

void main() {
  test('loads dashboard, members, member detail, and member actions', () async {
    final transport = _FakeApiTransport([
      ApiTransportResponse.ok({
        'resultCode': '200-1',
        'data': {
          'todayReportCount': 2,
          'openReportCount': 1,
          'processedReportCount': 1,
          'todayLetterCount': 3,
          'todayDiaryCount': 4,
          'receivableMemberCount': 5,
        },
      }),
      ApiTransportResponse.ok({
        'resultCode': '200-2',
        'data': {
          'content': [
            {
              'id': 7,
              'email': 'member@example.com',
              'nickname': '회원',
              'role': 'USER',
              'status': 'ACTIVE',
              'socialAccount': false,
              'randomReceiveAllowed': true,
              'reportCount': 1,
              'postCount': 2,
              'letterCount': 3,
              'diaryCount': 4,
            },
          ],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
          'last': true,
        },
      }),
      ApiTransportResponse.ok({
        'resultCode': '200-3',
        'data': _memberDetailJson(),
      }),
      ApiTransportResponse.ok({
        'resultCode': '200-4',
        'data': {
          'status': 'BLOCKED',
          'role': 'USER',
          'member': _memberJson(status: 'BLOCKED'),
          'latestAudit': _auditJson('STATUS_CHANGE'),
        },
      }),
      ApiTransportResponse.ok({
        'resultCode': '200-5',
        'data': {
          'revokedRefreshTokenCount': 1,
          'disabledDeviceTokenCount': 1,
          'latestAudit': _auditJson('SESSION_REVOKE'),
        },
      }),
    ]);
    final repository = ApiOperationsRepository(
      apiClient: ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      ),
    );

    final dashboard = await repository.fetchDashboard();
    final members = await repository.fetchMembers(
      query: 'member',
      status: 'ACTIVE',
      role: 'USER',
      socialAccount: false,
    );
    final detail = await repository.fetchMemberDetail(7);
    final status = await repository.updateMemberStatus(
      memberId: 7,
      status: 'BLOCKED',
      reason: '반복 신고로 차단',
    );
    final revoke = await repository.revokeMemberSessions(
      memberId: 7,
      reason: '분실 기기 회수',
    );

    expect(dashboard.openReportCount, 1);
    expect(transport.requests[0].path, '/api/v1/admin/dashboard');
    expect(transport.requests[1].path, '/api/v1/admin/members');
    expect(transport.requests[1].queryParameters['query'], 'member');
    expect(transport.requests[1].queryParameters['status'], 'ACTIVE');
    expect(transport.requests[1].queryParameters['role'], 'USER');
    expect(transport.requests[1].queryParameters['socialAccount'], false);
    expect(members.content.single.email, 'member@example.com');
    expect(detail.member.nickname, '회원');
    expect(detail.posts.single.title, '작성글');
    expect(transport.requests[3].path, '/api/v1/admin/members/7/status');
    expect(transport.requests[3].method, ApiMethod.patch);
    expect(transport.requests[3].body, {
      'status': 'BLOCKED',
      'reason': '반복 신고로 차단',
    });
    expect(status.member.status, 'BLOCKED');
    expect(transport.requests[4].path, '/api/v1/admin/members/7/sessions/revoke');
    expect(transport.requests[4].method, ApiMethod.post);
    expect(revoke.revokedRefreshTokenCount, 1);
  });
}

Map<String, Object?> _memberJson({String status = 'ACTIVE'}) {
  return {
    'id': 7,
    'email': 'member@example.com',
    'nickname': '회원',
    'role': 'USER',
    'status': status,
    'socialAccount': false,
    'randomReceiveAllowed': true,
    'reportCount': 1,
    'postCount': 2,
    'letterCount': 3,
    'diaryCount': 4,
  };
}

Map<String, Object?> _memberDetailJson() {
  return {
    'member': _memberJson(),
    'reports': [
      {
        'id': 1,
        'targetId': 10,
        'targetType': 'POST',
        'reason': 'SPAM',
        'content': '신고 내용',
        'status': 'RECEIVED',
        'createdAt': '2026-05-25T09:00:00',
        'targetTitle': '신고 대상',
        'targetPreview': '본문',
        'reporter': {
          'id': 7,
          'email': 'member@example.com',
          'nickname': '회원',
          'role': 'USER',
          'status': 'ACTIVE',
        },
        'targetOwner': null,
        'actionReason': null,
        'handledBy': null,
        'handledAt': null,
      },
    ],
    'posts': [
      {
        'id': 10,
        'title': '작성글',
        'status': 'ONGOING',
        'createdAt': '2026-05-25T09:00:00',
      },
    ],
    'letters': [],
    'diaries': [],
    'auditEvents': [_auditJson('STATUS_CHANGE')],
  };
}

Map<String, Object?> _auditJson(String action) {
  return {
    'id': 3,
    'targetMemberId': 7,
    'actorMemberId': 1,
    'action': action,
    'previousValue': 'ACTIVE',
    'newValue': 'BLOCKED',
    'reason': '반복 신고로 차단',
    'createdAt': '2026-05-25T09:10:00',
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

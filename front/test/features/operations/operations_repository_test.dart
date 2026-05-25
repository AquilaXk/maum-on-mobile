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

  test('loads letters, letter detail, and letter actions', () async {
    final transport = _FakeApiTransport([
      ApiTransportResponse.ok({
        'resultCode': '200-1',
        'data': {
          'content': [_letterSummaryJson()],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
          'last': true,
        },
      }),
      ApiTransportResponse.ok({
        'resultCode': '200-2',
        'data': _letterDetailJson(),
      }),
      ApiTransportResponse.ok({
        'resultCode': '200-3',
        'data': _letterActionResultJson(),
      }),
      ApiTransportResponse.ok({
        'resultCode': '200-4',
        'data': _letterActionResultJson(receiverId: 8),
      }),
      ApiTransportResponse.ok({
        'resultCode': '200-5',
        'data': _letterActionResultJson(revokedRefreshTokenCount: 2),
      }),
    ]);
    final repository = ApiOperationsRepository(
      apiClient: ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      ),
    );

    final letters = await repository.fetchLetters(
      query: '운영',
      status: 'SENT',
    );
    final detail = await repository.fetchLetterDetail(12);
    final note = await repository.addLetterNote(
      letterId: 12,
      note: '상담 이관',
      reason: '운영 확인',
    );
    final reassign = await repository.reassignLetterReceiver(
      letterId: 12,
      receiverMemberId: 8,
      reason: '수신자 변경',
    );
    final block = await repository.blockLetterSender(
      letterId: 12,
      reason: '반복 악용',
    );

    expect(letters.content.single.title, '운영 편지');
    expect(transport.requests[0].path, '/api/v1/admin/letters');
    expect(transport.requests[0].queryParameters['query'], '운영');
    expect(transport.requests[0].queryParameters['status'], 'SENT');
    expect(detail.sender.nickname, '발신자');
    expect(transport.requests[1].path, '/api/v1/admin/letters/12');
    expect(transport.requests[2].path, '/api/v1/admin/letters/12/notes');
    expect(transport.requests[2].method, ApiMethod.post);
    expect(transport.requests[2].body, {
      'note': '상담 이관',
      'reason': '운영 확인',
    });
    expect(note.letter.id, 12);
    expect(transport.requests[3].path, '/api/v1/admin/letters/12/reassign');
    expect(transport.requests[3].body, {
      'receiverMemberId': 8,
      'reason': '수신자 변경',
    });
    expect(reassign.letter.receiver?.id, 8);
    expect(
      transport.requests[4].path,
      '/api/v1/admin/letters/12/sender/block',
    );
    expect(transport.requests[4].body, {'reason': '반복 악용'});
    expect(block.revokedRefreshTokenCount, 2);
  });

  test('loads mobile api metrics for operations observability', () async {
    final transport = _FakeApiTransport([
      ApiTransportResponse.ok({
        'resultCode': '200-1',
        'data': _metricsJson(),
      }),
    ]);
    final repository = ApiOperationsRepository(
      apiClient: ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      ),
    );

    final metrics = await repository.fetchApiMetrics();

    expect(transport.requests.single.path, '/api/v1/observability/api-metrics');
    expect(transport.requests.single.method, ApiMethod.get);
    expect(metrics.sampleCount, 4);
    expect(metrics.endpoints.single.endpoint, 'GET /api/v1/home/stats');
    expect(metrics.endpoints.single.errorCodes['500'], 1);
    expect(metrics.client.eventCount('APP_START'), 2);
    expect(metrics.client.p95DurationMs['APP_START'], 420);
    expect(metrics.writeRecovery.duplicatePreventions['diary'], 1);
  });
}

Map<String, Object?> _metricsJson() {
  return {
    'sampleCount': 4,
    'endpoints': [
      {
        'endpoint': 'GET /api/v1/home/stats',
        'requestCount': 4,
        'successRate': 0.75,
        'p95LatencyMs': 1320,
        'errorCodes': {'500': 1},
      },
    ],
    'writeRecovery': {
      'duplicatePreventions': {'diary': 1},
      'imageLifecycle': {'compressed': 2},
    },
    'notifications': {
      'pushDelivery': {'ANDROID.delivered': 3},
    },
    'ai': {
      'model': {'consultation.success': 2},
      'contentModeration': {'POST.HIGH.blocked': 1},
      'consultationSafety': {'SELF_HARM.ESCALATE': 1},
    },
    'client': {
      'events': {
        'APP_START': 2,
        'SCREEN_VIEW': 3,
        'API_ERROR': 1,
        'WRITE_RECOVERY': 1,
      },
      'routes': {'/home': 3},
      'platforms': {'ANDROID': 3},
      'appVersions': {'1.0.0': 3},
      'networkStatus': {'WIFI': 3},
      'p95DurationMs': {'APP_START': 420},
      'dropped': {'sampled_out': 1},
    },
  };
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

Map<String, Object?> _reportMemberJson({
  required int id,
  required String email,
  required String nickname,
  String status = 'ACTIVE',
}) {
  return {
    'id': id,
    'email': email,
    'nickname': nickname,
    'role': 'USER',
    'status': status,
  };
}

Map<String, Object?> _letterSummaryJson({int receiverId = 7}) {
  return {
    'id': 12,
    'title': '운영 편지',
    'sender': _reportMemberJson(
      id: 3,
      email: 'sender@example.com',
      nickname: '발신자',
    ),
    'receiver': _reportMemberJson(
      id: receiverId,
      email: 'receiver@example.com',
      nickname: '수신자',
    ),
    'status': 'SENT',
    'createdAt': '2026-05-25T09:20:00',
    'originalSummary': '검수가 필요한 편지 요약입니다.',
    'replySummary': null,
    'availableReceiverCount': 4,
    'actionCount': 1,
  };
}

Map<String, Object?> _letterDetailJson({int receiverId = 7}) {
  return {
    'id': 12,
    'title': '운영 편지',
    'sender': _reportMemberJson(
      id: 3,
      email: 'sender@example.com',
      nickname: '발신자',
    ),
    'receiver': _reportMemberJson(
      id: receiverId,
      email: 'receiver@example.com',
      nickname: '수신자',
    ),
    'receivers': [
      _reportMemberJson(
        id: receiverId,
        email: 'receiver@example.com',
        nickname: '수신자',
      ),
    ],
    'status': 'SENT',
    'createdAt': '2026-05-25T09:20:00',
    'replyCreatedAt': null,
    'originalSummary': '검수가 필요한 편지 요약입니다.',
    'replySummary': null,
    'auditEvents': [_auditJson('LETTER_NOTE')],
  };
}

Map<String, Object?> _letterActionResultJson({
  int receiverId = 7,
  int revokedRefreshTokenCount = 0,
}) {
  return {
    'letter': _letterDetailJson(receiverId: receiverId),
    'latestAudit': _auditJson('LETTER_ACTION'),
    'revokedRefreshTokenCount': revokedRefreshTokenCount,
    'disabledDeviceTokenCount': revokedRefreshTokenCount,
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

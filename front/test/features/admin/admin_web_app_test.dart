import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_config.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/auth/data/auth_repository.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';
import 'package:maum_on_mobile_front/features/admin/data/admin_repository.dart';
import 'package:maum_on_mobile_front/features/admin/domain/admin_models.dart';
import 'package:maum_on_mobile_front/features/admin/presentation/admin_web_app.dart';

void main() {
  testWidgets('renders a dedicated admin web management shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminWebApp(repository: _FakeAdminRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('관리자 콘솔'), findsOneWidget);
    expect(find.text('모바일 앱과 분리된 운영 공간'), findsOneWidget);
    expect(find.text('운영 대시보드'), findsOneWidget);
    expect(find.text('신고 관리'), findsOneWidget);
    expect(find.text('회원 관리'), findsOneWidget);
    expect(find.text('편지 관리'), findsOneWidget);
    expect(find.text('AI 필터 상태'), findsOneWidget);
    expect(find.text('열린 신고 3건'), findsOneWidget);
    expect(find.text('미배정 편지 2건'), findsOneWidget);
  });

  testWidgets('reloads the admin overview from the toolbar action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminWebApp(repository: _FakeAdminRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('열린 신고 3건'), findsOneWidget);

    await tester.tap(find.text('새로고침'));
    await tester.pumpAndSettle();

    expect(find.text('열린 신고 4건'), findsOneWidget);
  });

  testWidgets('loads the admin console only after an admin login',
      (tester) async {
    final authRepository = _FakeAdminAuthRepository(
      loginSession: _adminSession(),
    );
    final adminRepository = _FakeAdminRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminWebAuthShell(
          authRepository: authRepository,
          adminRepository: adminRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('관리자 로그인'), findsWidgets);
    expect(
        find.byKey(const ValueKey('admin-login-email-field')), findsOneWidget);
    expect(find.text('관리자 콘솔'), findsNothing);
    expect(adminRepository.dashboardLoads, 0);

    await tester.enterText(
      find.byKey(const ValueKey('admin-login-email-field')),
      'admin@maum.on',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-login-password-field')),
      'admin-password',
    );
    await tester.tap(find.byKey(const ValueKey('admin-login-submit-button')));
    await tester.pumpAndSettle();

    expect(authRepository.lastLogin?.email, 'admin@maum.on');
    expect(authRepository.lastLogin?.password, 'admin-password');
    expect(find.text('관리자 로그인'), findsNothing);
    expect(find.text('관리자 콘솔'), findsOneWidget);
    expect(adminRepository.dashboardLoads, 1);
  });

  testWidgets('blocks non-admin accounts from the admin web shell',
      (tester) async {
    final authRepository = _FakeAdminAuthRepository(
      loginSession: _userSession(),
    );
    final adminRepository = _FakeAdminRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminWebAuthShell(
          authRepository: authRepository,
          adminRepository: adminRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('admin-login-email-field')),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-login-password-field')),
      'password',
    );
    await tester.tap(find.byKey(const ValueKey('admin-login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('관리자 권한이 필요합니다.'), findsOneWidget);
    expect(find.text('관리자 콘솔'), findsNothing);
    expect(adminRepository.dashboardLoads, 0);
    expect(authRepository.clearLocalSessionCount, 1);
  });

  testWidgets('returns to login when an active admin session becomes invalid',
      (tester) async {
    final authRepository = _FakeAdminAuthRepository(
      loginSession: _adminSession(),
      restoredSession: _adminSession(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminWebAuthShell(
          authRepository: authRepository,
          adminRepository: const _FailingAdminRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('관리자 로그인이 필요합니다.'), findsOneWidget);
    expect(find.text('로그인으로 돌아가기'), findsOneWidget);

    await tester.tap(find.text('로그인으로 돌아가기'));
    await tester.pumpAndSettle();

    expect(find.text('관리자 로그인'), findsWidgets);
    expect(find.text('관리자 로그인이 필요합니다.'), findsNothing);
    expect(authRepository.clearLocalSessionCount, 1);
  });

  test('admin web release config requires an injected API base URL', () {
    expect(
      () => adminWebApiConfigFromEnvironment(
        baseUrl: '',
        targetPlatform: TargetPlatform.macOS,
        isWeb: true,
        isReleaseMode: true,
      ),
      throwsA(isA<StateError>()),
    );

    final config = adminWebApiConfigFromEnvironment(
      baseUrl: 'https://api.maumon.example',
      targetPlatform: TargetPlatform.macOS,
      isWeb: true,
      isReleaseMode: true,
    );

    expect(config.baseUrl, Uri.parse('https://api.maumon.example'));
  });

  test('admin web dependencies refresh expired sessions during restore',
      () async {
    final transport = _QueuedApiTransport([
      const ApiTransportResponse(
        statusCode: 401,
        body: {
          'success': false,
          'error': {'message': 'expired'}
        },
      ),
      ApiTransportResponse.ok({
        'success': true,
        'data': _sessionJson(accessToken: 'fresh-access'),
      }),
      ApiTransportResponse.ok({
        'success': true,
        'data': _sessionJson(accessToken: 'fresh-access'),
      }),
    ]);
    final tokenStore = MemoryAuthTokenStore(
      initialTokens: const TokenPair(
        accessToken: 'expired-access',
        refreshToken: 'refresh-token',
      ),
    );
    final dependencies = buildAdminWebDependencies(
      apiConfig: ApiConfig(baseUrl: Uri.parse('http://localhost:8080')),
      tokenStore: tokenStore,
      rawTransport: transport,
      sessionTransport: transport,
    );

    final session = await dependencies.authRepository.restoreSession();

    expect(session.member.role, 'ADMIN');
    expect(await tokenStore.readAccessToken(), 'fresh-access');
    expect(
      transport.requests.map((request) => request.path),
      [
        '/api/v1/auth/session',
        '/api/v1/auth/refresh',
        '/api/v1/auth/session',
      ],
    );
    expect(
      transport.requests[0].headers['Authorization'],
      'Bearer expired-access',
    );
    expect(transport.requests[1].requiresAuth, isFalse);
    expect(
      transport.requests[2].headers['Authorization'],
      'Bearer fresh-access',
    );
  });
}

class _FakeAdminRepository implements AdminRepository {
  int _dashboardLoads = 0;

  int get dashboardLoads => _dashboardLoads;

  @override
  Future<AdminDashboard> fetchDashboard() async {
    _dashboardLoads += 1;
    return AdminDashboard(
      todayReportCount: 1,
      openReportCount: 2 + _dashboardLoads,
      processedReportCount: 8,
      todayLetterCount: 5,
      todayDiaryCount: 13,
      receivableMemberCount: 21,
      blockedMemberCount: 1,
      adminMemberCount: 2,
      unassignedLetterCount: 2,
      todayAdminActionCount: 4,
    );
  }

  @override
  Future<List<AdminReportSummary>> fetchReports({
    String? status,
    String? targetType,
    String? sort,
  }) async {
    return const [
      AdminReportSummary(
        id: 1,
        targetType: 'POST',
        targetId: 11,
        targetTitle: '확인할 신고',
        targetOwner: AdminReportMember(
          id: 2,
          email: 'owner@example.com',
          nickname: '작성자',
        ),
        reporter: AdminReportMember(
          id: 3,
          email: 'reporter@example.com',
          nickname: '신고자',
        ),
        reason: 'ABUSE',
        status: 'OPEN',
        createdAt: '2026-06-12T09:00:00Z',
        actionCount: 0,
      ),
    ];
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
    return const AdminMemberPage(
      content: [
        AdminMemberSummary(
          id: 7,
          email: 'member@example.com',
          nickname: '회원',
          role: 'USER',
          status: 'ACTIVE',
          socialAccount: false,
          randomReceiveAllowed: true,
          reportCount: 1,
          postCount: 2,
          letterCount: 3,
          diaryCount: 4,
        ),
      ],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<AdminLetterPage> fetchLetters({
    String? status,
    String? query,
    int page = 0,
    int size = 20,
  }) async {
    return const AdminLetterPage(
      content: [
        AdminLetterSummary(
          id: 9,
          title: '확인할 편지',
          sender: AdminReportMember(
            id: 4,
            email: 'sender@example.com',
            nickname: '보낸이',
          ),
          receiver: null,
          status: 'UNASSIGNED',
          createdAt: '2026-06-12T09:10:00Z',
          originalSummary: '편지 본문 요약',
          replySummary: null,
          availableReceiverCount: 8,
          actionCount: 1,
        ),
      ],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<AdminModerationSummary> fetchModerationSummary() async {
    return const AdminModerationSummary(
      totalCount: 10,
      blockedCount: 4,
      modelFailureCount: 1,
      failureRate: 0.1,
      highRiskCategories: {'abuse': 3},
      modelStatuses: {'ALLOW': 6, 'BLOCK': 4},
      targets: {'LETTER': 5, 'STORY': 5},
      recentFailures: [],
    );
  }
}

class _FailingAdminRepository implements AdminRepository {
  const _FailingAdminRepository();

  @override
  Future<AdminDashboard> fetchDashboard() async {
    throw Exception('session invalidated');
  }

  @override
  Future<List<AdminReportSummary>> fetchReports({
    String? status,
    String? targetType,
    String? sort,
  }) async {
    throw Exception('session invalidated');
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
    throw Exception('session invalidated');
  }

  @override
  Future<AdminLetterPage> fetchLetters({
    String? status,
    String? query,
    int page = 0,
    int size = 20,
  }) async {
    throw Exception('session invalidated');
  }

  @override
  Future<AdminModerationSummary> fetchModerationSummary() async {
    throw Exception('session invalidated');
  }
}

class _FakeAdminAuthRepository implements AuthRepository {
  _FakeAdminAuthRepository({
    required AuthSession loginSession,
    AuthSession? restoredSession,
  })  : _loginSession = loginSession,
        _restoredSession = restoredSession;

  final AuthSession _loginSession;
  final AuthSession? _restoredSession;
  LoginRequest? lastLogin;
  int clearLocalSessionCount = 0;

  @override
  Future<AuthSession> login(LoginRequest request) async {
    lastLogin = request;
    return _loginSession;
  }

  @override
  Future<AuthSession> restoreSession() async {
    final session = _restoredSession;
    if (session == null) {
      throw Exception('No admin session');
    }
    return session;
  }

  @override
  Future<void> clearLocalSession() async {
    clearLocalSessionCount += 1;
  }

  @override
  Future<void> logout() => clearLocalSession();

  @override
  Future<void> requestSignupEmailVerification(
    SignupEmailVerificationRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<AuthMember> signup(SignupRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> requestPasswordReset(PasswordResetRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> confirmPasswordReset(PasswordResetConfirmRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> refreshSession() {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> exchangeOidcSession(OidcSessionRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveSession(AuthSession session) {
    throw UnimplementedError();
  }

  @override
  Future<AuthMember> me() {
    throw UnimplementedError();
  }
}

AuthSession _adminSession() => _session(role: 'ADMIN');

AuthSession _userSession() => _session(role: 'USER');

AuthSession _session({required String role}) {
  return AuthSession(
    accessToken: 'access-token',
    tokenType: 'Bearer',
    expiresInSeconds: 3600,
    refreshToken: 'refresh-token',
    member: AuthMember(
      id: 1,
      email: 'admin@maum.on',
      nickname: '관리자',
      role: role,
      status: 'ACTIVE',
    ),
  );
}

Map<String, Object?> _sessionJson({required String accessToken}) {
  return {
    'accessToken': accessToken,
    'tokenType': 'Bearer',
    'expiresInSeconds': 3600,
    'refreshToken': 'refresh-token',
    'member': {
      'id': 1,
      'email': 'admin@maum.on',
      'nickname': '관리자',
      'role': 'ADMIN',
      'status': 'ACTIVE',
    },
  };
}

class _QueuedApiTransport implements ApiTransport {
  _QueuedApiTransport(this._responses);

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

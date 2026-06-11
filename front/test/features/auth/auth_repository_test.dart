import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/auth/data/auth_repository.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';

void main() {
  group('ApiAuthRepository', () {
    test('login stores the access token and sends credentials', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok(_tokenEnvelope(accessToken: 'access-token')),
      ]);
      final tokenStore = MemoryAuthTokenStore();
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      final session = await repository.login(
        const LoginRequest(email: 'me@example.com', password: 'secret'),
      );

      expect(session.member.email, 'me@example.com');
      expect(await tokenStore.readAccessToken(), 'access-token');
      expect(await tokenStore.readRefreshToken(), isNotEmpty);
      expect(transport.requests.single.method, ApiMethod.post);
      expect(transport.requests.single.path, '/api/v1/auth/login');
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
      expect(transport.requests.single.body, {
        'email': 'me@example.com',
        'password': 'secret',
      });
    });

    test('requestSignupEmailVerification sends email without authentication',
        () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {'accepted': true}
        }),
      ]);
      final tokenStore = MemoryAuthTokenStore();
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      await repository.requestSignupEmailVerification(
        const SignupEmailVerificationRequest(email: 'me@example.com'),
      );

      expect(transport.requests.single.method, ApiMethod.post);
      expect(
        transport.requests.single.path,
        '/api/v1/auth/signup/email-verifications',
      );
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
      expect(transport.requests.single.body, {'email': 'me@example.com'});
    });

    test('signup sends email verification code without authentication',
        () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'success': true, 'data': _memberJson()}),
      ]);
      final tokenStore = MemoryAuthTokenStore();
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      await repository.signup(
        const SignupRequest(
          email: 'me@example.com',
          password: 'pass1234',
          nickname: '마음이',
          emailVerificationCode: '123456',
        ),
      );

      expect(transport.requests.single.method, ApiMethod.post);
      expect(transport.requests.single.path, '/api/v1/auth/signup');
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
      expect(transport.requests.single.body, {
        'email': 'me@example.com',
        'password': 'pass1234',
        'nickname': '마음이',
        'emailVerificationCode': '123456',
      });
    });

    test('restoreSession stores the returned session token', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok(_tokenEnvelope(accessToken: 'restored-token')),
      ]);
      final tokenStore = MemoryAuthTokenStore(
        initialTokens: const TokenPair(
          accessToken: 'saved-access',
          refreshToken: 'saved-refresh',
        ),
      );
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      final session = await repository.restoreSession();

      expect(session.accessToken, 'restored-token');
      expect(await tokenStore.readAccessToken(), 'restored-token');
      expect(transport.requests.single.method, ApiMethod.get);
      expect(transport.requests.single.path, '/api/v1/auth/session');
      expect(transport.requests.single.requiresAuth, isTrue);
      expect(transport.requests.single.retryOnUnauthorized, isTrue);
      expect(
        transport.requests.single.headers['Authorization'],
        'Bearer saved-access',
      );
    });

    test('restoreSession skips network when no local session token exists',
        () async {
      final transport = _FakeApiTransport([]);
      final tokenStore = MemoryAuthTokenStore();
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      await expectLater(
        repository.restoreSession(),
        throwsA(
          isA<ApiClientException>()
              .having((error) => error.kind, 'kind', ApiErrorKind.unauthorized)
              .having((error) => error.statusCode, 'statusCode', 401),
        ),
      );
      expect(transport.requests, isEmpty);
    });

    test('restoreSession refreshes an expired access token before restoring',
        () async {
      final transport = _FakeApiTransport([
        const ApiTransportResponse(
          statusCode: 401,
          body: {
            'success': false,
            'error': {'code': 'AUTH_REQUIRED', 'message': '인증이 필요합니다.'},
          },
        ),
        ApiTransportResponse.ok(_tokenEnvelope(
          accessToken: 'restored-token',
          refreshToken: 'restored-refresh',
        )),
      ]);
      final tokenStore = MemoryAuthTokenStore(
        initialTokens: const TokenPair(
          accessToken: 'expired-access',
          refreshToken: 'saved-refresh',
        ),
      );
      final repository = ApiAuthRepository(
        apiClient: ApiClient(
          transport: transport,
          tokenStore: tokenStore,
          tokenRefresher: const _FakeTokenRefresher(
            tokens: TokenPair(
              accessToken: 'refreshed-access',
              refreshToken: 'refreshed-refresh',
            ),
          ),
        ),
        tokenStore: tokenStore,
      );

      final session = await repository.restoreSession();

      expect(session.accessToken, 'restored-token');
      expect(await tokenStore.readAccessToken(), 'restored-token');
      expect(await tokenStore.readRefreshToken(), 'restored-refresh');
      expect(transport.requests, hasLength(2));
      expect(
        transport.requests.first.headers['Authorization'],
        'Bearer expired-access',
      );
      expect(
        transport.requests.last.headers['Authorization'],
        'Bearer refreshed-access',
      );
    });

    test('refreshSession sends the stored refresh token and stores rotation',
        () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok(_tokenEnvelope(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
        )),
      ]);
      final tokenStore = MemoryAuthTokenStore(
        initialTokens: const TokenPair(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        ),
      );
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      final session = await repository.refreshSession();

      expect(session.accessToken, 'new-access');
      expect(await tokenStore.readAccessToken(), 'new-access');
      expect(await tokenStore.readRefreshToken(), 'new-refresh');
      expect(transport.requests.single.method, ApiMethod.post);
      expect(transport.requests.single.path, '/api/v1/auth/refresh');
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
      expect(transport.requests.single.body, {'refreshToken': 'old-refresh'});
    });

    test('refreshSession clears stored tokens when refresh fails', () async {
      final transport = _FakeApiTransport([
        const ApiTransportResponse(
          statusCode: 401,
          body: {
            'success': false,
            'error': {'code': 'AUTH_REQUIRED', 'message': '다시 로그인해 주세요.'},
          },
        ),
      ]);
      final tokenStore = MemoryAuthTokenStore(
        initialTokens: const TokenPair(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        ),
      );
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      await expectLater(
        repository.refreshSession(),
        throwsA(
          isA<ApiClientException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.unauthorized,
          ),
        ),
      );
      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
      expect(transport.requests.single.body, {'refreshToken': 'old-refresh'});
    });

    test('exchangeOidcSession sends provider code and stores returned tokens',
        () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok(_tokenEnvelope(
          accessToken: 'oidc-access',
          refreshToken: 'oidc-refresh',
        )),
      ]);
      final tokenStore = MemoryAuthTokenStore();
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      final session = await repository.exchangeOidcSession(
        const OidcSessionRequest(
          provider: 'kakao',
          code: 'provider-code',
          state: 'provider-state',
        ),
      );

      expect(session.accessToken, 'oidc-access');
      expect(await tokenStore.readAccessToken(), 'oidc-access');
      expect(await tokenStore.readRefreshToken(), 'oidc-refresh');
      expect(transport.requests.single.method, ApiMethod.post);
      expect(
        transport.requests.single.path,
        '/api/v1/auth/oidc/session/kakao',
      );
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
      expect(transport.requests.single.body, {
        'code': 'provider-code',
        'state': 'provider-state',
      });
    });

    test('requestPasswordReset sends email without authentication', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'success': true}),
      ]);
      final tokenStore = MemoryAuthTokenStore();
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      await repository.requestPasswordReset(
        const PasswordResetRequest(email: 'me@example.com'),
      );

      expect(transport.requests.single.method, ApiMethod.post);
      expect(
        transport.requests.single.path,
        '/api/v1/auth/password-reset/request',
      );
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
      expect(transport.requests.single.body, {'email': 'me@example.com'});
    });

    test('confirmPasswordReset sends token and new password without auth',
        () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'success': true}),
      ]);
      final tokenStore = MemoryAuthTokenStore();
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      await repository.confirmPasswordReset(
        const PasswordResetConfirmRequest(
          token: 'reset-token',
          newPassword: 'new-password',
        ),
      );

      expect(transport.requests.single.method, ApiMethod.post);
      expect(
        transport.requests.single.path,
        '/api/v1/auth/password-reset/confirm',
      );
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
      expect(transport.requests.single.body, {
        'token': 'reset-token',
        'newPassword': 'new-password',
      });
    });

    test('logout clears local tokens after calling logout endpoint', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
        }),
      ]);
      final tokenStore = MemoryAuthTokenStore(
        initialTokens: const TokenPair(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );
      final repository = ApiAuthRepository(
        apiClient: ApiClient(transport: transport, tokenStore: tokenStore),
        tokenStore: tokenStore,
      );

      await repository.logout();

      expect(transport.requests.single.method, ApiMethod.post);
      expect(transport.requests.single.path, '/api/v1/auth/logout');
      expect(transport.requests.single.body, {'refreshToken': 'refresh-token'});
      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
    });
  });
}

Map<String, Object?> _tokenEnvelope({
  required String accessToken,
  String refreshToken = 'refresh-token',
}) {
  return {
    'success': true,
    'data': {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': 'Bearer',
      'expiresInSeconds': 3600,
      'member': _memberJson(),
    },
  };
}

Map<String, Object?> _memberJson() {
  return {
    'id': 7,
    'email': 'me@example.com',
    'nickname': '마음이',
    'role': 'USER',
    'status': 'ACTIVE',
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

class _FakeTokenRefresher implements AuthTokenRefresher {
  const _FakeTokenRefresher({
    required this.tokens,
  });

  final TokenPair? tokens;

  @override
  Future<TokenPair?> refresh(String refreshToken) async => tokens;
}

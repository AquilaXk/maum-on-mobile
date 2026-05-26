import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/auth_token_store.dart';
import '../domain/auth_models.dart';

abstract interface class AuthRepository {
  Future<AuthMember> signup(SignupRequest request);

  Future<AuthSession> login(LoginRequest request);

  Future<void> requestPasswordReset(PasswordResetRequest request);

  Future<void> confirmPasswordReset(PasswordResetConfirmRequest request);

  Future<AuthSession> restoreSession();

  Future<AuthSession> refreshSession();

  Future<void> saveSession(AuthSession session);

  Future<AuthMember> me();

  Future<void> logout();

  Future<void> clearLocalSession();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required ApiClient apiClient,
    required AuthTokenStore tokenStore,
  })  : _apiClient = apiClient,
        _tokenStore = tokenStore;

  static const serverManagedRefreshToken = 'server-managed-refresh';

  final ApiClient _apiClient;
  final AuthTokenStore _tokenStore;

  @override
  Future<AuthMember> signup(SignupRequest request) {
    return _apiClient.post<AuthMember>(
      '/api/v1/auth/signup',
      body: request.toJson(),
      requiresAuth: false,
      retryOnUnauthorized: false,
      parser: AuthMember.fromJson,
    );
  }

  @override
  Future<AuthSession> login(LoginRequest request) async {
    final session = await _apiClient.post<AuthSession>(
      '/api/v1/auth/login',
      body: request.toJson(),
      requiresAuth: false,
      retryOnUnauthorized: false,
      parser: AuthSession.fromJson,
    );
    await _saveSession(session);
    return session;
  }

  @override
  Future<void> requestPasswordReset(PasswordResetRequest request) {
    return _apiClient.postVoid(
      '/api/v1/auth/password-reset/request',
      body: request.toJson(),
      requiresAuth: false,
      retryOnUnauthorized: false,
    );
  }

  @override
  Future<void> confirmPasswordReset(PasswordResetConfirmRequest request) {
    return _apiClient.postVoid(
      '/api/v1/auth/password-reset/confirm',
      body: request.toJson(),
      requiresAuth: false,
      retryOnUnauthorized: false,
    );
  }

  @override
  Future<AuthSession> restoreSession() async {
    final session = await _apiClient.get<AuthSession>(
      '/api/v1/auth/session',
      retryOnUnauthorized: false,
      parser: AuthSession.fromJson,
    );
    await _saveSession(session);
    return session;
  }

  @override
  Future<AuthSession> refreshSession() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStore.clear();
      throw const ApiClientException(
        kind: ApiErrorKind.unauthorized,
        message: '다시 로그인해 주세요.',
        statusCode: 401,
      );
    }

    try {
      final session = await _apiClient.post<AuthSession>(
        '/api/v1/auth/refresh',
        body: {'refreshToken': refreshToken},
        requiresAuth: false,
        retryOnUnauthorized: false,
        parser: AuthSession.fromJson,
      );
      await _saveSession(session);
      return session;
    } on Object {
      await _tokenStore.clear();
      rethrow;
    }
  }

  @override
  Future<void> saveSession(AuthSession session) {
    return _saveSession(session);
  }

  @override
  Future<AuthMember> me() {
    return _apiClient.get<AuthMember>(
      '/api/v1/auth/me',
      parser: AuthMember.fromJson,
    );
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    try {
      await _apiClient.postVoid(
        '/api/v1/auth/logout',
        body: refreshToken == null || refreshToken.isEmpty
            ? null
            : {'refreshToken': refreshToken},
        requiresAuth: false,
        retryOnUnauthorized: false,
      );
    } finally {
      await _tokenStore.clear();
    }
  }

  @override
  Future<void> clearLocalSession() {
    return _tokenStore.clear();
  }

  Future<void> _saveSession(AuthSession session) {
    final refreshToken = session.refreshToken;
    return _tokenStore.saveTokens(
      TokenPair(
        accessToken: session.accessToken,
        refreshToken: refreshToken == null || refreshToken.isEmpty
            ? serverManagedRefreshToken
            : refreshToken,
      ),
    );
  }
}

class AuthSessionTokenRefresher implements AuthTokenRefresher {
  const AuthSessionTokenRefresher({
    required AuthRepository authRepository,
  }) : _authRepository = authRepository;

  final AuthRepository _authRepository;

  @override
  Future<TokenPair?> refresh(String refreshToken) async {
    try {
      final session = await _authRepository.refreshSession();
      return TokenPair(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ??
            ApiAuthRepository.serverManagedRefreshToken,
      );
    } on Object {
      return null;
    }
  }
}

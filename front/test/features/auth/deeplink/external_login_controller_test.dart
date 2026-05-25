import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/auth/application/auth_controller.dart';
import 'package:maum_on_mobile_front/features/auth/data/auth_repository.dart';
import 'package:maum_on_mobile_front/features/auth/deeplink/external_login.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';

void main() {
  group('ExternalLoginController', () {
    test('starts provider login with the configured redirect URI', () async {
      final launcher = _RecordingExternalLoginLauncher();
      final controller = ExternalLoginController(
        authController: AuthController(
          authRepository: _FakeAuthRepository(restoredSession: _session()),
        ),
        launcher: launcher,
        config: ExternalLoginConfig(
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
      );

      await controller.start(provider: 'kakao');

      expect(launcher.launchedUris.single.path, '/api/v1/auth/oidc/authorize/kakao');
      expect(
        launcher.launchedUris.single.queryParameters['redirect_uri'],
        'maumon://auth/callback',
      );
      expect(controller.state.isStarting, isFalse);
      expect(controller.state.errorMessage, isNull);
    });

    test('shows a retry message when provider launch fails', () async {
      final launcher = _RecordingExternalLoginLauncher(launchResult: false);
      final controller = ExternalLoginController(
        authController: AuthController(
          authRepository: _FakeAuthRepository(restoredSession: _session()),
        ),
        launcher: launcher,
        config: ExternalLoginConfig(
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
      );

      await controller.start(provider: 'kakao');

      expect(launcher.launchedUris, hasLength(1));
      expect(controller.state.isStarting, isFalse);
      expect(controller.state.errorMessage, '외부 로그인을 시작할 수 없습니다.');
    });

    test('success callback stores returned tokens and authenticates the app',
        () async {
      final repository = _FakeAuthRepository(restoredSession: _session());
      final authController = AuthController(
        authRepository: repository,
      );
      final controller = ExternalLoginController(
        authController: authController,
        launcher: _RecordingExternalLoginLauncher(),
        config: ExternalLoginConfig(
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
      );

      final handled = await controller.handleIncomingUri(
        Uri.parse(
          'maumon://auth/callback?status=success'
          '&access_token=external-access'
          '&refresh_token=external-refresh'
          '&token_type=Bearer'
          '&expires_in=3600'
          '&member_id=7'
          '&email=me%40example.com'
          '&nickname=%EB%A7%88%EC%9D%8C%EC%9D%B4'
          '&role=USER'
          '&member_status=ACTIVE',
        ),
      );

      expect(handled, isTrue);
      expect(authController.state.isAuthenticated, isTrue);
      expect(repository.savedExternalSessions.single.accessToken, 'external-access');
      expect(repository.savedExternalSessions.single.refreshToken, 'external-refresh');
      expect(controller.state.errorMessage, isNull);
    });

    test('success callback without member status defaults to active', () async {
      final repository = _FakeAuthRepository(restoredSession: _session());
      final authController = AuthController(
        authRepository: repository,
      );
      final controller = ExternalLoginController(
        authController: authController,
        launcher: _RecordingExternalLoginLauncher(),
        config: ExternalLoginConfig(
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
      );

      final handled = await controller.handleIncomingUri(
        Uri.parse(
          'maumon://auth/callback?status=success'
          '&access_token=external-access'
          '&refresh_token=external-refresh'
          '&member_id=7'
          '&email=me%40example.com'
          '&nickname=%EB%A7%88%EC%9D%8C%EC%9D%B4',
        ),
      );

      expect(handled, isTrue);
      expect(authController.state.isAuthenticated, isTrue);
      expect(
        repository.savedExternalSessions.single.accessToken,
        'external-access',
      );
      expect(
        repository.savedExternalSessions.single.refreshToken,
        'external-refresh',
      );
      expect(repository.savedExternalSessions.single.member.status, 'ACTIVE');
      expect(controller.state.errorMessage, isNull);
    });

    test('success callback without tokens falls back to session restore',
        () async {
      final authController = AuthController(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
      );
      final controller = ExternalLoginController(
        authController: authController,
        launcher: _RecordingExternalLoginLauncher(),
        config: ExternalLoginConfig(
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
      );

      final handled = await controller.handleIncomingUri(
        Uri.parse('maumon://auth/callback?code=secret-code&state=secret-state'),
      );

      expect(handled, isTrue);
      expect(authController.state.isAuthenticated, isTrue);
      expect(controller.state.errorMessage, isNull);
    });

    test('cancel callback stays unauthenticated with a screen message', () async {
      final authController = AuthController(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
      );
      final controller = ExternalLoginController(
        authController: authController,
        launcher: _RecordingExternalLoginLauncher(),
        config: ExternalLoginConfig(
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
      );

      final handled = await controller.handleIncomingUri(
        Uri.parse('maumon://auth/callback?status=cancelled'),
      );

      expect(handled, isTrue);
      expect(authController.state.isAuthenticated, isFalse);
      expect(controller.state.errorMessage, '외부 로그인이 취소되었습니다.');
    });

    test('state mismatch callback shows a retry-safe error', () async {
      final controller = ExternalLoginController(
        authController: AuthController(
          authRepository: _FakeAuthRepository(restoredSession: _session()),
        ),
        launcher: _RecordingExternalLoginLauncher(),
        config: ExternalLoginConfig(
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
      );

      final handled = await controller.handleIncomingUri(
        Uri.parse('maumon://auth/callback?error=state_mismatch&state=secret-state'),
      );

      expect(handled, isTrue);
      expect(controller.state.errorMessage, '로그인 요청이 만료되었습니다. 다시 시도해 주세요.');
    });

    test('provider error callback displays a safe provider message', () async {
      final controller = ExternalLoginController(
        authController: AuthController(
          authRepository: _FakeAuthRepository(restoredSession: _session()),
        ),
        launcher: _RecordingExternalLoginLauncher(),
        config: ExternalLoginConfig(
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
      );

      final handled = await controller.handleIncomingUri(
        Uri.parse(
          'maumon://auth/callback?error=access_denied&error_description=Provider%20denied',
        ),
      );

      expect(handled, isTrue);
      expect(controller.state.errorMessage, 'Provider denied');
    });
  });
}

AuthSession _session() {
  return const AuthSession(
    accessToken: 'access-token',
    tokenType: 'Bearer',
    expiresInSeconds: 3600,
    member: AuthMember(
      id: 7,
      email: 'me@example.com',
      nickname: '마음이',
      role: 'USER',
      status: 'ACTIVE',
    ),
  );
}

class _RecordingExternalLoginLauncher implements ExternalLoginLauncher {
  _RecordingExternalLoginLauncher({this.launchResult = true});

  final bool launchResult;
  final List<Uri> launchedUris = [];

  @override
  Future<bool> launch(Uri uri) async {
    launchedUris.add(uri);
    return launchResult;
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    required this.restoredSession,
  });

  final AuthSession restoredSession;
  final List<AuthSession> savedExternalSessions = [];

  @override
  Future<AuthMember> signup(SignupRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> login(LoginRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> restoreSession() async => restoredSession;

  @override
  Future<AuthSession> refreshSession() {
    throw UnimplementedError();
  }

  @override
  Future<void> saveSession(AuthSession session) async {
    savedExternalSessions.add(session);
  }

  @override
  Future<AuthMember> me() {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearLocalSession() async {}
}

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/auth/application/auth_controller.dart';
import 'package:maum_on_mobile_front/features/auth/data/auth_repository.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';

void main() {
  group('AuthController', () {
    test('login success updates authenticated state', () async {
      final controller = AuthController(
        authRepository: _FakeAuthRepository(loginSession: _session()),
      );

      await controller.login(
        email: 'me@example.com',
        password: 'secret',
      );

      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.member?.nickname, '마음이');
      expect(controller.state.errorMessage, isNull);
    });

    test('login failure keeps unauthenticated state with screen-ready error',
        () async {
      final controller = AuthController(
        authRepository: _FakeAuthRepository(
          loginError: const ApiClientException(
            kind: ApiErrorKind.unauthorized,
            message: '이메일 또는 비밀번호가 맞지 않아요.',
            statusCode: 401,
          ),
        ),
      );

      await controller.login(
        email: 'wrong@example.com',
        password: 'bad',
      );

      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.errorMessage, '이메일 또는 비밀번호가 맞지 않아요.');
    });

    test('restoreSession success marks the session as restored', () async {
      final controller = AuthController(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
      );

      await controller.restoreSession();

      expect(controller.state.hasRestored, isTrue);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.member?.email, 'me@example.com');
    });

    test('restoreSession keeps a session invalidation message', () async {
      final controller = AuthController(
        authRepository: _FakeAuthRepository(
          restoreError: const ApiClientException(
            kind: ApiErrorKind.accountBlocked,
            message: '계정 상태가 변경되었습니다. 다시 로그인해 주세요.',
            statusCode: 401,
          ),
        ),
      );

      await controller.restoreSession();

      expect(controller.state.isAuthenticated, isFalse);
      expect(
        controller.state.infoMessage,
        '계정 상태가 변경되었습니다. 다시 로그인해 주세요.',
      );
    });

    test('restoreSession hides a generic unauthorized message', () async {
      final controller = AuthController(
        authRepository: _FakeAuthRepository(
          restoreError: const ApiClientException(
            kind: ApiErrorKind.unauthorized,
            message: '인증이 필요합니다.',
            statusCode: 401,
          ),
        ),
      );

      await controller.restoreSession();

      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.hasRestored, isTrue);
      expect(controller.state.infoMessage, isNull);
      expect(controller.state.errorMessage, isNull);
    });

    test('logout clears authenticated state immediately', () async {
      final repository = _FakeAuthRepository(loginSession: _session());
      final controller = AuthController(authRepository: repository);

      await controller.login(email: 'me@example.com', password: 'secret');
      await controller.logout();

      expect(repository.logoutCalled, isTrue);
      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.member, isNull);
    });

    test('invalidateSession clears local tokens once for concurrent failures',
        () async {
      final repository = _FakeAuthRepository(loginSession: _session());
      final controller = AuthController(authRepository: repository);

      await controller.login(email: 'me@example.com', password: 'secret');
      final authenticatedRevision = controller.state.sessionRevision;

      await Future.wait([
        controller.invalidateSession(message: '다시 로그인해 주세요.'),
        controller.invalidateSession(message: '다시 로그인해 주세요.'),
      ]);

      expect(repository.clearLocalSessionCount, 1);
      expect(repository.logoutCalled, isFalse);
      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.infoMessage, '다시 로그인해 주세요.');
      expect(controller.state.sessionRevision, authenticatedRevision + 1);
    });

    test('requestPasswordReset sends a trimmed email and shows generic info',
        () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(authRepository: repository);

      final requested = await controller.requestPasswordReset(
        email: '  me@example.com  ',
      );

      expect(requested, isTrue);
      expect(repository.passwordResetEmails, ['me@example.com']);
      expect(controller.state.isAuthenticated, isFalse);
      expect(
        controller.state.infoMessage,
        '계정이 있으면 재설정 안내가 전송됩니다.',
      );
      expect(controller.state.errorMessage, isNull);
    });

    test('requestSignupEmailVerification trims email and shows info', () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(authRepository: repository);

      final requested = await controller.requestSignupEmailVerification(
        email: '  me@example.com  ',
      );

      expect(requested, isTrue);
      expect(repository.signupVerificationEmails, ['me@example.com']);
      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.infoMessage, '인증번호를 이메일로 보냈습니다.');
      expect(controller.state.errorMessage, isNull);
    });

    test('signup sends the verification code and trims account fields',
        () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(authRepository: repository);

      await controller.signup(
        email: '  me@example.com  ',
        password: 'pass1234',
        nickname: ' 마음이 ',
        emailVerificationCode: '123456',
      );

      expect(repository.signupRequests.single.email, 'me@example.com');
      expect(repository.signupRequests.single.nickname, '마음이');
      expect(repository.signupRequests.single.emailVerificationCode, '123456');
      expect(controller.state.infoMessage, '가입이 완료되었습니다. 로그인해 주세요.');
      expect(controller.state.errorMessage, isNull);
    });

    test('confirmPasswordReset sends token and returns to login-ready state',
        () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(authRepository: repository);

      final confirmed = await controller.confirmPasswordReset(
        token: ' reset-token ',
        newPassword: 'new-password',
      );

      expect(confirmed, isTrue);
      expect(repository.passwordResetConfirmations.single.token, 'reset-token');
      expect(
        repository.passwordResetConfirmations.single.newPassword,
        'new-password',
      );
      expect(
        controller.state.infoMessage,
        '비밀번호가 변경되었습니다. 다시 로그인해 주세요.',
      );
      expect(controller.state.errorMessage, isNull);
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

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.loginSession,
    this.restoredSession,
    this.loginError,
    this.restoreError,
  });

  final AuthSession? loginSession;
  final AuthSession? restoredSession;
  final Object? loginError;
  final Object? restoreError;
  bool logoutCalled = false;
  int clearLocalSessionCount = 0;
  final List<SignupRequest> signupRequests = [];
  final List<String> signupVerificationEmails = [];
  final List<String> passwordResetEmails = [];
  final List<_PasswordResetConfirmation> passwordResetConfirmations = [];

  @override
  Future<AuthMember> signup(SignupRequest request) async {
    signupRequests.add(request);
    return const AuthMember(
      id: 1,
      email: 'me@example.com',
      nickname: '마음이',
      role: 'USER',
      status: 'ACTIVE',
    );
  }

  @override
  Future<void> requestSignupEmailVerification(
    SignupEmailVerificationRequest request,
  ) async {
    signupVerificationEmails.add(request.email);
  }

  @override
  Future<AuthSession> login(LoginRequest request) async {
    final error = loginError;
    if (error != null) {
      throw error;
    }
    return loginSession!;
  }

  @override
  Future<void> requestPasswordReset(PasswordResetRequest request) async {
    passwordResetEmails.add(request.email);
  }

  @override
  Future<void> confirmPasswordReset(
    PasswordResetConfirmRequest request,
  ) async {
    passwordResetConfirmations.add(
      _PasswordResetConfirmation(
        token: request.token,
        newPassword: request.newPassword,
      ),
    );
  }

  @override
  Future<AuthSession> restoreSession() async {
    final error = restoreError;
    if (error != null) {
      throw error;
    }
    return restoredSession!;
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
  Future<void> saveSession(AuthSession session) async {}

  @override
  Future<AuthMember> me() {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> clearLocalSession() async {
    clearLocalSessionCount += 1;
  }
}

class _PasswordResetConfirmation {
  const _PasswordResetConfirmation({
    required this.token,
    required this.newPassword,
  });

  final String token;
  final String newPassword;
}

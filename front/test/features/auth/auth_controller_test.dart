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

    test('login failure keeps unauthenticated state with screen-ready error', () async {
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

  @override
  Future<AuthMember> signup(SignupRequest request) {
    throw UnimplementedError();
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

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

    test('logout clears authenticated state immediately', () async {
      final repository = _FakeAuthRepository(loginSession: _session());
      final controller = AuthController(authRepository: repository);

      await controller.login(email: 'me@example.com', password: 'secret');
      await controller.logout();

      expect(repository.logoutCalled, isTrue);
      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.member, isNull);
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
  });

  final AuthSession? loginSession;
  final AuthSession? restoredSession;
  final Object? loginError;
  bool logoutCalled = false;

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
    return restoredSession!;
  }

  @override
  Future<AuthSession> refreshSession() {
    throw UnimplementedError();
  }

  @override
  Future<AuthMember> me() {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

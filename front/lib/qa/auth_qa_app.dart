import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../theme/app_theme.dart';

void main() {
  runApp(buildAuthQaApp());
}

Widget buildAuthQaApp() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    darkTheme: buildDarkAppTheme(),
    themeMode: ThemeMode.system,
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      overscroll: false,
    ),
    home: AuthScreen(
      controller: AuthController(authRepository: const _AuthQaRepository()),
    ),
  );
}

class _AuthQaRepository implements AuthRepository {
  const _AuthQaRepository();

  @override
  Future<void> requestSignupEmailVerification(
    SignupEmailVerificationRequest request,
  ) async {}

  @override
  Future<AuthMember> signup(SignupRequest request) async {
    return AuthMember(
      id: 431,
      email: request.email.trim(),
      nickname: request.nickname.trim(),
      role: 'USER',
      status: 'ACTIVE',
    );
  }

  @override
  Future<AuthSession> login(LoginRequest request) async {
    return AuthSession(
      accessToken: 'qa-access-token',
      refreshToken: 'qa-refresh-token',
      tokenType: 'Bearer',
      expiresInSeconds: 3600,
      member: AuthMember(
        id: 431,
        email: request.email.trim(),
        nickname: '마음이',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );
  }

  @override
  Future<void> requestPasswordReset(PasswordResetRequest request) async {}

  @override
  Future<void> confirmPasswordReset(
    PasswordResetConfirmRequest request,
  ) async {}

  @override
  Future<AuthSession> restoreSession() {
    throw const ApiClientException(
      kind: ApiErrorKind.unauthorized,
      message: '다시 로그인해 주세요.',
      statusCode: 401,
    );
  }

  @override
  Future<AuthSession> refreshSession() => restoreSession();

  @override
  Future<AuthSession> exchangeOidcSession(OidcSessionRequest request) {
    return login(const LoginRequest(email: 'qa@example.com', password: 'qa'));
  }

  @override
  Future<void> saveSession(AuthSession session) async {}

  @override
  Future<AuthMember> me() async {
    return const AuthMember(
      id: 431,
      email: 'qa@example.com',
      nickname: '마음이',
      role: 'USER',
      status: 'ACTIVE',
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearLocalSession() async {}
}

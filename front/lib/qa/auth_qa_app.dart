import 'package:flutter/material.dart';

import '../core/network/api_error.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/deeplink/external_login.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/auth/domain/login_provider_policy.dart';
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
    home: const _AuthQaShell(),
  );
}

class _AuthQaShell extends StatefulWidget {
  const _AuthQaShell();

  @override
  State<_AuthQaShell> createState() => _AuthQaShellState();
}

class _AuthQaShellState extends State<_AuthQaShell> {
  late final AuthController _authController = AuthController(
    authRepository: const _AuthQaRepository(),
  );
  late final ExternalLoginController _externalLoginController =
      ExternalLoginController(
    authController: _authController,
    launcher: const _AuthQaExternalLoginLauncher(),
    config:
        ExternalLoginConfig(apiBaseUrl: Uri.parse('https://qa.maumon.invalid')),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_authController.loadExternalLoginProviders);
  }

  @override
  void dispose() {
    _externalLoginController.dispose();
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _authController,
        _externalLoginController,
      ]),
      builder: (context, _) {
        final providerIds = _authController.state.externalLoginProviderIds;
        return AuthScreen(
          controller: _authController,
          externalLoginController: _externalLoginController,
          loginProviders: providerIds == null
              ? const []
              : LoginProviderPolicy.providersFor(
                  Theme.of(context).platform,
                  enabledProviderIds: providerIds.join(','),
                ),
        );
      },
    );
  }
}

class _AuthQaExternalLoginLauncher implements ExternalLoginLauncher {
  const _AuthQaExternalLoginLauncher();

  @override
  Future<bool> launch(Uri uri) async => true;
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
  Future<List<String>> fetchOidcProviderIds() async {
    return const ['kakao'];
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

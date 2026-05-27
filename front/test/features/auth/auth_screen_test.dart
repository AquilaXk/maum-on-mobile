import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/auth/application/auth_controller.dart';
import 'package:maum_on_mobile_front/features/auth/data/auth_repository.dart';
import 'package:maum_on_mobile_front/features/auth/deeplink/external_login.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';
import 'package:maum_on_mobile_front/features/auth/presentation/auth_screen.dart';

void main() {
  testWidgets('signup validates fields before calling the repository',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      _AuthScreenHarness(repository: repository),
    );

    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'wrong-email',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'short',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-confirm-field')),
      'different',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-nickname-field')),
      'a',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('signup-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('올바른 이메일 주소를 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호는 8자 이상이어야 합니다.'), findsOneWidget);
    expect(find.text('비밀번호가 서로 일치하지 않습니다.'), findsOneWidget);
    expect(
      find.text('닉네임은 2자 이상 20자 이하로 입력해 주세요.'),
      findsOneWidget,
    );
    expect(find.text('필수 동의 항목을 확인해 주세요.'), findsOneWidget);
    expect(repository.signupRequests, isEmpty);
  });

  testWidgets('password reset request and confirmation return to login',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      _AuthScreenHarness(repository: repository),
    );

    await tester.tap(find.byKey(const ValueKey('password-reset-open-button')));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호 재설정'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('password-reset-email-field')),
      'me@example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey('password-reset-request-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.passwordResetEmails, ['me@example.com']);
    expect(
      find.byKey(const ValueKey('password-reset-token-field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('password-reset-token-field')),
      'reset-token',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-reset-new-password-field')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-reset-confirm-password-field')),
      'new-password',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('password-reset-confirm-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('password-reset-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.passwordResetConfirmations.single.token, 'reset-token');
    expect(
      repository.passwordResetConfirmations.single.newPassword,
      'new-password',
    );
    expect(find.byKey(const ValueKey('login-submit-button')), findsOneWidget);
    expect(
      find.text('비밀번호가 변경되었습니다. 다시 로그인해 주세요.'),
      findsOneWidget,
    );
  });

  testWidgets('exposes privacy, terms, support, and deletion guidance',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      _AuthScreenHarness(repository: repository),
    );

    expect(
        find.byKey(const ValueKey('auth-privacy-policy-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-terms-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-support-link')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth-account-deletion-guidance')),
      findsOneWidget,
    );

    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('필수 약관 및 개인정보 처리에 동의합니다.'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('auth-privacy-policy-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-terms-link')), findsOneWidget);
  });

  testWidgets('shows Apple login and hides Kakao on iOS', (tester) async {
    final repository = _FakeAuthRepository();
    final authController = AuthController(authRepository: repository);
    final launcher = _FakeExternalLoginLauncher();

    await tester.pumpWidget(
      _AuthScreenHarness(
        repository: repository,
        controller: authController,
        platform: TargetPlatform.iOS,
        externalLoginController: ExternalLoginController(
          authController: authController,
          launcher: launcher,
          config: ExternalLoginConfig(
            apiBaseUrl: Uri.parse('https://api.example.com'),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('external-login-apple-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('external-login-kakao-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('ios-review-email-login-guidance')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('auth-account-deletion-guidance')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('external-login-apple-button')),
    );
    await tester.tap(find.byKey(const ValueKey('external-login-apple-button')));
    await tester.pumpAndSettle();

    final launchedUri = launcher.launchedUris.single;
    expect(launchedUri.path, '/api/v1/auth/oidc/authorize/apple');
    expect(
      launchedUri.queryParameters['redirect_uri'],
      'maumon://auth/callback?provider=apple',
    );
  });

  testWidgets('keeps Kakao login available outside iOS review builds',
      (tester) async {
    final repository = _FakeAuthRepository();
    final authController = AuthController(authRepository: repository);

    await tester.pumpWidget(
      _AuthScreenHarness(
        repository: repository,
        controller: authController,
        platform: TargetPlatform.android,
        externalLoginController: ExternalLoginController(
          authController: authController,
          launcher: _FakeExternalLoginLauncher(),
          config: ExternalLoginConfig(
            apiBaseUrl: Uri.parse('https://api.example.com'),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('external-login-kakao-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('external-login-apple-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('ios-review-email-login-guidance')),
      findsNothing,
    );
  });
}

class _AuthScreenHarness extends StatelessWidget {
  const _AuthScreenHarness({
    required this.repository,
    this.controller,
    this.externalLoginController,
    this.platform,
  });

  final _FakeAuthRepository repository;
  final AuthController? controller;
  final ExternalLoginController? externalLoginController;
  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(platform: platform),
      home: AuthScreen(
        controller: controller ?? AuthController(authRepository: repository),
        externalLoginController: externalLoginController,
      ),
    );
  }
}

class _FakeExternalLoginLauncher implements ExternalLoginLauncher {
  final List<Uri> launchedUris = [];

  @override
  Future<bool> launch(Uri uri) async {
    launchedUris.add(uri);
    return true;
  }
}

class _FakeAuthRepository implements AuthRepository {
  final List<SignupRequest> signupRequests = [];
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
  Future<AuthSession> login(LoginRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> restoreSession() {
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

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearLocalSession() async {}

  @override
  Future<void> requestPasswordReset(PasswordResetRequest request) async {
    passwordResetEmails.add(request.email);
  }

  @override
  Future<void> confirmPasswordReset(PasswordResetConfirmRequest request) async {
    passwordResetConfirmations.add(
      _PasswordResetConfirmation(
        token: request.token,
        newPassword: request.newPassword,
      ),
    );
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

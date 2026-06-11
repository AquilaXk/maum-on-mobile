import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/auth/application/auth_controller.dart';
import 'package:maum_on_mobile_front/features/auth/data/auth_repository.dart';
import 'package:maum_on_mobile_front/features/auth/deeplink/external_login.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';
import 'package:maum_on_mobile_front/features/auth/domain/login_provider_policy.dart';
import 'package:maum_on_mobile_front/features/auth/presentation/auth_screen.dart';
import 'package:maum_on_mobile_front/shared/ui/brand_identity.dart';
import 'package:maum_on_mobile_front/theme/app_theme.dart';

void main() {
  test('login provider policy exposes only configured linked providers', () {
    expect(
      LoginProviderPolicy.providersFor(
        TargetPlatform.iOS,
        enabledProviderIds: ' kakao,apple,unknown ',
      ),
      [LoginProvider.kakao, LoginProvider.apple],
    );
    expect(
      LoginProviderPolicy.providersFor(
        TargetPlatform.android,
        enabledProviderIds: '',
      ),
      isEmpty,
    );
  });

  testWidgets('renders the product brand wordmark without helper copy',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      _AuthScreenHarness(repository: repository),
    );

    expect(
        find.byKey(const ValueKey('maum-on-brand-wordmark')), findsOneWidget);
    expect(find.bySemanticsLabel('Maum On'), findsOneWidget);
    expect(find.text('계정으로 마음 기록을 이어가세요.'), findsNothing);
    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-submit-button')), findsOneWidget);
  });

  testWidgets('keeps auth modes free of trust strip helper copy',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      _AuthScreenHarness(repository: repository),
    );

    expect(find.byKey(const ValueKey('auth-trust-strip')), findsNothing);
    expect(find.text('이메일 로그인'), findsNothing);
    expect(find.text('자동 로그인'), findsNothing);
    expect(find.text('안전한 기록'), findsNothing);

    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-trust-strip')), findsNothing);
    expect(find.text('6자리 코드'), findsNothing);
    expect(find.text('프로필 설정'), findsNothing);
  });

  testWidgets('keeps auth structure inside a blue visual shell',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      _AuthScreenHarness(repository: repository),
    );

    expect(find.byKey(const ValueKey('auth-blue-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-form-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-form-title-row')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-form-title-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password-field')), findsOneWidget);
  });

  testWidgets('keeps login panel on a light blue surface in dark system mode',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      _AuthScreenHarness(
        repository: repository,
        theme: buildDarkAppTheme(),
      ),
    );

    final panel = tester.widget<Card>(
      find.byKey(const ValueKey('auth-form-panel')),
    );

    expect(panel.color, AppBrandColors.surfaceStrong);
    expect(panel.color, isNot(const Color(0xFF111827)));
  });

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
    await tester.ensureVisible(
      find.byKey(const ValueKey('signup-email-verification-request-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-email-verification-request-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('올바른 이메일 주소를 입력해 주세요.'), findsOneWidget);
    expect(repository.signupVerificationEmails, isEmpty);
    expect(repository.signupRequests, isEmpty);
  });

  testWidgets('signup requests an email code before account details',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      _AuthScreenHarness(repository: repository),
    );

    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('signup-email-verification-code-field')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('login-password-field')), findsNothing);
    expect(find.byKey(const ValueKey('signup-nickname-field')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      '  me@example.com  ',
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-email-verification-request-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.signupVerificationEmails, ['me@example.com']);
    expect(find.text('인증번호를 이메일로 보냈습니다.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('signup-email-verification-code-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('login-password-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('signup-nickname-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth-trust-strip')),
      findsNothing,
    );
    expect(find.text('인증번호 확인'), findsNothing);
    expect(find.text('비밀번호 설정'), findsNothing);
    expect(find.text('프로필 설정'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('signup-email-verification-code-field')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'pass1234',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-password-confirm-field')),
      'pass1234',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup-nickname-field')),
      ' 마음이 ',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('signup-required-terms-checkbox')),
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-required-terms-checkbox')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('signup-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('signup-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.signupRequests.single.email, 'me@example.com');
    expect(repository.signupRequests.single.nickname, '마음이');
    expect(repository.signupRequests.single.emailVerificationCode, '123456');
    expect(find.byKey(const ValueKey('login-submit-button')), findsOneWidget);
  });

  testWidgets('password reset request and confirmation return to login',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      _AuthScreenHarness(repository: repository),
    );

    await tester.tap(find.byKey(const ValueKey('password-reset-open-button')));
    await tester.pumpAndSettle();
    expect(find.text('계정 이메일 확인'), findsOneWidget);

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

  testWidgets('exposes legal links without account deletion helper copy',
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
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('auth-account-deletion-link')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-account-deletion-link')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-account-deletion-link')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('auth-account-deletion-dialog')),
      findsOneWidget,
    );
    expect(find.text('로그인 후 설정에서 진행할 수 있습니다.'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('필수 약관 및 개인정보 처리에 동의합니다.'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'me@example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey('signup-email-verification-request-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('필수 약관 및 개인정보 처리에 동의합니다.'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('auth-privacy-policy-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-terms-link')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth-account-deletion-guidance')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('auth-account-deletion-link')),
      findsOneWidget,
    );
  });

  testWidgets('hides quick login when no provider is linked', (tester) async {
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
    expect(find.text('간편 로그인'), findsNothing);
    expect(
        find.byKey(const ValueKey('quick-login-provider-row')), findsNothing);
    _expectOnlyQuickLoginProviders([]);
    expect(
      find.byKey(const ValueKey('ios-review-email-login-guidance')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('auth-account-deletion-guidance')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('auth-account-deletion-link')),
      findsOneWidget,
    );
    expect(launcher.launchedUris, isEmpty);
  });

  testWidgets('shows configured Kakao quick login on Android', (tester) async {
    final repository = _FakeAuthRepository();
    final authController = AuthController(authRepository: repository);
    final launcher = _FakeExternalLoginLauncher();

    await tester.pumpWidget(
      _AuthScreenHarness(
        repository: repository,
        controller: authController,
        platform: TargetPlatform.android,
        loginProviders: const [LoginProvider.kakao],
        externalLoginController: ExternalLoginController(
          authController: authController,
          launcher: launcher,
          config: ExternalLoginConfig(
            apiBaseUrl: Uri.parse('https://api.example.com'),
          ),
        ),
      ),
    );

    _expectOnlyQuickLoginProviders(['kakao']);
    expect(
      find.byKey(const ValueKey('quick-login-provider-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ios-review-email-login-guidance')),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('external-login-kakao-button')),
    );
    await tester.tap(find.byKey(const ValueKey('external-login-kakao-button')));
    await tester.pumpAndSettle();

    final launchedUri = launcher.launchedUris.single;
    expect(launchedUri.path, '/api/v1/auth/oidc/authorize/kakao');
    expect(
      launchedUri.queryParameters['redirect_uri'],
      'maumon://auth/callback?provider=kakao',
    );
  });

  testWidgets('shows configured Apple quick login on iOS', (tester) async {
    final repository = _FakeAuthRepository();
    final authController = AuthController(authRepository: repository);
    final launcher = _FakeExternalLoginLauncher();

    await tester.pumpWidget(
      _AuthScreenHarness(
        repository: repository,
        controller: authController,
        platform: TargetPlatform.iOS,
        loginProviders: const [LoginProvider.apple],
        externalLoginController: ExternalLoginController(
          authController: authController,
          launcher: launcher,
          config: ExternalLoginConfig(
            apiBaseUrl: Uri.parse('https://api.example.com'),
          ),
        ),
      ),
    );

    _expectOnlyQuickLoginProviders(['apple']);
    expect(
      find.byKey(const ValueKey('quick-login-provider-row')),
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

  testWidgets('disables other auth actions while quick login is starting',
      (tester) async {
    final repository = _FakeAuthRepository();
    final authController = AuthController(authRepository: repository);
    final launcher = _PendingExternalLoginLauncher();
    final externalLoginController = ExternalLoginController(
      authController: authController,
      launcher: launcher,
      config: ExternalLoginConfig(
        apiBaseUrl: Uri.parse('https://api.example.com'),
      ),
    );

    await tester.pumpWidget(
      _AuthScreenHarness(
        repository: repository,
        controller: authController,
        platform: TargetPlatform.android,
        loginProviders: const [LoginProvider.kakao],
        externalLoginController: externalLoginController,
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('external-login-kakao-button')),
    );
    await tester.tap(find.byKey(const ValueKey('external-login-kakao-button')));
    await tester.pump();

    expect(launcher.launchedUris, hasLength(1));
    expect(externalLoginController.state.isStarting, isTrue);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('login-submit-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('password-reset-open-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('external-login-kakao-button')),
          )
          .properties
          .enabled,
      isFalse,
    );

    await tester.tap(find.text('새 계정 만들기'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('signup-email-verification-request-button')),
      findsNothing,
    );

    launcher.complete();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('login-submit-button')),
          )
          .onPressed,
      isNotNull,
    );
  });
}

void _expectOnlyQuickLoginProviders(List<String> visibleProviders) {
  for (final provider in ['naver', 'kakao', 'facebook', 'google', 'apple']) {
    final matcher =
        visibleProviders.contains(provider) ? findsOneWidget : findsNothing;
    expect(
      find.byKey(ValueKey('external-login-$provider-button')),
      matcher,
    );
  }
}

class _AuthScreenHarness extends StatelessWidget {
  const _AuthScreenHarness({
    required this.repository,
    this.controller,
    this.externalLoginController,
    this.loginProviders,
    this.platform,
    this.theme,
  });

  final _FakeAuthRepository repository;
  final AuthController? controller;
  final ExternalLoginController? externalLoginController;
  final List<LoginProvider>? loginProviders;
  final TargetPlatform? platform;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final authController =
        controller ?? AuthController(authRepository: repository);

    return MaterialApp(
      theme: (theme ?? buildAppTheme()).copyWith(platform: platform),
      home: AnimatedBuilder(
        animation: Listenable.merge([
          authController,
          externalLoginController,
        ]),
        builder: (context, _) {
          return AuthScreen(
            controller: authController,
            externalLoginController: externalLoginController,
            loginProviders: loginProviders,
          );
        },
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

class _PendingExternalLoginLauncher implements ExternalLoginLauncher {
  final List<Uri> launchedUris = [];
  final Completer<bool> _launchCompleter = Completer<bool>();

  @override
  Future<bool> launch(Uri uri) {
    launchedUris.add(uri);
    return _launchCompleter.future;
  }

  void complete([bool launched = true]) {
    _launchCompleter.complete(launched);
  }
}

class _FakeAuthRepository implements AuthRepository {
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

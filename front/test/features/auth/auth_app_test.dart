import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/app/maum_on_mobile_app.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/auth/data/auth_repository.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';

void main() {
  testWidgets('restores a session and renders the authenticated home', (tester) async {
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('마음이님, 오늘의 마음을 이어가세요.'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('shows a login failure message on the auth screen', (tester) async {
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(
          restoreError: const ApiClientException(
            kind: ApiErrorKind.unauthorized,
            message: '다시 로그인해 주세요.',
            statusCode: 401,
          ),
          loginError: const ApiClientException(
            kind: ApiErrorKind.unauthorized,
            message: '이메일 또는 비밀번호가 맞지 않아요.',
            statusCode: 401,
          ),
        ),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'wrong@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'bad-password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('이메일 또는 비밀번호가 맞지 않아요.'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
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
    this.restoredSession,
    this.restoreError,
    this.loginError,
  });

  final AuthSession? restoredSession;
  final Object? restoreError;
  final Object? loginError;

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
    return _session();
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
  Future<AuthMember> me() {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}
}

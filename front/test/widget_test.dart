import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/app/maum_on_mobile_app.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/app/supported_platforms.dart';
import 'package:maum_on_mobile_front/features/auth/data/auth_repository.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';

void main() {
  testWidgets('renders the initial auth screen contract', (tester) async {
    await tester.pumpWidget(
      MaumOnMobileApp(authRepository: _UnauthenticatedRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maum On'), findsOneWidget);
    expect(find.text('계정으로 마음 기록을 이어가세요.'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
    expect(find.text('새 계정 만들기'), findsOneWidget);
  });

  test('supports only Android and iOS at bootstrap', () {
    expect(supportedPlatforms, <String>['android', 'ios']);
  });
}

class _UnauthenticatedRepository implements AuthRepository {
  @override
  Future<AuthMember> signup(SignupRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> login(LoginRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> restoreSession() {
    throw const ApiClientException(
      kind: ApiErrorKind.unauthorized,
      message: '다시 로그인해 주세요.',
      statusCode: 401,
    );
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

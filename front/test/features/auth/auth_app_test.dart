import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/app/maum_on_mobile_app.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/auth/data/auth_repository.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';
import 'package:maum_on_mobile_front/features/diary/data/diary_repository.dart';
import 'package:maum_on_mobile_front/features/diary/domain/diary_models.dart';
import 'package:maum_on_mobile_front/features/diary/presentation/diary_image_picker.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/home/data/home_repository.dart';
import 'package:maum_on_mobile_front/features/home/domain/home_models.dart';

void main() {
  testWidgets('restores a session and renders the authenticated home',
      (tester) async {
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('마음이님, 오늘의 마음을 이어가세요.'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('navigates authenticated users from home to diary',
      (tester) async {
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('다이어리 쓰기'));
    await tester.pumpAndSettle();

    expect(find.text('나의 기록'), findsOneWidget);
  });

  testWidgets('shows a login failure message on the auth screen',
      (tester) async {
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
        homeRepository: const _FakeHomeRepository(),
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
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

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository();

  @override
  Future<HomeStats> fetchStats() async {
    return const HomeStats(
      todayWorryCount: 1,
      todayLetterCount: 2,
      todayDiaryCount: 3,
    );
  }

  @override
  Future<HomeStoryPage> fetchStories({
    HomeStoryCategory category = HomeStoryCategory.all,
  }) async {
    return const HomeStoryPage(items: [], last: true);
  }
}

class _FakeDiaryRepository implements DiaryRepository {
  @override
  Future<PageResponse<DiaryEntry>> fetchDiaries({
    int page = 0,
    int size = 100,
  }) async {
    return const PageResponse(
      items: [],
      page: 0,
      size: 100,
      totalElements: 0,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<DiaryEntry> fetchDiary(int id) {
    throw UnimplementedError();
  }

  @override
  Future<int> createDiary(DiaryDraft draft) async => 1;

  @override
  Future<void> updateDiary(int id, DiaryDraft draft) async {}

  @override
  Future<void> deleteDiary(int id) async {}
}

class _FakeDiaryImagePicker implements DiaryImagePicker {
  const _FakeDiaryImagePicker();

  @override
  Future<DiaryImageAttachment?> pickImage() async {
    return null;
  }
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

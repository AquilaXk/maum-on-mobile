import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/app/maum_on_mobile_app.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/auth/data/auth_repository.dart';
import 'package:maum_on_mobile_front/features/auth/domain/auth_models.dart';
import 'package:maum_on_mobile_front/features/consultation/data/consultation_repository.dart';
import 'package:maum_on_mobile_front/features/consultation/domain/consultation_models.dart';
import 'package:maum_on_mobile_front/features/diary/data/diary_repository.dart';
import 'package:maum_on_mobile_front/features/diary/domain/diary_models.dart';
import 'package:maum_on_mobile_front/features/diary/presentation/diary_image_picker.dart';
import 'package:maum_on_mobile_front/features/home/data/home_repository.dart';
import 'package:maum_on_mobile_front/features/home/domain/home_models.dart';
import 'package:maum_on_mobile_front/features/letter/data/letter_repository.dart';
import 'package:maum_on_mobile_front/features/letter/domain/letter_models.dart';
import 'package:maum_on_mobile_front/features/notification/data/notification_repository.dart';
import 'package:maum_on_mobile_front/features/notification/domain/notification_models.dart';
import 'package:maum_on_mobile_front/features/report/data/report_repository.dart';
import 'package:maum_on_mobile_front/features/report/domain/report_models.dart';
import 'package:maum_on_mobile_front/features/settings/data/settings_repository.dart';
import 'package:maum_on_mobile_front/features/settings/domain/settings_models.dart';
import 'package:maum_on_mobile_front/features/story/data/story_repository.dart';
import 'package:maum_on_mobile_front/features/story/domain/story_models.dart';

void main() {
  testWidgets('restores a session and renders the authenticated home',
      (tester) async {
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(),
        letterRepository: _FakeLetterRepository(),
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
        storyRepository: _FakeStoryRepository(),
        letterRepository: _FakeLetterRepository(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('다이어리 쓰기'));
    await tester.pumpAndSettle();

    expect(find.text('나의 기록'), findsOneWidget);
  });

  testWidgets('system back returns authenticated users from diary to home',
      (tester) async {
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(),
        letterRepository: _FakeLetterRepository(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('다이어리 쓰기'));
    await tester.pumpAndSettle();

    expect(find.text('나의 기록'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('마음이님, 오늘의 마음을 이어가세요.'), findsOneWidget);
    expect(find.text('나의 기록'), findsNothing);
  });

  testWidgets('navigates authenticated users from home to letters',
      (tester) async {
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(),
        letterRepository: _FakeLetterRepository(
          statsQueue: [
            const LetterStats(receivedCount: 1),
          ],
          receivedPages: [
            const LetterListPage(
              items: [
                LetterSummary(
                  id: 1,
                  title: '도착한 편지',
                  content: '요약',
                  createdDate: '2026-05-24T08:00:00',
                  status: LetterStatus.sent,
                ),
              ],
              totalPages: 1,
              totalElements: 1,
              currentPage: 0,
              isFirst: true,
              isLast: true,
            ),
          ],
        ),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('편지 쓰기'));
    await tester.pumpAndSettle();

    expect(find.text('편지함'), findsOneWidget);
    expect(find.byKey(const ValueKey('letter-title-field')), findsOneWidget);
  });

  testWidgets('navigates authenticated users from home to consultation',
      (tester) async {
    final consultationRepository = _FakeConsultationRepository();
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        consultationRepository: consultationRepository,
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(),
        letterRepository: _FakeLetterRepository(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('상담하기'));
    await tester.pump();
    consultationRepository.emit(
      const ConsultationStreamEvent.connect('connected'),
    );
    await tester.pump();

    expect(find.text('실시간 상담'), findsOneWidget);
    expect(find.text('연결됨'), findsOneWidget);
    expect(consultationRepository.connectCount, 1);
  });

  testWidgets('navigates authenticated users from home to notifications',
      (tester) async {
    final notificationRepository = _FakeNotificationRepository();
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        consultationRepository: _FakeConsultationRepository(),
        notificationRepository: notificationRepository,
        reportRepository: _FakeReportRepository(),
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(),
        letterRepository: _FakeLetterRepository(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('알림/신고'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알림/신고'));
    await tester.pump();
    notificationRepository.emit(
      const NotificationStreamEvent.connect('연결되었습니다!'),
    );
    await tester.pump();

    expect(find.text('알림/신고'), findsWidgets);
    expect(find.text('연결됨'), findsOneWidget);
    expect(notificationRepository.ticketRequestCount, 1);
  });

  testWidgets('navigates authenticated users to settings and clears session',
      (tester) async {
    final authRepository = _FakeAuthRepository(restoredSession: _session());
    final settingsRepository = _FakeSettingsRepository();
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: authRepository,
        homeRepository: const _FakeHomeRepository(),
        settingsRepository: settingsRepository,
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(),
        letterRepository: _FakeLetterRepository(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('설정'));
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();

    expect(find.text('계정 설정'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-request-withdraw')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-request-withdraw')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-withdraw-password')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('settings-withdraw-password')),
      'old-password',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-confirm-withdraw')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-confirm-withdraw')));
    await tester.pumpAndSettle();

    expect(settingsRepository.withdrawPasswords, ['old-password']);
    expect(authRepository.logoutCount, 1);
    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
  });

  testWidgets('navigates authenticated users from home to story list',
      (tester) async {
    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(
          storyPages: [
            const PageResponse(
              items: [
                StorySummary(
                  id: 1,
                  title: '오늘의 스토리',
                  summary: '요약',
                  authorNickname: '마음이',
                  category: StoryCategory.worry,
                  resolutionStatus: StoryResolutionStatus.ongoing,
                  viewCount: 1,
                  createDate: '2026-05-24T08:00:00',
                  modifyDate: '2026-05-24T08:00:00',
                ),
              ],
              page: 0,
              size: 20,
              totalElements: 1,
              totalPages: 1,
              last: true,
            ),
          ],
        ),
        letterRepository: _FakeLetterRepository(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('스토리 보기'));
    await tester.pumpAndSettle();

    expect(find.text('스토리'), findsOneWidget);
    expect(find.text('오늘의 스토리'), findsOneWidget);
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
        storyRepository: _FakeStoryRepository(),
        letterRepository: _FakeLetterRepository(),
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

class _FakeConsultationRepository implements ConsultationRepository {
  int connectCount = 0;
  StreamController<ConsultationStreamEvent>? _controller;

  @override
  Stream<ConsultationStreamEvent> connect() {
    connectCount += 1;
    _controller = StreamController<ConsultationStreamEvent>(sync: true);
    return _controller!.stream;
  }

  @override
  Future<void> sendMessage(String message) async {}

  void emit(ConsultationStreamEvent event) {
    _controller?.add(event);
  }
}

class _FakeNotificationRepository implements NotificationRepository {
  int ticketRequestCount = 0;
  StreamController<NotificationStreamEvent>? _controller;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    return const [
      NotificationItem(
        id: 1,
        content: '상대방이 편지를 읽었습니다.',
        isRead: false,
        createdAt: '2026-05-24T09:00:00',
      ),
    ];
  }

  @override
  Future<NotificationSubscriptionTicket> requestSubscriptionTicket() async {
    ticketRequestCount += 1;
    return const NotificationSubscriptionTicket(
      ticket: 'ticket-1',
      expiresInSeconds: 60,
    );
  }

  @override
  Stream<NotificationStreamEvent> connect(String ticket) {
    _controller = StreamController<NotificationStreamEvent>(sync: true);
    return _controller!.stream;
  }

  void emit(NotificationStreamEvent event) {
    _controller?.add(event);
  }
}

class _FakeReportRepository implements ReportRepository {
  final List<ReportDraft> drafts = [];

  @override
  Future<int> createReport(ReportDraft draft) async {
    drafts.add(draft);
    return drafts.length;
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  final List<String?> withdrawPasswords = [];
  MemberSettings settings = const MemberSettings(
    id: 7,
    email: 'me@example.com',
    nickname: '마음이',
    randomReceiveAllowed: true,
    socialAccount: false,
  );

  @override
  Future<MemberSettings> fetchSettings() async => settings;

  @override
  Future<MemberSettings> updateNickname(String nickname) async {
    settings = settings.copyWith(nickname: nickname);
    return settings;
  }

  @override
  Future<MemberSettings> updateEmail(String email) async {
    settings = settings.copyWith(email: email);
    return settings;
  }

  @override
  Future<MemberSettings> updatePassword(PasswordChangeDraft draft) async {
    return settings;
  }

  @override
  Future<MemberSettings> toggleRandomSetting() async {
    settings = settings.copyWith(
      randomReceiveAllowed: !settings.randomReceiveAllowed,
    );
    return settings;
  }

  @override
  Future<void> withdraw({String? currentPassword}) async {
    withdrawPasswords.add(currentPassword);
  }
}

class _FakeStoryRepository implements StoryRepository {
  _FakeStoryRepository({
    List<PageResponse<StorySummary>> storyPages = const [
      PageResponse(
        items: [],
        page: 0,
        size: 20,
        totalElements: 0,
        totalPages: 1,
        last: true,
      ),
    ],
  }) : _storyPages = List<PageResponse<StorySummary>>.of(storyPages);

  final List<PageResponse<StorySummary>> _storyPages;

  @override
  Future<PageResponse<StorySummary>> fetchStories({
    String? title,
    StoryCategory category = StoryCategory.all,
    int page = 0,
    int size = 20,
  }) async {
    return _storyPages.isEmpty
        ? const PageResponse(
            items: [],
            page: 0,
            size: 20,
            totalElements: 0,
            totalPages: 1,
            last: true,
          )
        : _storyPages.removeAt(0);
  }

  @override
  Future<StoryDetail> fetchStory(int id) {
    throw UnimplementedError();
  }

  @override
  Future<int> createStory(StoryDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateStory(int id, StoryDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteStory(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateResolutionStatus(
    int id,
    StoryResolutionStatus status,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<PageResponse<StoryComment>> fetchComments(
    int postId, {
    int page = 0,
    int size = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> createComment({
    required int postId,
    required int authorId,
    required String content,
    int? parentCommentId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateComment(int commentId, String content) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteComment(int commentId) {
    throw UnimplementedError();
  }
}

class _FakeLetterRepository implements LetterRepository {
  _FakeLetterRepository({
    List<LetterStats> statsQueue = const [
      LetterStats(receivedCount: 0),
    ],
    List<LetterListPage> receivedPages = const [
      LetterListPage(
        items: [],
        totalPages: 1,
        totalElements: 0,
        currentPage: 0,
        isFirst: true,
        isLast: true,
      ),
    ],
    List<LetterListPage> sentPages = const [
      LetterListPage(
        items: [],
        totalPages: 1,
        totalElements: 0,
        currentPage: 0,
        isFirst: true,
        isLast: true,
      ),
    ],
  })  : _statsQueue = List<LetterStats>.of(statsQueue),
        _receivedPages = List<LetterListPage>.of(receivedPages),
        _sentPages = List<LetterListPage>.of(sentPages);

  final List<LetterStats> _statsQueue;
  final List<LetterListPage> _receivedPages;
  final List<LetterListPage> _sentPages;

  @override
  Future<int> createLetter(LetterDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<LetterListPage> fetchReceivedLetters({
    int page = 0,
    int size = 20,
  }) async {
    return _receivedPages.isEmpty
        ? const LetterListPage(
            items: [],
            totalPages: 1,
            totalElements: 0,
            currentPage: 0,
            isFirst: true,
            isLast: true,
          )
        : _receivedPages.removeAt(0);
  }

  @override
  Future<LetterListPage> fetchSentLetters({
    int page = 0,
    int size = 20,
  }) async {
    return _sentPages.isEmpty
        ? const LetterListPage(
            items: [],
            totalPages: 1,
            totalElements: 0,
            currentPage: 0,
            isFirst: true,
            isLast: true,
          )
        : _sentPages.removeAt(0);
  }

  @override
  Future<LetterDetail> fetchLetter(int id) {
    throw UnimplementedError();
  }

  @override
  Future<LetterStats> fetchStats() async {
    return _statsQueue.isEmpty
        ? const LetterStats(receivedCount: 0)
        : _statsQueue.removeAt(0);
  }

  @override
  Future<void> replyLetter(int id, String replyContent) {
    throw UnimplementedError();
  }

  @override
  Future<void> acceptLetter(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> rejectLetter(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> markWriting(int id) {
    throw UnimplementedError();
  }

  @override
  Future<LetterStatus> fetchLiveStatus(int id) {
    throw UnimplementedError();
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
  int logoutCount = 0;

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
  Future<void> logout() async {
    logoutCount += 1;
  }
}

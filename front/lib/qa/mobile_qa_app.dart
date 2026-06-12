import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/maum_on_mobile_app.dart';
import '../core/network/api_response.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/consultation/data/consultation_repository.dart';
import '../features/consultation/domain/consultation_models.dart';
import '../features/diary/data/diary_image_repository.dart';
import '../features/diary/data/diary_repository.dart';
import '../features/diary/domain/diary_models.dart';
import '../features/diary/presentation/diary_image_picker.dart';
import '../features/draft_recovery/data/draft_recovery_repository.dart';
import '../features/draft_recovery/domain/draft_recovery_models.dart';
import '../features/home/data/home_repository.dart';
import '../features/home/domain/home_models.dart';
import '../features/letter/data/letter_repository.dart';
import '../features/letter/domain/letter_models.dart';
import '../features/moderation/data/content_moderation_repository.dart';
import '../features/moderation/domain/content_moderation_models.dart';
import '../features/notification/data/notification_repository.dart';
import '../features/notification/data/push_notification_permission_client.dart';
import '../features/notification/domain/notification_models.dart';
import '../features/report/data/report_repository.dart';
import '../features/report/domain/report_models.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/domain/settings_models.dart';
import '../features/story/data/story_repository.dart';
import '../features/story/domain/story_models.dart';

void main() {
  runApp(buildMobileQaApp());
}

Widget buildMobileQaApp() {
  return MaumOnMobileApp(
    authRepository: const _QaAuthRepository(),
    homeRepository: const _QaHomeRepository(),
    diaryRepository: const _QaDiaryRepository(),
    diaryImageRepository: const _QaDiaryImageRepository(),
    diaryImagePicker: const _QaDiaryImagePicker(),
    draftRecoveryRepository: const _QaDraftRecoveryRepository(),
    storyRepository: const _QaStoryRepository(),
    letterRepository: const _QaLetterRepository(),
    consultationRepository: _QaConsultationRepository(),
    notificationRepository: _QaNotificationRepository(),
    pushNotificationPermissionClient: const _QaPushPermissionClient(),
    reportRepository: const _QaReportRepository(),
    settingsRepository: _QaSettingsRepository(),
    contentModerationRepository: const _QaContentModerationRepository(),
    listenForDeepLinks: false,
  );
}

ValueKey<String> mobileQaRouteKey(String routeKey) {
  return ValueKey('route-tab-$routeKey');
}

class _QaAuthRepository implements AuthRepository {
  const _QaAuthRepository();

  @override
  Future<AuthSession> restoreSession() async => _qaSession();

  @override
  Future<AuthSession> login(LoginRequest request) async => _qaSession();

  @override
  Future<AuthSession> refreshSession() async => _qaSession();

  @override
  Future<void> saveSession(AuthSession session) async {}

  @override
  Future<AuthMember> me() async => _qaSession().member;

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearLocalSession() async {}

  @override
  Future<void> requestSignupEmailVerification(
    SignupEmailVerificationRequest request,
  ) async {}

  @override
  Future<AuthMember> signup(SignupRequest request) async => _qaSession().member;

  @override
  Future<void> requestPasswordReset(PasswordResetRequest request) async {}

  @override
  Future<void> confirmPasswordReset(
      PasswordResetConfirmRequest request) async {}

  @override
  Future<AuthSession> exchangeOidcSession(OidcSessionRequest request) async {
    return _qaSession();
  }
}

class _QaHomeRepository implements HomeRepository {
  const _QaHomeRepository();

  @override
  Future<HomeStats> fetchStats() async {
    return const HomeStats(
      todayWorryCount: 8,
      todayLetterCount: 5,
      todayDiaryCount: 12,
      summary: HomeSummary(
        recoveryMessage: '오늘은 마음을 크게 바꾸려 하기보다 한 문장만 남겨도 충분해요.',
        primaryActionLabel: '마음 기록하기',
        primaryActionSurface: HomeActionSurface.diary,
        feedMessage: '최근 마음 나눔이 차분히 이어지고 있어요.',
      ),
      categorySummaries: [
        HomeCategorySummary(
          category: HomeStoryCategory.worry,
          label: '고민',
          count: 4,
        ),
        HomeCategorySummary(
          category: HomeStoryCategory.daily,
          label: '일상',
          count: 3,
        ),
      ],
      popularStories: [
        HomePopularStory(
          id: 1,
          title: '관계를 천천히 회복하는 방법',
          category: HomeStoryCategory.worry,
          label: '고민',
          viewCount: 32,
          nickname: '마음이',
        ),
      ],
    );
  }

  @override
  Future<HomeStoryPage> fetchStories({
    HomeStoryCategory category = HomeStoryCategory.all,
  }) async {
    final items = category == HomeStoryCategory.all
        ? const [
            HomeStory(
              id: 1,
              title: '관계를 천천히 회복하는 방법',
              summary: '답답했던 하루를 정리하고 다시 대화를 준비하는 이야기',
              authorNickname: '마음이',
              category: HomeStoryCategory.worry,
              createdAt: '2026-06-05T09:00:00',
              viewCount: 32,
            ),
            HomeStory(
              id: 2,
              title: '작은 산책이 남긴 여유',
              summary: '평범한 하루에서 찾은 회복의 장면',
              authorNickname: '온기',
              category: HomeStoryCategory.daily,
              createdAt: '2026-06-05T10:00:00',
              viewCount: 18,
            ),
            HomeStory(
              id: 3,
              title: '다른 관점을 묻는 밤',
              summary: '다른 사람의 관점을 묻고 답을 기다리는 이야기',
              authorNickname: '물음표',
              category: HomeStoryCategory.question,
              createdAt: '2026-06-05T11:00:00',
              viewCount: 11,
            ),
          ]
        : [_qaHomeStory(category)];

    return HomeStoryPage(
      items: items,
      last: true,
    );
  }
}

HomeStory _qaHomeStory(HomeStoryCategory category) {
  return switch (category) {
    HomeStoryCategory.worry => const HomeStory(
        id: 11,
        title: '복잡한 마음을 꺼내는 연습',
        summary: '복잡한 마음을 안전하게 꺼내 보는 이야기',
        authorNickname: '마음이',
        category: HomeStoryCategory.worry,
        createdAt: '2026-06-05T09:30:00',
        viewCount: 21,
      ),
    HomeStoryCategory.daily => const HomeStory(
        id: 12,
        title: '작은 산책이 남긴 여유',
        summary: '평범한 하루에서 찾은 회복의 장면',
        authorNickname: '온기',
        category: HomeStoryCategory.daily,
        createdAt: '2026-06-05T10:30:00',
        viewCount: 18,
      ),
    HomeStoryCategory.question => const HomeStory(
        id: 13,
        title: '다른 관점을 묻는 밤',
        summary: '다른 사람의 관점을 묻고 답을 기다리는 이야기',
        authorNickname: '물음표',
        category: HomeStoryCategory.question,
        createdAt: '2026-06-05T11:30:00',
        viewCount: 11,
      ),
    HomeStoryCategory.all => _qaHomeStory(HomeStoryCategory.worry),
  };
}

class _QaDiaryRepository implements DiaryRepository {
  const _QaDiaryRepository();

  @override
  Future<PageResponse<DiaryEntry>> fetchDiaries({
    int page = 0,
    int size = 100,
  }) async {
    return PageResponse(
      items: [_qaDiary()],
      page: page,
      size: size,
      totalElements: 1,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<PageResponse<DiaryEntry>> fetchPublicDiaries({
    int page = 0,
    int size = 20,
  }) async {
    return PageResponse(
      items: [_qaDiary(id: 2, title: '공개 마음 기록')],
      page: page,
      size: size,
      totalElements: 1,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<DiaryEntry> fetchDiary(int id) async => _qaDiary(id: id);

  @override
  Future<int> createDiary(DiaryDraft draft) async => 10;

  @override
  Future<void> updateDiary(int id, DiaryDraft draft) async {}

  @override
  Future<void> deleteDiary(int id) async {}
}

class _QaDiaryImageRepository implements DiaryImageRepository {
  const _QaDiaryImageRepository();

  @override
  Future<UploadedDiaryImage> uploadImage(DiaryImageAttachment image) async {
    return UploadedDiaryImage(
      imageUrl: 'https://example.invalid/qa/${image.filename}',
      originalFilename: image.filename,
      contentType: image.contentType,
      byteSize: image.byteSize,
      status: 'UPLOADED',
    );
  }

  @override
  Future<void> deleteImage(String imageUrl) async {}
}

class _QaDiaryImagePicker implements DiaryImagePicker {
  const _QaDiaryImagePicker();

  @override
  Future<DiaryImagePickResult> pickImage(DiaryImageSource source) async {
    return const DiaryImagePickResult.cancelled();
  }

  @override
  Future<bool> openSettings() async => true;
}

class _QaDraftRecoveryRepository implements DraftRecoveryRepository {
  const _QaDraftRecoveryRepository();

  @override
  Future<List<DraftEntry>> listFailed({
    required int memberId,
    DraftSurface? surface,
  }) async {
    return const [];
  }

  @override
  Future<DraftEntry?> read(DraftKey key) async => null;

  @override
  Future<void> saveEditing(
    DraftKey key, {
    required Map<String, String> fields,
  }) async {}

  @override
  Future<void> markFailed(
    DraftKey key, {
    required Map<String, String> fields,
    required String failureMessage,
  }) async {}

  @override
  Future<void> delete(DraftKey key) async {}

  @override
  Future<void> clearMember(int memberId) async {}
}

class _QaStoryRepository implements StoryRepository {
  const _QaStoryRepository();

  @override
  Future<PageResponse<StorySummary>> fetchStories({
    String? title,
    StoryCategory category = StoryCategory.all,
    int page = 0,
    int size = 20,
  }) async {
    final normalizedTitle = title?.trim();
    final items = _qaStorySummaries.where((story) {
      final matchesTitle = normalizedTitle == null ||
          normalizedTitle.isEmpty ||
          story.title.contains(normalizedTitle);
      final matchesCategory =
          category == StoryCategory.all || story.category == category;
      return matchesTitle && matchesCategory;
    }).toList(growable: false);

    return PageResponse(
      items: items,
      page: page,
      size: size,
      totalElements: items.length,
      totalPages: items.isEmpty ? 0 : 1,
      last: true,
    );
  }

  @override
  Future<StoryDetail> fetchStory(int id) async {
    return StoryDetail(
      id: id,
      title: '오늘의 스토리',
      content: '마음을 천천히 꺼내 놓는 연습을 하고 있어요.',
      summary: '',
      authorNickname: '마음이',
      category: StoryCategory.daily,
      resolutionStatus: StoryResolutionStatus.ongoing,
      viewCount: 21,
      createDate: '2026-06-05T08:00:00',
      modifyDate: '2026-06-05T08:00:00',
      authorId: 7,
    );
  }

  @override
  Future<int> createStory(StoryDraft draft) async => 11;

  @override
  Future<void> updateStory(int id, StoryDraft draft) async {}

  @override
  Future<void> deleteStory(int id) async {}

  @override
  Future<void> updateResolutionStatus(
    int id,
    StoryResolutionStatus status,
  ) async {}

  @override
  Future<PageResponse<StoryComment>> fetchComments(
    int postId, {
    int page = 0,
    int size = 20,
  }) async {
    return PageResponse(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<void> createComment({
    required int postId,
    required int authorId,
    required String content,
    int? parentCommentId,
  }) async {}

  @override
  Future<void> updateComment(int commentId, String content) async {}

  @override
  Future<void> deleteComment(int commentId) async {}
}

const _qaStorySummaries = [
  StorySummary(
    id: 1,
    title: '오늘의 스토리',
    summary: '마음을 천천히 꺼내 놓는 연습을 하고 있어요.',
    authorNickname: '마음이',
    category: StoryCategory.daily,
    resolutionStatus: StoryResolutionStatus.ongoing,
    viewCount: 21,
    createDate: '2026-06-05T08:00:00',
    modifyDate: '2026-06-05T08:00:00',
  ),
];

class _QaLetterRepository implements LetterRepository {
  const _QaLetterRepository();

  @override
  Future<LetterStats> fetchStats() async {
    return const LetterStats(receivedCount: 1);
  }

  @override
  Future<LetterListPage> fetchReceivedLetters({
    int page = 0,
    int size = 20,
  }) async {
    return const LetterListPage(
      items: [
        LetterSummary(
          id: 1,
          title: '도착한 편지',
          content: '오늘은 스스로를 조금 더 다정하게 바라봐도 괜찮아요.',
          createdDate: '2026-06-05T08:30:00',
          status: LetterStatus.sent,
          senderNickname: '친구',
        ),
      ],
      totalPages: 1,
      totalElements: 1,
      currentPage: 0,
      isFirst: true,
      isLast: true,
    );
  }

  @override
  Future<LetterListPage> fetchSentLetters({
    int page = 0,
    int size = 20,
  }) async {
    return const LetterListPage(
      items: [],
      totalPages: 1,
      totalElements: 0,
      currentPage: 0,
      isFirst: true,
      isLast: true,
    );
  }

  @override
  Future<LetterDetail> fetchLetter(int id) async {
    return LetterDetail(
      id: id,
      title: '도착한 편지',
      content: '오늘은 스스로를 조금 더 다정하게 바라봐도 괜찮아요.',
      status: LetterStatus.sent,
      replied: false,
      createdDate: '2026-06-05T08:30:00',
      senderNickname: '친구',
    );
  }

  @override
  Future<int> createLetter(LetterDraft draft) async => 12;

  @override
  Future<void> replyLetter(int id, String replyContent) async {}

  @override
  Future<void> acceptLetter(int id) async {}

  @override
  Future<void> rejectLetter(int id) async {}

  @override
  Future<void> markWriting(int id) async {}

  @override
  Future<LetterStatus> fetchLiveStatus(int id) async => LetterStatus.sent;
}

class _QaConsultationRepository implements ConsultationRepository {
  final StreamController<ConsultationStreamEvent> _events =
      StreamController<ConsultationStreamEvent>.broadcast(sync: true);

  @override
  Stream<ConsultationStreamEvent> connect() {
    Future<void>.microtask(
      () => _events.add(const ConsultationStreamEvent.connect('connected')),
    );
    return _events.stream;
  }

  @override
  Future<List<ConsultationMessage>> loadRecentMessages() async {
    return [
      ConsultationMessage(
        id: 'qa-assistant-1',
        role: ConsultationMessageRole.assistant,
        content: '안녕하세요. 지금 마음에 남아 있는 장면부터 천천히 이야기해 주세요.',
        createdAt: DateTime(2026, 6, 5, 9),
      ),
    ];
  }

  @override
  Future<ConsultationSendResult> sendMessage(String message) async {
    final reply = _qaConsultationReply(message);
    Future<void>.delayed(const Duration(milliseconds: 20), () {
      _events
        ..add(ConsultationStreamEvent.chat(reply))
        ..add(const ConsultationStreamEvent.done());
    });
    return const ConsultationSendResult(accepted: true);
  }

  @override
  Future<int> deleteSensitiveMessages() async => 0;
}

String _qaConsultationReply(String message) {
  final normalized = message.trim();
  if (normalized.length > 120) {
    return '말해줘서 고마워요. 마음에 쌓인 말이 많았던 만큼, 지금은 한 번에 해결하려 하기보다 가장 무거운 감정 하나만 천천히 짚어봐요. 지금 제일 먼저 내려놓고 싶은 마음은 무엇인가요?';
  }

  return '말해줘서 고마워요. 지금 마음이 무거운 상태라면, 먼저 숨을 천천히 고르고 가장 크게 남은 감정 하나만 짚어봐요. 지금 제일 크게 느껴지는 감정은 무엇인가요?';
}

class _QaNotificationRepository implements NotificationRepository {
  final StreamController<NotificationStreamEvent> _events =
      StreamController<NotificationStreamEvent>.broadcast(sync: true);

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    return const [
      NotificationItem(
        id: 1,
        content: 'AI 상담 답변이 도착했습니다.',
        type: 'consultation_reply',
        routeKey: 'consultation',
        targetType: 'CONSULTATION',
        targetId: 1,
        isRead: false,
        createdAt: '2026-06-05T09:15:00',
      ),
    ];
  }

  @override
  Future<NotificationItem> markRead(int notificationId) async {
    return NotificationItem(
      id: notificationId,
      content: 'AI 상담 답변이 도착했습니다.',
      type: 'consultation_reply',
      routeKey: 'consultation',
      targetType: 'CONSULTATION',
      targetId: 1,
      isRead: true,
      createdAt: '2026-06-05T09:15:00',
      readAt: '2026-06-05T09:16:00',
    );
  }

  @override
  Future<NotificationBulkReadResult> markAllRead() async {
    return const NotificationBulkReadResult(updatedCount: 1);
  }

  @override
  Future<NotificationDeviceTokenResult> registerDeviceToken({
    required NotificationDevicePlatform platform,
    required String token,
  }) async {
    return NotificationDeviceTokenResult(
      platform: platform,
      enabled: true,
      updatedAt: '2026-06-05T09:17:00',
    );
  }

  @override
  Future<bool> unregisterDeviceToken(String token) async => true;

  @override
  Future<NotificationSubscriptionTicket> requestSubscriptionTicket() async {
    return const NotificationSubscriptionTicket(
      ticket: 'qa-ticket',
      expiresInSeconds: 300,
    );
  }

  @override
  Stream<NotificationStreamEvent> connect(String ticket) {
    Future<void>.microtask(
      () => _events.add(const NotificationStreamEvent.connect('connected')),
    );
    return _events.stream;
  }
}

class _QaPushPermissionClient implements PushNotificationPermissionClient {
  const _QaPushPermissionClient();

  @override
  Future<PushNotificationPermissionResult> requestPermission() async {
    return PushNotificationPermissionResult(
      granted: true,
      platform: _qaNotificationPlatform(),
      token: 'qa-token',
    );
  }

  @override
  Future<PushNotificationPermissionResult> getPermissionStatus() async {
    return PushNotificationPermissionResult(
      granted: true,
      platform: _qaNotificationPlatform(),
      token: 'qa-token',
    );
  }

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<NotificationTapPayload?> takeInitialNotificationTap() async => null;

  @override
  Stream<NotificationTapPayload> get notificationTaps => const Stream.empty();
}

NotificationDevicePlatform _qaNotificationPlatform() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => NotificationDevicePlatform.android,
    TargetPlatform.iOS => NotificationDevicePlatform.ios,
    _ => NotificationDevicePlatform.ios,
  };
}

class _QaReportRepository implements ReportRepository {
  const _QaReportRepository();

  @override
  Future<int> createReport(ReportDraft draft) async => 1;
}

class _QaSettingsRepository implements SettingsRepository {
  MemberSettings _settings = const MemberSettings(
    id: 7,
    email: 'admin@maum.on',
    nickname: '마음이',
    randomReceiveAllowed: true,
    socialAccount: false,
  );

  @override
  Future<MemberSettings> fetchSettings() async => _settings;

  @override
  Future<MemberSettings> updateNickname(String nickname) async {
    _settings = _settings.copyWith(nickname: nickname);
    return _settings;
  }

  @override
  Future<MemberSettings> updateEmail(String email) async {
    _settings = _settings.copyWith(email: email);
    return _settings;
  }

  @override
  Future<MemberSettings> updatePassword(PasswordChangeDraft draft) async {
    return _settings;
  }

  @override
  Future<MemberSettings> toggleRandomSetting() async {
    _settings = _settings.copyWith(
      randomReceiveAllowed: !_settings.randomReceiveAllowed,
    );
    return _settings;
  }

  @override
  Future<MemberDataExportJob> requestDataExport() async {
    return const MemberDataExportJob(
      id: 1,
      status: MemberDataExportStatus.completed,
      requestedAt: '2026-06-05T09:30:00Z',
      completedAt: '2026-06-05T09:30:00Z',
      expiresAt: '2999-06-05T09:30:00Z',
      downloadUrl: '/exports/1',
    );
  }

  @override
  Future<MemberDataExportJob> fetchDataExportStatus(int exportId) async {
    return MemberDataExportJob(
      id: exportId,
      status: MemberDataExportStatus.completed,
      requestedAt: '2026-06-05T09:30:00Z',
      completedAt: '2026-06-05T09:30:00Z',
      expiresAt: '2999-06-05T09:30:00Z',
      downloadUrl: '/exports/$exportId',
    );
  }

  @override
  Future<MemberDataExportFile> downloadDataExport(int exportId) async {
    return MemberDataExportFile(
      filename: 'maum-on-export-$exportId.json',
      contentType: 'application/json',
      content: '{"ready":true}',
      expiresAt: '2999-06-05T09:30:00Z',
    );
  }

  @override
  Future<void> withdraw({String? currentPassword}) async {}
}

class _QaContentModerationRepository implements ContentModerationRepository {
  const _QaContentModerationRepository();

  @override
  Future<ContentModerationResult> reviewText({
    required ContentModerationTarget targetType,
    required String text,
  }) async {
    return const ContentModerationResult(
      allowed: true,
      riskLevel: ContentModerationRiskLevel.low,
      message: '입력 내용을 저장할 수 있습니다.',
      categories: [],
    );
  }
}

AuthSession _qaSession() {
  return const AuthSession(
    accessToken: 'qa-access-token',
    tokenType: 'Bearer',
    expiresInSeconds: 3600,
    member: AuthMember(
      id: 7,
      email: 'admin@maum.on',
      nickname: '마음이',
      role: 'ADMIN',
      status: 'ACTIVE',
    ),
  );
}

DiaryEntry _qaDiary({int id = 1, String title = '오늘 마음 기록'}) {
  return DiaryEntry(
    id: id,
    title: title,
    content: '아침에 느낀 감정을 짧게 적어 두었습니다.',
    category: DiaryCategory.daily,
    nickname: '마음이',
    imageUrl: null,
    isPrivate: true,
    createDate: '2026-06-05T07:30:00',
    modifyDate: '2026-06-05T07:30:00',
    contentBlocks: const [
      DiaryContentBlock(
        id: 'qa-block-1',
        type: DiaryContentBlockType.text,
        text: '아침에 느낀 감정을 짧게 적어 두었습니다.',
      ),
    ],
  );
}

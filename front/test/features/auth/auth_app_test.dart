import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maum_on_mobile_front/app/app_routes.dart';
import 'package:maum_on_mobile_front/app/authenticated_app_shell.dart';
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
import 'package:maum_on_mobile_front/features/draft_recovery/data/draft_recovery_repository.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/domain/draft_recovery_models.dart';
import 'package:maum_on_mobile_front/features/home/data/home_repository.dart';
import 'package:maum_on_mobile_front/features/home/domain/home_models.dart';
import 'package:maum_on_mobile_front/features/letter/data/letter_repository.dart';
import 'package:maum_on_mobile_front/features/letter/domain/letter_models.dart';
import 'package:maum_on_mobile_front/features/notification/data/notification_repository.dart';
import 'package:maum_on_mobile_front/features/notification/data/push_notification_permission_client.dart';
import 'package:maum_on_mobile_front/features/notification/domain/notification_models.dart';
import 'package:maum_on_mobile_front/features/operations/data/operations_repository.dart';
import 'package:maum_on_mobile_front/features/operations/domain/operations_models.dart';
import 'package:maum_on_mobile_front/features/report/data/report_repository.dart';
import 'package:maum_on_mobile_front/features/report/domain/report_models.dart';
import 'package:maum_on_mobile_front/features/settings/data/settings_repository.dart';
import 'package:maum_on_mobile_front/features/settings/domain/settings_models.dart';
import 'package:maum_on_mobile_front/features/story/data/story_repository.dart';
import 'package:maum_on_mobile_front/features/story/domain/story_models.dart';
import 'package:maum_on_mobile_front/theme/app_theme.dart';

void main() {
  testWidgets('uses high contrast selected tab foreground in dark mode',
      (tester) async {
    final theme = buildDarkAppTheme();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: AuthenticatedAppShell(
          currentRoute: AuthenticatedRoute.diary,
          onRouteSelected: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    );

    final selectedTab = find.byKey(const ValueKey('route-tab-diary'));
    expect(selectedTab, findsOneWidget);

    final selectedLabel = tester.widget<Text>(
      find.descendant(of: selectedTab, matching: find.text('기록')),
    );
    final selectedIcon = tester.widget<Icon>(
      find.descendant(of: selectedTab, matching: find.byIcon(Icons.edit_note)),
    );

    expect(selectedLabel.style?.color, theme.colorScheme.onPrimaryContainer);
    expect(selectedIcon.color, theme.colorScheme.onPrimaryContainer);
  });

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

    expect(find.byKey(const ValueKey('route-tab-home')), findsOneWidget);
    expect(find.text('마음이님, 오늘의 마음을 이어가세요.'), findsNothing);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('syncs the home notification badge and read state',
      (tester) async {
    final notificationRepository = _FakeNotificationRepository();

    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
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

    expect(find.textContaining('읽지 않은 알림 1개'), findsOneWidget);

    await _tapVisibleText(tester, '알림/신고');
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('notification-card-1')));
    await tester.drag(
      find.byKey(const ValueKey('notification-list')),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-card-1')));
    await tester.pumpAndSettle();
    await _returnHome(tester);

    expect(notificationRepository.ticketRequestCount, 1);
    expect(find.textContaining('읽지 않은 알림 없음'), findsOneWidget);
  });

  testWidgets('runs the authenticated mobile smoke flow without network',
      (tester) async {
    final consultationRepository = _FakeConsultationRepository();
    final notificationRepository = _FakeNotificationRepository();

    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        consultationRepository: consultationRepository,
        notificationRepository: notificationRepository,
        reportRepository: _FakeReportRepository(),
        settingsRepository: _FakeSettingsRepository(),
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(
          storyPages: const [
            PageResponse(
              items: [
                StorySummary(
                  id: 1,
                  title: '오늘의 스토리',
                  summary: '마음 나눔',
                  authorNickname: '친구',
                  category: StoryCategory.daily,
                  resolutionStatus: StoryResolutionStatus.ongoing,
                  viewCount: 1,
                  createDate: '2026-05-24T09:00:00',
                  modifyDate: '2026-05-24T09:00:00',
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
        letterRepository: _FakeLetterRepository(
          statsQueue: const [LetterStats(receivedCount: 1)],
          receivedPages: const [
            LetterListPage(
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
    expect(find.byKey(const ValueKey('route-tab-home')), findsOneWidget);
    expect(find.text('마음이님, 오늘의 마음을 이어가세요.'), findsNothing);

    await _tapVisibleText(tester, '다이어리 쓰기');
    expect(find.text('나의 기록'), findsOneWidget);
    await _returnHome(tester);

    await _tapVisibleText(tester, '스토리 보기');
    expect(find.byKey(const ValueKey('story-create-button')), findsOneWidget);
    expect(find.text('오늘의 스토리'), findsOneWidget);
    await _returnHome(tester);

    await _tapVisibleText(tester, '편지 쓰기');
    expect(find.text('편지함'), findsOneWidget);
    expect(find.byKey(const ValueKey('letter-title-field')), findsOneWidget);
    await _returnHome(tester);

    await _tapVisibleText(tester, '상담하기');
    await tester.pump();
    consultationRepository.emit(
      const ConsultationStreamEvent.connect('connected'),
    );
    await tester.pump();
    expect(find.text('실시간 상담'), findsOneWidget);
    expect(find.text('상담 연결됨'), findsOneWidget);
    await _returnHome(tester);

    await _tapVisibleText(tester, '알림/신고');
    await tester.pump();
    notificationRepository.emit(
      const NotificationStreamEvent.connect('connected'),
    );
    await tester.pump();
    expect(find.text('알림/신고'), findsWidgets);
    expect(find.text('연결됨'), findsOneWidget);
    await _returnHome(tester);

    await _tapVisibleText(tester, '설정');
    expect(find.text('계정 설정'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-account-toolbar')),
        matching: find.text('me@example.com'),
      ),
      findsOneWidget,
    );
    await _returnHome(tester);
  });

  testWidgets('switches primary authenticated tabs through bottom navigation',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        MaumOnMobileApp(
          authRepository: _FakeAuthRepository(restoredSession: _session()),
          homeRepository: const _FakeHomeRepository(),
          diaryRepository: _FakeDiaryRepository(),
          diaryImagePicker: const _FakeDiaryImagePicker(),
          storyRepository: _FakeStoryRepository(),
          letterRepository: _FakeLetterRepository(),
          consultationRepository: _FakeConsultationRepository(),
          listenForDeepLinks: false,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(
          find.byKey(const ValueKey('app-bottom-navigation')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('app-bottom-navigation-surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('route-tab-home-indicator')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(
              find.byKey(
                const ValueKey('route-tab-home-indicator'),
              ),
            )
            .height,
        greaterThanOrEqualTo(64),
      );
      expect(
        [
          'route-tab-home',
          'route-tab-diary',
          'route-tab-story',
          'route-tab-letter',
          'route-tab-consultation',
        ].map((key) {
          return tester.getSize(find.byKey(ValueKey(key))).height;
        }),
        everyElement(greaterThanOrEqualTo(64)),
      );
      expect(find.text('홈'), findsOneWidget);
      expect(find.text('기록'), findsOneWidget);
      expect(find.text('스토리'), findsOneWidget);
      expect(find.text('편지'), findsOneWidget);
      expect(find.text('상담'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('홈 Tab 1 of 5')),
        matchesSemantics(
          label: '홈 Tab 1 of 5',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('route-tab-story')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('story-create-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('route-tab-letter')));
      await tester.pumpAndSettle();
      expect(find.text('편지함'), findsOneWidget);
      expect(find.byKey(const ValueKey('letter-title-field')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('route-tab-home')));
      await tester.pumpAndSettle();
      expect(find.text('마음이님, 오늘의 마음을 이어가세요.'), findsNothing);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('marks home selected when the current route is not a primary tab',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthenticatedAppShell(
            currentRoute: AuthenticatedRoute.settings,
            onRouteSelected: (_) {},
            child: const SizedBox.shrink(),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('route-tab-home-indicator')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('홈 Tab 1 of 5')),
        matchesSemantics(
          label: '홈 Tab 1 of 5',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semanticsHandle.dispose();
    }
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
    expect(find.text('마음이님, 오늘의 마음을 이어가세요.'), findsNothing);
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
    await tester.ensureVisible(find.text('편지 쓰기'));
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
    final consultationAction =
        find.byKey(const ValueKey('home-action-consultation'));
    await tester.ensureVisible(consultationAction);
    await tester.pumpAndSettle();
    await tester.tap(consultationAction);
    await tester.pump();
    consultationRepository.emit(
      const ConsultationStreamEvent.connect('connected'),
    );
    await tester.pump();

    expect(find.text('실시간 상담'), findsOneWidget);
    expect(find.text('상담 연결됨'), findsOneWidget);
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

  testWidgets('opens target route from an initial notification tap',
      (tester) async {
    final pushClient = _FakePushNotificationPermissionClient(
      initialPayload: const NotificationTapPayload(
        destination: NotificationTapDestination.letter,
        letterId: 7,
      ),
    );

    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        notificationRepository: _FakeNotificationRepository(),
        pushNotificationPermissionClient: pushClient,
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(),
        letterRepository: _FakeLetterRepository(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('편지함'), findsOneWidget);
  });

  testWidgets('routes live notification taps while authenticated',
      (tester) async {
    final pushClient = _FakePushNotificationPermissionClient();
    final consultationRepository = _FakeConsultationRepository();

    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        consultationRepository: consultationRepository,
        notificationRepository: _FakeNotificationRepository(),
        pushNotificationPermissionClient: pushClient,
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(),
        letterRepository: _FakeLetterRepository(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();
    await pushClient.waitForTapListener();
    pushClient.emitTap(
      const NotificationTapPayload(
        destination: NotificationTapDestination.consultation,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('실시간 상담'), findsOneWidget);
  });

  testWidgets('applies initial letter notification tap after session restore',
      (tester) async {
    final pushClient = _FakePushNotificationPermissionClient(
      initialPayload: const NotificationTapPayload(
        destination: NotificationTapDestination.letter,
        notificationId: 91,
        letterId: 3,
      ),
    );
    final letterRepository = _FakeLetterRepository(
      details: const [
        LetterDetail(
          id: 3,
          title: '알림으로 연 편지',
          content: '푸시 탭 이동',
          status: LetterStatus.sent,
          replied: false,
          createdDate: '2026-05-24T09:00:00',
        ),
      ],
    );

    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        notificationRepository: _FakeNotificationRepository(),
        pushNotificationPermissionClient: pushClient,
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        storyRepository: _FakeStoryRepository(),
        letterRepository: letterRepository,
        listenForDeepLinks: false,
      ),
    );

    await tester.pumpAndSettle();

    expect(letterRepository.fetchedLetterIds, [3]);
    expect(find.text('편지함'), findsOneWidget);
    expect(find.text('알림으로 연 편지'), findsOneWidget);
  });

  testWidgets('applies initial story notification tap after session restore',
      (tester) async {
    final pushClient = _FakePushNotificationPermissionClient(
      initialPayload: const NotificationTapPayload(
        destination: NotificationTapDestination.story,
        notificationId: 92,
        targetType: 'POST',
        targetId: 5,
      ),
    );
    final storyRepository = _FakeStoryRepository(
      details: {
        5: _storyDetail(
          id: 5,
          title: '알림으로 연 스토리',
          content: '푸시 탭으로 이동한 스토리입니다.',
        ),
      },
    );

    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: _FakeAuthRepository(restoredSession: _session()),
        homeRepository: const _FakeHomeRepository(),
        notificationRepository: _FakeNotificationRepository(),
        pushNotificationPermissionClient: pushClient,
        diaryRepository: _FakeDiaryRepository(),
        diaryImagePicker: const _FakeDiaryImagePicker(),
        draftRecoveryRepository: const _EmptyDraftRecoveryRepository(),
        storyRepository: storyRepository,
        letterRepository: _FakeLetterRepository(),
        listenForDeepLinks: false,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(storyRepository.fetchedStoryIds, [5]);
    expect(find.text('알림으로 연 스토리'), findsOneWidget);
  });

  testWidgets('unregisters the push token on logout', (tester) async {
    final authRepository = _FakeAuthRepository(restoredSession: _session());
    final notificationRepository = _FakeNotificationRepository();

    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: authRepository,
        homeRepository: const _FakeHomeRepository(),
        notificationRepository: notificationRepository,
        pushNotificationPermissionClient: _FakePushNotificationPermissionClient(
          permissionResult: const PushNotificationPermissionResult(
            granted: true,
            platform: NotificationDevicePlatform.ios,
            token: 'ios-token-logout',
          ),
        ),
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
    await tester.tap(find.text('알림/신고'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-push-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-tab-home')));
    await tester.pumpAndSettle();
    final logoutAction = find.byKey(const ValueKey('home-action-logout'));
    await tester.ensureVisible(logoutAction);
    await tester.pumpAndSettle();
    await tester.tap(logoutAction);
    await tester.pumpAndSettle();

    expect(notificationRepository.registeredTokens, ['IOS:ios-token-logout']);
    expect(notificationRepository.unregisteredTokens, ['ios-token-logout']);
    expect(authRepository.logoutCount, 1);
  });

  testWidgets(
      'clears session and push state when operations permission changes',
      (tester) async {
    final authRepository = _FakeAuthRepository(
      restoredSession: _session(role: 'ADMIN'),
    );
    final notificationRepository = _FakeNotificationRepository();

    await tester.pumpWidget(
      MaumOnMobileApp(
        authRepository: authRepository,
        homeRepository: const _FakeHomeRepository(),
        notificationRepository: notificationRepository,
        pushNotificationPermissionClient: _FakePushNotificationPermissionClient(
          permissionResult: const PushNotificationPermissionResult(
            granted: true,
            platform: NotificationDevicePlatform.ios,
            token: 'ios-token-permission-change',
          ),
        ),
        operationsRepository: _PermissionChangedOperationsRepository(),
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
    await tester.tap(find.text('알림/신고'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-push-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-tab-home')));
    await tester.pumpAndSettle();
    final operationsAction = find.byKey(
      const ValueKey('home-operations-button'),
    );
    await tester.ensureVisible(operationsAction);
    await tester.pumpAndSettle();
    await tester.tap(operationsAction);
    await tester.pumpAndSettle();

    expect(notificationRepository.unregisteredTokens, [
      'ios-token-permission-change',
    ]);
    expect(authRepository.clearLocalSessionCount, 1);
    expect(find.byKey(const ValueKey('login-email-field')), findsOneWidget);
    expect(find.text('운영 권한이 변경되었습니다.'), findsOneWidget);
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-account-toolbar')),
        matching: find.text('me@example.com'),
      ),
      findsOneWidget,
    );

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
    await tester.ensureVisible(find.text('스토리 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('스토리 보기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('story-create-button')), findsOneWidget);
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

Future<void> _tapVisibleText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _returnHome(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();

  expect(handled, isTrue);
  expect(find.text('마음이님, 오늘의 마음을 이어가세요.'), findsNothing);
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
  Future<PageResponse<DiaryEntry>> fetchPublicDiaries({
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
  Future<DiaryImagePickResult> pickImage(DiaryImageSource source) async {
    return const DiaryImagePickResult.cancelled();
  }

  @override
  Future<bool> openSettings() async {
    return true;
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
  Future<ConsultationSendResult> sendMessage(String message) async {
    return const ConsultationSendResult(accepted: true);
  }

  @override
  Future<List<ConsultationMessage>> loadRecentMessages() async => const [];

  @override
  Future<int> deleteSensitiveMessages() async => 0;

  void emit(ConsultationStreamEvent event) {
    _controller?.add(event);
  }
}

class _FakeNotificationRepository implements NotificationRepository {
  int ticketRequestCount = 0;
  final List<String> registeredTokens = [];
  final List<String> unregisteredTokens = [];
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
  Future<NotificationItem> markRead(int notificationId) async {
    return NotificationItem(
      id: notificationId,
      content: '상대방이 편지를 읽었습니다.',
      isRead: true,
      createdAt: '2026-05-24T09:00:00',
      readAt: '2026-05-24T09:01:00',
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
    registeredTokens.add('${platform.apiValue}:$token');
    return NotificationDeviceTokenResult(
      platform: platform,
      enabled: true,
      updatedAt: '2026-05-24T09:02:00',
    );
  }

  @override
  Future<bool> unregisterDeviceToken(String token) async {
    unregisteredTokens.add(token);
    return true;
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

class _FakePushNotificationPermissionClient
    implements PushNotificationPermissionClient {
  _FakePushNotificationPermissionClient({
    this.initialPayload,
    this.permissionResult = const PushNotificationPermissionResult(
      granted: true,
      platform: NotificationDevicePlatform.ios,
      token: 'ios-token',
    ),
  });

  final NotificationTapPayload? initialPayload;
  final PushNotificationPermissionResult permissionResult;
  final Completer<void> _tapListenerReady = Completer<void>();
  final StreamController<NotificationTapPayload> _tapController =
      StreamController<NotificationTapPayload>.broadcast();
  bool initialPayloadConsumed = false;
  int openSettingsCount = 0;

  @override
  Future<PushNotificationPermissionResult> requestPermission() async {
    return permissionResult;
  }

  @override
  Future<PushNotificationPermissionResult> getPermissionStatus() async {
    return permissionResult;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount += 1;
    return true;
  }

  @override
  Future<NotificationTapPayload?> takeInitialNotificationTap() async {
    if (initialPayloadConsumed) {
      return null;
    }
    initialPayloadConsumed = true;
    return initialPayload;
  }

  @override
  Stream<NotificationTapPayload> get notificationTaps {
    if (!_tapListenerReady.isCompleted) {
      _tapListenerReady.complete();
    }
    return _tapController.stream;
  }

  Future<void> waitForTapListener() {
    return _tapListenerReady.future;
  }

  void emitTap(NotificationTapPayload payload) {
    _tapController.add(payload);
  }
}

class _FakeReportRepository implements ReportRepository {
  final List<ReportDraft> drafts = [];

  @override
  Future<int> createReport(ReportDraft draft) async {
    drafts.add(draft);
    return drafts.length;
  }

  @override
  Future<List<AdminReportSummary>> fetchAdminReports() {
    throw UnimplementedError();
  }

  @override
  Future<AdminReportDetail> fetchAdminReport(int id) {
    throw UnimplementedError();
  }

  @override
  Future<AdminReportActionResult> updateAdminReportStatus(
    int id,
    AdminReportActionDraft draft,
  ) {
    throw UnimplementedError();
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
  Future<MemberDataExportJob> requestDataExport() async {
    return const MemberDataExportJob(
      id: 1,
      status: MemberDataExportStatus.completed,
      requestedAt: '2026-05-26T00:00:00Z',
      completedAt: '2026-05-26T00:00:00Z',
      expiresAt: '2999-05-27T00:00:00Z',
      downloadUrl: '/api/v1/members/me/data-exports/1/download',
    );
  }

  @override
  Future<MemberDataExportJob> fetchDataExportStatus(int exportId) async {
    return MemberDataExportJob(
      id: exportId,
      status: MemberDataExportStatus.completed,
      requestedAt: '2026-05-26T00:00:00Z',
      completedAt: '2026-05-26T00:00:00Z',
      expiresAt: '2999-05-27T00:00:00Z',
      downloadUrl: '/api/v1/members/me/data-exports/$exportId/download',
    );
  }

  @override
  Future<MemberDataExportFile> downloadDataExport(int exportId) async {
    return MemberDataExportFile(
      filename: 'maum-on-data-export-$exportId.json',
      contentType: 'application/json',
      content: '{"account":{}}',
      expiresAt: '2999-05-27T00:00:00Z',
    );
  }

  @override
  Future<void> withdraw({String? currentPassword}) async {
    withdrawPasswords.add(currentPassword);
  }
}

class _EmptyDraftRecoveryRepository implements DraftRecoveryRepository {
  const _EmptyDraftRecoveryRepository();

  @override
  Future<void> clearMember(int memberId) async {}

  @override
  Future<void> delete(DraftKey key) async {}

  @override
  Future<List<DraftEntry>> listFailed({
    required int memberId,
    DraftSurface? surface,
  }) async {
    return const [];
  }

  @override
  Future<void> markFailed(
    DraftKey key, {
    required Map<String, String> fields,
    required String failureMessage,
  }) async {}

  @override
  Future<DraftEntry?> read(DraftKey key) async {
    return null;
  }

  @override
  Future<void> saveEditing(
    DraftKey key, {
    required Map<String, String> fields,
  }) async {}
}

StoryDetail _storyDetail({
  required int id,
  required String title,
  required String content,
}) {
  return StoryDetail(
    id: id,
    title: title,
    content: content,
    summary: '요약',
    authorNickname: '마음이',
    category: StoryCategory.worry,
    resolutionStatus: StoryResolutionStatus.ongoing,
    viewCount: 1,
    createDate: '2026-05-24T08:00:00',
    modifyDate: '2026-05-24T08:00:00',
    authorId: 7,
  );
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
    Map<int, StoryDetail> details = const {},
    Map<int, PageResponse<StoryComment>> commentPages = const {},
  })  : _storyPages = List<PageResponse<StorySummary>>.of(storyPages),
        _details = Map<int, StoryDetail>.of(details),
        _commentPages = Map<int, PageResponse<StoryComment>>.of(commentPages);

  final List<PageResponse<StorySummary>> _storyPages;
  final Map<int, StoryDetail> _details;
  final Map<int, PageResponse<StoryComment>> _commentPages;
  final List<int> fetchedStoryIds = [];

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
  Future<StoryDetail> fetchStory(int id) async {
    fetchedStoryIds.add(id);
    final detail = _details[id];
    if (detail == null) {
      throw const ApiClientException(
        kind: ApiErrorKind.unknown,
        message: '스토리를 찾을 수 없습니다.',
      );
    }
    return detail;
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
  }) async {
    return _commentPages[postId] ??
        const PageResponse(
          items: [],
          page: 0,
          size: 20,
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
    List<LetterDetail> details = const [],
  })  : _statsQueue = List<LetterStats>.of(statsQueue),
        _receivedPages = List<LetterListPage>.of(receivedPages),
        _sentPages = List<LetterListPage>.of(sentPages),
        _details = List<LetterDetail>.of(details);

  final List<LetterStats> _statsQueue;
  final List<LetterListPage> _receivedPages;
  final List<LetterListPage> _sentPages;
  final List<LetterDetail> _details;
  final List<int> fetchedLetterIds = [];

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
  Future<LetterDetail> fetchLetter(int id) async {
    fetchedLetterIds.add(id);
    if (_details.isEmpty) {
      return LetterDetail(
        id: id,
        title: '편지 #$id',
        content: '알림으로 연 편지',
        status: LetterStatus.sent,
        replied: false,
        createdDate: '2026-05-24T09:00:00',
      );
    }

    return _details.removeAt(0);
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

AuthSession _session({String role = 'USER'}) {
  return AuthSession(
    accessToken: 'access-token',
    tokenType: 'Bearer',
    expiresInSeconds: 3600,
    member: AuthMember(
      id: 7,
      email: 'me@example.com',
      nickname: '마음이',
      role: role,
      status: 'ACTIVE',
    ),
  );
}

class _PermissionChangedOperationsRepository implements OperationsRepository {
  @override
  Future<OperationsDashboard> fetchDashboard() {
    throw const ApiClientException(
      kind: ApiErrorKind.permissionChanged,
      message: '운영 권한이 변경되었습니다.',
      statusCode: 403,
      code: 'FORBIDDEN',
    );
  }

  @override
  Future<MobileApiMetricsSnapshot> fetchApiMetrics() {
    throw UnimplementedError();
  }

  @override
  Future<OperationsSystemStatus> fetchSystemStatus(
    OperationsSystemEnvironment environment,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<AdminMemberPage> fetchMembers({
    String? query,
    String? status,
    String? role,
    bool? socialAccount,
    int page = 0,
    int size = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminMemberDetail> fetchMemberDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<AdminMemberActionResult> updateMemberStatus({
    required int memberId,
    required String status,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminMemberActionResult> updateMemberRole({
    required int memberId,
    required String role,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminSessionRevokeResult> revokeMemberSessions({
    required int memberId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminLetterPage> fetchLetters({
    String? status,
    String? query,
    int page = 0,
    int size = 20,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminLetterDetail> fetchLetterDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<AdminLetterActionResult> addLetterNote({
    required int letterId,
    required String note,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminLetterActionResult> reassignLetterReceiver({
    required int letterId,
    required int receiverMemberId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminLetterActionResult> blockLetterSender({
    required int letterId,
    required String reason,
  }) {
    throw UnimplementedError();
  }
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
  int clearLocalSessionCount = 0;

  @override
  Future<void> requestSignupEmailVerification(
    SignupEmailVerificationRequest request,
  ) {
    throw UnimplementedError();
  }

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
  Future<void> requestPasswordReset(PasswordResetRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> confirmPasswordReset(PasswordResetConfirmRequest request) {
    throw UnimplementedError();
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
  Future<AuthSession> exchangeOidcSession(OidcSessionRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveSession(AuthSession session) async {}

  @override
  Future<AuthMember> me() {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    logoutCount += 1;
  }

  @override
  Future<void> clearLocalSession() async {
    clearLocalSessionCount += 1;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/data/draft_recovery_repository.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/domain/draft_recovery_models.dart';
import 'package:maum_on_mobile_front/features/home/application/home_controller.dart';
import 'package:maum_on_mobile_front/features/home/data/home_repository.dart';
import 'package:maum_on_mobile_front/features/home/domain/home_models.dart';
import 'package:maum_on_mobile_front/features/home/home_screen.dart';
import 'package:maum_on_mobile_front/shared/ui/brand_identity.dart';
import 'package:maum_on_mobile_front/theme/app_theme.dart';

void main() {
  testWidgets('renders stats, story feed, and category filter in a scroll view',
      (tester) async {
    final controller = HomeController(
      homeRepository: const _FakeHomeRepository(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          nickname: '마음이',
          homeController: controller,
          onWriteDiary: () {},
          onWriteLetter: () {},
          onViewStory: () {},
          onOpenConsultation: () {},
          onOpenNotifications: () {},
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('홈'), findsNothing);
    expect(find.text('마음이님, 오늘의 마음을 이어가세요.'), findsNothing);
    expect(find.text('오늘 올라온 고민'), findsOneWidget);
    expect(find.text('전달된 비밀 편지'), findsOneWidget);
    expect(find.text('오늘의 기록'), findsOneWidget);
    expect(find.text('알림/신고'), findsOneWidget);
    expect(find.text('읽지 않은 알림 없음 · 알림 센터'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-primary-panel')), findsNothing);
    expect(find.byKey(const ValueKey('home-blue-hero')), findsNothing);
    expect(find.text('지금 마음을 천천히 살펴보세요.'), findsNothing);
    expect(find.byKey(const ValueKey('home-primary-actions-panel')),
        findsOneWidget);
    expect(find.text('이어쓸 내용이 없습니다.'), findsNothing);
    expect(
      find.text('새 기록, 편지, 스토리, AI 상담을 바로 시작할 수 있습니다.'),
      findsNothing,
    );
    expect(find.text('고민 이야기가 가장 활발합니다.'), findsNothing);
    expect(find.text('최근 인기'), findsOneWidget);
    expect(find.text('오늘 너무 지쳐요'), findsWidgets);
    expect(find.byKey(const ValueKey('home-feed-story-1')), findsOneWidget);
    expect(find.text('ANDROID'), findsNothing);
    expect(find.text('IOS'), findsNothing);

    final questionChip = find.byKey(const ValueKey('home-category-question'));
    await tester.ensureVisible(questionChip);
    await tester.pumpAndSettle();
    await tester.tap(questionChip);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-feed-story-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-feed-story-1')), findsNothing);
  });

  testWidgets('keeps mobile home summary stats in a single row',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HomeController(
      homeRepository: const _FakeHomeRepository(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          nickname: '마음이',
          homeController: controller,
          onWriteDiary: () {},
          onWriteLetter: () {},
          onViewStory: () {},
          onOpenConsultation: () {},
          onOpenNotifications: () {},
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );

    final diaryTop = tester.getTopLeft(find.text('오늘의 기록')).dy;
    final letterTop = tester.getTopLeft(find.text('전달된 비밀 편지')).dy;
    final worryTop = tester.getTopLeft(find.text('오늘 올라온 고민')).dy;

    expect(letterTop, moreOrLessEquals(diaryTop, epsilon: 1));
    expect(worryTop, moreOrLessEquals(diaryTop, epsilon: 1));
  });

  testWidgets('uses primary action surfaces without the hero card on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HomeController(
      homeRepository: const _FakeHomeRepository(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          nickname: '마음이',
          homeController: controller,
          onWriteDiary: () {},
          onWriteLetter: () {},
          onViewStory: () {},
          onOpenConsultation: () {},
          onOpenNotifications: () {},
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home-primary-panel')), findsNothing);
    expect(find.byKey(const ValueKey('home-blue-hero')), findsNothing);
    expect(find.text('지금 마음을 천천히 살펴보세요.'), findsNothing);
    expect(find.text('마음이님, 오늘의 마음을 이어가세요.'), findsNothing);
    expect(
      find.byKey(const ValueKey('home-primary-actions-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-action-diary-surface')),
      findsOneWidget,
    );
    expect(
      (tester
              .widget<DecoratedBox>(
                find.byKey(const ValueKey('home-action-diary-surface')),
              )
              .decoration as BoxDecoration)
          .color,
      const Color(0xFFE8F1FF),
    );
    expect(
      find.byKey(const ValueKey('home-action-story-surface')),
      findsOneWidget,
    );
    expect(find.text('오늘 마음 정리'), findsNothing);
    expect(find.text('조용히 전하기'), findsNothing);
    expect(find.text('함께 읽기'), findsNothing);
    expect(find.text('지금 대화하기'), findsNothing);
  });

  testWidgets('prioritizes the mobile action launcher above dashboard details',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HomeController(
      homeRepository: const _FakeHomeRepository(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(
          nickname: '마음이',
          homeController: controller,
          onWriteDiary: () {},
          onWriteLetter: () {},
          onViewStory: () {},
          onOpenConsultation: () {},
          onOpenNotifications: () {},
          onOpenSettings: () {},
          onLogout: () {},
          unreadNotificationCount: 3,
          hasLiveNotificationConnection: true,
        ),
      ),
    );

    final launcher = find.byKey(const ValueKey('home-action-launcher'));
    final stats = find.byKey(const ValueKey('home-stats-section'));
    final secondaryTools = find.byKey(const ValueKey('home-secondary-tools'));

    expect(launcher, findsOneWidget);
    expect(stats, findsOneWidget);
    expect(secondaryTools, findsOneWidget);
    expect(
        tester.getTopLeft(launcher).dy, lessThan(tester.getTopLeft(stats).dy));
    expect(
      find.byKey(const ValueKey('home-action-consultation-primary')),
      findsOneWidget,
    );
    expect(find.text('계정 관리'), findsNothing);
    expect(find.text('알림/신고'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('exposes home launcher actions as button semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = HomeController(
        homeRepository: const _FakeHomeRepository(),
      );
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: HomeScreen(
            nickname: '마음이',
            homeController: controller,
            onWriteDiary: () {},
            onWriteLetter: () {},
            onViewStory: () {},
            onOpenConsultation: () {},
            onOpenNotifications: () {},
            onOpenSettings: () {},
            onLogout: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('AI 상담, 지금 마음을 바로 정리하기'), findsOneWidget);
      expect(find.bySemanticsLabel('기록'), findsOneWidget);
      expect(find.bySemanticsLabel('편지'), findsOneWidget);
      expect(find.bySemanticsLabel('스토리'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('keeps dark home surfaces cohesive with the blue brand shell',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = HomeController(
      homeRepository: const _FakeHomeRepository(),
    );
    await controller.load();

    final theme = buildDarkAppTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: HomeScreen(
          nickname: '마음이',
          homeController: controller,
          onWriteDiary: () {},
          onWriteLetter: () {},
          onViewStory: () {},
          onOpenConsultation: () {},
          onOpenNotifications: () {},
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );

    final consultationSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('home-action-consultation-primary')),
    );
    expect(
      (consultationSurface.decoration as BoxDecoration).color,
      const Color(0xFF244C79),
    );

    final diarySurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('home-action-diary-surface')),
    );
    expect(
      (diarySurface.decoration as BoxDecoration).color,
      const Color(0xFF244C79),
    );

    final wordmark = tester.widget<MaumOnBrandWordmark>(
      find.byKey(const ValueKey('maum-on-brand-wordmark')),
    );
    expect(wordmark.foregroundColor, theme.colorScheme.onSurface);
  });

  testWidgets('keeps home feed empty state free of helper explanation copy',
      (tester) async {
    final controller = HomeController(
      homeRepository: const _EmptyFeedHomeRepository(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          nickname: '마음이',
          homeController: controller,
          onWriteDiary: () {},
          onWriteLetter: () {},
          onViewStory: () {},
          onOpenConsultation: () {},
          onOpenNotifications: () {},
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );

    await tester.ensureVisible(find.text('아직 공개된 스토리가 없습니다.'));
    await tester.pumpAndSettle();

    expect(find.text('아직 공개된 스토리가 없습니다.'), findsOneWidget);
    expect(
      find.text('카테고리를 바꾸거나 잠시 뒤 다시 확인해 주세요.'),
      findsNothing,
    );
  });

  testWidgets('routes draft continuation cards to their writing surfaces',
      (tester) async {
    final draftRepository = StorageDraftRecoveryRepository(
      storage: MemoryDraftRecoveryStorage(),
    );
    await draftRepository.saveEditing(
      const DraftKey(memberId: 7, surface: DraftSurface.diary),
      fields: {
        'title': '오늘의 기록',
        'content': '퇴근길 마음을 이어서 적기',
      },
    );
    final controller = HomeController(
      homeRepository: const _FakeHomeRepository(),
      draftRepository: draftRepository,
      currentMemberId: 7,
    );
    await controller.load();
    var diaryTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          nickname: '마음이',
          homeController: controller,
          onWriteDiary: () => diaryTaps += 1,
          onWriteLetter: () {},
          onViewStory: () {},
          onOpenConsultation: () {},
          onOpenNotifications: () {},
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('이어쓰기'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-draft-diary')),
        matching: find.text('오늘의 기록'),
      ),
      findsOneWidget,
    );

    await _tapVisibleKey(tester, const ValueKey('home-draft-diary'));

    expect(diaryTaps, 1);
  });

  testWidgets('runs home action callbacks', (tester) async {
    final controller = HomeController(
      homeRepository: const _FakeHomeRepository(),
    );
    await controller.load();
    var diaryTaps = 0;
    var letterTaps = 0;
    var storyTaps = 0;
    var consultationTaps = 0;
    var notificationTaps = 0;
    var settingsTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          nickname: '마음이',
          homeController: controller,
          onWriteDiary: () => diaryTaps += 1,
          onWriteLetter: () => letterTaps += 1,
          onViewStory: () => storyTaps += 1,
          onOpenConsultation: () => consultationTaps += 1,
          onOpenNotifications: () => notificationTaps += 1,
          onOpenSettings: () => settingsTaps += 1,
          unreadNotificationCount: 2,
          hasLiveNotificationConnection: true,
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('읽지 않은 알림 2개 · 실시간 연결됨'), findsOneWidget);
    expect(find.text('AI 상담'), findsOneWidget);

    await _tapVisibleKey(tester, const ValueKey('home-action-diary'));
    await _tapVisibleKey(tester, const ValueKey('home-action-letter'));
    await _tapVisibleKey(tester, const ValueKey('home-action-story'));
    await _tapVisibleKey(tester, const ValueKey('home-action-consultation'));
    await _tapVisibleKey(tester, const ValueKey('home-action-notifications'));
    await _tapVisibleKey(tester, const ValueKey('home-action-settings'));

    expect(diaryTaps, 1);
    expect(letterTaps, 1);
    expect(storyTaps, 1);
    expect(consultationTaps, 1);
    expect(notificationTaps, 1);
    expect(settingsTaps, 1);
  });

  testWidgets('separates account tools from the primary home action grid',
      (tester) async {
    final controller = HomeController(
      homeRepository: const _FakeHomeRepository(),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          nickname: '관리자',
          homeController: controller,
          onWriteDiary: () {},
          onWriteLetter: () {},
          onViewStory: () {},
          onOpenConsultation: () {},
          onOpenNotifications: () {},
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home-primary-actions')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-secondary-tools')), findsOneWidget);
    expect(find.text('계정 관리'), findsNothing);
    expect(find.byKey(const ValueKey('home-operations-button')), findsNothing);
    expect(find.text('운영 검수'), findsNothing);
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
  });

  testWidgets('does not expose operations entry to admin accounts',
      (tester) async {
    final userController = HomeController(
      homeRepository: const _FakeHomeRepository(),
    );
    await userController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          nickname: '마음이',
          homeController: userController,
          onWriteDiary: () {},
          onWriteLetter: () {},
          onViewStory: () {},
          onOpenConsultation: () {},
          onOpenNotifications: () {},
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home-operations-button')), findsNothing);

    final adminController = HomeController(
      homeRepository: const _FakeHomeRepository(),
    );
    await adminController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          nickname: '관리자',
          homeController: adminController,
          onWriteDiary: () {},
          onWriteLetter: () {},
          onViewStory: () {},
          onOpenConsultation: () {},
          onOpenNotifications: () {},
          onOpenSettings: () {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home-operations-button')), findsNothing);
    expect(find.text('운영 검수'), findsNothing);
  });
}

Future<void> _tapVisibleKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository();

  @override
  Future<HomeStats> fetchStats() async {
    return const HomeStats(
      todayWorryCount: 2,
      todayLetterCount: 3,
      todayDiaryCount: 4,
      summary: HomeSummary(
        recoveryMessage: '지금 마음을 천천히 살펴보세요.',
        primaryActionLabel: '오늘 마음 기록하기',
        primaryActionSurface: HomeActionSurface.diary,
        feedMessage: '고민 이야기가 가장 활발합니다.',
      ),
      categorySummaries: [
        HomeCategorySummary(
          category: HomeStoryCategory.worry,
          label: '고민',
          count: 2,
        ),
        HomeCategorySummary(
          category: HomeStoryCategory.question,
          label: '질문',
          count: 1,
        ),
      ],
      popularStories: [
        HomePopularStory(
          id: 1,
          title: '오늘 너무 지쳐요',
          category: HomeStoryCategory.worry,
          label: '고민',
          viewCount: 42,
          nickname: '마음온데모',
        ),
      ],
    );
  }

  @override
  Future<HomeStoryPage> fetchStories({
    HomeStoryCategory category = HomeStoryCategory.all,
  }) async {
    return const HomeStoryPage(
      last: true,
      items: [
        HomeStory(
          id: 1,
          title: '오늘 너무 지쳐요',
          summary: '누군가 제 이야기를 들어주면 좋겠어요.',
          authorNickname: '마음온데모',
          category: HomeStoryCategory.worry,
          createdAt: '2026-04-10T08:00:00',
          viewCount: 42,
        ),
        HomeStory(
          id: 2,
          title: '어떻게 말해야 할까요?',
          summary: '말을 꺼내기 어렵습니다.',
          authorNickname: '질문자',
          category: HomeStoryCategory.question,
          createdAt: '2026-04-10T10:00:00',
          viewCount: 11,
        ),
      ],
    );
  }
}

class _EmptyFeedHomeRepository implements HomeRepository {
  const _EmptyFeedHomeRepository();

  @override
  Future<HomeStats> fetchStats() async {
    return const HomeStats(
      todayWorryCount: 0,
      todayLetterCount: 0,
      todayDiaryCount: 0,
      summary: HomeSummary(
        recoveryMessage: '',
        primaryActionLabel: '',
        primaryActionSurface: HomeActionSurface.diary,
        feedMessage: '',
      ),
    );
  }

  @override
  Future<HomeStoryPage> fetchStories({
    HomeStoryCategory category = HomeStoryCategory.all,
  }) async {
    return const HomeStoryPage(last: true, items: []);
  }
}

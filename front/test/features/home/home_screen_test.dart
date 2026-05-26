import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/data/draft_recovery_repository.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/domain/draft_recovery_models.dart';
import 'package:maum_on_mobile_front/features/home/application/home_controller.dart';
import 'package:maum_on_mobile_front/features/home/data/home_repository.dart';
import 'package:maum_on_mobile_front/features/home/domain/home_models.dart';
import 'package:maum_on_mobile_front/features/home/home_screen.dart';

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
          routeTitle: '홈',
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
    expect(find.text('오늘 올라온 고민'), findsOneWidget);
    expect(find.text('전달된 비밀 편지'), findsOneWidget);
    expect(find.text('오늘의 기록'), findsOneWidget);
    expect(find.text('알림/신고'), findsOneWidget);
    expect(find.text('읽지 않은 알림 없음 · 알림 센터'), findsOneWidget);
    expect(find.text('지금 마음을 천천히 살펴보세요.'), findsOneWidget);
    expect(find.text('최근 인기'), findsOneWidget);
    expect(find.text('오늘 너무 지쳐요'), findsWidgets);
    expect(find.byKey(const ValueKey('home-feed-story-1')), findsOneWidget);

    final questionChip = find.byKey(const ValueKey('home-category-question'));
    await tester.ensureVisible(questionChip);
    await tester.pumpAndSettle();
    await tester.tap(questionChip);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-feed-story-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-feed-story-1')), findsNothing);
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
          routeTitle: '홈',
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

    await tester.tap(find.byKey(const ValueKey('home-draft-diary')));

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
          routeTitle: '홈',
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

  testWidgets('shows operations entry only to admins', (tester) async {
    final userController = HomeController(
      homeRepository: const _FakeHomeRepository(),
    );
    await userController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          routeTitle: '홈',
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
    var operationsTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          routeTitle: '홈',
          nickname: '관리자',
          homeController: adminController,
          isAdmin: true,
          onOpenOperations: () => operationsTaps += 1,
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

    await _tapVisibleKey(tester, const ValueKey('home-operations-button'));

    expect(operationsTaps, 1);
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

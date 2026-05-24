import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
          onLogout: () {},
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('오늘 올라온 고민'), findsOneWidget);
    expect(find.text('전달된 비밀 편지'), findsOneWidget);
    expect(find.text('오늘의 기록'), findsOneWidget);
    expect(find.text('오늘 너무 지쳐요'), findsOneWidget);

    await tester.tap(find.text('질문'));
    await tester.pumpAndSettle();

    expect(find.text('어떻게 말해야 할까요?'), findsOneWidget);
    expect(find.text('오늘 너무 지쳐요'), findsNothing);
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
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.text('다이어리 쓰기'));
    await tester.tap(find.text('편지 쓰기'));
    await tester.tap(find.text('스토리 보기'));
    await tester.tap(find.text('상담하기'));
    await tester.tap(find.text('알림/신고'));

    expect(diaryTaps, 1);
    expect(letterTaps, 1);
    expect(storyTaps, 1);
    expect(consultationTaps, 1);
    expect(notificationTaps, 1);
  });
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository();

  @override
  Future<HomeStats> fetchStats() async {
    return const HomeStats(
      todayWorryCount: 2,
      todayLetterCount: 3,
      todayDiaryCount: 4,
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

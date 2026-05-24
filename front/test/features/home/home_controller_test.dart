import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/home/application/home_controller.dart';
import 'package:maum_on_mobile_front/features/home/data/home_repository.dart';
import 'package:maum_on_mobile_front/features/home/domain/home_models.dart';

void main() {
  group('HomeController', () {
    test('load succeeds with stats and feed items', () async {
      final controller = HomeController(
        homeRepository: _FakeHomeRepository(
          stats: _stats(),
          stories: _stories(),
        ),
      );

      await controller.load();

      expect(controller.state.stats?.todayWorryCount, 2);
      expect(controller.state.visibleStories, hasLength(3));
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.feedErrorMessage, isNull);
    });

    test('keeps feed data visible when stats fail', () async {
      final controller = HomeController(
        homeRepository: _FakeHomeRepository(
          statsError: const ApiClientException(
            kind: ApiErrorKind.server,
            message: '통계를 불러오지 못했습니다.',
          ),
          stories: _stories(),
        ),
      );

      await controller.load();

      expect(controller.state.stats, isNull);
      expect(controller.state.statsErrorMessage, '통계를 불러오지 못했습니다.');
      expect(controller.state.visibleStories, hasLength(3));
    });

    test('marks empty feed after a successful empty response', () async {
      final controller = HomeController(
        homeRepository: _FakeHomeRepository(
          stats: _stats(),
          stories: const [],
        ),
      );

      await controller.load();

      expect(controller.state.isFeedEmpty, isTrue);
      expect(controller.state.feedErrorMessage, isNull);
    });

    test('stores feed error when feed request fails', () async {
      final controller = HomeController(
        homeRepository: _FakeHomeRepository(
          stats: _stats(),
          storiesError: const ApiClientException(
            kind: ApiErrorKind.network,
            message: '네트워크 연결을 확인해 주세요.',
          ),
        ),
      );

      await controller.load();

      expect(controller.state.visibleStories, isEmpty);
      expect(controller.state.feedErrorMessage, '네트워크 연결을 확인해 주세요.');
    });

    test('filters visible stories by selected category', () async {
      final controller = HomeController(
        homeRepository: _FakeHomeRepository(
          stats: _stats(),
          stories: _stories(),
        ),
      );

      await controller.load();
      controller.selectCategory(HomeStoryCategory.question);

      expect(controller.state.visibleStories, hasLength(1));
      expect(controller.state.visibleStories.single.category, HomeStoryCategory.question);
    });
  });
}

HomeStats _stats() {
  return const HomeStats(
    todayWorryCount: 2,
    todayLetterCount: 3,
    todayDiaryCount: 4,
  );
}

List<HomeStory> _stories() {
  return const [
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
      title: '작은 산책',
      summary: '오랜만에 걸었어요.',
      authorNickname: '산책러',
      category: HomeStoryCategory.daily,
      createdAt: '2026-04-10T09:00:00',
      viewCount: 8,
    ),
    HomeStory(
      id: 3,
      title: '어떻게 말해야 할까요?',
      summary: '말을 꺼내기 어렵습니다.',
      authorNickname: '질문자',
      category: HomeStoryCategory.question,
      createdAt: '2026-04-10T10:00:00',
      viewCount: 11,
    ),
  ];
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository({
    this.stats,
    this.stories,
    this.statsError,
    this.storiesError,
  });

  final HomeStats? stats;
  final List<HomeStory>? stories;
  final Object? statsError;
  final Object? storiesError;

  @override
  Future<HomeStats> fetchStats() async {
    final error = statsError;
    if (error != null) {
      throw error;
    }
    return stats!;
  }

  @override
  Future<HomeStoryPage> fetchStories({
    HomeStoryCategory category = HomeStoryCategory.all,
  }) async {
    final error = storiesError;
    if (error != null) {
      throw error;
    }
    return HomeStoryPage(items: stories ?? const [], last: true);
  }
}

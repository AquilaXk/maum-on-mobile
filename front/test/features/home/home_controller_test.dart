import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/data/draft_recovery_repository.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/domain/draft_recovery_models.dart';
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

    test('loads active member draft summaries for home continuation', () async {
      final draftRepository = StorageDraftRecoveryRepository(
        storage: MemoryDraftRecoveryStorage(),
      );
      await draftRepository.saveEditing(
        const DraftKey(memberId: 7, surface: DraftSurface.diary),
        fields: {
          'title': '오늘의 기록',
          'content': '퇴근길에 마음이 조금 가벼워졌어요.',
        },
      );
      await draftRepository.saveEditing(
        const DraftKey(memberId: 7, surface: DraftSurface.consultation),
        fields: {'content': '상담에서 이어서 묻고 싶은 내용'},
      );

      final controller = HomeController(
        homeRepository: _FakeHomeRepository(
          stats: _stats(),
          stories: _stories(),
        ),
        draftRepository: draftRepository,
        currentMemberId: 7,
      );

      await controller.load();

      expect(controller.state.drafts, hasLength(2));
      expect(
        controller.state.drafts.map((draft) => draft.surface),
        containsAll([HomeActionSurface.diary, HomeActionSurface.consultation]),
      );
      expect(controller.state.draftErrorMessage, isNull);
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
      expect(controller.state.visibleStories.single.category,
          HomeStoryCategory.question);
    });

    test('ignores stale feed responses when category changes quickly', () async {
      final initialStoriesCompleter = Completer<HomeStoryPage>();
      final questionStoriesCompleter = Completer<HomeStoryPage>();
      final controller = HomeController(
        homeRepository: _FakeHomeRepository(
          stats: _stats(),
          storyCompletersByCategory: {
            HomeStoryCategory.all: initialStoriesCompleter,
            HomeStoryCategory.question: questionStoriesCompleter,
          },
        ),
      );

      final loadFuture = controller.load();
      await Future<void>.delayed(Duration.zero);
      controller.selectCategory(HomeStoryCategory.question);

      questionStoriesCompleter.complete(
        HomeStoryPage(items: [_stories().last], last: true),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.selectedCategory, HomeStoryCategory.question);
      expect(controller.state.visibleStories, hasLength(1));
      expect(controller.state.visibleStories.single.category,
          HomeStoryCategory.question);
      expect(controller.state.isFeedLoading, isFalse);

      initialStoriesCompleter.complete(
        HomeStoryPage(items: [_stories().first], last: true),
      );
      await loadFuture;

      expect(controller.state.selectedCategory, HomeStoryCategory.question);
      expect(controller.state.visibleStories, hasLength(1));
      expect(controller.state.visibleStories.single.category,
          HomeStoryCategory.question);
    });

    test('ignores duplicate load calls while a request is in flight', () async {
      final statsCompleter = Completer<HomeStats>();
      final storiesCompleter = Completer<HomeStoryPage>();
      final repository = _FakeHomeRepository(
        statsCompleter: statsCompleter,
        storiesCompleter: storiesCompleter,
      );
      final controller = HomeController(homeRepository: repository);

      final firstLoad = controller.load();
      final secondLoad = controller.load();

      expect(repository.statsCallCount, 1);
      expect(repository.storiesCallCount, 1);

      statsCompleter.complete(_stats());
      storiesCompleter.complete(HomeStoryPage(items: _stories(), last: true));
      await Future.wait([firstLoad, secondLoad]);

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.visibleStories, hasLength(3));
    });
  });
}

HomeStats _stats() {
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
  _FakeHomeRepository({
    this.stats,
    this.stories,
    this.statsError,
    this.storiesError,
    this.statsCompleter,
    this.storiesCompleter,
    this.storyCompletersByCategory,
  });

  final HomeStats? stats;
  final List<HomeStory>? stories;
  final Object? statsError;
  final Object? storiesError;
  final Completer<HomeStats>? statsCompleter;
  final Completer<HomeStoryPage>? storiesCompleter;
  final Map<HomeStoryCategory, Completer<HomeStoryPage>>?
      storyCompletersByCategory;
  int statsCallCount = 0;
  int storiesCallCount = 0;

  @override
  Future<HomeStats> fetchStats() async {
    statsCallCount += 1;
    final completer = statsCompleter;
    if (completer != null) {
      return completer.future;
    }

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
    storiesCallCount += 1;
    final completer = storiesCompleter;
    if (completer != null) {
      return completer.future;
    }
    final categoryCompleter = storyCompletersByCategory?[category];
    if (categoryCompleter != null) {
      return categoryCompleter.future;
    }

    final error = storiesError;
    if (error != null) {
      throw error;
    }
    return HomeStoryPage(items: stories ?? const [], last: true);
  }
}

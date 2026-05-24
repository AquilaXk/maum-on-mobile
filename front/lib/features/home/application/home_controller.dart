import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../data/home_repository.dart';
import '../domain/home_models.dart';

class HomeState {
  const HomeState({
    this.stats,
    this.stories = const [],
    this.selectedCategory = HomeStoryCategory.all,
    this.isStatsLoading = false,
    this.isFeedLoading = false,
    this.hasLoaded = false,
    this.statsErrorMessage,
    this.feedErrorMessage,
  });

  final HomeStats? stats;
  final List<HomeStory> stories;
  final HomeStoryCategory selectedCategory;
  final bool isStatsLoading;
  final bool isFeedLoading;
  final bool hasLoaded;
  final String? statsErrorMessage;
  final String? feedErrorMessage;

  bool get isLoading => isStatsLoading || isFeedLoading;

  bool get isFeedEmpty =>
      hasLoaded && feedErrorMessage == null && visibleStories.isEmpty;

  List<HomeStory> get visibleStories {
    if (selectedCategory == HomeStoryCategory.all) {
      return stories;
    }

    return stories
        .where((story) => story.category == selectedCategory)
        .toList(growable: false);
  }

  HomeState copyWith({
    HomeStats? stats,
    bool clearStats = false,
    List<HomeStory>? stories,
    HomeStoryCategory? selectedCategory,
    bool? isStatsLoading,
    bool? isFeedLoading,
    bool? hasLoaded,
    String? statsErrorMessage,
    bool clearStatsError = false,
    String? feedErrorMessage,
    bool clearFeedError = false,
  }) {
    return HomeState(
      stats: clearStats ? null : stats ?? this.stats,
      stories: stories ?? this.stories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isStatsLoading: isStatsLoading ?? this.isStatsLoading,
      isFeedLoading: isFeedLoading ?? this.isFeedLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      statsErrorMessage:
          clearStatsError ? null : statsErrorMessage ?? this.statsErrorMessage,
      feedErrorMessage:
          clearFeedError ? null : feedErrorMessage ?? this.feedErrorMessage,
    );
  }
}

class HomeController extends ChangeNotifier {
  HomeController({
    required HomeRepository homeRepository,
  }) : _homeRepository = homeRepository;

  final HomeRepository _homeRepository;

  HomeState _state = const HomeState();
  bool _isLoading = false;
  bool _isDisposed = false;

  HomeState get state => _state;

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _setState(
      _state.copyWith(
        isStatsLoading: true,
        isFeedLoading: true,
        clearStatsError: true,
        clearFeedError: true,
      ),
    );

    try {
      await Future.wait([
        _loadStats(),
        _loadStories(),
      ]);
    } finally {
      _isLoading = false;
      _setState(
        _state.copyWith(
          hasLoaded: true,
          isStatsLoading: false,
          isFeedLoading: false,
        ),
      );
    }
  }

  void selectCategory(HomeStoryCategory category) {
    _setState(_state.copyWith(selectedCategory: category));
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _homeRepository.fetchStats();
      _setState(
        _state.copyWith(
          stats: stats,
          clearStatsError: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          clearStats: true,
          statsErrorMessage: _messageFromError(error, '통계를 불러오지 못했습니다.'),
        ),
      );
    }
  }

  Future<void> _loadStories() async {
    try {
      final page = await _homeRepository.fetchStories();
      _setState(
        _state.copyWith(
          stories: page.items,
          clearFeedError: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          stories: const [],
          feedErrorMessage: _messageFromError(error, '스토리를 불러오지 못했습니다.'),
        ),
      );
    }
  }

  String _messageFromError(Object error, String fallback) {
    if (error is ApiClientException) {
      return error.message;
    }

    return fallback;
  }

  void _setState(HomeState nextState) {
    if (_isDisposed) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

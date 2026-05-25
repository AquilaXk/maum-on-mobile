import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../draft_recovery/data/draft_recovery_repository.dart';
import '../../draft_recovery/domain/draft_recovery_models.dart';
import '../data/home_repository.dart';
import '../domain/home_models.dart';

class HomeState {
  const HomeState({
    this.stats,
    this.stories = const [],
    this.drafts = const [],
    this.selectedCategory = HomeStoryCategory.all,
    this.isStatsLoading = false,
    this.isFeedLoading = false,
    this.isDraftLoading = false,
    this.hasLoaded = false,
    this.statsErrorMessage,
    this.feedErrorMessage,
    this.draftErrorMessage,
  });

  final HomeStats? stats;
  final List<HomeStory> stories;
  final List<HomeDraftSummary> drafts;
  final HomeStoryCategory selectedCategory;
  final bool isStatsLoading;
  final bool isFeedLoading;
  final bool isDraftLoading;
  final bool hasLoaded;
  final String? statsErrorMessage;
  final String? feedErrorMessage;
  final String? draftErrorMessage;

  bool get isLoading => isStatsLoading || isFeedLoading || isDraftLoading;

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
    List<HomeDraftSummary>? drafts,
    HomeStoryCategory? selectedCategory,
    bool? isStatsLoading,
    bool? isFeedLoading,
    bool? isDraftLoading,
    bool? hasLoaded,
    String? statsErrorMessage,
    bool clearStatsError = false,
    String? feedErrorMessage,
    bool clearFeedError = false,
    String? draftErrorMessage,
    bool clearDraftError = false,
  }) {
    return HomeState(
      stats: clearStats ? null : stats ?? this.stats,
      stories: stories ?? this.stories,
      drafts: drafts ?? this.drafts,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isStatsLoading: isStatsLoading ?? this.isStatsLoading,
      isFeedLoading: isFeedLoading ?? this.isFeedLoading,
      isDraftLoading: isDraftLoading ?? this.isDraftLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      statsErrorMessage:
          clearStatsError ? null : statsErrorMessage ?? this.statsErrorMessage,
      feedErrorMessage:
          clearFeedError ? null : feedErrorMessage ?? this.feedErrorMessage,
      draftErrorMessage:
          clearDraftError ? null : draftErrorMessage ?? this.draftErrorMessage,
    );
  }
}

class HomeController extends ChangeNotifier {
  HomeController({
    required HomeRepository homeRepository,
    DraftRecoveryRepository? draftRepository,
    int? currentMemberId,
  })  : _homeRepository = homeRepository,
        _draftRepository = draftRepository,
        _currentMemberId = currentMemberId;

  final HomeRepository _homeRepository;
  final DraftRecoveryRepository? _draftRepository;
  final int? _currentMemberId;

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
        isDraftLoading: _draftRepository != null && _currentMemberId != null,
        clearStatsError: true,
        clearFeedError: true,
        clearDraftError: true,
      ),
    );

    try {
      await Future.wait([
        _loadStats(),
        _loadStories(),
        _loadDrafts(),
      ]);
    } finally {
      _isLoading = false;
      _setState(
        _state.copyWith(
          hasLoaded: true,
          isStatsLoading: false,
          isFeedLoading: false,
          isDraftLoading: false,
        ),
      );
    }
  }

  void selectCategory(HomeStoryCategory category) {
    _setState(
      _state.copyWith(
        selectedCategory: category,
        isFeedLoading: true,
        clearFeedError: true,
      ),
    );
    unawaited(_loadStories(category: category));
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

  Future<void> _loadStories({HomeStoryCategory? category}) async {
    try {
      final page = await _homeRepository.fetchStories(
        category: category ?? _state.selectedCategory,
      );
      _setState(
        _state.copyWith(
          stories: page.items,
          isFeedLoading: false,
          clearFeedError: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          stories: const [],
          isFeedLoading: false,
          feedErrorMessage: _messageFromError(error, '스토리를 불러오지 못했습니다.'),
        ),
      );
    }
  }

  Future<void> _loadDrafts() async {
    final repository = _draftRepository;
    final memberId = _currentMemberId;
    if (repository == null || memberId == null) {
      _setState(
        _state.copyWith(
          drafts: const [],
          isDraftLoading: false,
          clearDraftError: true,
        ),
      );
      return;
    }

    try {
      final entries = <DraftEntry>[];
      for (final surface in _homeDraftSurfaces.keys) {
        final entry = await repository.read(
          DraftKey(memberId: memberId, surface: surface),
        ).timeout(
          _draftReadTimeout,
          onTimeout: () => null,
        );
        if (entry != null && entry.fields.isNotEmpty) {
          entries.add(entry);
        }
      }

      final drafts = entries.map(_homeDraftSummary).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _setState(
        _state.copyWith(
          drafts: drafts,
          clearDraftError: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          drafts: const [],
          draftErrorMessage: _messageFromError(
            error,
            '임시 저장 내용을 불러오지 못했습니다.',
          ),
        ),
      );
    }
  }

  HomeDraftSummary _homeDraftSummary(DraftEntry entry) {
    final surface = _homeDraftSurfaces[entry.key.surface]!;
    final title = _draftTitle(surface, entry.fields);
    final preview = _draftPreview(entry.fields);
    return HomeDraftSummary(
      surface: surface,
      title: title,
      preview: preview,
      updatedAt: entry.updatedAt,
      failed: entry.isFailed,
    );
  }

  String _draftTitle(
    HomeActionSurface surface,
    Map<String, String> fields,
  ) {
    final title = fields['title']?.trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }
    return '${surface.label} 작성 중';
  }

  String _draftPreview(Map<String, String> fields) {
    final content = fields['content']?.trim() ?? '';
    if (content.isNotEmpty) {
      return content.length > 48 ? '${content.substring(0, 48)}...' : content;
    }
    return '마지막 작성 내용을 이어갈 수 있습니다.';
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

const _homeDraftSurfaces = {
  DraftSurface.diary: HomeActionSurface.diary,
  DraftSurface.story: HomeActionSurface.story,
  DraftSurface.letter: HomeActionSurface.letter,
  DraftSurface.consultation: HomeActionSurface.consultation,
};

const _draftReadTimeout = Duration(milliseconds: 500);

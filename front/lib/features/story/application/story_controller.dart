import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../draft_recovery/data/draft_recovery_repository.dart';
import '../../draft_recovery/domain/draft_recovery_models.dart';
import '../../moderation/data/content_moderation_repository.dart';
import '../../moderation/domain/content_moderation_models.dart';
import '../data/story_repository.dart';
import '../domain/story_models.dart';

enum StoryViewMode {
  list,
  detail,
  editor,
}

class StoryState {
  const StoryState({
    this.mode = StoryViewMode.list,
    this.stories = const [],
    this.comments = const [],
    this.selectedStory,
    this.selectedCategory = StoryCategory.all,
    this.searchQuery = '',
    this.editingStoryId,
    this.storyTitle = '',
    this.storyContent = '',
    this.storyCategory = StoryCategory.worry,
    this.commentDraft = '',
    this.activeReplyCommentId,
    this.replyDrafts = const {},
    this.editingCommentId,
    this.editingCommentContent = '',
    this.isListLoading = false,
    this.isDetailLoading = false,
    this.isLoadingMore = false,
    this.storyPage = 0,
    this.isLastStoryPage = true,
    this.isSubmitting = false,
    this.hasLoaded = false,
    this.errorMessage,
    this.noticeMessage,
    this.moderationFeedback,
    this.reportTarget,
  });

  final StoryViewMode mode;
  final List<StorySummary> stories;
  final List<StoryComment> comments;
  final StoryDetail? selectedStory;
  final StoryCategory selectedCategory;
  final String searchQuery;
  final int? editingStoryId;
  final String storyTitle;
  final String storyContent;
  final StoryCategory storyCategory;
  final String commentDraft;
  final int? activeReplyCommentId;
  final Map<int, String> replyDrafts;
  final int? editingCommentId;
  final String editingCommentContent;
  final bool isListLoading;
  final bool isDetailLoading;
  final bool isLoadingMore;
  final int storyPage;
  final bool isLastStoryPage;
  final bool isSubmitting;
  final bool hasLoaded;
  final String? errorMessage;
  final String? noticeMessage;
  final ContentModerationFeedback? moderationFeedback;
  final StoryReportTarget? reportTarget;

  bool get isEditingStory => editingStoryId != null;

  bool get canSubmitStory {
    return storyTitle.trim().isNotEmpty &&
        storyContent.trim().isNotEmpty &&
        storyCategory != StoryCategory.all &&
        !isSubmitting;
  }

  bool get canSubmitComment => commentDraft.trim().isNotEmpty && !isSubmitting;

  bool canSubmitReply(int parentCommentId) {
    return replyDrafts[parentCommentId]?.trim().isNotEmpty == true &&
        !isSubmitting;
  }

  bool get canSubmitCommentEdit =>
      editingCommentContent.trim().isNotEmpty &&
      editingCommentId != null &&
      !isSubmitting;

  bool get isEmpty =>
      hasLoaded && stories.isEmpty && errorMessage == null && !isListLoading;

  bool get canLoadMoreStories {
    return hasLoaded &&
        stories.isNotEmpty &&
        !isListLoading &&
        !isLoadingMore &&
        !isLastStoryPage &&
        errorMessage == null;
  }

  StoryState copyWith({
    StoryViewMode? mode,
    List<StorySummary>? stories,
    List<StoryComment>? comments,
    StoryDetail? selectedStory,
    bool clearSelectedStory = false,
    StoryCategory? selectedCategory,
    String? searchQuery,
    int? editingStoryId,
    bool clearEditingStoryId = false,
    String? storyTitle,
    String? storyContent,
    StoryCategory? storyCategory,
    String? commentDraft,
    int? activeReplyCommentId,
    bool clearActiveReplyCommentId = false,
    Map<int, String>? replyDrafts,
    int? editingCommentId,
    bool clearEditingCommentId = false,
    String? editingCommentContent,
    bool? isListLoading,
    bool? isDetailLoading,
    bool? isLoadingMore,
    int? storyPage,
    bool? isLastStoryPage,
    bool? isSubmitting,
    bool? hasLoaded,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? noticeMessage,
    bool clearNoticeMessage = false,
    ContentModerationFeedback? moderationFeedback,
    bool clearModerationFeedback = false,
    StoryReportTarget? reportTarget,
    bool clearReportTarget = false,
  }) {
    return StoryState(
      mode: mode ?? this.mode,
      stories: stories ?? this.stories,
      comments: comments ?? this.comments,
      selectedStory:
          clearSelectedStory ? null : selectedStory ?? this.selectedStory,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      editingStoryId:
          clearEditingStoryId ? null : editingStoryId ?? this.editingStoryId,
      storyTitle: storyTitle ?? this.storyTitle,
      storyContent: storyContent ?? this.storyContent,
      storyCategory: storyCategory ?? this.storyCategory,
      commentDraft: commentDraft ?? this.commentDraft,
      activeReplyCommentId: clearActiveReplyCommentId
          ? null
          : activeReplyCommentId ?? this.activeReplyCommentId,
      replyDrafts: replyDrafts ?? this.replyDrafts,
      editingCommentId: clearEditingCommentId
          ? null
          : editingCommentId ?? this.editingCommentId,
      editingCommentContent:
          editingCommentContent ?? this.editingCommentContent,
      isListLoading: isListLoading ?? this.isListLoading,
      isDetailLoading: isDetailLoading ?? this.isDetailLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      storyPage: storyPage ?? this.storyPage,
      isLastStoryPage: isLastStoryPage ?? this.isLastStoryPage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      noticeMessage:
          clearNoticeMessage ? null : noticeMessage ?? this.noticeMessage,
      moderationFeedback: clearModerationFeedback
          ? null
          : moderationFeedback ?? this.moderationFeedback,
      reportTarget:
          clearReportTarget ? null : reportTarget ?? this.reportTarget,
    );
  }
}

class StoryController extends ChangeNotifier {
  StoryController({
    required StoryRepository storyRepository,
    required int currentMemberId,
    ContentModerationRepository? moderationRepository,
    DraftRecoveryRepository? draftRepository,
    VoidCallback? onUnauthorized,
    ValueChanged<StoryReportTarget>? onReportTargetSelected,
  })  : _storyRepository = storyRepository,
        _currentMemberId = currentMemberId,
        _moderationRepository = moderationRepository,
        _draftRepository = draftRepository,
        _onUnauthorized = onUnauthorized,
        _onReportTargetSelected = onReportTargetSelected;

  final StoryRepository _storyRepository;
  final int _currentMemberId;
  final ContentModerationRepository? _moderationRepository;
  final DraftRecoveryRepository? _draftRepository;
  final VoidCallback? _onUnauthorized;
  final ValueChanged<StoryReportTarget>? _onReportTargetSelected;

  StoryState _state = const StoryState();
  bool _isDisposed = false;

  StoryState get state => _state;

  int get currentMemberId => _currentMemberId;

  DraftKey get _storyDraftKey => DraftKey(
        memberId: _currentMemberId,
        surface: DraftSurface.story,
      );

  DraftKey _commentDraftKey(int storyId) => DraftKey(
        memberId: _currentMemberId,
        surface: DraftSurface.storyComment,
        scopeId: storyId.toString(),
      );

  Future<void> restoreDraft() async {
    final entry = await _draftRepository?.read(_storyDraftKey);
    if (entry == null || entry.fields.isEmpty) {
      return;
    }

    _setState(
      _state.copyWith(
        mode: StoryViewMode.editor,
        clearEditingStoryId: true,
        storyTitle: entry.fields['title'] ?? '',
        storyContent: entry.fields['content'] ?? '',
        storyCategory: _storyCategoryFromDraft(entry.fields['category']),
        noticeMessage: '임시 저장된 스토리를 복원했습니다.',
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> loadStories() async {
    await _loadStoriesPage(pageIndex: 0, append: false);
  }

  Future<void> loadMoreStories() async {
    if (!_state.canLoadMoreStories) {
      return;
    }

    await _loadStoriesPage(pageIndex: _state.storyPage + 1, append: true);
  }

  Future<void> _loadStoriesPage({
    required int pageIndex,
    required bool append,
  }) async {
    _setState(
      _state.copyWith(
        isListLoading: append ? false : true,
        isLoadingMore: append,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final response = await _storyRepository.fetchStories(
        title: _state.searchQuery,
        category: _state.selectedCategory,
        page: pageIndex,
      );
      _setState(
        _state.copyWith(
          stories: append
              ? _mergeStoryPages(_state.stories, response.items)
              : response.items,
          storyPage: response.page,
          isLastStoryPage: response.last,
          isListLoading: false,
          isLoadingMore: false,
          hasLoaded: true,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(
        _state.copyWith(
          isListLoading: false,
          isLoadingMore: false,
          hasLoaded: true,
        ),
      );
    }
  }

  void updateSearchQuery(String query) {
    _setState(_state.copyWith(searchQuery: query, clearErrorMessage: true));
  }

  Future<void> selectCategory(StoryCategory category) async {
    _setState(
      _state.copyWith(
        selectedCategory: category,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
    await loadStories();
  }

  Future<void> openStory(StorySummary story) {
    return openStoryById(story.id);
  }

  Future<void> openStoryById(int storyId) async {
    _setState(
      _state.copyWith(
        mode: StoryViewMode.detail,
        isDetailLoading: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
        clearReportTarget: true,
      ),
    );

    try {
      final detail = await _storyRepository.fetchStory(storyId);
      final commentsPage = await _storyRepository.fetchComments(storyId);
      final commentDraft = await _readCommentDraft(storyId);
      _setState(
        _state.copyWith(
          selectedStory: detail,
          comments: commentsPage.items,
          isDetailLoading: false,
          commentDraft: commentDraft,
          clearActiveReplyCommentId: true,
          replyDrafts: const {},
          clearEditingCommentId: true,
          editingCommentContent: '',
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isDetailLoading: false));
    }
  }

  void backToList() {
    _setState(
      _state.copyWith(
        mode: StoryViewMode.list,
        clearSelectedStory: true,
        comments: const [],
        clearActiveReplyCommentId: true,
        replyDrafts: const {},
        clearEditingStoryId: true,
        clearEditingCommentId: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void startCreate() {
    _setState(
      _state.copyWith(
        mode: StoryViewMode.editor,
        clearEditingStoryId: true,
        storyTitle: '',
        storyContent: '',
        storyCategory: StoryCategory.worry,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void startEditingSelectedStory() {
    final story = _state.selectedStory;
    if (story == null || !story.canEdit(_currentMemberId)) {
      return;
    }

    _setState(
      _state.copyWith(
        mode: StoryViewMode.editor,
        editingStoryId: story.id,
        storyTitle: story.title,
        storyContent: story.content,
        storyCategory: story.category,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void cancelEditor() {
    _setState(
      _state.copyWith(
        mode: _state.selectedStory == null
            ? StoryViewMode.list
            : StoryViewMode.detail,
        clearEditingStoryId: true,
        storyTitle: '',
        storyContent: '',
        storyCategory: StoryCategory.worry,
        clearErrorMessage: true,
      ),
    );
    unawaited(_draftRepository?.delete(_storyDraftKey));
  }

  void updateStoryTitle(String title) {
    _setState(
      _state.copyWith(
        storyTitle: title,
        clearErrorMessage: true,
        clearModerationFeedback: true,
      ),
    );
    _saveStoryDraft();
  }

  void updateStoryContent(String content) {
    _setState(
      _state.copyWith(
        storyContent: content,
        clearErrorMessage: true,
        clearModerationFeedback: true,
      ),
    );
    _saveStoryDraft();
  }

  void updateStoryCategory(StoryCategory category) {
    if (category == StoryCategory.all) {
      return;
    }

    _setState(_state.copyWith(storyCategory: category));
    _saveStoryDraft();
  }

  Future<void> submitStory() async {
    if (!_state.canSubmitStory) {
      return;
    }

    final editingId = _state.editingStoryId;
    final draft = StoryDraft(
      title: _state.storyTitle.trim(),
      content: _state.storyContent.trim(),
      category: _state.storyCategory,
    );

    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      if (!await _ensureModerationAllowed(
        targetType: ContentModerationTarget.story,
        text: '${draft.title}\n${draft.content}',
      )) {
        return;
      }

      final int storyId;
      if (editingId == null) {
        storyId = await _storyRepository.createStory(draft);
      } else {
        await _storyRepository.updateStory(editingId, draft);
        storyId = editingId;
      }

      await _draftRepository?.delete(_storyDraftKey);
      _resetEditorSilently();
      await loadStories();
      await openStoryById(storyId);
      _setState(
        _state.copyWith(
          isSubmitting: false,
          noticeMessage: editingId == null ? '스토리가 등록되었습니다.' : '스토리가 수정되었습니다.',
        ),
      );
    } on Object catch (error) {
      await _markStoryDraftFailed(error);
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  Future<void> deleteSelectedStory() async {
    final story = _state.selectedStory;
    if (story == null || !story.canEdit(_currentMemberId)) {
      return;
    }

    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      await _storyRepository.deleteStory(story.id);
      _setState(
        _state.copyWith(
          mode: StoryViewMode.list,
          clearSelectedStory: true,
          comments: const [],
          clearActiveReplyCommentId: true,
          replyDrafts: const {},
          isSubmitting: false,
        ),
      );
      await loadStories();
      _setState(_state.copyWith(noticeMessage: '스토리가 삭제되었습니다.'));
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  Future<void> toggleSelectedResolutionStatus() async {
    final story = _state.selectedStory;
    if (story == null || !story.canEdit(_currentMemberId)) {
      return;
    }

    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      await _storyRepository.updateResolutionStatus(
        story.id,
        story.resolutionStatus.toggled,
      );
      await openStoryById(story.id);
      _setState(
        _state.copyWith(
          isSubmitting: false,
          noticeMessage: '스토리 상태가 변경되었습니다.',
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  void updateCommentDraft(String content) {
    _setState(
      _state.copyWith(
        commentDraft: content,
        clearErrorMessage: true,
        clearModerationFeedback: true,
      ),
    );
    _saveCommentDraft();
  }

  void startReply(StoryComment comment) {
    final currentDraft = _state.replyDrafts[comment.id];
    final shouldPrefillMention =
        comment.authorId != _currentMemberId && (currentDraft ?? '').isEmpty;
    final nextDrafts = Map<int, String>.of(_state.replyDrafts);
    if (shouldPrefillMention) {
      nextDrafts[comment.id] = '@${comment.authorNickname} ';
    }

    _setState(
      _state.copyWith(
        activeReplyCommentId: comment.id,
        replyDrafts: nextDrafts,
        clearErrorMessage: true,
        clearNoticeMessage: true,
        clearModerationFeedback: true,
      ),
    );
  }

  void cancelReply(int parentCommentId) {
    final nextDrafts = Map<int, String>.of(_state.replyDrafts)
      ..remove(parentCommentId);
    _setState(
      _state.copyWith(
        clearActiveReplyCommentId: true,
        replyDrafts: nextDrafts,
        clearErrorMessage: true,
        clearModerationFeedback: true,
      ),
    );
  }

  void updateReplyDraft(int parentCommentId, String content) {
    final nextDrafts = Map<int, String>.of(_state.replyDrafts)
      ..[parentCommentId] = content;
    _setState(
      _state.copyWith(
        replyDrafts: nextDrafts,
        clearErrorMessage: true,
        clearModerationFeedback: true,
      ),
    );
  }

  Future<void> submitComment({int? parentCommentId}) async {
    final story = _state.selectedStory;
    if (story == null || !_state.canSubmitComment) {
      return;
    }

    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      if (!await _ensureModerationAllowed(
        targetType: ContentModerationTarget.comment,
        text: _state.commentDraft.trim(),
      )) {
        return;
      }

      await _storyRepository.createComment(
        postId: story.id,
        authorId: _currentMemberId,
        content: _state.commentDraft.trim(),
        parentCommentId: parentCommentId,
      );
      await _draftRepository?.delete(_commentDraftKey(story.id));
      final commentsPage = await _storyRepository.fetchComments(story.id);
      _setState(
        _state.copyWith(
          comments: commentsPage.items,
          commentDraft: '',
          isSubmitting: false,
          noticeMessage: '댓글이 등록되었습니다.',
        ),
      );
    } on Object catch (error) {
      await _markCommentDraftFailed(error);
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  Future<void> submitReply(int parentCommentId) async {
    final story = _state.selectedStory;
    final content = _state.replyDrafts[parentCommentId]?.trim() ?? '';
    if (story == null || content.isEmpty || _state.isSubmitting) {
      return;
    }

    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      if (!await _ensureModerationAllowed(
        targetType: ContentModerationTarget.comment,
        text: content,
      )) {
        return;
      }

      await _storyRepository.createComment(
        postId: story.id,
        authorId: _currentMemberId,
        content: content,
        parentCommentId: parentCommentId,
      );
      final commentsPage = await _storyRepository.fetchComments(story.id);
      final nextDrafts = Map<int, String>.of(_state.replyDrafts)
        ..remove(parentCommentId);
      _setState(
        _state.copyWith(
          comments: commentsPage.items,
          replyDrafts: nextDrafts,
          clearActiveReplyCommentId: true,
          isSubmitting: false,
          noticeMessage: '답글이 등록되었습니다.',
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  void startEditingComment(StoryComment comment) {
    if (!comment.canEdit(_currentMemberId)) {
      return;
    }

    _setState(
      _state.copyWith(
        editingCommentId: comment.id,
        editingCommentContent: comment.content,
        clearErrorMessage: true,
        clearNoticeMessage: true,
        clearModerationFeedback: true,
      ),
    );
  }

  void updateEditingCommentContent(String content) {
    _setState(
      _state.copyWith(
        editingCommentContent: content,
        clearErrorMessage: true,
        clearModerationFeedback: true,
      ),
    );
  }

  void cancelEditingComment() {
    _setState(
      _state.copyWith(
        clearEditingCommentId: true,
        editingCommentContent: '',
        clearErrorMessage: true,
        clearModerationFeedback: true,
      ),
    );
  }

  void clearModerationFeedback() {
    _setState(
      _state.copyWith(
        clearErrorMessage: true,
        clearModerationFeedback: true,
      ),
    );
  }

  Future<String> _readCommentDraft(int storyId) async {
    final entry = await _draftRepository?.read(_commentDraftKey(storyId));
    return entry?.fields['content'] ?? '';
  }

  void _saveStoryDraft() {
    final repository = _draftRepository;
    if (repository == null) {
      return;
    }
    unawaited(
      repository.saveEditing(
        _storyDraftKey,
        fields: {
          'title': _state.storyTitle,
          'content': _state.storyContent,
          'category': _state.storyCategory.name,
        },
      ),
    );
  }

  void _saveCommentDraft() {
    final repository = _draftRepository;
    final story = _state.selectedStory;
    if (repository == null || story == null) {
      return;
    }
    unawaited(
      repository.saveEditing(
        _commentDraftKey(story.id),
        fields: {'content': _state.commentDraft},
      ),
    );
  }

  Future<void> _markStoryDraftFailed(Object error) async {
    final repository = _draftRepository;
    if (repository == null) {
      return;
    }
    await repository.markFailed(
      _storyDraftKey,
      fields: {
        'title': _state.storyTitle,
        'content': _state.storyContent,
        'category': _state.storyCategory.name,
      },
      failureMessage: _messageFromError(error),
    );
  }

  Future<void> _markCommentDraftFailed(Object error) async {
    final repository = _draftRepository;
    final story = _state.selectedStory;
    if (repository == null || story == null) {
      return;
    }
    await repository.markFailed(
      _commentDraftKey(story.id),
      fields: {'content': _state.commentDraft},
      failureMessage: _messageFromError(error),
    );
  }

  StoryCategory _storyCategoryFromDraft(String? value) {
    return StoryCategory.values.firstWhere(
      (category) => category.name == value && category != StoryCategory.all,
      orElse: () => StoryCategory.worry,
    );
  }

  Future<void> submitCommentEdit() async {
    final story = _state.selectedStory;
    final commentId = _state.editingCommentId;
    if (story == null || commentId == null || !_state.canSubmitCommentEdit) {
      return;
    }

    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      if (!await _ensureModerationAllowed(
        targetType: ContentModerationTarget.comment,
        text: _state.editingCommentContent.trim(),
      )) {
        return;
      }

      await _storyRepository.updateComment(
        commentId,
        _state.editingCommentContent.trim(),
      );
      final commentsPage = await _storyRepository.fetchComments(story.id);
      _setState(
        _state.copyWith(
          comments: commentsPage.items,
          isSubmitting: false,
          clearEditingCommentId: true,
          editingCommentContent: '',
          noticeMessage: '댓글이 수정되었습니다.',
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  Future<void> deleteComment(StoryComment comment) async {
    final story = _state.selectedStory;
    if (story == null || !comment.canEdit(_currentMemberId)) {
      return;
    }

    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      await _storyRepository.deleteComment(comment.id);
      final commentsPage = await _storyRepository.fetchComments(story.id);
      _setState(
        _state.copyWith(
          comments: commentsPage.items,
          isSubmitting: false,
          noticeMessage: '댓글이 삭제되었습니다.',
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  void selectStoryReportTarget() {
    final story = _state.selectedStory;
    if (story == null) {
      return;
    }

    _selectReportTarget(
      StoryReportTarget(
        targetType: 'POST',
        targetId: story.id,
        label: story.title,
      ),
    );
  }

  void selectCommentReportTarget(StoryComment comment) {
    _selectReportTarget(
      StoryReportTarget(
        targetType: 'COMMENT',
        targetId: comment.id,
        label: comment.content,
      ),
    );
  }

  void _selectReportTarget(StoryReportTarget target) {
    _onReportTargetSelected?.call(target);
    _setState(
      _state.copyWith(
        reportTarget: target,
        noticeMessage: '신고 대상이 선택되었습니다.',
      ),
    );
  }

  void _resetEditorSilently() {
    _state = _state.copyWith(
      clearEditingStoryId: true,
      storyTitle: '',
      storyContent: '',
      storyCategory: StoryCategory.worry,
    );
  }

  Future<bool> _ensureModerationAllowed({
    required ContentModerationTarget targetType,
    required String text,
  }) async {
    final repository = _moderationRepository;
    if (repository == null) {
      return true;
    }

    final ContentModerationResult result;
    try {
      result = await repository.reviewText(
        targetType: targetType,
        text: text,
      );
    } on ApiClientException catch (error) {
      if (error.sessionInvalidated) {
        rethrow;
      }
      final feedback = ContentModerationFeedback.failure(
        targetType: targetType,
        error: error,
      );
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: feedback.message,
          moderationFeedback: feedback,
          clearNoticeMessage: true,
        ),
      );
      return false;
    }

    if (result.allowed) {
      if (result.riskLevel != ContentModerationRiskLevel.low) {
        _setState(
          _state.copyWith(
            noticeMessage: result.message,
            clearModerationFeedback: true,
          ),
        );
      } else if (_state.moderationFeedback != null) {
        _setState(_state.copyWith(clearModerationFeedback: true));
      }
      return true;
    }

    final feedback = ContentModerationFeedback.blocked(
      targetType: targetType,
      result: result,
    );
    _setState(
      _state.copyWith(
        isSubmitting: false,
        errorMessage: result.message,
        moderationFeedback: feedback,
        clearNoticeMessage: true,
      ),
    );
    return false;
  }

  void _handleError(Object error) {
    if (error is ApiClientException) {
      if (error.kind == ApiErrorKind.unauthorized) {
        _onUnauthorized?.call();
      }
      _setState(
        _state.copyWith(
          errorMessage: error.message,
          clearNoticeMessage: true,
          clearModerationFeedback: true,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        errorMessage: '요청을 처리하지 못했습니다.',
        clearNoticeMessage: true,
        clearModerationFeedback: true,
      ),
    );
  }

  String _messageFromError(Object error) {
    if (error is ApiClientException) {
      return error.message;
    }
    return '요청을 처리하지 못했습니다.';
  }

  void _setState(StoryState nextState) {
    if (_isDisposed) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  List<StorySummary> _mergeStoryPages(
    List<StorySummary> current,
    List<StorySummary> next,
  ) {
    final seenIds = current.map((story) => story.id).toSet();
    return [
      ...current,
      for (final story in next)
        if (seenIds.add(story.id)) story,
    ];
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/story/application/story_controller.dart';
import 'package:maum_on_mobile_front/features/story/data/story_repository.dart';
import 'package:maum_on_mobile_front/features/story/domain/story_models.dart';

void main() {
  group('StoryController', () {
    test('loads stories with search and category filters', () async {
      final repository = _FakeStoryRepository(
        storyPages: [
          _storyPage([_summary(id: 1, title: '처음')]),
          _storyPage([_summary(id: 2, title: '검색 결과')]),
        ],
      );
      final controller = StoryController(
        storyRepository: repository,
        currentMemberId: 7,
      );

      await controller.loadStories();
      controller.updateSearchQuery('검색');
      await controller.selectCategory(StoryCategory.worry);

      expect(controller.state.stories.single.title, '검색 결과');
      expect(repository.fetchStoryRequests.last.title, '검색');
      expect(repository.fetchStoryRequests.last.category, StoryCategory.worry);
    });

    test('creates a story and opens the created detail', () async {
      final repository = _FakeStoryRepository(
        storyPages: [
          _storyPage([_summary(id: 12, title: '새 글')]),
        ],
        createdStoryId: 12,
        details: [_detail(id: 12, title: '새 글', authorId: 7)],
        commentPages: [_commentPage([])],
      );
      final controller = StoryController(
        storyRepository: repository,
        currentMemberId: 7,
      );

      controller.startCreate();
      controller.updateStoryTitle('새 글');
      controller.updateStoryContent('새 본문');
      controller.updateStoryCategory(StoryCategory.question);
      await controller.submitStory();

      expect(repository.createdDrafts.single.title, '새 글');
      expect(controller.state.mode, StoryViewMode.detail);
      expect(controller.state.selectedStory?.id, 12);
      expect(controller.state.noticeMessage, '스토리가 등록되었습니다.');
    });

    test(
        'updates status, edits, and deletes only when current member is author',
        () async {
      final repository = _FakeStoryRepository(
        storyPages: [
          _storyPage([_summary(id: 5, title: '수정 글')]),
        ],
        details: [
          _detail(id: 5, title: '수정 글', authorId: 7),
          _detail(
            id: 5,
            title: '수정 글',
            authorId: 7,
            status: StoryResolutionStatus.resolved,
          ),
          _detail(id: 5, title: '수정됨', authorId: 7),
        ],
        commentPages: [
          _commentPage([]),
          _commentPage([]),
          _commentPage([]),
        ],
      );
      final controller = StoryController(
        storyRepository: repository,
        currentMemberId: 7,
      );

      await controller.openStoryById(5);
      await controller.toggleSelectedResolutionStatus();
      controller.startEditingSelectedStory();
      controller.updateStoryTitle('수정됨');
      await controller.submitStory();
      await controller.deleteSelectedStory();

      expect(repository.statusUpdates.single.status,
          StoryResolutionStatus.resolved);
      expect(repository.updatedDrafts.single.draft.title, '수정됨');
      expect(repository.deletedStoryIds, [5]);
      expect(controller.state.mode, StoryViewMode.list);
    });

    test('keeps edit actions unavailable for non-author stories', () async {
      final repository = _FakeStoryRepository(
        details: [_detail(id: 3, title: '다른 사람 글', authorId: 99)],
        commentPages: [_commentPage([])],
      );
      final controller = StoryController(
        storyRepository: repository,
        currentMemberId: 7,
      );

      await controller.openStoryById(3);
      controller.startEditingSelectedStory();
      await controller.deleteSelectedStory();

      expect(controller.state.mode, StoryViewMode.detail);
      expect(repository.deletedStoryIds, isEmpty);
      expect(controller.state.selectedStory?.canEdit(7), isFalse);
    });

    test('creates, updates, deletes comments and exposes report targets',
        () async {
      StoryReportTarget? selectedTarget;
      final firstComment = _comment(id: 21, authorId: 7, content: '첫 댓글');
      final repository = _FakeStoryRepository(
        details: [_detail(id: 8, title: '댓글 글', authorId: 7)],
        commentPages: [
          _commentPage([firstComment]),
          _commentPage([
            _comment(id: 22, authorId: 7, content: '등록 댓글'),
          ]),
          _commentPage([
            _comment(id: 22, authorId: 7, content: '수정 댓글'),
          ]),
          _commentPage([]),
        ],
      );
      final controller = StoryController(
        storyRepository: repository,
        currentMemberId: 7,
        onReportTargetSelected: (target) {
          selectedTarget = target;
        },
      );

      await controller.openStoryById(8);
      controller.updateCommentDraft('등록 댓글');
      await controller.submitComment();
      controller.startEditingComment(controller.state.comments.single);
      controller.updateEditingCommentContent('수정 댓글');
      await controller.submitCommentEdit();
      controller.selectCommentReportTarget(controller.state.comments.single);
      await controller.deleteComment(controller.state.comments.single);

      expect(repository.createdComments.single.content, '등록 댓글');
      expect(repository.updatedComments.single.content, '수정 댓글');
      expect(repository.deletedCommentIds, [22]);
      expect(selectedTarget?.targetType, 'COMMENT');
      expect(selectedTarget?.targetId, 22);
    });

    test('invokes unauthorized callback on expired auth', () async {
      var unauthorizedCount = 0;
      final controller = StoryController(
        storyRepository: _FakeStoryRepository(
          fetchError: const ApiClientException(
            kind: ApiErrorKind.unauthorized,
            message: '다시 로그인해 주세요.',
          ),
        ),
        currentMemberId: 7,
        onUnauthorized: () => unauthorizedCount += 1,
      );

      await controller.loadStories();

      expect(unauthorizedCount, 1);
      expect(controller.state.errorMessage, '다시 로그인해 주세요.');
    });
  });
}

PageResponse<StorySummary> _storyPage(List<StorySummary> items) {
  return PageResponse(
    items: items,
    page: 0,
    size: 20,
    totalElements: items.length,
    totalPages: 1,
    last: true,
  );
}

PageResponse<StoryComment> _commentPage(List<StoryComment> items) {
  return PageResponse(
    items: items,
    page: 0,
    size: 20,
    totalElements: items.length,
    totalPages: 1,
    last: true,
  );
}

StorySummary _summary({required int id, required String title}) {
  return StorySummary(
    id: id,
    title: title,
    summary: '요약',
    authorNickname: '마음이',
    category: StoryCategory.worry,
    resolutionStatus: StoryResolutionStatus.ongoing,
    viewCount: 1,
    createDate: '2026-05-24T08:00:00',
    modifyDate: '2026-05-24T08:00:00',
  );
}

StoryDetail _detail({
  required int id,
  required String title,
  required int authorId,
  StoryResolutionStatus status = StoryResolutionStatus.ongoing,
}) {
  return StoryDetail(
    id: id,
    title: title,
    content: '본문',
    summary: '요약',
    authorNickname: '마음이',
    category: StoryCategory.worry,
    resolutionStatus: status,
    viewCount: 1,
    createDate: '2026-05-24T08:00:00',
    modifyDate: '2026-05-24T08:00:00',
    authorId: authorId,
  );
}

StoryComment _comment({
  required int id,
  required int authorId,
  required String content,
}) {
  return StoryComment(
    id: id,
    content: content,
    authorId: authorId,
    authorNickname: '댓글이',
    postId: 8,
    createDate: '2026-05-24T10:00:00',
    modifyDate: '2026-05-24T10:00:00',
  );
}

class _FakeStoryRepository implements StoryRepository {
  _FakeStoryRepository({
    this.storyPages = const [],
    this.details = const [],
    this.commentPages = const [],
    this.createdStoryId = 1,
    this.fetchError,
  });

  final List<PageResponse<StorySummary>> storyPages;
  final List<StoryDetail> details;
  final List<PageResponse<StoryComment>> commentPages;
  final int createdStoryId;
  final Object? fetchError;
  final List<({String? title, StoryCategory category})> fetchStoryRequests = [];
  final List<StoryDraft> createdDrafts = [];
  final List<({int id, StoryDraft draft})> updatedDrafts = [];
  final List<int> deletedStoryIds = [];
  final List<({int id, StoryResolutionStatus status})> statusUpdates = [];
  final List<({int postId, int authorId, String content})> createdComments = [];
  final List<({int id, String content})> updatedComments = [];
  final List<int> deletedCommentIds = [];

  @override
  Future<PageResponse<StorySummary>> fetchStories({
    String? title,
    StoryCategory category = StoryCategory.all,
    int page = 0,
    int size = 20,
  }) async {
    fetchStoryRequests.add((title: title, category: category));
    final error = fetchError;
    if (error != null) {
      throw error;
    }
    return storyPages.isEmpty ? _storyPage([]) : storyPages.removeAt(0);
  }

  @override
  Future<StoryDetail> fetchStory(int id) async {
    return details.removeAt(0);
  }

  @override
  Future<int> createStory(StoryDraft draft) async {
    createdDrafts.add(draft);
    return createdStoryId;
  }

  @override
  Future<void> updateStory(int id, StoryDraft draft) async {
    updatedDrafts.add((id: id, draft: draft));
  }

  @override
  Future<void> deleteStory(int id) async {
    deletedStoryIds.add(id);
  }

  @override
  Future<void> updateResolutionStatus(
    int id,
    StoryResolutionStatus status,
  ) async {
    statusUpdates.add((id: id, status: status));
  }

  @override
  Future<PageResponse<StoryComment>> fetchComments(
    int postId, {
    int page = 0,
    int size = 20,
  }) async {
    return commentPages.isEmpty ? _commentPage([]) : commentPages.removeAt(0);
  }

  @override
  Future<void> createComment({
    required int postId,
    required int authorId,
    required String content,
    int? parentCommentId,
  }) async {
    createdComments.add((
      postId: postId,
      authorId: authorId,
      content: content,
    ));
  }

  @override
  Future<void> updateComment(int commentId, String content) async {
    updatedComments.add((id: commentId, content: content));
  }

  @override
  Future<void> deleteComment(int commentId) async {
    deletedCommentIds.add(commentId);
  }
}

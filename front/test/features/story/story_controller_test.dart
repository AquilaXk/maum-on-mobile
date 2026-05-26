import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/data/draft_recovery_repository.dart';
import 'package:maum_on_mobile_front/features/moderation/data/content_moderation_repository.dart';
import 'package:maum_on_mobile_front/features/moderation/domain/content_moderation_models.dart';
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

    test('blocks high-risk story text before creating a story', () async {
      final repository = _FakeStoryRepository();
      final moderationRepository = _FakeContentModerationRepository(
        result: const ContentModerationResult(
          allowed: false,
          riskLevel: ContentModerationRiskLevel.high,
          message: '위험도가 높은 표현이 포함되어 수정이 필요합니다.',
          categories: [ContentModerationCategory.profanity],
        ),
      );
      final controller = StoryController(
        storyRepository: repository,
        currentMemberId: 7,
        moderationRepository: moderationRepository,
      );

      controller.startCreate();
      controller.updateStoryTitle('새 글');
      controller.updateStoryContent('너 죽어 버려');
      await controller.submitStory();

      expect(repository.createdDrafts, isEmpty);
      expect(moderationRepository.requests.single.targetType,
          ContentModerationTarget.story);
      expect(moderationRepository.requests.single.text, contains('너 죽어 버려'));
      expect(controller.state.errorMessage, '위험도가 높은 표현이 포함되어 수정이 필요합니다.');
      expect(controller.state.storyContent, '너 죽어 버려');
      expect(controller.state.moderationFeedback?.status,
          ContentModerationFeedbackStatus.policyBlocked);
      expect(controller.state.moderationFeedback?.title, '스토리 표현을 수정해 주세요.');
      expect(
        controller.state.moderationFeedback?.guidanceItems,
        contains('비난, 욕설, 위협으로 읽힐 수 있는 표현을 부드럽게 바꿔 주세요.'),
      );
      expect(controller.state.isSubmitting, isFalse);
    });

    test('retries story submission after blocked text is edited', () async {
      final repository = _FakeStoryRepository(
        storyPages: [
          _storyPage([]),
          _storyPage([_summary(id: 13, title: '순화한 글')]),
        ],
        createdStoryId: 13,
        details: [_detail(id: 13, title: '순화한 글', authorId: 7)],
        commentPages: [_commentPage([])],
      );
      final moderationRepository = _FakeContentModerationRepository(
        results: [
          const ContentModerationResult(
            allowed: false,
            riskLevel: ContentModerationRiskLevel.high,
            message: '위험도가 높은 표현이 포함되어 수정이 필요합니다.',
            categories: [ContentModerationCategory.profanity],
          ),
          const ContentModerationResult(
            allowed: true,
            riskLevel: ContentModerationRiskLevel.low,
            message: '검수 결과 저장 가능한 내용입니다.',
            categories: [],
          ),
        ],
      );
      final controller = StoryController(
        storyRepository: repository,
        currentMemberId: 7,
        moderationRepository: moderationRepository,
      );

      controller.startCreate();
      controller.updateStoryTitle('순화한 글');
      controller.updateStoryContent('너 죽어 버려');
      await controller.submitStory();
      controller.updateStoryContent('속상했지만 다시 말해 볼게요.');
      await controller.submitStory();

      expect(repository.createdDrafts.single.content, '속상했지만 다시 말해 볼게요.');
      expect(moderationRepository.requests, hasLength(2));
      expect(controller.state.moderationFeedback, isNull);
      expect(controller.state.noticeMessage, '스토리가 등록되었습니다.');
    });

    test('blocks high-risk comments before creating a comment', () async {
      final repository = _FakeStoryRepository(
        details: [_detail(id: 8, title: '댓글 글', authorId: 7)],
        commentPages: [_commentPage([])],
      );
      final moderationRepository = _FakeContentModerationRepository(
        result: const ContentModerationResult(
          allowed: false,
          riskLevel: ContentModerationRiskLevel.high,
          message: '위험도가 높은 표현이 포함되어 수정이 필요합니다.',
          categories: [ContentModerationCategory.personalInfo],
        ),
      );
      final controller = StoryController(
        storyRepository: repository,
        currentMemberId: 7,
        moderationRepository: moderationRepository,
      );

      await controller.openStoryById(8);
      controller.updateCommentDraft('010-1234-5678');
      await controller.submitComment();

      expect(repository.createdComments, isEmpty);
      expect(moderationRepository.requests.single.targetType,
          ContentModerationTarget.comment);
      expect(
        moderationRepository.requests.single.text,
        contains('010-1234-5678'),
      );
      expect(controller.state.errorMessage, '위험도가 높은 표현이 포함되어 수정이 필요합니다.');
      expect(controller.state.commentDraft, '010-1234-5678');
      expect(controller.state.moderationFeedback?.targetType,
          ContentModerationTarget.comment);
      expect(
        controller.state.moderationFeedback?.guidanceItems,
        contains('전화번호, 이메일, 주소처럼 개인을 특정할 수 있는 표현을 지워 주세요.'),
      );
    });

    test('clears moderation notice when story submission fails', () async {
      final repository = _FakeStoryRepository(
        createError: const ApiClientException(
          kind: ApiErrorKind.server,
          message: '등록하지 못했습니다.',
        ),
      );
      final moderationRepository = _FakeContentModerationRepository(
        result: const ContentModerationResult(
          allowed: true,
          riskLevel: ContentModerationRiskLevel.high,
          message: '표현을 순화해 주세요.',
          categories: [ContentModerationCategory.profanity],
        ),
      );
      final controller = StoryController(
        storyRepository: repository,
        currentMemberId: 7,
        moderationRepository: moderationRepository,
      );

      controller.startCreate();
      controller.updateStoryTitle('새 글');
      controller.updateStoryContent('조금 거친 본문');
      await controller.submitStory();

      expect(controller.state.errorMessage, '등록하지 못했습니다.');
      expect(controller.state.noticeMessage, isNull);
    });

    test('restores story and comment drafts for the active member', () async {
      final draftRepository = StorageDraftRecoveryRepository(
        storage: MemoryDraftRecoveryStorage(),
      );
      final controller = StoryController(
        storyRepository: _FakeStoryRepository(
          details: [_detail(id: 42, title: '댓글 글', authorId: 7)],
          commentPages: [_commentPage([])],
        ),
        currentMemberId: 7,
        draftRepository: draftRepository,
      );

      controller.startCreate();
      controller.updateStoryTitle('작성 중 글');
      controller.updateStoryContent('이어 쓸 본문');
      controller.updateStoryCategory(StoryCategory.question);
      await Future<void>.delayed(Duration.zero);

      final restoredStoryController = StoryController(
        storyRepository: _FakeStoryRepository(),
        currentMemberId: 7,
        draftRepository: draftRepository,
      );
      await restoredStoryController.restoreDraft();

      expect(restoredStoryController.state.storyTitle, '작성 중 글');
      expect(restoredStoryController.state.storyContent, '이어 쓸 본문');
      expect(
          restoredStoryController.state.storyCategory, StoryCategory.question);

      await controller.openStoryById(42);
      controller.updateCommentDraft('작성 중 댓글');
      await Future<void>.delayed(Duration.zero);

      final restoredCommentController = StoryController(
        storyRepository: _FakeStoryRepository(
          details: [_detail(id: 42, title: '댓글 글', authorId: 7)],
          commentPages: [_commentPage([])],
        ),
        currentMemberId: 7,
        draftRepository: draftRepository,
      );
      await restoredCommentController.openStoryById(42);

      expect(restoredCommentController.state.commentDraft, '작성 중 댓글');
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
      final replyTarget = _comment(id: 51, authorId: 10, content: '삭제 전 댓글');
      controller.startReply(replyTarget);
      controller.updateReplyDraft(replyTarget.id, '@댓글이 답글 초안');
      await controller.deleteSelectedStory();

      expect(repository.statusUpdates.single.status,
          StoryResolutionStatus.resolved);
      expect(repository.updatedDrafts.single.draft.title, '수정됨');
      expect(repository.deletedStoryIds, [5]);
      expect(controller.state.mode, StoryViewMode.list);
      expect(controller.state.activeReplyCommentId, isNull);
      expect(controller.state.replyDrafts, isEmpty);
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

    test('creates replies with mention drafts while preserving other drafts',
        () async {
      final firstComment = _comment(
        id: 31,
        authorId: 10,
        content: '첫 댓글',
        nickname: '마음친구',
      );
      final secondComment = _comment(
        id: 32,
        authorId: 11,
        content: '두 번째 댓글',
        nickname: '다른친구',
      );
      final repository = _FakeStoryRepository(
        details: [_detail(id: 8, title: '댓글 글', authorId: 7)],
        commentPages: [
          _commentPage([firstComment, secondComment]),
          _commentPage([firstComment, secondComment]),
        ],
      );
      final controller = StoryController(
        storyRepository: repository,
        currentMemberId: 7,
      );

      await controller.openStoryById(8);
      controller.startReply(firstComment);
      controller.updateReplyDraft(firstComment.id, '@마음친구 고마워요');
      controller.startReply(secondComment);
      controller.updateReplyDraft(secondComment.id, '다른 답글 초안');
      controller.startReply(firstComment);
      await controller.submitReply(firstComment.id);

      expect(
          repository.createdComments.single.parentCommentId, firstComment.id);
      expect(repository.createdComments.single.content, '@마음친구 고마워요');
      expect(controller.state.replyDrafts[firstComment.id], isNull);
      expect(controller.state.replyDrafts[secondComment.id], '다른 답글 초안');
      expect(controller.state.activeReplyCommentId, isNull);
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
  String nickname = '댓글이',
  List<StoryComment> replies = const [],
}) {
  return StoryComment(
    id: id,
    content: content,
    authorId: authorId,
    authorNickname: nickname,
    postId: 8,
    createDate: '2026-05-24T10:00:00',
    modifyDate: '2026-05-24T10:00:00',
    replies: replies,
  );
}

class _FakeStoryRepository implements StoryRepository {
  _FakeStoryRepository({
    this.storyPages = const [],
    this.details = const [],
    this.commentPages = const [],
    this.createdStoryId = 1,
    this.fetchError,
    this.createError,
  });

  final List<PageResponse<StorySummary>> storyPages;
  final List<StoryDetail> details;
  final List<PageResponse<StoryComment>> commentPages;
  final int createdStoryId;
  final Object? fetchError;
  final Object? createError;
  final List<({String? title, StoryCategory category})> fetchStoryRequests = [];
  final List<StoryDraft> createdDrafts = [];
  final List<({int id, StoryDraft draft})> updatedDrafts = [];
  final List<int> deletedStoryIds = [];
  final List<({int id, StoryResolutionStatus status})> statusUpdates = [];
  final List<
      ({
        int postId,
        int authorId,
        String content,
        int? parentCommentId,
      })> createdComments = [];
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
    final error = createError;
    if (error != null) {
      throw error;
    }
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
      parentCommentId: parentCommentId,
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

class _FakeContentModerationRepository implements ContentModerationRepository {
  _FakeContentModerationRepository({
    ContentModerationResult? result,
    List<ContentModerationResult>? results,
  }) : results = results ?? [if (result != null) result];

  final List<ContentModerationResult> results;
  final List<ContentModerationRequest> requests = [];

  @override
  Future<ContentModerationResult> reviewText({
    required ContentModerationTarget targetType,
    required String text,
  }) async {
    requests.add(ContentModerationRequest(targetType: targetType, text: text));
    if (results.isEmpty) {
      throw StateError('No moderation result configured.');
    }
    return results.length == 1 ? results.single : results.removeAt(0);
  }
}

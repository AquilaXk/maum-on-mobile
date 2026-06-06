import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/story/application/story_controller.dart';
import 'package:maum_on_mobile_front/features/story/data/story_repository.dart';
import 'package:maum_on_mobile_front/features/story/domain/story_models.dart';
import 'package:maum_on_mobile_front/features/story/presentation/story_screen.dart';
import 'package:maum_on_mobile_front/shared/ui/app_design_system.dart';

void main() {
  testWidgets('keeps story discovery controls compact on a phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = StoryController(
      storyRepository: _FakeStoryRepository(
        storyPages: [
          _storyPage([_summary(id: 1, title: '잠이 오지 않는 밤')]),
        ],
      ),
      currentMemberId: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('story-discovery-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-search-field')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('story-category-question')), findsOneWidget);
    expect(find.text('1개의 스토리'), findsOneWidget);
  });

  testWidgets('stacks story editor actions on a narrow phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = StoryController(
      storyRepository: _FakeStoryRepository(storyPages: [_storyPage([])]),
      currentMemberId: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-create-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('story-submit-button')),
    );
    await tester.pumpAndSettle();

    final submitWidth =
        tester.getSize(find.byKey(const ValueKey('story-submit-button'))).width;
    final cancelWidth = tester
        .getSize(find.byKey(const ValueKey('story-editor-cancel-button')))
        .width;

    expect(submitWidth, greaterThanOrEqualTo(250));
    expect(cancelWidth, moreOrLessEquals(submitWidth, epsilon: 1));
  });

  testWidgets('renders story list and opens detail with comments',
      (tester) async {
    final repository = _FakeStoryRepository(
      storyPages: [
        _storyPage([
          _summary(
            id: 1,
            title: '잠이 오지 않는 밤',
            summary: '목록 요약 텍스트',
          ),
        ]),
      ],
      details: [
        _detail(id: 1, title: '잠이 오지 않는 밤', content: '긴 이야기를 나눕니다.'),
      ],
      commentPages: [
        _commentPage([_comment(id: 10, content: '천천히 쉬어도 괜찮아요.')]),
      ],
    );
    final controller = StoryController(
      storyRepository: repository,
      currentMemberId: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('story-search-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-flow-panel')), findsNothing);
    expect(find.text('스토리 탐색 흐름'), findsNothing);
    expect(find.text('대화 확인 흐름'), findsNothing);
    expect(find.text('스토리 작성 흐름'), findsNothing);
    expect(find.text('목록 요약 텍스트'), findsNothing);
    expect(find.byKey(const ValueKey('story-search-panel')), findsOneWidget);
    expect(find.text('잠이 오지 않는 밤'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('story-card-1')));
    await tester.tap(find.byKey(const ValueKey('story-card-1')));
    await tester.pumpAndSettle();

    expect(find.text('긴 이야기를 나눕니다.'), findsOneWidget);
    expect(find.text('천천히 쉬어도 괜찮아요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('story-flow-panel')), findsNothing);
  });

  testWidgets('submits a new story from the editor', (tester) async {
    final repository = _FakeStoryRepository(
      storyPages: [
        _storyPage([]),
        _storyPage([_summary(id: 3, title: '새 질문')]),
      ],
      createdStoryId: 3,
      details: [_detail(id: 3, title: '새 질문', content: '질문 본문')],
      commentPages: [_commentPage([])],
    );
    final controller = StoryController(
      storyRepository: repository,
      currentMemberId: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('story-create-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('story-title-field')),
      '새 질문',
    );
    await tester.enterText(
      find.byKey(const ValueKey('story-content-field')),
      '질문 본문',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('story-editor-category-question')),
    );
    await tester.tap(
      find.byKey(const ValueKey('story-editor-category-question')),
    );
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('story-submit-button')));
    await tester.tap(find.byKey(const ValueKey('story-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.createdDrafts.single.category, StoryCategory.question);
    expect(find.text('스토리가 등록되었습니다.'), findsOneWidget);
    expect(find.text('질문 본문'), findsOneWidget);
    final emptyState = tester.widget<AppStateView>(find.byType(AppStateView));
    expect(emptyState.title, '아직 댓글이 없습니다.');
    expect(emptyState.message, isNull);
  });

  testWidgets('loads the next story page from the list footer', (tester) async {
    final repository = _FakeStoryRepository(
      storyPages: [
        _storyPage(
          [_summary(id: 1, title: '첫 번째 이야기')],
          totalPages: 2,
          last: false,
        ),
        _storyPage(
          [_summary(id: 2, title: '두 번째 이야기')],
          page: 1,
          totalPages: 2,
        ),
      ],
    );
    final controller = StoryController(
      storyRepository: repository,
      currentMemberId: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('첫 번째 이야기'), findsOneWidget);
    expect(find.text('두 번째 이야기'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('story-load-more-button')),
    );
    await tester.tap(find.byKey(const ValueKey('story-load-more-button')));
    await tester.pumpAndSettle();

    expect(find.text('첫 번째 이야기'), findsOneWidget);
    expect(find.text('두 번째 이야기'), findsOneWidget);
    expect(find.byKey(const ValueKey('story-load-more-button')), findsNothing);
    expect(find.byType(AppNotice), findsNothing);
  });

  testWidgets('keeps story list empty state free of helper explanation copy',
      (tester) async {
    final controller = StoryController(
      storyRepository: _FakeStoryRepository(storyPages: [_storyPage([])]),
      currentMemberId: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('조건에 맞는 스토리가 없습니다.'), findsOneWidget);
    expect(find.text('검색어 또는 카테고리를 바꿔 다시 확인해 주세요.'), findsNothing);
  });

  testWidgets('keeps story detail fallback free of helper explanation copy',
      (tester) async {
    final controller = StoryController(
      storyRepository: _FakeStoryRepository(),
      currentMemberId: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(
          controller: controller,
          initialStoryId: 404,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('스토리를 선택해 주세요.'), findsOneWidget);
    expect(
      find.text('목록에서 읽을 스토리를 선택하면 상세 내용을 볼 수 있습니다.'),
      findsNothing,
    );
  });

  testWidgets('pull refresh reloads the visible story list', (tester) async {
    final repository = _FakeStoryRepository(
      storyPages: [
        _storyPage([_summary(id: 1, title: '오래된 이야기')]),
        _storyPage([_summary(id: 2, title: '새 이야기')]),
      ],
    );
    final controller = StoryController(
      storyRepository: repository,
      currentMemberId: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await indicator.onRefresh();
    await tester.pumpAndSettle();

    expect(find.text('오래된 이야기'), findsNothing);
    expect(find.text('새 이야기'), findsOneWidget);
  });

  testWidgets('shows author-only story and comment actions', (tester) async {
    StoryReportTarget? reportTarget;
    final comment = _comment(id: 40, content: '내 댓글', authorId: 7);
    final controller = StoryController(
      storyRepository: _FakeStoryRepository(
        details: [
          _detail(id: 4, title: '내 글', content: '본문', authorId: 7),
        ],
        commentPages: [
          _commentPage([comment]),
        ],
      ),
      currentMemberId: 7,
      onReportTargetSelected: (target) {
        reportTarget = target;
      },
    );
    await controller.openStoryById(4);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('story-edit-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-delete-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-status-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('story-comment-edit-button-40')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('story-comment-delete-button-40')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('story-report-button')));
    await tester.pump();

    expect(reportTarget?.targetType, 'POST');
    expect(reportTarget?.targetId, 4);
  });

  testWidgets('keeps report context visible near the story detail actions',
      (tester) async {
    StoryReportTarget? reportTarget;
    final controller = StoryController(
      storyRepository: _FakeStoryRepository(
        details: [
          _detail(id: 8, title: '신고할 글', content: '확인할 본문', authorId: 99),
        ],
        commentPages: [_commentPage([])],
      ),
      currentMemberId: 7,
      onReportTargetSelected: (target) {
        reportTarget = target;
      },
    );
    await controller.openStoryById(8);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('story-detail-action-panel')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('story-report-button')));
    await tester.pump();

    expect(reportTarget?.targetType, 'POST');
    expect(reportTarget?.targetId, 8);
    expect(find.byKey(const ValueKey('story-report-target-notice')),
        findsOneWidget);
    expect(find.text('확인할 본문'), findsOneWidget);
  });

  testWidgets('comment action controls keep mobile touch targets',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = StoryController(
      storyRepository: _FakeStoryRepository(
        details: [
          _detail(id: 11, title: '작은 화면', content: '본문', authorId: 99),
        ],
        commentPages: [
          _commentPage([
            _comment(id: 55, content: '조심스럽게 남긴 댓글입니다.'),
          ]),
        ],
      ),
      currentMemberId: 7,
    );
    await controller.openStoryById(11);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final actionRow = find.byKey(const ValueKey('story-comment-action-row-55'));
    expect(actionRow, findsOneWidget);

    final reportButton =
        find.byKey(const ValueKey('story-comment-report-button-55'));
    expect(tester.getSize(reportButton).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('submits a reply with mention prefill from the comment tile',
      (tester) async {
    final parentComment = _comment(
      id: 60,
      content: '저도 비슷했어요.',
      authorId: 10,
      nickname: '마음친구',
    );
    final repository = _FakeStoryRepository(
      details: [
        _detail(id: 12, title: '답글 글', content: '본문', authorId: 99),
      ],
      commentPages: [
        _commentPage([parentComment]),
        _commentPage([parentComment]),
      ],
    );
    final controller = StoryController(
      storyRepository: repository,
      currentMemberId: 7,
    );
    await controller.openStoryById(12);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final replyButton = find.byKey(
      const ValueKey('story-comment-reply-button-60'),
    );
    await tester.ensureVisible(replyButton);
    await tester.tap(replyButton);
    await tester.pump();

    expect(find.byKey(const ValueKey('story-reply-field-60')), findsOneWidget);
    expect(find.text('@마음친구 '), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('story-reply-field-60')),
      '@마음친구 고마워요',
    );
    await tester.pump();
    final submitReplyButton = find.byKey(
      const ValueKey('story-reply-submit-button-60'),
    );
    await tester.ensureVisible(submitReplyButton);
    await tester.tap(submitReplyButton);
    await tester.pumpAndSettle();

    expect(repository.createdComments.single.parentCommentId, 60);
    expect(repository.createdComments.single.content, '@마음친구 고마워요');
  });

  testWidgets('highlights mention tokens inside comments and replies',
      (tester) async {
    final reply = _comment(
      id: 71,
      content: '@마음친구 고마워요',
      authorId: 11,
      nickname: '답글이',
    );
    final controller = StoryController(
      storyRepository: _FakeStoryRepository(
        details: [
          _detail(id: 13, title: '멘션 글', content: '본문', authorId: 99),
        ],
        commentPages: [
          _commentPage([
            _comment(
              id: 70,
              content: '부모 댓글',
              replies: [reply],
            ),
          ]),
        ],
      ),
      currentMemberId: 7,
    );
    await controller.openStoryById(13);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('story-comment-content-71')),
        matching: find.byType(Text),
      ),
    );
    final rootSpan = text.textSpan! as TextSpan;
    final mentionSpan = rootSpan.children!.cast<TextSpan>().firstWhere(
          (span) => span.text == '@마음친구',
        );

    expect(mentionSpan.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('renders deleted comments without reply or author actions',
      (tester) async {
    final controller = StoryController(
      storyRepository: _FakeStoryRepository(
        details: [
          _detail(id: 14, title: '삭제 댓글 글', content: '본문', authorId: 99),
        ],
        commentPages: [
          _commentPage([
            _comment(
              id: 80,
              content: '삭제된 댓글입니다.',
              authorId: 7,
              deleted: true,
            ),
          ]),
        ],
      ),
      currentMemberId: 7,
    );
    await controller.openStoryById(14);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('삭제된 댓글입니다.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('story-comment-reply-button-80')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('story-comment-edit-button-80')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('story-comment-delete-button-80')),
      findsNothing,
    );
  });

  testWidgets('long story and comments stay scrollable on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longText = List.filled(40, '긴 문장').join(' ');
    final controller = StoryController(
      storyRepository: _FakeStoryRepository(
        details: [
          _detail(id: 9, title: '긴 글', content: longText, authorId: 99),
        ],
        commentPages: [
          _commentPage([
            _comment(id: 91, content: longText, authorId: 10),
          ]),
        ],
      ),
      currentMemberId: 7,
    );
    await controller.openStoryById(9);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('긴 글'), findsOneWidget);
    expect(find.byKey(const ValueKey('story-comment-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

PageResponse<StorySummary> _storyPage(
  List<StorySummary> items, {
  int page = 0,
  int totalPages = 1,
  bool last = true,
}) {
  return PageResponse(
    items: items,
    page: page,
    size: 20,
    totalElements: items.length,
    totalPages: totalPages,
    last: last,
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

StorySummary _summary({
  required int id,
  required String title,
  String summary = '요약',
}) {
  return StorySummary(
    id: id,
    title: title,
    summary: summary,
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
  required String content,
  int authorId = 7,
}) {
  return StoryDetail(
    id: id,
    title: title,
    content: content,
    summary: '요약',
    authorNickname: '마음이',
    category: StoryCategory.worry,
    resolutionStatus: StoryResolutionStatus.ongoing,
    viewCount: 1,
    createDate: '2026-05-24T08:00:00',
    modifyDate: '2026-05-24T08:00:00',
    authorId: authorId,
  );
}

StoryComment _comment({
  required int id,
  required String content,
  int authorId = 10,
  String nickname = '댓글이',
  bool deleted = false,
  List<StoryComment> replies = const [],
}) {
  return StoryComment(
    id: id,
    content: content,
    authorId: authorId,
    authorNickname: nickname,
    postId: 1,
    createDate: '2026-05-24T10:00:00',
    modifyDate: '2026-05-24T10:00:00',
    deleted: deleted,
    replies: replies,
  );
}

class _FakeStoryRepository implements StoryRepository {
  _FakeStoryRepository({
    this.storyPages = const [],
    this.details = const [],
    this.commentPages = const [],
    this.createdStoryId = 1,
  });

  final List<PageResponse<StorySummary>> storyPages;
  final List<StoryDetail> details;
  final List<PageResponse<StoryComment>> commentPages;
  final int createdStoryId;
  final List<StoryDraft> createdDrafts = [];
  final List<
      ({
        int postId,
        int authorId,
        String content,
        int? parentCommentId,
      })> createdComments = [];

  @override
  Future<PageResponse<StorySummary>> fetchStories({
    String? title,
    StoryCategory category = StoryCategory.all,
    int page = 0,
    int size = 20,
  }) async {
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
  Future<void> updateStory(int id, StoryDraft draft) async {}

  @override
  Future<void> deleteStory(int id) async {}

  @override
  Future<void> updateResolutionStatus(
    int id,
    StoryResolutionStatus status,
  ) async {}

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
  Future<void> updateComment(int commentId, String content) async {}

  @override
  Future<void> deleteComment(int commentId) async {}
}

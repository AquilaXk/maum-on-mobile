import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/story/application/story_controller.dart';
import 'package:maum_on_mobile_front/features/story/data/story_repository.dart';
import 'package:maum_on_mobile_front/features/story/domain/story_models.dart';
import 'package:maum_on_mobile_front/features/story/presentation/story_screen.dart';

void main() {
  testWidgets('renders story list and opens detail with comments',
      (tester) async {
    final repository = _FakeStoryRepository(
      storyPages: [
        _storyPage([_summary(id: 1, title: '잠이 오지 않는 밤')]),
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
    expect(find.text('잠이 오지 않는 밤'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('story-card-1')));
    await tester.pumpAndSettle();

    expect(find.text('긴 이야기를 나눕니다.'), findsOneWidget);
    expect(find.text('천천히 쉬어도 괜찮아요.'), findsOneWidget);
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
}) {
  return StoryComment(
    id: id,
    content: content,
    authorId: authorId,
    authorNickname: '댓글이',
    postId: 1,
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
  });

  final List<PageResponse<StorySummary>> storyPages;
  final List<StoryDetail> details;
  final List<PageResponse<StoryComment>> commentPages;
  final int createdStoryId;
  final List<StoryDraft> createdDrafts = [];

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
  }) async {}

  @override
  Future<void> updateComment(int commentId, String content) async {}

  @override
  Future<void> deleteComment(int commentId) async {}
}

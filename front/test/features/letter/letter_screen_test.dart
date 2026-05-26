import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/letter/application/letter_controller.dart';
import 'package:maum_on_mobile_front/features/letter/data/letter_repository.dart';
import 'package:maum_on_mobile_front/features/letter/domain/letter_models.dart';
import 'package:maum_on_mobile_front/features/letter/presentation/letter_screen.dart';

void main() {
  testWidgets('renders mailbox stats and opens a received letter',
      (tester) async {
    final repository = _FakeLetterRepository(
      statsQueue: [_stats()],
      receivedPages: [
        _page([_summary(id: 1, title: '도착한 편지')]),
      ],
      details: [_detail(id: 1, status: LetterStatus.sent)],
    );
    final controller = LetterController(letterRepository: repository);

    await tester.pumpWidget(
      MaterialApp(home: LetterScreen(controller: controller, onBack: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('받은 편지'), findsWidgets);
    expect(find.text('도착한 편지'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('letter-card-1')));
    await tester.pumpAndSettle();

    expect(find.text('본문'), findsOneWidget);
    expect(find.byKey(const ValueKey('letter-accept-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('letter-reject-button')), findsOneWidget);
  });

  testWidgets('renders mailbox state guidance and opens receive settings',
      (tester) async {
    var settingsOpenCount = 0;
    final repository = _FakeLetterRepository(
      statsQueue: [_stats()],
      receivedPages: [
        _page([
          _summary(id: 1, title: '기다리는 편지'),
          _summary(
            id: 2,
            title: '작성 중인 답장',
            status: LetterStatus.writing,
          ),
        ]),
      ],
    );
    final controller = LetterController(letterRepository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: LetterScreen(
          controller: controller,
          onBack: () {},
          onOpenRandomReceiveSettings: () => settingsOpenCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('랜덤 편지 수신'), findsOneWidget);
    expect(find.text('수신 설정'), findsOneWidget);
    expect(find.text('수신 대기'), findsOneWidget);
    expect(find.text('답장 작성 중'), findsOneWidget);
    expect(find.text('상대방의 답장을 기다리고 있습니다.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('letter-receive-settings')));
    await tester.pump();

    expect(settingsOpenCount, 1);
  });

  testWidgets('submits a new letter and moves to sent mailbox', (tester) async {
    final repository = _FakeLetterRepository(
      statsQueue: [_stats(), _stats()],
      receivedPages: [_page([])],
      sentPages: [
        _page([_summary(id: 9, title: '새 편지')]),
      ],
      createdId: 9,
    );
    final controller = LetterController(letterRepository: repository);

    await tester.pumpWidget(
      MaterialApp(home: LetterScreen(controller: controller, onBack: () {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('letter-compose-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('letter-title-field')),
      '새 편지',
    );
    await tester.enterText(
      find.byKey(const ValueKey('letter-content-field')),
      '마음 본문',
    );
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('letter-submit-button')));
    await tester.tap(find.byKey(const ValueKey('letter-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.createdDrafts.single.title, '새 편지');
    expect(find.text('편지가 전송되었습니다.'), findsOneWidget);
    expect(find.text('보낸 편지함에서 상태를 확인해 주세요.'), findsOneWidget);
    expect(find.text('보낸 편지함'), findsOneWidget);
  });

  testWidgets('asks before leaving a compose draft', (tester) async {
    final controller = LetterController(
      letterRepository: _FakeLetterRepository(
        statsQueue: [_stats()],
        receivedPages: [_page([])],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LetterScreen(controller: controller, onBack: () {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('letter-compose-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('letter-title-field')),
      '남길 편지',
    );
    await tester.tap(find.byKey(const ValueKey('letter-compose-cancel-button')));
    await tester.pumpAndSettle();

    expect(find.text('작성 중인 편지를 나갈까요?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('letter-compose-keep-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('letter-title-field')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('letter-compose-cancel-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('letter-compose-leave-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('letter-title-field')), findsNothing);
    expect(find.text('랜덤 편지 수신'), findsOneWidget);
  });

  testWidgets('shows receiver guidance when no recipient is available',
      (tester) async {
    final controller = LetterController(
      letterRepository: _FakeLetterRepository(
        statsQueue: [_stats()],
        receivedPages: [_page([])],
        createError: const ApiClientException(
          kind: ApiErrorKind.server,
          message: '수신 가능한 회원이 없습니다.',
          code: '404-2',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: LetterScreen(controller: controller, onBack: () {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('letter-compose-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('letter-title-field')),
      '새 편지',
    );
    await tester.enterText(
      find.byKey(const ValueKey('letter-content-field')),
      '마음 본문',
    );
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('letter-submit-button')));
    await tester.tap(find.byKey(const ValueKey('letter-submit-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('지금은 편지를 받을 수 있는 사용자가 없습니다. 잠시 뒤 다시 보내 주세요.'),
      findsOneWidget,
    );
  });

  testWidgets('opens compose mode immediately when requested', (tester) async {
    final controller = LetterController(
      letterRepository: _FakeLetterRepository(
        statsQueue: [_stats()],
        receivedPages: [_page([])],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LetterScreen(
          controller: controller,
          initiallyCompose: true,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('letter-title-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('letter-content-field')), findsOneWidget);
  });

  testWidgets('loads the next mailbox page from the list footer',
      (tester) async {
    final repository = _FakeLetterRepository(
      statsQueue: [_stats()],
      receivedPages: [
        _page(
          [_summary(id: 1, title: '첫 편지')],
          totalPages: 2,
          isLast: false,
        ),
        _page(
          [_summary(id: 2, title: '다음 편지')],
          currentPage: 1,
          totalPages: 2,
        ),
      ],
    );
    final controller = LetterController(letterRepository: repository);

    await tester.pumpWidget(
      MaterialApp(home: LetterScreen(controller: controller, onBack: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('첫 편지'), findsOneWidget);
    expect(find.text('다음 편지'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('letter-load-more-button')),
    );
    await tester.tap(find.byKey(const ValueKey('letter-load-more-button')));
    await tester.pumpAndSettle();

    expect(find.text('첫 편지'), findsOneWidget);
    expect(find.text('다음 편지'), findsOneWidget);
    expect(find.text('마지막 편지입니다.'), findsOneWidget);
  });

  testWidgets('accepts a letter, writes a reply, and selects report target',
      (tester) async {
    LetterReportTarget? reportTarget;
    final repository = _FakeLetterRepository(
      statsQueue: [_stats(), _stats(), _stats()],
      receivedPages: [
        _page([_summary(id: 3, title: '답장할 편지')]),
        _page([_summary(id: 3, title: '답장할 편지')]),
      ],
      details: [
        _detail(id: 3, status: LetterStatus.sent),
        _detail(id: 3, status: LetterStatus.accepted),
        _detail(id: 3, status: LetterStatus.replied, replyContent: '답장'),
      ],
    );
    final controller = LetterController(
      letterRepository: repository,
      onReportTargetSelected: (target) {
        reportTarget = target;
      },
    );

    await controller.load();
    await controller.openLetterById(3);
    await tester.pumpWidget(
      MaterialApp(home: LetterScreen(controller: controller, onBack: () {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('letter-accept-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('letter-reply-field')),
      '답장',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('letter-reply-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('letter-reply-submit-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('letter-report-button')));
    await tester.pump();

    expect(repository.acceptedIds, [3]);
    expect(repository.replies.single.replyContent, '답장');
    expect(reportTarget?.targetType, 'LETTER');
    expect(reportTarget?.targetId, 3);
  });

  testWidgets('long letter content stays scrollable on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longText = List.filled(50, '긴 문장').join(' ');
    final controller = LetterController(
      letterRepository: _FakeLetterRepository(
        details: [
          _detail(
            id: 7,
            status: LetterStatus.replied,
            content: longText,
            replyContent: longText,
          ),
        ],
      ),
    );
    await controller.openLetterById(7);

    await tester.pumpWidget(
      MaterialApp(home: LetterScreen(controller: controller, onBack: () {})),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(find.text('편지'), findsWidgets);
    expect(find.text('답장'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

LetterListPage _page(
  List<LetterSummary> items, {
  int currentPage = 0,
  int totalPages = 1,
  bool isLast = true,
}) {
  return LetterListPage(
    items: items,
    totalPages: totalPages,
    totalElements: items.length,
    currentPage: currentPage,
    isFirst: currentPage == 0,
    isLast: isLast,
  );
}

LetterStats _stats() {
  return LetterStats(
    receivedCount: 1,
    latestReceivedLetter: _summary(id: 1, title: '최근 받은 편지'),
    latestSentLetter: _summary(id: 2, title: '최근 보낸 편지'),
  );
}

LetterSummary _summary({
  required int id,
  required String title,
  LetterStatus status = LetterStatus.sent,
}) {
  return LetterSummary(
    id: id,
    title: title,
    content: '요약',
    createdDate: '2026-05-24T08:00:00',
    status: status,
  );
}

LetterDetail _detail({
  required int id,
  required LetterStatus status,
  String content = '본문',
  String? replyContent,
}) {
  return LetterDetail(
    id: id,
    title: '편지',
    content: content,
    status: status,
    replied: status == LetterStatus.replied,
    replyContent: replyContent,
    createdDate: '2026-05-24T08:00:00',
  );
}

class _FakeLetterRepository implements LetterRepository {
  _FakeLetterRepository({
    this.statsQueue = const [],
    this.receivedPages = const [],
    this.sentPages = const [],
    this.details = const [],
    this.createdId = 1,
    this.createError,
  });

  final List<LetterStats> statsQueue;
  final List<LetterListPage> receivedPages;
  final List<LetterListPage> sentPages;
  final List<LetterDetail> details;
  final int createdId;
  final Object? createError;
  final List<LetterDraft> createdDrafts = [];
  final List<int> acceptedIds = [];
  final List<({int id, String replyContent})> replies = [];

  @override
  Future<int> createLetter(LetterDraft draft) async {
    createdDrafts.add(draft);
    final error = createError;
    if (error != null) {
      throw error;
    }
    return createdId;
  }

  @override
  Future<LetterListPage> fetchReceivedLetters({
    int page = 0,
    int size = 20,
  }) async {
    return receivedPages.isEmpty ? _page([]) : receivedPages.removeAt(0);
  }

  @override
  Future<LetterListPage> fetchSentLetters({
    int page = 0,
    int size = 20,
  }) async {
    return sentPages.isEmpty ? _page([]) : sentPages.removeAt(0);
  }

  @override
  Future<LetterDetail> fetchLetter(int id) async {
    return details.removeAt(0);
  }

  @override
  Future<LetterStats> fetchStats() async {
    return statsQueue.isEmpty ? _stats() : statsQueue.removeAt(0);
  }

  @override
  Future<void> replyLetter(int id, String replyContent) async {
    replies.add((id: id, replyContent: replyContent));
  }

  @override
  Future<void> acceptLetter(int id) async {
    acceptedIds.add(id);
  }

  @override
  Future<void> rejectLetter(int id) async {}

  @override
  Future<void> markWriting(int id) async {}

  @override
  Future<LetterStatus> fetchLiveStatus(int id) async {
    return LetterStatus.writing;
  }
}

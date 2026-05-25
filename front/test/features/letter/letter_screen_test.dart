import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('보낸 편지함'), findsOneWidget);
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
  });

  final List<LetterStats> statsQueue;
  final List<LetterListPage> receivedPages;
  final List<LetterListPage> sentPages;
  final List<LetterDetail> details;
  final int createdId;
  final List<LetterDraft> createdDrafts = [];
  final List<int> acceptedIds = [];
  final List<({int id, String replyContent})> replies = [];

  @override
  Future<int> createLetter(LetterDraft draft) async {
    createdDrafts.add(draft);
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

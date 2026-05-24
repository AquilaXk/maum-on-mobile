import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/letter/application/letter_controller.dart';
import 'package:maum_on_mobile_front/features/letter/data/letter_repository.dart';
import 'package:maum_on_mobile_front/features/letter/domain/letter_models.dart';

void main() {
  group('LetterController', () {
    test('loads received mailbox and switches to sent mailbox', () async {
      final repository = _FakeLetterRepository(
        statsQueue: [_stats(), _stats()],
        receivedPages: [
          _page([_summary(id: 1, title: '받은 편지')])
        ],
        sentPages: [
          _page([_summary(id: 2, title: '보낸 편지')])
        ],
      );
      final controller = LetterController(letterRepository: repository);

      await controller.load();
      await controller.selectTab(LetterMailboxTab.sent);

      expect(controller.state.receivedLetters.single.title, '받은 편지');
      expect(controller.state.sentLetters.single.title, '보낸 편지');
      expect(controller.state.activeTab, LetterMailboxTab.sent);
    });

    test('creates a letter and returns to sent mailbox', () async {
      final repository = _FakeLetterRepository(
        statsQueue: [_stats()],
        sentPages: [
          _page([_summary(id: 10, title: '새 편지')])
        ],
        createdId: 10,
      );
      final controller = LetterController(letterRepository: repository);

      controller.startCompose();
      controller.updateTitle('새 편지');
      controller.updateContent('본문');
      await controller.submitLetter();

      expect(repository.createdDrafts.single.title, '새 편지');
      expect(controller.state.activeTab, LetterMailboxTab.sent);
      expect(controller.state.noticeMessage, '편지가 전송되었습니다.');
    });

    test('accepts, marks writing, replies, refreshes status, and reports',
        () async {
      LetterReportTarget? selectedTarget;
      final repository = _FakeLetterRepository(
        statsQueue: [_stats(), _stats(), _stats()],
        receivedPages: [
          _page([_summary(id: 3, title: '받은 편지')]),
          _page(
              [_summary(id: 3, title: '받은 편지', status: LetterStatus.replied)]),
        ],
        details: [
          _detail(id: 3, status: LetterStatus.sent),
          _detail(id: 3, status: LetterStatus.accepted),
          _detail(id: 3, status: LetterStatus.replied, replyContent: '답장'),
        ],
        liveStatuses: [LetterStatus.writing],
      );
      final controller = LetterController(
        letterRepository: repository,
        onReportTargetSelected: (target) {
          selectedTarget = target;
        },
      );

      await controller.load();
      await controller.openLetterById(3);
      await controller.acceptSelectedLetter();

      expect(controller.state.selectedLetter?.status, LetterStatus.accepted);
      expect(controller.state.noticeMessage, '편지를 수락했습니다.');

      controller.updateReplyContent('답장');
      await Future<void>.delayed(Duration.zero);
      await controller.submitReply();

      expect(controller.state.selectedLetter?.status, LetterStatus.replied);
      expect(controller.state.noticeMessage, '답장이 전송되었습니다.');

      await controller.refreshSelectedStatus();

      expect(controller.state.selectedLetter?.status, LetterStatus.writing);

      controller.selectReportTarget();

      expect(repository.acceptedIds, [3]);
      expect(repository.writingIds, [3]);
      expect(repository.replies.single.replyContent, '답장');
      expect(repository.liveStatusRequests, [3]);
      expect(selectedTarget?.targetType, 'LETTER');
      expect(selectedTarget?.targetId, 3);
    });

    test('rejects a received letter and refreshes mailbox', () async {
      final repository = _FakeLetterRepository(
        statsQueue: [_stats()],
        receivedPages: [_page([])],
        details: [_detail(id: 4, status: LetterStatus.sent)],
      );
      final controller = LetterController(letterRepository: repository);

      await controller.openLetterById(4);
      await controller.rejectSelectedLetter();

      expect(repository.rejectedIds, [4]);
      expect(controller.state.mode, LetterViewMode.mailbox);
      expect(controller.state.noticeMessage, '편지를 다른 수신자에게 전달했습니다.');
    });

    test('ignores stale mailbox loads after a newer tab load completes',
        () async {
      final repository = _DeferredLoadRepository();
      final controller = LetterController(letterRepository: repository);

      final firstLoad = controller.load();
      await Future<void>.delayed(Duration.zero);

      final secondLoad = controller.selectTab(LetterMailboxTab.sent);
      await Future<void>.delayed(Duration.zero);

      repository.statsCompleters[1].complete(_stats());
      await Future<void>.delayed(Duration.zero);
      repository.sentCompleters.single.complete(
        _page([_summary(id: 8, title: '최신 보낸 편지')]),
      );
      await secondLoad;

      repository.statsCompleters[0].complete(_stats());
      await Future<void>.delayed(Duration.zero);
      repository.receivedCompleters.single.complete(
        _page([_summary(id: 7, title: '늦은 받은 편지')]),
      );
      await firstLoad;

      expect(controller.state.activeTab, LetterMailboxTab.sent);
      expect(controller.state.sentLetters.single.title, '최신 보낸 편지');
      expect(controller.state.receivedLetters, isEmpty);
    });

    test('retries writing status after a failed writing notification',
        () async {
      final repository = _FakeLetterRepository(
        details: [_detail(id: 5, status: LetterStatus.accepted)],
        markWritingErrors: [Exception('writing failed')],
      );
      final controller = LetterController(letterRepository: repository);

      await controller.openLetterById(5);
      controller.updateReplyContent('첫 답장');
      await Future<void>.delayed(Duration.zero);
      controller.updateReplyContent('두 번째 답장');
      await Future<void>.delayed(Duration.zero);

      expect(repository.writingIds, [5, 5]);
      expect(controller.state.selectedLetter?.status, LetterStatus.writing);
    });

    test('invokes unauthorized callback on expired auth', () async {
      var unauthorizedCount = 0;
      final controller = LetterController(
        letterRepository: _FakeLetterRepository(
          fetchError: const ApiClientException(
            kind: ApiErrorKind.unauthorized,
            message: '다시 로그인해 주세요.',
          ),
        ),
        onUnauthorized: () => unauthorizedCount += 1,
      );

      await controller.load();

      expect(unauthorizedCount, 1);
      expect(controller.state.errorMessage, '다시 로그인해 주세요.');
    });
  });
}

LetterListPage _page(List<LetterSummary> items) {
  return LetterListPage(
    items: items,
    totalPages: 1,
    totalElements: items.length,
    currentPage: 0,
    isFirst: true,
    isLast: true,
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
  String? replyContent,
}) {
  return LetterDetail(
    id: id,
    title: '편지',
    content: '본문',
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
    this.liveStatuses = const [],
    this.markWritingErrors = const [],
    this.createdId = 1,
    this.fetchError,
  });

  final List<LetterStats> statsQueue;
  final List<LetterListPage> receivedPages;
  final List<LetterListPage> sentPages;
  final List<LetterDetail> details;
  final List<LetterStatus> liveStatuses;
  final List<Object> markWritingErrors;
  final int createdId;
  final Object? fetchError;
  final List<LetterDraft> createdDrafts = [];
  final List<int> acceptedIds = [];
  final List<int> rejectedIds = [];
  final List<int> writingIds = [];
  final List<int> liveStatusRequests = [];
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
    final error = fetchError;
    if (error != null) {
      throw error;
    }
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
  Future<void> rejectLetter(int id) async {
    rejectedIds.add(id);
  }

  @override
  Future<void> markWriting(int id) async {
    writingIds.add(id);
    if (markWritingErrors.isNotEmpty) {
      throw markWritingErrors.removeAt(0);
    }
  }

  @override
  Future<LetterStatus> fetchLiveStatus(int id) async {
    liveStatusRequests.add(id);
    return liveStatuses.isEmpty ? LetterStatus.sent : liveStatuses.removeAt(0);
  }
}

class _DeferredLoadRepository implements LetterRepository {
  final List<Completer<LetterStats>> statsCompleters = [];
  final List<Completer<LetterListPage>> receivedCompleters = [];
  final List<Completer<LetterListPage>> sentCompleters = [];

  @override
  Future<int> createLetter(LetterDraft draft) async => 1;

  @override
  Future<LetterDetail> fetchLetter(int id) async {
    return _detail(id: id, status: LetterStatus.sent);
  }

  @override
  Future<LetterListPage> fetchReceivedLetters({
    int page = 0,
    int size = 20,
  }) {
    final completer = Completer<LetterListPage>();
    receivedCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<LetterListPage> fetchSentLetters({
    int page = 0,
    int size = 20,
  }) {
    final completer = Completer<LetterListPage>();
    sentCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<LetterStats> fetchStats() {
    final completer = Completer<LetterStats>();
    statsCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<LetterStatus> fetchLiveStatus(int id) async => LetterStatus.sent;

  @override
  Future<void> acceptLetter(int id) async {}

  @override
  Future<void> markWriting(int id) async {}

  @override
  Future<void> rejectLetter(int id) async {}

  @override
  Future<void> replyLetter(int id, String replyContent) async {}
}

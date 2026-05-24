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
      controller.updateReplyContent('답장');
      await Future<void>.delayed(Duration.zero);
      await controller.submitReply();
      await controller.refreshSelectedStatus();
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
    this.createdId = 1,
    this.fetchError,
  });

  final List<LetterStats> statsQueue;
  final List<LetterListPage> receivedPages;
  final List<LetterListPage> sentPages;
  final List<LetterDetail> details;
  final List<LetterStatus> liveStatuses;
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
  }

  @override
  Future<LetterStatus> fetchLiveStatus(int id) async {
    liveStatusRequests.add(id);
    return liveStatuses.isEmpty ? LetterStatus.sent : liveStatuses.removeAt(0);
  }
}

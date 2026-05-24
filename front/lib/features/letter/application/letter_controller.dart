import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../moderation/data/content_moderation_repository.dart';
import '../../moderation/domain/content_moderation_models.dart';
import '../data/letter_repository.dart';
import '../domain/letter_models.dart';

enum LetterViewMode {
  mailbox,
  detail,
  compose,
}

class LetterState {
  const LetterState({
    this.mode = LetterViewMode.mailbox,
    this.activeTab = LetterMailboxTab.received,
    this.receivedLetters = const [],
    this.sentLetters = const [],
    this.stats,
    this.selectedLetter,
    this.title = '',
    this.content = '',
    this.replyContent = '',
    this.isLoading = false,
    this.isSubmitting = false,
    this.hasLoaded = false,
    this.errorMessage,
    this.noticeMessage,
    this.reportTarget,
  });

  final LetterViewMode mode;
  final LetterMailboxTab activeTab;
  final List<LetterSummary> receivedLetters;
  final List<LetterSummary> sentLetters;
  final LetterStats? stats;
  final LetterDetail? selectedLetter;
  final String title;
  final String content;
  final String replyContent;
  final bool isLoading;
  final bool isSubmitting;
  final bool hasLoaded;
  final String? errorMessage;
  final String? noticeMessage;
  final LetterReportTarget? reportTarget;

  bool get canSubmitLetter =>
      title.trim().isNotEmpty && content.trim().isNotEmpty && !isSubmitting;

  bool get canSubmitReply =>
      canReply && replyContent.trim().isNotEmpty && !isSubmitting;

  bool get canReply {
    final letter = selectedLetter;
    if (letter == null || activeTab != LetterMailboxTab.received) {
      return false;
    }

    return letter.status == LetterStatus.accepted ||
        letter.status == LetterStatus.writing;
  }

  bool get canAcceptOrReject {
    return activeTab == LetterMailboxTab.received &&
        selectedLetter?.status == LetterStatus.sent &&
        !isSubmitting;
  }

  List<LetterSummary> get visibleLetters {
    return activeTab == LetterMailboxTab.received
        ? receivedLetters
        : sentLetters;
  }

  bool get isEmpty =>
      hasLoaded && visibleLetters.isEmpty && !isLoading && errorMessage == null;

  LetterState copyWith({
    LetterViewMode? mode,
    LetterMailboxTab? activeTab,
    List<LetterSummary>? receivedLetters,
    List<LetterSummary>? sentLetters,
    LetterStats? stats,
    bool clearStats = false,
    LetterDetail? selectedLetter,
    bool clearSelectedLetter = false,
    String? title,
    String? content,
    String? replyContent,
    bool? isLoading,
    bool? isSubmitting,
    bool? hasLoaded,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? noticeMessage,
    bool clearNoticeMessage = false,
    LetterReportTarget? reportTarget,
    bool clearReportTarget = false,
  }) {
    return LetterState(
      mode: mode ?? this.mode,
      activeTab: activeTab ?? this.activeTab,
      receivedLetters: receivedLetters ?? this.receivedLetters,
      sentLetters: sentLetters ?? this.sentLetters,
      stats: clearStats ? null : stats ?? this.stats,
      selectedLetter:
          clearSelectedLetter ? null : selectedLetter ?? this.selectedLetter,
      title: title ?? this.title,
      content: content ?? this.content,
      replyContent: replyContent ?? this.replyContent,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      noticeMessage:
          clearNoticeMessage ? null : noticeMessage ?? this.noticeMessage,
      reportTarget:
          clearReportTarget ? null : reportTarget ?? this.reportTarget,
    );
  }
}

class LetterController extends ChangeNotifier {
  LetterController({
    required LetterRepository letterRepository,
    ContentModerationRepository? moderationRepository,
    VoidCallback? onUnauthorized,
    ValueChanged<LetterReportTarget>? onReportTargetSelected,
  })  : _letterRepository = letterRepository,
        _moderationRepository = moderationRepository,
        _onUnauthorized = onUnauthorized,
        _onReportTargetSelected = onReportTargetSelected;

  final LetterRepository _letterRepository;
  final ContentModerationRepository? _moderationRepository;
  final VoidCallback? _onUnauthorized;
  final ValueChanged<LetterReportTarget>? _onReportTargetSelected;

  LetterState _state = const LetterState();
  bool _isDisposed = false;
  int? _writingNotifiedLetterId;
  int _loadRequestId = 0;

  LetterState get state => _state;

  Future<void> load() async {
    final requestId = ++_loadRequestId;
    final tab = _state.activeTab;

    _setState(
      _state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final stats = await _letterRepository.fetchStats();
      final page = await _fetchPage(tab);
      if (requestId != _loadRequestId) {
        return;
      }

      _setMailboxPage(tab, page, stats);
    } on Object catch (error) {
      if (requestId != _loadRequestId) {
        return;
      }

      _handleError(error);
      _setState(_state.copyWith(isLoading: false, hasLoaded: true));
    }
  }

  Future<void> selectTab(LetterMailboxTab tab) async {
    _setState(
      _state.copyWith(
        activeTab: tab,
        mode: LetterViewMode.mailbox,
        clearSelectedLetter: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
    await load();
  }

  void startCompose() {
    _setState(
      _state.copyWith(
        mode: LetterViewMode.compose,
        title: '',
        content: '',
        clearSelectedLetter: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void updateTitle(String title) {
    _setState(_state.copyWith(title: title, clearErrorMessage: true));
  }

  void updateContent(String content) {
    _setState(_state.copyWith(content: content, clearErrorMessage: true));
  }

  Future<void> submitLetter() async {
    if (!_state.canSubmitLetter) {
      return;
    }

    final draft = LetterDraft(
      title: _state.title.trim(),
      content: _state.content.trim(),
    );
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      if (!await _ensureModerationAllowed('${draft.title}\n${draft.content}')) {
        return;
      }

      await _letterRepository.createLetter(draft);
      _setState(
        _state.copyWith(
          activeTab: LetterMailboxTab.sent,
          mode: LetterViewMode.mailbox,
          title: '',
          content: '',
          isSubmitting: false,
        ),
      );
      await load();
      _setState(_state.copyWith(noticeMessage: '편지가 전송되었습니다.'));
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  Future<void> openLetter(LetterSummary letter) {
    return openLetterById(letter.id);
  }

  Future<void> openLetterById(int id) async {
    _setState(
      _state.copyWith(
        mode: LetterViewMode.detail,
        isLoading: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
        clearReportTarget: true,
      ),
    );

    try {
      final detail = await _letterRepository.fetchLetter(id);
      _writingNotifiedLetterId = null;
      _setState(
        _state.copyWith(
          selectedLetter: detail,
          replyContent: detail.replyContent ?? '',
          isLoading: false,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isLoading: false));
    }
  }

  void backToMailbox() {
    _setState(
      _state.copyWith(
        mode: LetterViewMode.mailbox,
        clearSelectedLetter: true,
        replyContent: '',
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void cancelCompose() {
    _setState(
      _state.copyWith(
        mode: LetterViewMode.mailbox,
        title: '',
        content: '',
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> acceptSelectedLetter() async {
    final letter = _state.selectedLetter;
    if (letter == null || !_state.canAcceptOrReject) {
      return;
    }

    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      await _letterRepository.acceptLetter(letter.id);
      await _reloadSelectedLetter(letter.id);
      _setState(
        _state.copyWith(
          isSubmitting: false,
          noticeMessage: '편지를 수락했습니다.',
        ),
      );
      await _refreshMailboxSilently();
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  Future<void> rejectSelectedLetter() async {
    final letter = _state.selectedLetter;
    if (letter == null || !_state.canAcceptOrReject) {
      return;
    }

    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      await _letterRepository.rejectLetter(letter.id);
      _setState(
        _state.copyWith(
          mode: LetterViewMode.mailbox,
          clearSelectedLetter: true,
          replyContent: '',
          isSubmitting: false,
        ),
      );
      await load();
      _setState(_state.copyWith(noticeMessage: '편지를 다른 수신자에게 전달했습니다.'));
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  void updateReplyContent(String content) {
    _setState(_state.copyWith(replyContent: content, clearErrorMessage: true));

    final letter = _state.selectedLetter;
    if (letter == null ||
        content.trim().isEmpty ||
        _writingNotifiedLetterId == letter.id ||
        letter.status != LetterStatus.accepted) {
      return;
    }

    _writingNotifiedLetterId = letter.id;
    Future<void>.microtask(() async {
      try {
        await _letterRepository.markWriting(letter.id);
        final selected = _state.selectedLetter;
        if (selected?.id == letter.id) {
          _setState(
            _state.copyWith(
              selectedLetter: selected!.copyWith(status: LetterStatus.writing),
            ),
          );
        }
      } on Object catch (error) {
        if (_writingNotifiedLetterId == letter.id) {
          _writingNotifiedLetterId = null;
        }
        _handleError(error);
      }
    });
  }

  Future<void> submitReply() async {
    final letter = _state.selectedLetter;
    if (letter == null || !_state.canSubmitReply) {
      return;
    }

    _setState(_state.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      if (!await _ensureModerationAllowed(_state.replyContent.trim())) {
        return;
      }

      await _letterRepository.replyLetter(
          letter.id, _state.replyContent.trim());
      await _reloadSelectedLetter(letter.id);
      _setState(
        _state.copyWith(
          isSubmitting: false,
          noticeMessage: '답장이 전송되었습니다.',
        ),
      );
      await _refreshMailboxSilently();
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  Future<void> refreshSelectedStatus() async {
    final letter = _state.selectedLetter;
    if (letter == null) {
      return;
    }

    try {
      final status = await _letterRepository.fetchLiveStatus(letter.id);
      _setState(
        _state.copyWith(
          selectedLetter: letter.copyWith(status: status),
          noticeMessage: '편지 상태를 확인했습니다.',
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
    }
  }

  void selectReportTarget() {
    final letter = _state.selectedLetter;
    if (letter == null) {
      return;
    }

    final target = LetterReportTarget(
      targetType: 'LETTER',
      targetId: letter.id,
      label: letter.title,
    );
    _onReportTargetSelected?.call(target);
    _setState(
      _state.copyWith(
        reportTarget: target,
        noticeMessage: '신고 대상이 선택되었습니다.',
      ),
    );
  }

  Future<LetterListPage> _fetchPage(LetterMailboxTab tab) {
    return tab == LetterMailboxTab.received
        ? _letterRepository.fetchReceivedLetters()
        : _letterRepository.fetchSentLetters();
  }

  void _setMailboxPage(
    LetterMailboxTab tab,
    LetterListPage page,
    LetterStats stats,
  ) {
    _setState(
      _state.copyWith(
        receivedLetters: tab == LetterMailboxTab.received ? page.items : null,
        sentLetters: tab == LetterMailboxTab.sent ? page.items : null,
        stats: stats,
        isLoading: false,
        hasLoaded: true,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _reloadSelectedLetter(int id) async {
    final detail = await _letterRepository.fetchLetter(id);
    _setState(
      _state.copyWith(
        selectedLetter: detail,
        replyContent: detail.replyContent ?? _state.replyContent,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _refreshMailboxSilently() async {
    final stats = await _letterRepository.fetchStats();
    final page = await _fetchPage(_state.activeTab);
    _setMailboxPage(_state.activeTab, page, stats);
  }

  Future<bool> _ensureModerationAllowed(String text) async {
    final repository = _moderationRepository;
    if (repository == null) {
      return true;
    }

    final result = await repository.reviewText(
      targetType: ContentModerationTarget.letter,
      text: text,
    );
    if (result.allowed) {
      if (result.riskLevel != ContentModerationRiskLevel.low) {
        _setState(_state.copyWith(noticeMessage: result.message));
      }
      return true;
    }

    _setState(
      _state.copyWith(
        isSubmitting: false,
        errorMessage: result.message,
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
      _setState(_state.copyWith(errorMessage: error.message));
      return;
    }

    _setState(_state.copyWith(errorMessage: '요청을 처리하지 못했습니다.'));
  }

  void _setState(LetterState nextState) {
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

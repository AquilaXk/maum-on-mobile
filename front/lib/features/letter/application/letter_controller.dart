import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../draft_recovery/data/draft_recovery_repository.dart';
import '../../draft_recovery/domain/draft_recovery_models.dart';
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
    this.isLoadingMore = false,
    this.receivedPage = 0,
    this.receivedLastPage = true,
    this.sentPage = 0,
    this.sentLastPage = true,
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
  final bool isLoadingMore;
  final int receivedPage;
  final bool receivedLastPage;
  final int sentPage;
  final bool sentLastPage;
  final bool isSubmitting;
  final bool hasLoaded;
  final String? errorMessage;
  final String? noticeMessage;
  final LetterReportTarget? reportTarget;

  bool get hasComposeDraft =>
      title.trim().isNotEmpty || content.trim().isNotEmpty;

  bool get isComposeOverLimit {
    return title.trim().length > LetterLimits.titleMaxLength ||
        content.trim().length > LetterLimits.contentMaxLength;
  }

  bool get isReplyOverLimit {
    return replyContent.trim().length > LetterLimits.replyMaxLength;
  }

  bool get canSubmitLetter =>
      title.trim().isNotEmpty &&
      content.trim().isNotEmpty &&
      !isComposeOverLimit &&
      !isSubmitting;

  bool get canSubmitReply =>
      canReply &&
      replyContent.trim().isNotEmpty &&
      !isReplyOverLimit &&
      !isSubmitting;

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

  int get visiblePage {
    return activeTab == LetterMailboxTab.received ? receivedPage : sentPage;
  }

  bool get isVisibleLastPage {
    return activeTab == LetterMailboxTab.received
        ? receivedLastPage
        : sentLastPage;
  }

  bool get canLoadMoreLetters {
    return hasLoaded &&
        visibleLetters.isNotEmpty &&
        !isLoading &&
        !isLoadingMore &&
        !isVisibleLastPage &&
        errorMessage == null;
  }

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
    bool? isLoadingMore,
    int? receivedPage,
    bool? receivedLastPage,
    int? sentPage,
    bool? sentLastPage,
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
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      receivedPage: receivedPage ?? this.receivedPage,
      receivedLastPage: receivedLastPage ?? this.receivedLastPage,
      sentPage: sentPage ?? this.sentPage,
      sentLastPage: sentLastPage ?? this.sentLastPage,
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
    int currentMemberId = 0,
    DraftRecoveryRepository? draftRepository,
    VoidCallback? onUnauthorized,
    ValueChanged<LetterReportTarget>? onReportTargetSelected,
  })  : _letterRepository = letterRepository,
        _moderationRepository = moderationRepository,
        _currentMemberId = currentMemberId,
        _draftRepository = draftRepository,
        _onUnauthorized = onUnauthorized,
        _onReportTargetSelected = onReportTargetSelected;

  final LetterRepository _letterRepository;
  final ContentModerationRepository? _moderationRepository;
  final int _currentMemberId;
  final DraftRecoveryRepository? _draftRepository;
  final VoidCallback? _onUnauthorized;
  final ValueChanged<LetterReportTarget>? _onReportTargetSelected;

  LetterState _state = const LetterState();
  bool _isDisposed = false;
  int? _writingNotifiedLetterId;
  int _loadRequestId = 0;

  LetterState get state => _state;

  DraftKey get _composeDraftKey => DraftKey(
        memberId: _currentMemberId,
        surface: DraftSurface.letter,
      );

  DraftKey _replyDraftKey(int letterId) => DraftKey(
        memberId: _currentMemberId,
        surface: DraftSurface.letterReply,
        scopeId: letterId.toString(),
      );

  Future<void> restoreDraft() async {
    final entry = await _draftRepository?.read(_composeDraftKey);
    if (entry == null || entry.fields.isEmpty) {
      return;
    }
    // 알림 딥링크처럼 이미 상세 이동이 시작된 경우 임시저장이 화면을 덮어쓰지 않게 한다.
    if (_state.mode != LetterViewMode.mailbox ||
        _state.isLoading ||
        _state.selectedLetter != null) {
      return;
    }

    _setState(
      _state.copyWith(
        mode: LetterViewMode.compose,
        title: entry.fields['title'] ?? '',
        content: entry.fields['content'] ?? '',
        noticeMessage: '임시 저장된 편지를 복원했습니다.',
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> load() async {
    final requestId = ++_loadRequestId;
    final tab = _state.activeTab;

    _setState(
      _state.copyWith(
        isLoading: true,
        isLoadingMore: false,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final stats = await _letterRepository.fetchStats();
      final page = await _fetchPage(tab, page: 0);
      if (requestId != _loadRequestId) {
        return;
      }

      _setMailboxPage(tab, page, stats: stats);
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

  Future<void> loadMore() async {
    if (!_state.canLoadMoreLetters) {
      return;
    }

    final requestId = ++_loadRequestId;
    final tab = _state.activeTab;
    final nextPage = _state.visiblePage + 1;

    _setState(
      _state.copyWith(
        isLoadingMore: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final page = await _fetchPage(tab, page: nextPage);
      if (requestId != _loadRequestId || tab != _state.activeTab) {
        return;
      }

      _setMailboxPage(tab, page, append: true);
    } on Object catch (error) {
      if (requestId != _loadRequestId) {
        return;
      }

      _handleError(error);
      _setState(_state.copyWith(isLoadingMore: false, hasLoaded: true));
    }
  }

  void startCompose() {
    final hasDraft =
        _state.title.trim().isNotEmpty || _state.content.trim().isNotEmpty;
    _setState(
      _state.copyWith(
        mode: LetterViewMode.compose,
        title: hasDraft ? _state.title : '',
        content: hasDraft ? _state.content : '',
        clearSelectedLetter: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void updateTitle(String title) {
    _setState(_state.copyWith(title: title, clearErrorMessage: true));
    _saveComposeDraft();
  }

  void updateContent(String content) {
    _setState(_state.copyWith(content: content, clearErrorMessage: true));
    _saveComposeDraft();
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
      await _draftRepository?.delete(_composeDraftKey);
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
      await _markComposeDraftFailed(error);
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
      // 상세는 먼저 보여주고, 답장 임시저장은 늦게 도착해도 같은 편지에만 반영한다.
      final replyDraft = await _draftRepository?.read(_replyDraftKey(id));
      if (_state.mode != LetterViewMode.detail ||
          _state.selectedLetter?.id != id) {
        return;
      }
      _setState(
        _state.copyWith(
          replyContent: replyDraft?.fields['content'] ??
              detail.replyContent ??
              '',
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
    unawaited(_draftRepository?.delete(_composeDraftKey));
  }

  void resetCompose() {
    _setState(
      _state.copyWith(
        title: '',
        content: '',
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
    unawaited(_draftRepository?.delete(_composeDraftKey));
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
    _saveReplyDraft();

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
      await _draftRepository?.delete(_replyDraftKey(letter.id));
      await _reloadSelectedLetter(letter.id);
      _setState(
        _state.copyWith(
          isSubmitting: false,
          noticeMessage: '답장이 전송되었습니다.',
        ),
      );
      await _refreshMailboxSilently();
    } on Object catch (error) {
      await _markReplyDraftFailed(error);
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

  Future<LetterListPage> _fetchPage(LetterMailboxTab tab, {required int page}) {
    return tab == LetterMailboxTab.received
        ? _letterRepository.fetchReceivedLetters(page: page)
        : _letterRepository.fetchSentLetters(page: page);
  }

  void _setMailboxPage(
    LetterMailboxTab tab,
    LetterListPage page, {
    LetterStats? stats,
    bool append = false,
  }) {
    final nextReceivedLetters = tab == LetterMailboxTab.received
        ? append
            ? _mergeLetterPages(_state.receivedLetters, page.items)
            : page.items
        : null;
    final nextSentLetters = tab == LetterMailboxTab.sent
        ? append
            ? _mergeLetterPages(_state.sentLetters, page.items)
            : page.items
        : null;

    _setState(
      _state.copyWith(
        receivedLetters: nextReceivedLetters,
        sentLetters: nextSentLetters,
        receivedPage:
            tab == LetterMailboxTab.received ? page.currentPage : null,
        receivedLastPage: tab == LetterMailboxTab.received ? page.isLast : null,
        sentPage: tab == LetterMailboxTab.sent ? page.currentPage : null,
        sentLastPage: tab == LetterMailboxTab.sent ? page.isLast : null,
        stats: stats,
        isLoading: false,
        isLoadingMore: false,
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

  void _saveComposeDraft() {
    final repository = _draftRepository;
    if (repository == null) {
      return;
    }
    unawaited(
      repository.saveEditing(
        _composeDraftKey,
        fields: {
          'title': _state.title,
          'content': _state.content,
        },
      ),
    );
  }

  void _saveReplyDraft() {
    final repository = _draftRepository;
    final letter = _state.selectedLetter;
    if (repository == null || letter == null) {
      return;
    }
    unawaited(
      repository.saveEditing(
        _replyDraftKey(letter.id),
        fields: {'content': _state.replyContent},
      ),
    );
  }

  Future<void> _markComposeDraftFailed(Object error) async {
    final repository = _draftRepository;
    if (repository == null) {
      return;
    }
    await repository.markFailed(
      _composeDraftKey,
      fields: {
        'title': _state.title,
        'content': _state.content,
      },
      failureMessage: _messageFromError(error),
    );
  }

  Future<void> _markReplyDraftFailed(Object error) async {
    final repository = _draftRepository;
    final letter = _state.selectedLetter;
    if (repository == null || letter == null) {
      return;
    }
    await repository.markFailed(
      _replyDraftKey(letter.id),
      fields: {'content': _state.replyContent},
      failureMessage: _messageFromError(error),
    );
  }

  Future<void> _refreshMailboxSilently() async {
    final stats = await _letterRepository.fetchStats();
    final page = await _fetchPage(_state.activeTab, page: 0);
    _setMailboxPage(_state.activeTab, page, stats: stats);
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
      _setState(
        _state.copyWith(
          errorMessage: _messageFromError(error),
          clearNoticeMessage: true,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        errorMessage: '요청을 처리하지 못했습니다.',
        clearNoticeMessage: true,
      ),
    );
  }

  String _messageFromError(Object error) {
    if (error is ApiClientException) {
      if (error.code == '404-2') {
        return '지금은 편지를 받을 수 있는 사용자가 없습니다. 잠시 뒤 다시 보내 주세요.';
      }
      return error.message;
    }
    return '요청을 처리하지 못했습니다.';
  }

  void _setState(LetterState nextState) {
    if (_isDisposed) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  List<LetterSummary> _mergeLetterPages(
    List<LetterSummary> current,
    List<LetterSummary> next,
  ) {
    final seenIds = current.map((letter) => letter.id).toSet();
    return [
      ...current,
      for (final letter in next)
        if (seenIds.add(letter.id)) letter,
    ];
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

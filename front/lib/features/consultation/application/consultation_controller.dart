import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../../draft_recovery/data/draft_recovery_repository.dart';
import '../../draft_recovery/domain/draft_recovery_models.dart';
import '../data/consultation_repository.dart';
import '../domain/consultation_models.dart';

const List<Duration> _defaultReconnectBackoffDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];

class ConsultationFailedMessage {
  const ConsultationFailedMessage({
    required this.content,
    required this.userMessageId,
    required this.errorMessage,
    this.systemMessageId,
  });

  final String content;
  final String userMessageId;
  final String errorMessage;
  final String? systemMessageId;
}

class ConsultationState {
  const ConsultationState({
    required this.messages,
    this.connectionState = ConsultationConnectionState.idle,
    this.draft = '',
    this.isSending = false,
    this.isStreaming = false,
    this.errorMessage,
    this.safetyNotice,
    this.failedMessage,
  });

  final List<ConsultationMessage> messages;
  final ConsultationConnectionState connectionState;
  final String draft;
  final bool isSending;
  final bool isStreaming;
  final String? errorMessage;
  final ConsultationSafetyResult? safetyNotice;
  final ConsultationFailedMessage? failedMessage;

  bool get inputBlockedBySafety => safetyNotice?.blocksConversation ?? false;

  bool get canSubmit {
    return connectionState == ConsultationConnectionState.connected &&
        draft.trim().isNotEmpty &&
        draft.trim().length <= ConsultationController.maxMessageLength &&
        !inputBlockedBySafety &&
        !isSending &&
        !isStreaming;
  }

  ConsultationState copyWith({
    List<ConsultationMessage>? messages,
    ConsultationConnectionState? connectionState,
    String? draft,
    bool? isSending,
    bool? isStreaming,
    String? errorMessage,
    bool clearErrorMessage = false,
    ConsultationSafetyResult? safetyNotice,
    bool clearSafetyNotice = false,
    ConsultationFailedMessage? failedMessage,
    bool clearFailedMessage = false,
  }) {
    return ConsultationState(
      messages: messages ?? this.messages,
      connectionState: connectionState ?? this.connectionState,
      draft: draft ?? this.draft,
      isSending: isSending ?? this.isSending,
      isStreaming: isStreaming ?? this.isStreaming,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      safetyNotice:
          clearSafetyNotice ? null : safetyNotice ?? this.safetyNotice,
      failedMessage:
          clearFailedMessage ? null : failedMessage ?? this.failedMessage,
    );
  }
}

class ConsultationController extends ChangeNotifier {
  ConsultationController({
    required ConsultationRepository repository,
    int currentMemberId = 0,
    DraftRecoveryRepository? draftRepository,
    VoidCallback? onUnauthorized,
    List<Duration> reconnectBackoffDelays = _defaultReconnectBackoffDelays,
  })  : _repository = repository,
        _currentMemberId = currentMemberId,
        _draftRepository = draftRepository,
        _onUnauthorized = onUnauthorized,
        _reconnectBackoffDelays = reconnectBackoffDelays,
        _state = ConsultationState(
          messages: [
            ConsultationMessage(
              id: 'system-0',
              role: ConsultationMessageRole.system,
              content: '상담을 시작하려면 메시지를 입력해 주세요.',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ],
        );

  static const int maxMessageLength = 600;

  final ConsultationRepository _repository;
  final int _currentMemberId;
  final DraftRecoveryRepository? _draftRepository;
  final VoidCallback? _onUnauthorized;
  final List<Duration> _reconnectBackoffDelays;

  ConsultationState _state;
  StreamSubscription<ConsultationStreamEvent>? _streamSubscription;
  Timer? _reconnectTimer;
  bool _shouldRestoreConnection = false;
  bool _hasLoadedRecentMessages = false;
  bool _isDisposed = false;
  int _reconnectAttempt = 0;
  int _messageSequence = 0;
  String? _activeAssistantMessageId;

  ConsultationState get state => _state;

  DraftKey get _draftKey => DraftKey(
        memberId: _currentMemberId,
        surface: DraftSurface.consultation,
      );

  Future<void> restoreDraft() async {
    final entry = await _draftRepository?.read(_draftKey);
    final draft = entry?.fields['content'];
    if (draft == null || draft.isEmpty) {
      return;
    }

    _setState(
      _state.copyWith(
        draft: draft,
        clearErrorMessage: true,
        clearSafetyNotice: true,
      ),
    );
  }

  Future<void> connect({bool reloadRecentMessages = false}) async {
    if (_streamSubscription != null) {
      return;
    }

    _shouldRestoreConnection = true;
    if (reloadRecentMessages || !_hasLoadedRecentMessages) {
      await _loadRecentMessages(force: reloadRecentMessages);
    }
    _setState(
      _state.copyWith(
        connectionState: ConsultationConnectionState.connecting,
        clearErrorMessage: true,
      ),
    );

    try {
      _streamSubscription = _repository.connect().listen(
            _handleStreamEvent,
            onError: _handleStreamError,
            onDone: _handleStreamDone,
          );
    } on Object catch (error) {
      _handleStreamError(error);
    }
  }

  Future<void> reconnect() async {
    _shouldRestoreConnection = true;
    _reconnectAttempt = 0;
    _cancelPendingReconnect();
    await _cancelStream();
    await connect(reloadRecentMessages: true);
  }

  void close() {
    _shouldRestoreConnection = false;
    _cancelPendingReconnect();
    _cancelStreamForLifecycle(
      connectionState: ConsultationConnectionState.idle,
      clearErrorMessage: true,
    );
  }

  void handleLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      if (_shouldRestoreConnection && _streamSubscription == null) {
        unawaited(connect());
      }
      return;
    }

    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.detached) {
      if (_streamSubscription != null) {
        _shouldRestoreConnection = true;
        _cancelPendingReconnect();
        _cancelStreamForLifecycle(
          connectionState: ConsultationConnectionState.idle,
          clearErrorMessage: true,
        );
      }
    }
  }

  void updateDraft(String draft) {
    if (_state.inputBlockedBySafety) {
      return;
    }

    _setState(
      _state.copyWith(
        draft: draft,
        clearErrorMessage: true,
        clearSafetyNotice: true,
      ),
    );
    _saveDraft();
  }

  Future<void> submitMessage() async {
    if (_state.inputBlockedBySafety) {
      return;
    }

    final content = _state.draft.trim();
    if (content.isEmpty || _state.isSending || _state.isStreaming) {
      return;
    }

    if (content.length > maxMessageLength) {
      _appendSystemMessage('메시지는 최대 $maxMessageLength자까지 입력할 수 있습니다.');
      return;
    }

    if (_state.connectionState != ConsultationConnectionState.connected) {
      _appendSystemMessage('상담 연결 후 메시지를 보낼 수 있습니다.');
      return;
    }

    final userMessage = _createMessage(ConsultationMessageRole.user, content);
    final assistantMessage =
        _createMessage(ConsultationMessageRole.assistant, '');
    _activeAssistantMessageId = assistantMessage.id;
    _setState(
      _state.copyWith(
        messages: [..._state.messages, userMessage, assistantMessage],
        draft: '',
        isSending: true,
        isStreaming: true,
        clearErrorMessage: true,
        clearFailedMessage: true,
      ),
    );

    await _sendMessageContent(
      content,
      userMessageId: userMessage.id,
      assistantMessageId: assistantMessage.id,
    );
  }

  Future<void> retryFailedMessage() async {
    final failedMessage = _state.failedMessage;
    if (failedMessage == null ||
        _state.inputBlockedBySafety ||
        _state.isSending ||
        _state.isStreaming) {
      return;
    }

    if (_state.connectionState != ConsultationConnectionState.connected) {
      _setState(
        _state.copyWith(errorMessage: '상담 연결 후 다시 시도해 주세요.'),
      );
      return;
    }

    final assistantMessage =
        _createMessage(ConsultationMessageRole.assistant, '');
    _activeAssistantMessageId = assistantMessage.id;
    _setState(
      _state.copyWith(
        messages: [
          for (final message in _state.messages)
            if (message.id != failedMessage.systemMessageId) message,
          assistantMessage,
        ],
        isSending: true,
        isStreaming: true,
        clearErrorMessage: true,
        clearFailedMessage: true,
      ),
    );

    await _sendMessageContent(
      failedMessage.content,
      userMessageId: failedMessage.userMessageId,
      assistantMessageId: assistantMessage.id,
    );
  }

  Future<void> deleteFailedMessage() async {
    final failedMessage = _state.failedMessage;
    if (failedMessage == null) {
      return;
    }

    await _draftRepository?.delete(_draftKey);
    final messages = [
      for (final message in _state.messages)
        if (message.id != failedMessage.userMessageId &&
            message.id != failedMessage.systemMessageId)
          message,
    ];
    _setState(
      _state.copyWith(
        messages: messages.isEmpty ? _initialMessages() : messages,
        clearErrorMessage: true,
        clearFailedMessage: true,
      ),
    );
  }

  Future<void> _sendMessageContent(
    String content, {
    required String userMessageId,
    required String assistantMessageId,
  }) async {
    try {
      final result = await _repository.sendMessage(content);
      final safety = result.safety;
      if (safety != null && safety.blocksConversation) {
        await _draftRepository?.delete(_draftKey);
        _replaceActiveAssistantWithSystem(safety.message);
        _activeAssistantMessageId = null;
        _setState(
          _state.copyWith(
            isSending: false,
            isStreaming: false,
            safetyNotice: safety,
            clearErrorMessage: true,
          ),
        );
        return;
      }

      await _draftRepository?.delete(_draftKey);
      _setState(
        _state.copyWith(
          isSending: false,
          clearSafetyNotice: true,
          clearFailedMessage: true,
        ),
      );
    } on Object catch (error) {
      final errorMessage = _messageFromError(error);
      await _markDraftFailed(content, error);
      _replaceActiveAssistantWithSystem('전송 실패: $errorMessage');
      _activeAssistantMessageId = null;
      _setState(
        _state.copyWith(
          isSending: false,
          isStreaming: false,
          errorMessage: errorMessage,
          failedMessage: ConsultationFailedMessage(
            content: content,
            userMessageId: userMessageId,
            systemMessageId: assistantMessageId,
            errorMessage: errorMessage,
          ),
        ),
      );
    }
  }

  Future<void> deleteSensitiveMessages() async {
    try {
      await _repository.deleteSensitiveMessages();
      await _draftRepository?.delete(_draftKey);
      final messages = await _repository.loadRecentMessages();
      _setState(
        _state.copyWith(
          messages: messages.isEmpty ? _initialMessages() : messages,
          clearErrorMessage: true,
          clearSafetyNotice: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  void _saveDraft() {
    final repository = _draftRepository;
    if (repository == null) {
      return;
    }
    unawaited(
      repository.saveEditing(
        _draftKey,
        fields: {'content': _state.draft},
      ),
    );
  }

  Future<void> _markDraftFailed(String content, Object error) async {
    final repository = _draftRepository;
    if (repository == null) {
      return;
    }
    await repository.markFailed(
      _draftKey,
      fields: {'content': content},
      failureMessage: _messageFromError(error),
    );
  }

  void _handleStreamEvent(ConsultationStreamEvent event) {
    switch (event.type) {
      case ConsultationStreamEventType.connect:
        _reconnectAttempt = 0;
        _setState(
          _state.copyWith(
            connectionState: ConsultationConnectionState.connected,
            clearErrorMessage: true,
          ),
        );
        return;
      case ConsultationStreamEventType.heartbeat:
        _setState(
          _state.copyWith(
            connectionState: ConsultationConnectionState.connected,
            clearErrorMessage: true,
          ),
        );
        return;
      case ConsultationStreamEventType.chat:
        _appendAssistantChunk(event.data);
        return;
      case ConsultationStreamEventType.done:
        _finishStreaming();
        return;
      case ConsultationStreamEventType.error:
        final message =
            event.data.isEmpty ? '상담 응답 생성 중 오류가 발생했습니다.' : event.data;
        _replaceActiveAssistantWithSystem(message);
        _setState(
          _state.copyWith(
            errorMessage: message,
          ),
        );
        _finishStreaming();
        return;
      case ConsultationStreamEventType.streamError:
        _handleRecoverableStreamFailure(
          event.data.isEmpty ? '상담 연결이 지연되고 있습니다.' : event.data,
        );
        return;
      case ConsultationStreamEventType.unknown:
        return;
    }
  }

  void _handleStreamError(Object error) {
    final currentSubscription = _streamSubscription;
    _streamSubscription = null;
    if (currentSubscription != null) {
      unawaited(currentSubscription.cancel());
    }

    if (error is ApiClientException &&
        error.kind == ApiErrorKind.unauthorized) {
      _finishStreaming();
      _onUnauthorized?.call();
      _setState(
        _state.copyWith(
          connectionState: ConsultationConnectionState.error,
          isSending: false,
          errorMessage: _messageFromError(error),
        ),
      );
      return;
    }

    _handleRecoverableStreamFailure(_messageFromError(error));
  }

  void _handleStreamDone() {
    _streamSubscription = null;
    _handleRecoverableStreamFailure('상담 연결이 종료되었습니다.');
  }

  void _handleRecoverableStreamFailure(String message) {
    final currentSubscription = _streamSubscription;
    _streamSubscription = null;
    if (currentSubscription != null) {
      unawaited(currentSubscription.cancel());
    }

    _clearPendingAssistantMessage();
    _finishStreaming();
    _scheduleReconnect(message);
  }

  void _scheduleReconnect(String message) {
    if (!_shouldRestoreConnection || _isDisposed) {
      return;
    }

    if (_reconnectAttempt >= _reconnectBackoffDelays.length) {
      _appendConnectionNotice('상담 연결이 끊어졌습니다. 다시 연결해 주세요.');
      _setState(
        _state.copyWith(
          connectionState: ConsultationConnectionState.error,
          isSending: false,
          isStreaming: false,
          errorMessage: message,
        ),
      );
      return;
    }

    final delay = _reconnectBackoffDelays[_reconnectAttempt];
    _reconnectAttempt += 1;
    _appendConnectionNotice('상담 연결이 끊어졌습니다. 자동으로 다시 연결합니다.');
    _setState(
      _state.copyWith(
        connectionState: ConsultationConnectionState.reconnecting,
        isSending: false,
        isStreaming: false,
        errorMessage: message,
      ),
    );

    _cancelPendingReconnect();
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (!_shouldRestoreConnection || _isDisposed) {
        return;
      }
      unawaited(connect(reloadRecentMessages: true));
    });
  }

  void _appendConnectionNotice(String content) {
    if (_state.inputBlockedBySafety ||
        _state.messages.any((message) => message.content == content)) {
      return;
    }

    _setState(
      _state.copyWith(
        messages: [
          ..._state.messages,
          _createMessage(ConsultationMessageRole.system, content),
        ],
      ),
    );
  }

  void _clearPendingAssistantMessage() {
    final messageId = _activeAssistantMessageId;
    if (messageId == null) {
      return;
    }

    final hasPendingAssistant = _state.messages.any((message) {
      return message.id == messageId &&
          message.role == ConsultationMessageRole.assistant &&
          message.content.isEmpty;
    });
    if (!hasPendingAssistant) {
      return;
    }

    _setState(
      _state.copyWith(
        messages: [
          for (final message in _state.messages)
            if (message.id != messageId) message,
        ],
      ),
    );
  }

  void _appendAssistantChunk(String chunk) {
    if (chunk.isEmpty) {
      return;
    }

    final messageId = _activeAssistantMessageId;
    if (messageId == null) {
      final message = _createMessage(ConsultationMessageRole.assistant, chunk);
      _activeAssistantMessageId = message.id;
      _setState(
        _state.copyWith(
          messages: [..._state.messages, message],
          connectionState: ConsultationConnectionState.connected,
          isStreaming: true,
          clearErrorMessage: true,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        messages: [
          for (final message in _state.messages)
            if (message.id == messageId)
              message.copyWith(content: '${message.content}$chunk')
            else
              message,
        ],
        connectionState: ConsultationConnectionState.connected,
        isStreaming: true,
        clearErrorMessage: true,
      ),
    );
  }

  void _appendSystemMessage(String content) {
    _setState(
      _state.copyWith(
        messages: [
          ..._state.messages,
          _createMessage(ConsultationMessageRole.system, content),
        ],
        clearSafetyNotice: true,
      ),
    );
  }

  void _replaceActiveAssistantWithSystem(String content) {
    final messageId = _activeAssistantMessageId;
    if (messageId == null) {
      _appendSystemMessage(content);
      return;
    }

    _setState(
      _state.copyWith(
        messages: [
          for (final message in _state.messages)
            if (message.id == messageId)
              message.copyWith(
                role: ConsultationMessageRole.system,
                content: content,
              )
            else
              message,
        ],
      ),
    );
  }

  void _finishStreaming() {
    _activeAssistantMessageId = null;
    _setState(_state.copyWith(isStreaming: false));
  }

  Future<void> _loadRecentMessages({bool force = false}) async {
    if (_hasLoadedRecentMessages && !force) {
      return;
    }

    _hasLoadedRecentMessages = true;
    try {
      final messages = await _repository.loadRecentMessages();
      if (messages.isNotEmpty) {
        _setState(
          _state.copyWith(
            messages: _mergeRecentMessages(messages),
            clearErrorMessage: true,
          ),
        );
      }
    } on Object catch (error) {
      _hasLoadedRecentMessages = false;
      _setState(
        _state.copyWith(
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  List<ConsultationMessage> _mergeRecentMessages(
    List<ConsultationMessage> recentMessages,
  ) {
    // 재연결 중 서버 기록으로 교체하되, 로컬 전송 실패 항목은 재시도할 수 있게 보존한다.
    final failedMessage = _state.failedMessage;
    if (failedMessage == null) {
      return recentMessages;
    }

    final recentIds = recentMessages.map((message) => message.id).toSet();
    final preservedIds = {
      failedMessage.userMessageId,
      if (failedMessage.systemMessageId != null) failedMessage.systemMessageId!,
    };
    return [
      ...recentMessages,
      for (final message in _state.messages)
        if (preservedIds.contains(message.id) &&
            !recentIds.contains(message.id))
          message,
    ];
  }

  Future<void> _cancelStream({
    ConsultationConnectionState connectionState =
        ConsultationConnectionState.idle,
    bool clearErrorMessage = false,
  }) async {
    final currentSubscription = _streamSubscription;
    _streamSubscription = null;
    _cancelPendingReconnect();
    await currentSubscription?.cancel();
    _activeAssistantMessageId = null;
    _setState(
      _state.copyWith(
        connectionState: connectionState,
        isSending: false,
        isStreaming: false,
        clearErrorMessage: clearErrorMessage,
      ),
    );
  }

  void _cancelStreamForLifecycle({
    required ConsultationConnectionState connectionState,
    required bool clearErrorMessage,
  }) {
    final currentSubscription = _streamSubscription;
    _streamSubscription = null;
    _cancelPendingReconnect();
    if (currentSubscription != null) {
      unawaited(currentSubscription.cancel());
    }
    _activeAssistantMessageId = null;
    _setState(
      _state.copyWith(
        connectionState: connectionState,
        isSending: false,
        isStreaming: false,
        clearErrorMessage: clearErrorMessage,
      ),
    );
  }

  ConsultationMessage _createMessage(
    ConsultationMessageRole role,
    String content,
  ) {
    _messageSequence += 1;
    return ConsultationMessage(
      id: 'consultation-message-$_messageSequence',
      role: role,
      content: content,
      createdAt: DateTime.now(),
    );
  }

  List<ConsultationMessage> _initialMessages() {
    return [
      ConsultationMessage(
        id: 'system-0',
        role: ConsultationMessageRole.system,
        content: '상담을 시작하려면 메시지를 입력해 주세요.',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    ];
  }

  String _messageFromError(Object error) {
    if (error is ApiClientException) {
      return error.message;
    }

    return '요청을 처리하지 못했습니다.';
  }

  void _setState(ConsultationState nextState) {
    if (_isDisposed) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelPendingReconnect();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _cancelPendingReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../data/consultation_repository.dart';
import '../domain/consultation_models.dart';

class ConsultationState {
  const ConsultationState({
    required this.messages,
    this.connectionState = ConsultationConnectionState.idle,
    this.draft = '',
    this.isSending = false,
    this.isStreaming = false,
    this.errorMessage,
    this.safetyNotice,
  });

  final List<ConsultationMessage> messages;
  final ConsultationConnectionState connectionState;
  final String draft;
  final bool isSending;
  final bool isStreaming;
  final String? errorMessage;
  final ConsultationSafetyResult? safetyNotice;

  bool get canSubmit {
    return connectionState == ConsultationConnectionState.connected &&
        draft.trim().isNotEmpty &&
        draft.trim().length <= ConsultationController.maxMessageLength &&
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
    );
  }
}

class ConsultationController extends ChangeNotifier {
  ConsultationController({
    required ConsultationRepository repository,
    VoidCallback? onUnauthorized,
  })  : _repository = repository,
        _onUnauthorized = onUnauthorized,
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
  final VoidCallback? _onUnauthorized;

  ConsultationState _state;
  StreamSubscription<ConsultationStreamEvent>? _streamSubscription;
  bool _shouldRestoreConnection = false;
  bool _hasLoadedRecentMessages = false;
  bool _isDisposed = false;
  int _messageSequence = 0;
  String? _activeAssistantMessageId;

  ConsultationState get state => _state;

  Future<void> connect() async {
    if (_streamSubscription != null) {
      return;
    }

    _shouldRestoreConnection = true;
    if (!_hasLoadedRecentMessages) {
      await _loadRecentMessages();
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
    await _cancelStream();
    await connect();
  }

  void close() {
    _shouldRestoreConnection = false;
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
        _cancelStreamForLifecycle(
          connectionState: ConsultationConnectionState.idle,
          clearErrorMessage: true,
        );
      }
    }
  }

  void updateDraft(String draft) {
    _setState(
      _state.copyWith(
        draft: draft,
        clearErrorMessage: true,
        clearSafetyNotice: true,
      ),
    );
  }

  Future<void> submitMessage() async {
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

    final assistantMessage = _createMessage(
      ConsultationMessageRole.assistant,
      '',
    );
    _activeAssistantMessageId = assistantMessage.id;
    _setState(
      _state.copyWith(
        messages: [
          ..._state.messages,
          _createMessage(ConsultationMessageRole.user, content),
          assistantMessage,
        ],
        draft: '',
        isSending: true,
        isStreaming: true,
        clearErrorMessage: true,
      ),
    );

    try {
      final result = await _repository.sendMessage(content);
      final safety = result.safety;
      if (safety != null && safety.blocksConversation) {
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

      _setState(_state.copyWith(isSending: false, clearSafetyNotice: true));
    } on Object catch (error) {
      _replaceActiveAssistantWithSystem('전송 실패: ${_messageFromError(error)}');
      _activeAssistantMessageId = null;
      _setState(
        _state.copyWith(
          isSending: false,
          isStreaming: false,
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  Future<void> deleteSensitiveMessages() async {
    try {
      await _repository.deleteSensitiveMessages();
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

  void _handleStreamEvent(ConsultationStreamEvent event) {
    switch (event.type) {
      case ConsultationStreamEventType.connect:
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
        final message = event.data.isEmpty
            ? '상담 응답 생성 중 오류가 발생했습니다.'
            : event.data;
        _replaceActiveAssistantWithSystem(message);
        _setState(
          _state.copyWith(
            errorMessage: message,
          ),
        );
        _finishStreaming();
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

    _finishStreaming();
    if (error is ApiClientException &&
        error.kind == ApiErrorKind.unauthorized) {
      _onUnauthorized?.call();
    }
    _appendSystemMessage('상담 연결이 끊어졌습니다. 다시 연결해 주세요.');
    _setState(
      _state.copyWith(
        connectionState: ConsultationConnectionState.error,
        isSending: false,
        errorMessage: _messageFromError(error),
      ),
    );
  }

  void _handleStreamDone() {
    _streamSubscription = null;
    _finishStreaming();
    if (_state.connectionState == ConsultationConnectionState.connected) {
      _setState(
        _state.copyWith(connectionState: ConsultationConnectionState.error),
      );
      _appendSystemMessage('상담 연결이 종료되었습니다. 다시 연결해 주세요.');
    }
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

  Future<void> _loadRecentMessages() async {
    if (_hasLoadedRecentMessages) {
      return;
    }

    _hasLoadedRecentMessages = true;
    try {
      final messages = await _repository.loadRecentMessages();
      if (messages.isNotEmpty) {
        _setState(
          _state.copyWith(
            messages: messages,
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

  Future<void> _cancelStream({
    ConsultationConnectionState connectionState =
        ConsultationConnectionState.idle,
    bool clearErrorMessage = false,
  }) async {
    final currentSubscription = _streamSubscription;
    _streamSubscription = null;
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
    _streamSubscription?.cancel();
    super.dispose();
  }
}

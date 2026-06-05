import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../application/consultation_controller.dart';
import '../domain/consultation_models.dart';

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({
    required this.controller,
    required this.onBack,
    super.key,
  });

  final ConsultationController controller;
  final VoidCallback onBack;

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textController =
        TextEditingController(text: widget.controller.state.draft);
    unawaited(widget.controller.connect());
  }

  @override
  void didUpdateWidget(covariant ConsultationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _syncText();
      unawaited(widget.controller.connect());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.handleLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.close();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _syncText() {
    final nextText = widget.controller.state.draft;
    if (_textController.text == nextText) {
      return;
    }

    _textController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        _syncText();
        _scheduleScrollToBottom();

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _ConsultationHeader(
                  connectionState: state.connectionState,
                  onBack: widget.onBack,
                ),
                if (state.errorMessage != null)
                  AppNotice(
                    message: state.errorMessage!,
                    tone: AppNoticeTone.error,
                  ),
                if (state.safetyNotice != null)
                  _SafetyNotice(
                    safety: state.safetyNotice!,
                    onDeleteSensitive:
                        widget.controller.deleteSensitiveMessages,
                  ),
                if (state.safetyNotice == null && state.failedMessage != null)
                  _FailedMessageNotice(
                    failedMessage: state.failedMessage!,
                    onRetry: widget.controller.retryFailedMessage,
                    onDelete: widget.controller.deleteFailedMessage,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: _ConsultationStatusToolbar(
                    state: state,
                    onReconnect: widget.controller.reconnect,
                  ),
                ),
                Expanded(
                  key: const ValueKey('consultation-chat-section'),
                  child: ListView.builder(
                    key: const ValueKey('consultation-message-list'),
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      return _MessageBubble(message: state.messages[index]);
                    },
                  ),
                ),
                _Composer(
                  controller: _textController,
                  state: state,
                  onChanged: widget.controller.updateDraft,
                  onSubmitted: widget.controller.submitMessage,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FailedMessageNotice extends StatelessWidget {
  const _FailedMessageNotice({
    required this.failedMessage,
    required this.onRetry,
    required this.onDelete,
  });

  final ConsultationFailedMessage failedMessage;
  final Future<void> Function() onRetry;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      key: const ValueKey('consultation-failed-message-notice'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: AppRadii.card,
          border: Border.all(color: colorScheme.secondary),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                container: true,
                liveRegion: true,
                label: '전송 실패. ${failedMessage.errorMessage}',
                child: ExcludeSemantics(
                  child: Text(
                    '전송하지 못한 메시지가 있습니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                failedMessage.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppResponsiveActionWrap(
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey(
                      'consultation-retry-failed-message-button',
                    ),
                    onPressed: () => onRetry(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 전송'),
                  ),
                  TextButton.icon(
                    key: const ValueKey(
                      'consultation-delete-failed-message-button',
                    ),
                    onPressed: () => onDelete(),
                    icon: const Icon(Icons.close),
                    label: const Text('삭제'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({
    required this.safety,
    required this.onDeleteSensitive,
  });

  final ConsultationSafetyResult safety;
  final Future<void> Function() onDeleteSensitive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('consultation-safety-notice'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppStateView.risk(
            title: '즉시 도움 요청',
            message: safety.message,
            semanticLabel: '상담 위험 상황 도움 안내. ${safety.message}',
          ),
          const SizedBox(height: AppSpacing.sm),
          AppResponsiveActionWrap(
            children: [
              _EmergencyActionButton(
                key: const ValueKey('consultation-emergency-119-button'),
                icon: Icons.local_hospital_outlined,
                label: '119',
                semanticLabel: '119 긴급 구조 요청',
                onPressed: () => _showEmergencyContact(context, '119'),
              ),
              _EmergencyActionButton(
                key: const ValueKey('consultation-emergency-112-button'),
                icon: Icons.local_police_outlined,
                label: '112',
                semanticLabel: '112 경찰 긴급 신고',
                onPressed: () => _showEmergencyContact(context, '112'),
              ),
              _EmergencyActionButton(
                key: const ValueKey('consultation-emergency-1388-button'),
                icon: Icons.support_agent_outlined,
                label: '1388',
                semanticLabel: '1388 청소년 상담 연결',
                onPressed: () => _showEmergencyContact(context, '1388'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: '민감한 상담 기록 삭제',
              child: TextButton.icon(
                key: const ValueKey(
                  'consultation-delete-sensitive-button',
                ),
                onPressed: () => onDeleteSensitive(),
                icon: const Icon(Icons.delete_outline),
                label: const Text('민감 기록 삭제'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyContact(BuildContext context, String number) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('기기 전화 앱에서 $number에 연락해 주세요.')),
      );
  }
}

class _EmergencyActionButton extends StatelessWidget {
  const _EmergencyActionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _ConsultationHeader extends StatelessWidget {
  const _ConsultationHeader({
    required this.connectionState,
    required this.onBack,
  });

  final ConsultationConnectionState connectionState;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: AppScreenHeader(
        title: '실시간 상담',
        onBack: onBack,
      ),
    );
  }
}

class _ConsultationStatusToolbar extends StatelessWidget {
  const _ConsultationStatusToolbar({
    required this.state,
    required this.onReconnect,
  });

  final ConsultationState state;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusText = _consultationStatusText(
      state.connectionState,
      state.isStreaming,
    );
    final inputLabel = state.inputBlockedBySafety
        ? '안전 확인 필요'
        : state.isSending
            ? '전송 중'
            : state.isStreaming
                ? '응답 대기'
                : state.connectionState == ConsultationConnectionState.connected
                    ? '입력 가능'
                    : '입력 대기';

    return Card(
      key: const ValueKey('consultation-status-toolbar'),
      margin: EdgeInsets.zero,
      color: colorScheme.primaryContainer.withValues(alpha: 0.62),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.support_agent_outlined,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '상담 상태',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (state.connectionState == ConsultationConnectionState.error)
                  IconButton.filledTonal(
                    key: const ValueKey('consultation-reconnect-button'),
                    tooltip: '상담 다시 연결',
                    onPressed: () => onReconnect(),
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppStatusPill(
                  label: statusText,
                  tone: _consultationStatusTone(state.connectionState),
                ),
                AppStatusPill(label: '메시지 ${state.messages.length}개'),
                AppStatusPill(
                  label: inputLabel,
                  tone: state.inputBlockedBySafety
                      ? AppStatusTone.danger
                      : state.connectionState ==
                              ConsultationConnectionState.connected
                          ? AppStatusTone.success
                          : AppStatusTone.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _consultationStatusText(
  ConsultationConnectionState connectionState,
  bool isStreaming,
) {
  return switch (connectionState) {
    ConsultationConnectionState.idle => '상담 연결 대기',
    ConsultationConnectionState.connecting => '자동 연결 중',
    ConsultationConnectionState.connected when isStreaming => '답변 작성 중',
    ConsultationConnectionState.connected => '상담 연결됨',
    ConsultationConnectionState.reconnecting => '자동 재연결 중',
    ConsultationConnectionState.error => '재연결 필요',
  };
}

AppStatusTone _consultationStatusTone(
  ConsultationConnectionState connectionState,
) {
  return switch (connectionState) {
    ConsultationConnectionState.connected => AppStatusTone.success,
    ConsultationConnectionState.connecting ||
    ConsultationConnectionState.reconnecting =>
      AppStatusTone.warning,
    ConsultationConnectionState.error => AppStatusTone.danger,
    ConsultationConnectionState.idle => AppStatusTone.neutral,
  };
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ConsultationMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ConsultationMessageRole.user;
    final isSystem = message.role == ConsultationMessageRole.system;
    final isPendingAssistant =
        message.role == ConsultationMessageRole.assistant &&
            message.content.isEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser
                  ? colorScheme.primary
                  : isSystem
                      ? colorScheme.errorContainer
                      : colorScheme.surfaceContainerHighest,
              borderRadius: AppRadii.card,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: isPendingAssistant
                  ? Semantics(
                      container: true,
                      liveRegion: true,
                      label: '상담사가 답변을 작성 중입니다.',
                      child: ExcludeSemantics(
                        child: Row(
                          key: const ValueKey('consultation-typing-indicator'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '응답 작성 중입니다.',
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Text(
                      message.content,
                      style: TextStyle(
                        color: isUser
                            ? colorScheme.onPrimary
                            : isSystem
                                ? colorScheme.onErrorContainer
                                : colorScheme.onSurface,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.state,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ConsultationState state;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSubmitted;

  @override
  Widget build(BuildContext context) {
    final inputBlocked = state.inputBlockedBySafety;
    final helperText = inputBlocked
        ? '안전 안내 확인 후 다시 이용할 수 있습니다.'
        : state.isStreaming
            ? '답변을 작성 중입니다.'
            : '${state.draft.length}/${ConsultationController.maxMessageLength}';

    return SafeArea(
      key: const ValueKey('consultation-composer-section'),
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('consultation-message-field'),
                  controller: controller,
                  enabled: !inputBlocked && !state.isSending,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: ConsultationController.maxMessageLength,
                  decoration: InputDecoration(
                    labelText: '고민을 입력해 주세요',
                    helperText: helperText,
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  onChanged: inputBlocked ? null : onChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton.filled(
                key: const ValueKey('consultation-send-button'),
                tooltip: inputBlocked ? '안전 안내 확인 필요' : '전송',
                onPressed: state.canSubmit ? () => onSubmitted() : null,
                icon: state.isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Streaming chat bubble isolation and near-bottom scroll pinning adapted from:
// - flyerhq/flutter_chat_ui (Apache-2.0)
// - flutter/ai (BSD-3-Clause)
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/ui/app_design_system.dart';
import '../../../shared/ui/text_editing_sync.dart';
import '../application/consultation_controller.dart';
import '../domain/consultation_models.dart';

typedef ConsultationEmergencyDialer = Future<void> Function(String number);

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({
    required this.controller,
    this.onBack,
    this.emergencyDialer,
    super.key,
  });

  final ConsultationController controller;
  final VoidCallback? onBack;
  final ConsultationEmergencyDialer? emergencyDialer;

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen>
    with WidgetsBindingObserver {
  static final RegExp _nonDigitPattern = RegExp(r'[^0-9]');
  static const double _nearBottomThreshold = 64;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showJumpToBottomNotifier =
      ValueNotifier<bool>(false);
  late final TextEditingController _textController;
  bool _isNearBottom = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScrollChanged);
    _textController =
        TextEditingController(text: widget.controller.state.draft);
    _attachController(widget.controller);
    unawaited(widget.controller.connect());
  }

  @override
  void didUpdateWidget(covariant ConsultationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      _attachController(widget.controller);
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
    _detachController(widget.controller);
    _scrollController.removeListener(_handleScrollChanged);
    widget.controller.close();
    _showJumpToBottomNotifier.dispose();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _attachController(ConsultationController controller) {
    controller.streamingContentNotifier.addListener(_handleStreamingChunkUpdate);
  }

  void _detachController(ConsultationController controller) {
    controller.streamingContentNotifier
        .removeListener(_handleStreamingChunkUpdate);
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final nearBottom = position.extentAfter <= _nearBottomThreshold;
    _isNearBottom = nearBottom;
    final showJump = !nearBottom && position.maxScrollExtent > 0;
    if (_showJumpToBottomNotifier.value != showJump) {
      _showJumpToBottomNotifier.value = showJump;
    }
  }

  void _handleStreamingChunkUpdate() {
    if (_isNearBottom) {
      _scheduleScrollToBottom();
    }
  }

  void _syncText() {
    syncTextControllerWithImeGuard(
      _textController,
      widget.controller.state.draft,
    );
  }

  void _scheduleScrollToBottom() {
    if (!_isNearBottom) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !_isNearBottom) {
        return;
      }

      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _jumpToBottom() {
    _isNearBottom = true;
    _showJumpToBottomNotifier.value = false;
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _handleEmergencyContact(BuildContext context, String number) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('기기 전화 앱에서 $number에 연락해 주세요.')),
      );
    unawaited(_launchEmergencyDialer(number));
  }

  Future<void> _launchEmergencyDialer(String number) async {
    final customDialer = widget.emergencyDialer;
    if (customDialer != null) {
      try {
        await customDialer(number);
      } on Object {
        // Keep immediate contact notice visible when platform dialer is unavailable.
      }
      return;
    }

    final digitsOnly = number.replaceAll(_nonDigitPattern, '');
    if (digitsOnly.isEmpty) {
      return;
    }
    try {
      await launchUrl(
        Uri(scheme: 'tel', path: digitsOnly),
        mode: LaunchMode.externalApplication,
      );
    } on MissingPluginException {
      // Headless tests and platforms without url_launcher plugin keep snackbar feedback.
    } on PlatformException {
      // Emulators without telephony fall back gracefully to snackbar feedback.
    } on Object {
      // Preserve fail-safe emergency guidance when OS dialer cannot open.
    }
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
                    onEmergencyContact: _handleEmergencyContact,
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
                  child: Stack(
                    children: [
                      _ConversationList(
                        controller: _scrollController,
                        messages: state.messages,
                        streamingMessageId:
                            widget.controller.activeStreamingMessageId,
                        streamingContentListenable:
                            widget.controller.streamingContentNotifier,
                      ),
                      Positioned(
                        right: AppSpacing.md,
                        bottom: AppSpacing.sm,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _showJumpToBottomNotifier,
                          builder: (context, showJump, _) {
                            if (!showJump) {
                              return const SizedBox.shrink();
                            }
                            return Semantics(
                              button: true,
                              label: '최신 답변 보기',
                              child: FilledButton.tonalIcon(
                                key: const ValueKey(
                                  'consultation-jump-to-bottom-button',
                                ),
                                onPressed: _jumpToBottom,
                                icon: const Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 18,
                                ),
                                label: const Text('최신 답변 보기'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
    required this.onEmergencyContact,
  });

  final ConsultationSafetyResult safety;
  final Future<void> Function() onDeleteSensitive;
  final void Function(BuildContext context, String number) onEmergencyContact;

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
            semanticLabel: 'AI 상담 위험 상황 도움 안내. ${safety.message}',
          ),
          const SizedBox(height: AppSpacing.sm),
          AppResponsiveActionWrap(
            children: [
              _EmergencyActionButton(
                key: const ValueKey('consultation-emergency-109-button'),
                icon: Icons.phone_in_talk_outlined,
                label: '109',
                semanticLabel: '109 24시간 자살예방 상담전화',
                onPressed: () => onEmergencyContact(context, '109'),
              ),
              _EmergencyActionButton(
                key: const ValueKey('consultation-emergency-119-button'),
                icon: Icons.local_hospital_outlined,
                label: '119',
                semanticLabel: '119 긴급 구조 요청',
                onPressed: () => onEmergencyContact(context, '119'),
              ),
              _EmergencyActionButton(
                key: const ValueKey('consultation-emergency-1577-0199-button'),
                icon: Icons.support_outlined,
                label: '1577-0199',
                semanticLabel: '1577-0199 정신건강 위기상담전화',
                onPressed: () => onEmergencyContact(context, '1577-0199'),
              ),
              _EmergencyActionButton(
                key: const ValueKey('consultation-emergency-112-button'),
                icon: Icons.local_police_outlined,
                label: '112',
                semanticLabel: '112 경찰 긴급 신고',
                onPressed: () => onEmergencyContact(context, '112'),
              ),
              _EmergencyActionButton(
                key: const ValueKey('consultation-emergency-1388-button'),
                icon: Icons.support_agent_outlined,
                label: '1388',
                semanticLabel: '1388 청소년 상담 연결',
                onPressed: () => onEmergencyContact(context, '1388'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: '민감한 AI 상담 기록 삭제',
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
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
  final VoidCallback? onBack;

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
        title: 'AI 상담',
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
    final conversationMessageCount = _conversationMessageCount(state.messages);
    final inputLabel = state.inputBlockedBySafety
        ? '안전 확인 필요'
        : state.isSending
            ? '전송 중'
            : state.isStreaming
                ? '응답 대기'
                : state.connectionState == ConsultationConnectionState.connected
                    ? '입력 가능'
                    : '입력 대기';

    return DecoratedBox(
      key: const ValueKey('consultation-status-toolbar'),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: AppRadii.status,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.support_agent_outlined,
              color: colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CompactStatusPill(
                    label: statusText,
                    tone: _consultationStatusTone(state.connectionState),
                  ),
                  _CompactStatusPill(label: '대화 $conversationMessageCount개'),
                  _CompactStatusPill(
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
            ),
            if (state.connectionState == ConsultationConnectionState.error) ...[
              const SizedBox(width: AppSpacing.xs),
              SizedBox.square(
                dimension: 48,
                child: IconButton.filledTonal(
                  key: const ValueKey('consultation-reconnect-button'),
                  tooltip: 'AI 상담 다시 연결',
                  onPressed: () => onReconnect(),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactStatusPill extends StatelessWidget {
  const _CompactStatusPill({
    required this.label,
    this.tone = AppStatusTone.neutral,
  });

  final String label;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = _compactStatusColors(colorScheme, tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.status,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

({Color background, Color foreground, Color border}) _compactStatusColors(
  ColorScheme colorScheme,
  AppStatusTone tone,
) {
  return switch (tone) {
    AppStatusTone.neutral => (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
        border: colorScheme.outlineVariant,
      ),
    AppStatusTone.success => (
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
        border: colorScheme.primary.withValues(alpha: 0.28),
      ),
    AppStatusTone.warning => (
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
        border: colorScheme.tertiary.withValues(alpha: 0.28),
      ),
    AppStatusTone.danger => (
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
        border: colorScheme.error.withValues(alpha: 0.28),
      ),
  };
}

String _consultationStatusText(
  ConsultationConnectionState connectionState,
  bool isStreaming,
) {
  return switch (connectionState) {
    ConsultationConnectionState.idle => 'AI 상담 연결 대기',
    ConsultationConnectionState.connecting => '자동 연결 중',
    ConsultationConnectionState.connected when isStreaming => '답변 작성 중',
    ConsultationConnectionState.connected => 'AI 상담 연결됨',
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

int _conversationMessageCount(List<ConsultationMessage> messages) {
  return messages.where((message) {
    return (message.role == ConsultationMessageRole.user ||
            message.role == ConsultationMessageRole.assistant) &&
        message.content.trim().isNotEmpty;
  }).length;
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.controller,
    required this.messages,
    required this.streamingMessageId,
    required this.streamingContentListenable,
  });

  final ScrollController controller;
  final List<ConsultationMessage> messages;
  final String? streamingMessageId;
  final ValueListenable<String?> streamingContentListenable;

  @override
  Widget build(BuildContext context) {
    final visibleMessages = messages
        .where((message) => !_isInitialSystemMessage(message))
        .toList(growable: false);
    final showEmptyState = visibleMessages.isEmpty;

    return ListView.builder(
      key: const ValueKey('consultation-message-list'),
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      itemCount: showEmptyState ? 1 : visibleMessages.length,
      itemBuilder: (context, index) {
        if (showEmptyState) {
          return const _ConsultationEmptyState();
        }

        final message = visibleMessages[index];
        if (streamingMessageId != null && message.id == streamingMessageId) {
          return RepaintBoundary(
            child: ValueListenableBuilder<String?>(
              valueListenable: streamingContentListenable,
              builder: (context, streamedContent, _) {
                final activeMessage = streamedContent == null
                    ? message
                    : message.copyWith(content: streamedContent);
                return _MessageBubble(message: activeMessage);
              },
            ),
          );
        }

        return RepaintBoundary(
          child: _MessageBubble(message: message),
        );
      },
    );
  }
}

bool _isInitialSystemMessage(ConsultationMessage message) {
  return message.id == 'system-0' &&
      message.role == ConsultationMessageRole.system;
}

class _ConsultationEmptyState extends StatelessWidget {
  const _ConsultationEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('consultation-empty-state'),
      padding: EdgeInsets.only(top: AppSpacing.md),
      child: AppStateView.empty(
        title: '상담 대기 중',
        message: '지금 떠오르는 마음을 적어 주세요.',
      ),
    );
  }
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
                      label: 'AI가 답변을 작성 중입니다.',
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('consultation-message-field'),
                  controller: controller,
                  enabled: !inputBlocked && !state.isSending,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: ConsultationController.maxMessageLength,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) =>
                      null,
                  decoration: const InputDecoration(
                    labelText: '고민을 입력해 주세요',
                    border: OutlineInputBorder(),
                    constraints: BoxConstraints(minHeight: 56),
                  ),
                  onChanged: inputBlocked ? null : onChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox.square(
                dimension: 52,
                child: IconButton.filled(
                  key: const ValueKey('consultation-send-button'),
                  tooltip: inputBlocked ? '안전 안내 확인 필요' : '전송',
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(52),
                    minimumSize: const Size.square(52),
                    maximumSize: const Size.square(52),
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  onPressed: state.canSubmit ? () => onSubmitted() : null,
                  icon: state.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

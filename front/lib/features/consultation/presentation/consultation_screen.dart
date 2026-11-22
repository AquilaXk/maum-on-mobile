// Streaming chat bubble isolation and near-bottom scroll pinning.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/ui/app_design_system.dart';
import '../../../shared/ui/text_editing_sync.dart';
import '../../../theme/app_theme.dart';
import '../application/consultation_controller.dart';
import '../domain/consultation_models.dart';
import 'widgets/breathing_grounding_sheet.dart';
import 'widgets/counselor_markdown_message.dart';
import 'widgets/jumping_dots_indicator.dart';

typedef ConsultationEmergencyDialer = Future<void> Function(String number);

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({
    required this.controller,
    this.onBack,
    this.emergencyDialer,
    this.closeStreamOnDispose = true,
    super.key,
  });

  final ConsultationController controller;
  final VoidCallback? onBack;
  final ConsultationEmergencyDialer? emergencyDialer;
  final bool closeStreamOnDispose;

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
    if (widget.closeStreamOnDispose) {
      widget.controller.handleLifecycleState(state);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachController(widget.controller);
    _scrollController.removeListener(_handleScrollChanged);
    if (widget.closeStreamOnDispose) {
      widget.controller.close();
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || !_isNearBottom) {
        return;
      }
      if (_scrollController.position.extentAfter > 1) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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

        return MaumShadThemeScope(
          child: Scaffold(
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
                      onOpenBreathing: () => showBreathingGroundingSheet(context),
                      onStartNewSession: widget.controller.startNewSession,
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
                          onSelectStarterPrompt: state.inputBlockedBySafety
                              ? null
                              : (prompt) {
                                  widget.controller.selectStarterTopic(prompt);
                                  _syncText();
                                },
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
                    showTopicsToggle: !state.inputBlockedBySafety &&
                        state.messages
                            .any((message) => !_isInitialSystemMessage(message)),
                    onToggleTopics: widget.controller.toggleStarterTopics,
                    onSelectTopic: (prompt) {
                      widget.controller.selectStarterTopic(prompt);
                      _syncText();
                    },
                    onChanged: widget.controller.updateDraft,
                    onSubmitted: widget.controller.submitMessage,
                    onStop: widget.controller.stopGenerating,
                  ),
                ],
              ),
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
      child: ShadCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: colorScheme.secondaryContainer,
        border: ShadBorder.all(color: colorScheme.secondary, width: 1),
        rowMainAxisSize: MainAxisSize.max,
        columnCrossAxisAlignment: CrossAxisAlignment.stretch,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
                icon: Icons.phone_outlined,
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
    required this.onOpenBreathing,
    required this.onStartNewSession,
  });

  final ConsultationState state;
  final Future<void> Function() onReconnect;
  final VoidCallback onOpenBreathing;
  final Future<void> Function() onStartNewSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF212529) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF343A40) : const Color(0xFFDBE7FB);
    final foreground =
        isDark ? const Color(0xFFF8F9FA) : const Color(0xFF1E293B);
    final secondary =
        isDark ? const Color(0xFFADB5BD) : const Color(0xFF4A5E78);
    final accent = isDark ? const Color(0xFF8E9CE6) : const Color(0xFF2563EB);
    final statusText = _consultationStatusText(
      state.connectionState,
      state.isStreaming,
    );
    final dotColor = _consultationDotColor(state.connectionState, isDark);
    final useWrap = MediaQuery.textScalerOf(context).scale(1) > 1.35;

    final statusLead = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
          child: const SizedBox.square(dimension: 8),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final actionButtons = <Widget>[
      TextButton.icon(
        key: const ValueKey('consultation-breathing-button'),
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          foregroundColor: accent,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onOpenBreathing,
        icon: const Icon(Icons.air_rounded, size: 18),
        label: const Text('호흡·안정'),
      ),
      TextButton.icon(
        key: const ValueKey('consultation-new-session-button'),
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          foregroundColor: secondary,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => onStartNewSession(),
        icon: const Icon(Icons.edit_square, size: 17),
        label: const Text('새 대화'),
      ),
      if (state.connectionState == ConsultationConnectionState.error)
        SizedBox.square(
          dimension: 48,
          child: IconButton.filledTonal(
            key: const ValueKey('consultation-reconnect-button'),
            tooltip: 'AI 상담 다시 연결',
            onPressed: () => onReconnect(),
            icon: const Icon(Icons.refresh),
          ),
        ),
    ];

    return DecoratedBox(
      key: const ValueKey('consultation-status-toolbar'),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        child: useWrap
            ? Wrap(
                spacing: AppSpacing.xs,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  statusLead,
                  ...actionButtons,
                ],
              )
            : Row(
                children: [
                  Expanded(child: statusLead),
                  ...actionButtons,
                ],
              ),
      ),
    );
  }
}

Color _consultationDotColor(
  ConsultationConnectionState connectionState,
  bool isDark,
) {
  return switch (connectionState) {
    ConsultationConnectionState.connected =>
      isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
    ConsultationConnectionState.connecting ||
    ConsultationConnectionState.reconnecting =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
    ConsultationConnectionState.error =>
      isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    ConsultationConnectionState.idle =>
      isDark ? const Color(0xFFADB5BD) : const Color(0xFF64748B),
  };
}

String _consultationStatusText(
  ConsultationConnectionState connectionState,
  bool isStreaming,
) {
  return switch (connectionState) {
    ConsultationConnectionState.idle => '연결 대기',
    ConsultationConnectionState.connecting => '연결 중',
    ConsultationConnectionState.connected when isStreaming => '답변 작성 중',
    ConsultationConnectionState.connected => '연결됨',
    ConsultationConnectionState.reconnecting => '다시 연결 중',
    ConsultationConnectionState.error => '재연결 필요',
  };
}

const List<String> _consultationStarterPrompts = [
  '마음이 지쳐서 쉬고 싶어요',
  '머릿속이 복잡해요',
  '조용히 이야기하고 싶어요',
];

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.controller,
    required this.messages,
    required this.streamingMessageId,
    required this.streamingContentListenable,
    this.onSelectStarterPrompt,
  });

  final ScrollController controller;
  final List<ConsultationMessage> messages;
  final String? streamingMessageId;
  final ValueListenable<String?> streamingContentListenable;
  final ValueChanged<String>? onSelectStarterPrompt;

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
          return _ConsultationEmptyState(
            onSelectStarterPrompt: onSelectStarterPrompt,
          );
        }

        final message = visibleMessages[index];
        final prevRole = index > 0 ? visibleMessages[index - 1].role : null;
        final nextRole = index + 1 < visibleMessages.length
            ? visibleMessages[index + 1].role
            : null;
        final isFirstInGroup = prevRole != message.role;
        final isLastInGroup = nextRole != message.role;

        if (streamingMessageId != null && message.id == streamingMessageId) {
          return RepaintBoundary(
            child: ValueListenableBuilder<String?>(
              valueListenable: streamingContentListenable,
              builder: (context, streamedContent, _) {
                final activeMessage = streamedContent == null
                    ? message
                    : message.copyWith(content: streamedContent);
                return _MessageBubble(
                  message: activeMessage,
                  isFirstInGroup: isFirstInGroup,
                  isLastInGroup: isLastInGroup,
                  isStreamingBubble: true,
                );
              },
            ),
          );
        }

        return RepaintBoundary(
          child: _MessageBubble(
            message: message,
            isFirstInGroup: isFirstInGroup,
            isLastInGroup: isLastInGroup,
          ),
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
  const _ConsultationEmptyState({this.onSelectStarterPrompt});

  final ValueChanged<String>? onSelectStarterPrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF8E9CE6) : const Color(0xFF2563EB);
    final iconBg =
        isDark ? const Color(0xFF283054) : const Color(0xFFEDF5FF);
    final foreground =
        isDark ? const Color(0xFFF8F9FA) : const Color(0xFF1E293B);
    final secondary =
        isDark ? const Color(0xFFADB5BD) : const Color(0xFF4A5E78);

    return Padding(
      key: const ValueKey('consultation-empty-state'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: ShadCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        rowMainAxisSize: MainAxisSize.max,
        columnCrossAxisAlignment: CrossAxisAlignment.stretch,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '오늘 마음을 나눠 볼까요',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '지금 떠오르는 마음을 편하게 적어 보세요.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final prompt in _consultationStarterPrompts)
                    ActionChip(
                      label: Text(prompt),
                      onPressed: onSelectStarterPrompt == null
                          ? null
                          : () => onSelectStarterPrompt!(prompt),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.isStreamingBubble = false,
  });

  final ConsultationMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isStreamingBubble;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ConsultationMessageRole.user;
    final isSystem = message.role == ConsultationMessageRole.system;
    final isAssistant = message.role == ConsultationMessageRole.assistant;
    final isPendingAssistant = isAssistant && message.content.isEmpty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final userBg = isDark ? const Color(0xFF8E9CE6) : const Color(0xFF2563EB);
    final userFg = isDark ? const Color(0xFF141824) : Colors.white;
    final assistantBg =
        isDark ? const Color(0xFF212529) : const Color(0xFFFFFFFF);
    final assistantBorder =
        isDark ? const Color(0xFF343A40) : const Color(0xFFDBE7FB);
    final avatarBg =
        isDark ? const Color(0xFF283054) : const Color(0xFFEDF5FF);
    final avatarFg = isDark ? const Color(0xFF8E9CE6) : const Color(0xFF2563EB);

    final bubbleRadius = isUser
        ? BorderRadius.only(
            topLeft: const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            topRight: Radius.circular(isFirstInGroup ? 16 : 6),
            bottomRight: Radius.circular(isLastInGroup ? 16 : 6),
          )
        : BorderRadius.only(
            topRight: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
            topLeft: Radius.circular(isFirstInGroup ? 16 : 6),
            bottomLeft: Radius.circular(isLastInGroup ? 16 : 6),
          );

    final Widget contentChild;
    if (isPendingAssistant) {
      contentChild = const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: JumpingDotsIndicator(
          key: ValueKey('consultation-typing-indicator'),
        ),
      );
    } else if (isAssistant) {
      contentChild = CounselorMarkdownMessage(
        data: message.content,
        showCopyButton: !isStreamingBubble,
        copyButtonKey: ValueKey('consultation-copy-${message.id}'),
      );
    } else {
      contentChild = Text(
        message.content,
        style: TextStyle(
          color: isUser ? userFg : colorScheme.onErrorContainer,
          height: 1.45,
        ),
      );
    }

    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: isUser
            ? userBg
            : isSystem
                ? colorScheme.errorContainer
                : assistantBg,
        borderRadius: bubbleRadius,
        border: isUser || isSystem ? null : Border.all(color: assistantBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: contentChild,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLastInGroup ? AppSpacing.sm : 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && !isSystem) ...[
            if (isLastInGroup)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 28,
                  child: Icon(
                    Icons.favorite_border_rounded,
                    size: 16,
                    color: avatarFg,
                  ),
                ),
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.state,
    required this.showTopicsToggle,
    required this.onToggleTopics,
    required this.onSelectTopic,
    required this.onChanged,
    required this.onSubmitted,
    required this.onStop,
  });

  final TextEditingController controller;
  final ConsultationState state;
  final bool showTopicsToggle;
  final VoidCallback onToggleTopics;
  final ValueChanged<String> onSelectTopic;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSubmitted;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final inputBlocked = state.inputBlockedBySafety;
    final isGenerating = state.isSending || state.isStreaming;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF212529) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF343A40) : const Color(0xFFDBE7FB);

    return SafeArea(
      key: const ValueKey('consultation-composer-section'),
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          border: Border(top: BorderSide(color: border)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.topicsExpanded && !inputBlocked) ...[
                Padding(
                  key: const ValueKey('consultation-topics-tray'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final prompt in _consultationStarterPrompts)
                        ActionChip(
                          label: Text(prompt),
                          onPressed: () => onSelectTopic(prompt),
                        ),
                    ],
                  ),
                ),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showTopicsToggle && !isGenerating) ...[
                    SizedBox.square(
                      dimension: 48,
                      child: IconButton(
                        key: const ValueKey('consultation-topics-button'),
                        tooltip: '추천 주제',
                        onPressed: onToggleTopics,
                        icon: Icon(
                          state.topicsExpanded
                              ? Icons.expand_more_rounded
                              : Icons.lightbulb_outline_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
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
                    child: isGenerating
                        ? IconButton.filled(
                            key: const ValueKey('consultation-stop-button'),
                            tooltip: '답변 중단',
                            style: IconButton.styleFrom(
                              fixedSize: const Size.square(52),
                              minimumSize: const Size.square(52),
                              maximumSize: const Size.square(52),
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            onPressed: () => onStop(),
                            icon: const Icon(Icons.stop_rounded),
                          )
                        : IconButton.filled(
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
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
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

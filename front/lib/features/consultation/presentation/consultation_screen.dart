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
                  onReconnect: widget.controller.reconnect,
                ),
                if (state.errorMessage != null)
                  AppNotice(
                    message: state.errorMessage!,
                    tone: AppNoticeTone.error,
                  ),
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey('consultation-message-list'),
                    controller: _scrollController,
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

class _ConsultationHeader extends StatelessWidget {
  const _ConsultationHeader({
    required this.connectionState,
    required this.onBack,
    required this.onReconnect,
  });

  final ConsultationConnectionState connectionState;
  final VoidCallback onBack;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (connectionState) {
      ConsultationConnectionState.idle => '연결 대기',
      ConsultationConnectionState.connecting => '연결 중',
      ConsultationConnectionState.connected => '연결됨',
      ConsultationConnectionState.error => '연결 불안정',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: AppScreenHeader(
        title: '실시간 상담',
        subtitle: statusText,
        onBack: onBack,
        actions: [
          if (connectionState == ConsultationConnectionState.error)
            IconButton.filledTonal(
              key: const ValueKey('consultation-reconnect-button'),
              tooltip: '다시 연결',
              onPressed: () => onReconnect(),
              icon: const Icon(Icons.refresh),
            ),
        ],
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
              child: Text(
                message.content.isEmpty ? '응답 작성 중입니다.' : message.content,
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
    final helperText = state.isStreaming
        ? '답변을 작성 중입니다.'
        : '${state.draft.length}/${ConsultationController.maxMessageLength}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
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
                minLines: 1,
                maxLines: 4,
                maxLength: ConsultationController.maxMessageLength,
                decoration: InputDecoration(
                  labelText: '고민을 입력해 주세요',
                  helperText: helperText,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filled(
              key: const ValueKey('consultation-send-button'),
              tooltip: '전송',
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
    );
  }
}

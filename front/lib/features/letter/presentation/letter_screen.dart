import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../../moderation/presentation/content_moderation_feedback_panel.dart';
import '../application/letter_controller.dart';
import '../domain/letter_models.dart';

class LetterScreen extends StatefulWidget {
  const LetterScreen({
    required this.controller,
    required this.onBack,
    this.initiallyCompose = false,
    this.initialLetterId,
    this.onOpenRandomReceiveSettings,
    super.key,
  });

  final LetterController controller;
  final VoidCallback onBack;
  final bool initiallyCompose;
  final int? initialLetterId;
  final VoidCallback? onOpenRandomReceiveSettings;

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initiallyCompose) {
      widget.controller.startCompose();
    } else if (widget.initialLetterId != null) {
      Future<void>.microtask(
        () => widget.controller.openLetterById(widget.initialLetterId!),
      );
    }
    _loadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant LetterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldStartCompose =
        !oldWidget.initiallyCompose && widget.initiallyCompose;
    if (oldWidget.controller != widget.controller || shouldStartCompose) {
      if (widget.initiallyCompose) {
        widget.controller.startCompose();
      }
      _loadIfNeeded();
    }
    if (oldWidget.initialLetterId != widget.initialLetterId &&
        widget.initialLetterId != null) {
      Future<void>.microtask(
        () => widget.controller.openLetterById(widget.initialLetterId!),
      );
    }
  }

  void _loadIfNeeded() {
    if (!widget.controller.state.hasLoaded) {
      Future<void>.microtask(widget.controller.load);
    }
  }

  Future<void> _retryModeration(LetterState state) {
    if (state.mode == LetterViewMode.compose) {
      return widget.controller.submitLetter();
    }
    return widget.controller.submitReply();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;

        return AppScreen(
          title: '편지함',
          subtitle: '받은 편지와 보낸 마음을 확인합니다.',
          onBack: widget.onBack,
          onRefresh: state.mode == LetterViewMode.mailbox
              ? widget.controller.load
              : null,
          actions: [
            FilledButton.icon(
              key: const ValueKey('letter-compose-button'),
              onPressed: widget.controller.startCompose,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('새 편지'),
            ),
          ],
          children: [
            if (state.moderationFeedback != null) ...[
              ContentModerationFeedbackPanel(
                feedback: state.moderationFeedback!,
                onRetry: () => _retryModeration(state),
                onDismiss: widget.controller.clearModerationFeedback,
              ),
              const SizedBox(height: AppSpacing.md),
            ] else if (state.errorMessage != null) ...[
              AppNotice(
                message: state.errorMessage!,
                tone: AppNoticeTone.error,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.noticeMessage != null) ...[
              _LetterNotice(message: state.noticeMessage!),
              const SizedBox(height: AppSpacing.md),
            ],
            switch (state.mode) {
              LetterViewMode.mailbox => _MailboxView(
                  state: state,
                  controller: widget.controller,
                  onOpenRandomReceiveSettings:
                      widget.onOpenRandomReceiveSettings,
                ),
              LetterViewMode.detail => _LetterDetailView(
                  state: state,
                  controller: widget.controller,
                ),
              LetterViewMode.compose => _LetterComposeView(
                  state: state,
                  controller: widget.controller,
                ),
            },
          ],
        );
      },
    );
  }
}

class _MailboxView extends StatelessWidget {
  const _MailboxView({
    required this.state,
    required this.controller,
    this.onOpenRandomReceiveSettings,
  });

  final LetterState state;
  final LetterController controller;
  final VoidCallback? onOpenRandomReceiveSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatsSection(
          stats: state.stats,
          onOpenLatestReceived: state.stats?.latestReceivedLetter == null
              ? null
              : () => controller.openLetter(state.stats!.latestReceivedLetter!),
          onOpenLatestSent: state.stats?.latestSentLetter == null
              ? null
              : () => controller.openLetter(state.stats!.latestSentLetter!),
        ),
        const SizedBox(height: AppSpacing.md),
        _ReceiveSettingsCard(
          onOpenRandomReceiveSettings: onOpenRandomReceiveSettings,
        ),
        const SizedBox(height: AppSpacing.md),
        KeyedSubtree(
          key: const ValueKey('letter-list-section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppInlineSectionHeader(
                icon: Icons.inbox_outlined,
                title: '편지 목록',
                subtitle: '받은 편지와 보낸 편지를 탭으로 전환합니다.',
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final tab in LetterMailboxTab.values)
                    ChoiceChip(
                      key: ValueKey('letter-tab-${tab.name}'),
                      label: Text(tab.label),
                      selected: state.activeTab == tab,
                      onSelected: (_) => controller.selectTab(tab),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.isLoading)
                const AppStateView.loading(
                  title: '편지를 불러오는 중입니다.',
                  semanticLabel: '편지함을 불러오는 중',
                )
              else if (state.isEmpty)
                AppStateView.empty(
                  title: state.activeTab == LetterMailboxTab.received
                      ? '아직 받은 편지가 없습니다.'
                      : '아직 보낸 편지가 없습니다.',
                  message: state.activeTab == LetterMailboxTab.received
                      ? '랜덤 편지 수신 설정을 켜 두면 새로운 편지를 받을 수 있습니다.'
                      : '새 편지를 쓰면 이곳에서 발송 상태를 확인할 수 있습니다.',
                  semanticLabel: '편지함 비어 있음',
                )
              else
                for (final letter in state.visibleLetters) ...[
                  _LetterCard(
                    letter: letter,
                    onTap: () => controller.openLetter(letter),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              if (!state.isLoading && state.visibleLetters.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                if (state.isVisibleLastPage)
                  const AppNotice(message: '마지막 편지입니다.')
                else
                  OutlinedButton.icon(
                    key: const ValueKey('letter-load-more-button'),
                    onPressed: state.isLoadingMore || state.errorMessage != null
                        ? null
                        : controller.loadMore,
                    icon: state.isLoadingMore
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more),
                    label: Text(state.isLoadingMore ? '불러오는 중' : '더 보기'),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.stats,
    this.onOpenLatestReceived,
    this.onOpenLatestSent,
  });

  final LetterStats? stats;
  final VoidCallback? onOpenLatestReceived;
  final VoidCallback? onOpenLatestSent;

  @override
  Widget build(BuildContext context) {
    final latestReceived = stats?.latestReceivedLetter?.title ?? '-';
    final latestSent = stats?.latestSentLetter?.title ?? '-';
    final receivedCount = stats?.receivedCount ?? 0;

    return AppSectionCard(
      key: const ValueKey('letter-mailbox-toolbar'),
      title: '받은 편지',
      subtitle: '최근 편지와 답장 상태를 빠르게 확인합니다.',
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppStatusPill(
                  label: '받은 편지 $receivedCount개',
                  tone: AppStatusTone.success,
                ),
                AppStatusPill(label: '최근 받은 편지 $latestReceived'),
                AppStatusPill(
                  label: '최근 보낸 편지 $latestSent',
                  tone: AppStatusTone.warning,
                ),
              ],
            ),
            if (stats?.latestReceivedLetter != null ||
                stats?.latestSentLetter != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppResponsiveActionWrap(
                children: [
                  if (stats?.latestReceivedLetter != null)
                    OutlinedButton.icon(
                      key: const ValueKey('letter-latest-received-button'),
                      onPressed: onOpenLatestReceived,
                      icon: const Icon(Icons.inbox_outlined),
                      label: const Text('최근 받은 편지 열기'),
                    ),
                  if (stats?.latestSentLetter != null)
                    OutlinedButton.icon(
                      key: const ValueKey('letter-latest-sent-button'),
                      onPressed: onOpenLatestSent,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('최근 보낸 편지 열기'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({
    required this.letter,
    required this.onTap,
  });

  final LetterSummary letter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      key: ValueKey('letter-card-${letter.id}'),
      leadingIcon: Icons.mail_outline,
      title: letter.title.isEmpty ? '제목 없는 편지' : letter.title,
      subtitle: letter.createdDate,
      badges: [_StatusPill(status: letter.status)],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (letter.content.isNotEmpty) ...[
            Text(
              letter.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(letter.status.guidance),
        ],
      ),
      onTap: onTap,
      semanticLabel:
          '편지 항목: ${letter.title.isEmpty ? '제목 없는 편지' : letter.title}, ${letter.status.displayLabel}',
    );
  }
}

class _LetterDetailView extends StatelessWidget {
  const _LetterDetailView({
    required this.state,
    required this.controller,
  });

  final LetterState state;
  final LetterController controller;

  @override
  Widget build(BuildContext context) {
    final letter = state.selectedLetter;

    if (state.isLoading) {
      return const AppStateView.loading(
        title: '편지를 불러오는 중입니다.',
        semanticLabel: '편지 상세를 불러오는 중',
      );
    }

    if (letter == null) {
      return const AppStateView.empty(
        title: '편지를 선택해 주세요.',
        message: '편지함에서 확인할 편지를 선택하면 상세 내용이 열립니다.',
        semanticLabel: '편지 상세 선택 필요',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('letter-list-back-button'),
            onPressed: controller.backToMailbox,
            icon: const Icon(Icons.arrow_back),
            label: const Text('목록'),
          ),
        ),
        AppContentCard(
          key: const ValueKey('letter-detail-card'),
          leadingIcon: Icons.mail_outline,
          title: letter.title,
          subtitle: letter.createdDate,
          badges: [_StatusPill(status: letter.status)],
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusGuidance(status: letter.status),
              const SizedBox(height: AppSpacing.md),
              Text(letter.content),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              key: const ValueKey('letter-report-button'),
              onPressed: controller.selectReportTarget,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('신고'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('letter-status-refresh-button'),
              onPressed: controller.refreshSelectedStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('상태 확인'),
            ),
            if (state.canAcceptOrReject) ...[
              FilledButton.tonalIcon(
                key: const ValueKey('letter-accept-button'),
                onPressed: controller.acceptSelectedLetter,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('수락'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('letter-reject-button'),
                onPressed: controller.rejectSelectedLetter,
                icon: const Icon(Icons.close),
                label: const Text('거절'),
              ),
            ],
          ],
        ),
        if (letter.replied && letter.replyContent != null) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '답장',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(letter.replyContent!),
                ],
              ),
            ),
          ),
        ],
        if (state.canReply) ...[
          const SizedBox(height: AppSpacing.md),
          _ReplyComposer(state: state, controller: controller),
        ],
      ],
    );
  }
}

class _ReplyComposer extends StatefulWidget {
  const _ReplyComposer({
    required this.state,
    required this.controller,
  });

  final LetterState state;
  final LetterController controller;

  @override
  State<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends State<_ReplyComposer> {
  late final TextEditingController _replyController;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController(text: widget.state.replyContent);
  }

  @override
  void didUpdateWidget(covariant _ReplyComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncText(_replyController, widget.state.replyContent);
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      key: ValueKey('letter-reply-${widget.state.selectedLetter?.id ?? 0}'),
      title: '답장',
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('letter-reply-field'),
              controller: _replyController,
              minLines: 4,
              maxLines: 8,
              maxLength: LetterLimits.replyMaxLength,
              decoration: const InputDecoration(
                labelText: '답장',
                border: OutlineInputBorder(),
              ),
              onChanged: widget.controller.updateReplyContent,
            ),
            if (widget.state.isReplyOverLimit) ...[
              const SizedBox(height: AppSpacing.xs),
              const AppNotice(
                message: '답장은 1000자까지 보낼 수 있습니다.',
                tone: AppNoticeTone.warning,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const ValueKey('letter-reply-submit-button'),
              onPressed: widget.state.canSubmitReply
                  ? widget.controller.submitReply
                  : null,
              child: const Text('답장 보내기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterComposeView extends StatefulWidget {
  const _LetterComposeView({
    required this.state,
    required this.controller,
  });

  final LetterState state;
  final LetterController controller;

  @override
  State<_LetterComposeView> createState() => _LetterComposeViewState();
}

class _LetterComposeViewState extends State<_LetterComposeView> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.state.title);
    _contentController = TextEditingController(text: widget.state.content);
  }

  @override
  void didUpdateWidget(covariant _LetterComposeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncText(_titleController, widget.state.title);
    _syncText(_contentController, widget.state.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      key: const ValueKey('letter-compose-form'),
      title: '편지 쓰기',
      subtitle: '제목은 60자, 본문은 1000자까지 보낼 수 있습니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('letter-title-field'),
            controller: _titleController,
            maxLength: LetterLimits.titleMaxLength,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.controller.updateTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey('letter-content-field'),
            controller: _contentController,
            minLines: 8,
            maxLines: 14,
            maxLength: LetterLimits.contentMaxLength,
            decoration: const InputDecoration(
              labelText: '본문',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.controller.updateContent,
          ),
          if (widget.state.isComposeOverLimit) ...[
            const SizedBox(height: AppSpacing.xs),
            const AppNotice(
              message: '편지 길이를 줄인 뒤 다시 보내 주세요.',
              tone: AppNoticeTone.warning,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppResponsiveActionWrap(
            children: [
              FilledButton(
                key: const ValueKey('letter-submit-button'),
                onPressed: widget.state.canSubmitLetter
                    ? widget.controller.submitLetter
                    : null,
                child: const Text('보내기'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('letter-compose-reset-button'),
                onPressed: widget.state.hasComposeDraft
                    ? widget.controller.resetCompose
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('초기화'),
              ),
              OutlinedButton(
                key: const ValueKey('letter-compose-cancel-button'),
                onPressed: _handleCancelCompose,
                child: const Text('취소'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancelCompose() async {
    final hasDraft = widget.state.title.trim().isNotEmpty ||
        widget.state.content.trim().isNotEmpty;
    if (!hasDraft) {
      widget.controller.cancelCompose();
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('작성 중인 편지를 나갈까요?'),
          content: const Text('나가면 작성 중인 제목과 본문이 지워집니다.'),
          actions: [
            TextButton(
              key: const ValueKey('letter-compose-keep-button'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('계속 작성'),
            ),
            FilledButton(
              key: const ValueKey('letter-compose-leave-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('나가기'),
            ),
          ],
        );
      },
    );

    if (shouldLeave == true && mounted) {
      widget.controller.cancelCompose();
    }
  }
}

void _syncText(TextEditingController controller, String nextText) {
  if (controller.text == nextText) {
    return;
  }

  controller.value = TextEditingValue(
    text: nextText,
    selection: TextSelection.collapsed(offset: nextText.length),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final LetterStatus status;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(label: status.displayLabel, tone: status.tone);
  }
}

class _LetterNotice extends StatelessWidget {
  const _LetterNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isSendSuccess = message == '편지가 전송되었습니다.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppNotice(
          message: message,
          tone: isSendSuccess ? AppNoticeTone.success : AppNoticeTone.neutral,
        ),
        if (isSendSuccess) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '보낸 편지함에서 상태를 확인해 주세요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _ReceiveSettingsCard extends StatelessWidget {
  const _ReceiveSettingsCard({this.onOpenRandomReceiveSettings});

  final VoidCallback? onOpenRandomReceiveSettings;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '랜덤 편지 수신',
      subtitle: '수신 설정을 켜 두면 익명의 마음 편지를 받을 수 있습니다.',
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const ValueKey('letter-receive-settings'),
          onPressed: onOpenRandomReceiveSettings,
          icon: const Icon(Icons.tune),
          label: const Text('수신 설정'),
        ),
      ),
    );
  }
}

class _StatusGuidance extends StatelessWidget {
  const _StatusGuidance({required this.status});

  final LetterStatus status;

  @override
  Widget build(BuildContext context) {
    return Text(
      status.guidance,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

extension _LetterStatusPresentation on LetterStatus {
  String get displayLabel {
    return switch (this) {
      LetterStatus.sent => '수신 대기',
      LetterStatus.accepted => '답장 가능',
      LetterStatus.writing => '답장 작성 중',
      LetterStatus.replied => '답장 완료',
    };
  }

  String get guidance {
    return switch (this) {
      LetterStatus.sent => '상대방의 답장을 기다리고 있습니다.',
      LetterStatus.accepted => '편지를 수락했습니다. 답장을 작성할 수 있습니다.',
      LetterStatus.writing => '상대방이 답장을 작성하고 있습니다.',
      LetterStatus.replied => '답장이 도착했습니다. 상세에서 내용을 확인해 주세요.',
    };
  }

  AppStatusTone get tone {
    return switch (this) {
      LetterStatus.sent => AppStatusTone.warning,
      LetterStatus.accepted => AppStatusTone.success,
      LetterStatus.writing => AppStatusTone.neutral,
      LetterStatus.replied => AppStatusTone.success,
    };
  }
}

import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../application/letter_controller.dart';
import '../domain/letter_models.dart';

class LetterScreen extends StatefulWidget {
  const LetterScreen({
    required this.controller,
    required this.onBack,
    this.initiallyCompose = false,
    this.initialLetterId,
    super.key,
  });

  final LetterController controller;
  final VoidCallback onBack;
  final bool initiallyCompose;
  final int? initialLetterId;

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
            if (state.errorMessage != null) ...[
              AppNotice(
                message: state.errorMessage!,
                tone: AppNoticeTone.error,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.noticeMessage != null) ...[
              AppNotice(message: state.noticeMessage!),
              const SizedBox(height: AppSpacing.md),
            ],
            switch (state.mode) {
              LetterViewMode.mailbox => _MailboxView(
                  state: state,
                  controller: widget.controller,
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
  });

  final LetterState state;
  final LetterController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatsSection(stats: state.stats),
        const SizedBox(height: AppSpacing.md),
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
          const AppStateView.empty(
            title: '아직 편지가 없습니다.',
            message: '새 편지를 쓰거나 다른 탭을 확인해 주세요.',
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
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});

  final LetterStats? stats;

  @override
  Widget build(BuildContext context) {
    final latestReceived = stats?.latestReceivedLetter?.title ?? '-';
    final latestSent = stats?.latestSentLetter?.title ?? '-';

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        AppMetricTile(
          label: '받은 편지',
          value: (stats?.receivedCount ?? 0).toString(),
          tone: AppStatusTone.success,
        ),
        AppMetricTile(label: '최근 받은 편지', value: latestReceived),
        AppMetricTile(
          label: '최근 보낸 편지',
          value: latestSent,
          tone: AppStatusTone.warning,
        ),
      ],
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
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('letter-card-${letter.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusPill(status: letter.status),
              const SizedBox(height: AppSpacing.xs),
              Text(
                letter.title.isEmpty ? '제목 없는 편지' : letter.title,
                style: theme.textTheme.titleMedium,
              ),
              if (letter.content.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  letter.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                letter.createdDate,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
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
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusPill(status: letter.status),
                const SizedBox(height: AppSpacing.md),
                Text(
                  letter.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  letter.createdDate,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(letter.content),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('letter-report-button'),
                      onPressed: controller.selectReportTarget,
                      child: const Text('신고'),
                    ),
                    OutlinedButton(
                      key: const ValueKey('letter-status-refresh-button'),
                      onPressed: controller.refreshSelectedStatus,
                      child: const Text('상태 확인'),
                    ),
                    if (state.canAcceptOrReject) ...[
                      FilledButton.tonal(
                        key: const ValueKey('letter-accept-button'),
                        onPressed: controller.acceptSelectedLetter,
                        child: const Text('수락'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('letter-reject-button'),
                        onPressed: controller.rejectSelectedLetter,
                        child: const Text('거절'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
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
    return Card(
      key: ValueKey('letter-reply-${widget.state.selectedLetter?.id ?? 0}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('letter-reply-field'),
              controller: _replyController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '답장',
                border: OutlineInputBorder(),
              ),
              onChanged: widget.controller.updateReplyContent,
            ),
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
    return Card(
      key: const ValueKey('letter-compose-form'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '편지 쓰기',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('letter-title-field'),
              controller: _titleController,
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
              decoration: const InputDecoration(
                labelText: '본문',
                border: OutlineInputBorder(),
              ),
              onChanged: widget.controller.updateContent,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton(
                  key: const ValueKey('letter-submit-button'),
                  onPressed: widget.state.canSubmitLetter
                      ? widget.controller.submitLetter
                      : null,
                  child: const Text('보내기'),
                ),
                OutlinedButton(
                  key: const ValueKey('letter-compose-cancel-button'),
                  onPressed: widget.controller.cancelCompose,
                  child: const Text('취소'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    return AppStatusPill(label: status.label, tone: AppStatusTone.success);
  }
}

import 'package:flutter/material.dart';

import '../application/letter_controller.dart';
import '../domain/letter_models.dart';

class LetterScreen extends StatefulWidget {
  const LetterScreen({
    required this.controller,
    required this.onBack,
    this.initiallyCompose = false,
    super.key,
  });

  final LetterController controller;
  final VoidCallback onBack;
  final bool initiallyCompose;

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initiallyCompose) {
      widget.controller.startCompose();
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

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LetterHeader(
                        onBack: widget.onBack,
                        onCompose: widget.controller.startCompose,
                      ),
                      const SizedBox(height: 16),
                      if (state.errorMessage != null) ...[
                        _InlineNotice(message: state.errorMessage!),
                        const SizedBox(height: 12),
                      ],
                      if (state.noticeMessage != null) ...[
                        _InlineNotice(message: state.noticeMessage!),
                        const SizedBox(height: 12),
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LetterHeader extends StatelessWidget {
  const _LetterHeader({
    required this.onBack,
    required this.onCompose,
  });

  final VoidCallback onBack;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('letter-home-back-button'),
          tooltip: '홈으로',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '편지함',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        SizedBox(
          width: 104,
          child: FilledButton(
            key: const ValueKey('letter-compose-button'),
            onPressed: onCompose,
            child: const Text('새 편지'),
          ),
        ),
      ],
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
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
        const SizedBox(height: 16),
        if (state.isLoading)
          const _InlineNotice(message: '편지를 불러오는 중입니다.')
        else if (state.isEmpty)
          const _InlineNotice(message: '아직 편지가 없습니다.')
        else
          for (final letter in state.visibleLetters) ...[
            _LetterCard(
              letter: letter,
              onTap: () => controller.openLetter(letter),
            ),
            const SizedBox(height: 10),
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
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatTile(
          label: '받은 편지',
          value: (stats?.receivedCount ?? 0).toString(),
        ),
        _StatTile(label: '최근 받은 편지', value: latestReceived),
        _StatTile(label: '최근 보낸 편지', value: latestSent),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 176,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
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
              const SizedBox(height: 8),
              Text(
                letter.title.isEmpty ? '제목 없는 편지' : letter.title,
                style: theme.textTheme.titleMedium,
              ),
              if (letter.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  letter.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
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
      return const _InlineNotice(message: '편지를 불러오는 중입니다.');
    }

    if (letter == null) {
      return const _InlineNotice(message: '편지를 선택해 주세요.');
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
                const SizedBox(height: 12),
                Text(
                  letter.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  letter.createdDate,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text(letter.content),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
          const SizedBox(height: 14),
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
                  const SizedBox(height: 8),
                  Text(letter.replyContent!),
                ],
              ),
            ),
          ),
        ],
        if (state.canReply) ...[
          const SizedBox(height: 14),
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
            const SizedBox(height: 10),
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
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('letter-title-field'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              onChanged: widget.controller.updateTitle,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          status.label,
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(message),
      ),
    );
  }
}

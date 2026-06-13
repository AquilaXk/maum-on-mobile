import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../../moderation/presentation/content_moderation_feedback_panel.dart';
import '../application/story_controller.dart';
import '../domain/story_models.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({
    required this.controller,
    this.onBack,
    this.initialStoryId,
    super.key,
  });

  final StoryController controller;
  final VoidCallback? onBack;
  final int? initialStoryId;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  @override
  void initState() {
    super.initState();
    _openInitialStoryIfNeeded();
    _loadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant StoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      _openInitialStoryIfNeeded();
      _loadIfNeeded();
    }
    if (!controllerChanged &&
        oldWidget.initialStoryId != widget.initialStoryId) {
      _openInitialStoryIfNeeded();
    }
  }

  void _loadIfNeeded() {
    if (!widget.controller.state.hasLoaded) {
      Future<void>.microtask(widget.controller.loadStories);
    }
  }

  void _openInitialStoryIfNeeded() {
    final storyId = widget.initialStoryId;
    if (storyId == null || storyId <= 0) {
      return;
    }

    Future<void>.microtask(() => widget.controller.openStoryById(storyId));
  }

  Future<void> _retryModeration(StoryState state) {
    if (state.mode == StoryViewMode.editor) {
      return widget.controller.submitStory();
    }
    if (state.editingCommentId != null) {
      return widget.controller.submitCommentEdit();
    }
    final replyCommentId = state.activeReplyCommentId;
    if (replyCommentId != null) {
      return widget.controller.submitReply(replyCommentId);
    }
    return widget.controller.submitComment(
      parentCommentId: state.activeReplyCommentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final onHeaderBack =
            state.mode == StoryViewMode.list ? null : widget.onBack;

        return AppScreen(
          title: '스토리',
          onBack: onHeaderBack,
          onRefresh: state.mode == StoryViewMode.list
              ? widget.controller.loadStories
              : null,
          actions: [
            if (state.mode != StoryViewMode.editor)
              FilledButton.icon(
                key: const ValueKey('story-create-button'),
                onPressed: widget.controller.startCreate,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('글쓰기'),
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
              AppNotice(message: state.noticeMessage!),
              const SizedBox(height: AppSpacing.md),
            ],
            switch (state.mode) {
              StoryViewMode.list => _StoryListView(
                  state: state,
                  controller: widget.controller,
                ),
              StoryViewMode.detail => _StoryDetailView(
                  state: state,
                  controller: widget.controller,
                ),
              StoryViewMode.editor => _StoryEditorView(
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

class _StoryListView extends StatelessWidget {
  const _StoryListView({
    required this.state,
    required this.controller,
  });

  final StoryState state;
  final StoryController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: const ValueKey('story-search-panel'),
          child: _StoryDiscoveryStrip(
            state: state,
            controller: controller,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.isListLoading)
          const AppStateView.loading(
            title: '스토리를 불러오는 중입니다.',
            semanticLabel: '스토리 목록을 불러오는 중',
          )
        else if (state.isEmpty)
          const AppStateView.empty(
            title: '조건에 맞는 스토리가 없습니다.',
            semanticLabel: '스토리 목록 비어 있음',
          )
        else
          for (final story in state.stories) ...[
            _StoryListCard(
              story: story,
              onTap: () => controller.openStory(story),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        if (!state.isListLoading &&
            state.stories.isNotEmpty &&
            !state.isLastStoryPage) ...[
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            key: const ValueKey('story-load-more-button'),
            onPressed: state.isLoadingMore || state.errorMessage != null
                ? null
                : controller.loadMoreStories,
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

class _StoryDiscoveryStrip extends StatelessWidget {
  const _StoryDiscoveryStrip({
    required this.state,
    required this.controller,
  });

  final StoryState state;
  final StoryController controller;

  @override
  Widget build(BuildContext context) {
    final storyCountLabel = '${state.stories.length}개의 스토리';
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return DecoratedBox(
      key: const ValueKey('story-discovery-strip'),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.52),
        borderRadius: AppRadii.card,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.travel_explore_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '이야기 찾기',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AppStatusPill(
                  label: storyCountLabel,
                  tone: state.stories.isEmpty
                      ? AppStatusTone.neutral
                      : AppStatusTone.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              key: const ValueKey('story-search-toolbar'),
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('story-search-field'),
                    decoration: const InputDecoration(
                      hintText: '제목 검색',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: controller.updateSearchQuery,
                    onSubmitted: (_) {
                      if (!state.isListLoading) {
                        controller.loadStories();
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filledTonal(
                  key: const ValueKey('story-search-button'),
                  onPressed:
                      state.isListLoading ? null : controller.loadStories,
                  tooltip: '검색',
                  icon: const Icon(Icons.manage_search),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _StoryCategoryFilter(
              selectedCategory: state.selectedCategory,
              onSelected: controller.selectCategory,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCategoryFilter extends StatelessWidget {
  const _StoryCategoryFilter({
    required this.selectedCategory,
    required this.onSelected,
  });

  final StoryCategory selectedCategory;
  final Future<void> Function(StoryCategory category) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final category in StoryCategory.values)
          ChoiceChip(
            key: ValueKey('story-category-${category.name}'),
            label: Text(category.label),
            selected: selectedCategory == category,
            visualDensity: VisualDensity.compact,
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: selectedCategory == category ? FontWeight.w800 : null,
            ),
            onSelected: (_) => onSelected(category),
          ),
      ],
    );
  }
}

class _StoryListCard extends StatelessWidget {
  const _StoryListCard({
    required this.story,
    required this.onTap,
  });

  final StorySummary story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = story.summary.trim();

    return AppContentCard(
      key: ValueKey('story-card-${story.id}'),
      leadingIcon: Icons.forum_outlined,
      title: story.title,
      subtitle: '${story.authorNickname} · 조회 ${story.viewCount}',
      badges: [
        AppStatusPill(
          label: story.category.label,
          tone: AppStatusTone.success,
        ),
        AppStatusPill(label: story.resolutionStatus.label),
      ],
      content: summary.isEmpty
          ? null
          : Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: onTap,
      semanticLabel:
          '스토리 항목: ${story.title}, $summary, ${story.category.label}, 조회 ${story.viewCount}',
    );
  }
}

class _StoryDetailView extends StatelessWidget {
  const _StoryDetailView({
    required this.state,
    required this.controller,
  });

  final StoryState state;
  final StoryController controller;

  @override
  Widget build(BuildContext context) {
    final story = state.selectedStory;

    if (state.isDetailLoading) {
      return const AppStateView.loading(
        title: '스토리를 불러오는 중입니다.',
        semanticLabel: '스토리 상세를 불러오는 중',
      );
    }

    if (story == null) {
      return const AppStateView.empty(
        title: '스토리를 선택해 주세요.',
        semanticLabel: '스토리 상세 선택 필요',
      );
    }

    final canEdit = story.canEdit(controller.currentMemberId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('story-list-back-button'),
            onPressed: controller.backToList,
            icon: const Icon(Icons.arrow_back),
            label: const Text('목록'),
          ),
        ),
        AppContentCard(
          key: const ValueKey('story-detail-card'),
          leadingIcon: Icons.article_outlined,
          title: story.title,
          subtitle: '${story.authorNickname} · 조회 ${story.viewCount}',
          badges: [
            AppStatusPill(
              label: story.category.label,
              tone: AppStatusTone.success,
            ),
            AppStatusPill(label: story.resolutionStatus.label),
          ],
          content: Text(story.content),
          actionsKey: const ValueKey('story-detail-action-panel'),
          actions: [
            OutlinedButton.icon(
              key: const ValueKey('story-report-button'),
              onPressed: controller.selectStoryReportTarget,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('신고'),
            ),
            if (canEdit) ...[
              FilledButton.tonalIcon(
                key: const ValueKey('story-status-button'),
                onPressed: state.isSubmitting
                    ? null
                    : controller.toggleSelectedResolutionStatus,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('상태 변경'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('story-edit-button'),
                onPressed: controller.startEditingSelectedStory,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('수정'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('story-delete-button'),
                onPressed:
                    state.isSubmitting ? null : controller.deleteSelectedStory,
                icon: const Icon(Icons.delete_outline),
                label: const Text('삭제'),
              ),
            ],
          ],
        ),
        if (state.reportTarget != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppNotice(
            key: const ValueKey('story-report-target-notice'),
            message: '${state.reportTarget!.label} 신고 대상을 선택했습니다.',
            tone: AppNoticeTone.warning,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _CommentSectionHeader(
          commentCount: state.commentTotalCount,
        ),
        const SizedBox(height: AppSpacing.sm),
        _CommentComposer(state: state, controller: controller),
        const SizedBox(height: AppSpacing.md),
        _CommentList(state: state, controller: controller),
      ],
    );
  }
}

class _CommentSectionHeader extends StatelessWidget {
  const _CommentSectionHeader({required this.commentCount});

  final int commentCount;

  @override
  Widget build(BuildContext context) {
    return AppInlineSectionHeader(
      key: const ValueKey('story-comment-section-header'),
      icon: Icons.mode_comment_outlined,
      title: '댓글',
      trailing: AppStatusPill(label: '댓글 $commentCount개'),
    );
  }
}

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({
    required this.state,
    required this.controller,
  });

  final StoryState state;
  final StoryController controller;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  late final TextEditingController _textController = TextEditingController();

  @override
  void didUpdateWidget(covariant _CommentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draft = widget.state.commentDraft;
    if (_textController.text != draft) {
      _textController.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('story-comment-field'),
              controller: _textController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '댓글',
                border: OutlineInputBorder(),
              ),
              onChanged: widget.controller.updateCommentDraft,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const ValueKey('story-comment-submit-button'),
              onPressed: widget.state.canSubmitComment
                  ? widget.controller.submitComment
                  : null,
              child: const Text('댓글 등록'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentList extends StatelessWidget {
  const _CommentList({
    required this.state,
    required this.controller,
  });

  final StoryState state;
  final StoryController controller;

  @override
  Widget build(BuildContext context) {
    if (state.comments.isEmpty) {
      return const AppStateView.empty(
        title: '아직 댓글이 없습니다.',
        semanticLabel: '스토리 댓글 비어 있음',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final comment in state.comments) ...[
          _CommentTile(
            comment: comment,
            state: state,
            controller: controller,
            depth: 0,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.state,
    required this.controller,
    required this.depth,
  });

  final StoryComment comment;
  final StoryState state;
  final StoryController controller;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final isEditing = state.editingCommentId == comment.id;
    final canEdit = comment.canEdit(controller.currentMemberId);

    return Padding(
      padding: EdgeInsets.only(left: depth * 18),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.authorNickname,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              if (isEditing) ...[
                TextFormField(
                  key: ValueKey('story-comment-edit-field-${comment.id}'),
                  initialValue: state.editingCommentContent,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  onChanged: controller.updateEditingCommentContent,
                ),
                const SizedBox(height: AppSpacing.xs),
                AppResponsiveActionWrap(
                  children: [
                    FilledButton.tonal(
                      key: ValueKey('story-comment-save-button-${comment.id}'),
                      onPressed: state.canSubmitCommentEdit
                          ? controller.submitCommentEdit
                          : null,
                      child: const Text('저장'),
                    ),
                    OutlinedButton(
                      onPressed: controller.cancelEditingComment,
                      child: const Text('취소'),
                    ),
                  ],
                ),
              ] else ...[
                _MentionText(
                  key: ValueKey('story-comment-content-${comment.id}'),
                  text: comment.content,
                ),
                if (comment.canReceiveReply) ...[
                  const SizedBox(height: AppSpacing.xs),
                  AppResponsiveActionWrap(
                    key: ValueKey('story-comment-action-row-${comment.id}'),
                    children: [
                      TextButton.icon(
                        key: ValueKey(
                            'story-comment-reply-button-${comment.id}'),
                        onPressed: state.isSubmitting
                            ? null
                            : () => controller.startReply(comment),
                        icon: const Icon(Icons.reply_outlined),
                        label: const Text('답글'),
                      ),
                      TextButton.icon(
                        key: ValueKey(
                            'story-comment-report-button-${comment.id}'),
                        onPressed: state.isSubmitting
                            ? null
                            : () => controller.selectCommentReportTarget(
                                  comment,
                                ),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('신고'),
                      ),
                      if (canEdit) ...[
                        TextButton.icon(
                          key: ValueKey(
                              'story-comment-edit-button-${comment.id}'),
                          onPressed: state.isSubmitting
                              ? null
                              : () => controller.startEditingComment(
                                    comment,
                                  ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('수정'),
                        ),
                        TextButton.icon(
                          key: ValueKey(
                              'story-comment-delete-button-${comment.id}'),
                          onPressed: state.isSubmitting
                              ? null
                              : () => controller.deleteComment(comment),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('삭제'),
                        ),
                      ],
                    ],
                  ),
                  if (state.activeReplyCommentId == comment.id) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ReplyComposer(
                      parentCommentId: comment.id,
                      draft: state.replyDrafts[comment.id] ?? '',
                      isSubmitting: state.isSubmitting,
                      canSubmit: state.canSubmitReply(comment.id),
                      onChanged: controller.updateReplyDraft,
                      onSubmit: controller.submitReply,
                      onCancel: controller.cancelReply,
                    ),
                  ],
                ],
              ],
              if (comment.replies.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                for (final reply in comment.replies) ...[
                  _CommentTile(
                    comment: reply,
                    state: state,
                    controller: controller,
                    depth: depth + 1,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyComposer extends StatefulWidget {
  const _ReplyComposer({
    required this.parentCommentId,
    required this.draft,
    required this.isSubmitting,
    required this.canSubmit,
    required this.onChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  final int parentCommentId;
  final String draft;
  final bool isSubmitting;
  final bool canSubmit;
  final void Function(int parentCommentId, String content) onChanged;
  final Future<void> Function(int parentCommentId) onSubmit;
  final void Function(int parentCommentId) onCancel;

  @override
  State<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends State<_ReplyComposer> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.draft);
  var _isSubmitting = false;

  @override
  void didUpdateWidget(covariant _ReplyComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.draft) {
      _controller.value = TextEditingValue(
        text: widget.draft,
        selection: TextSelection.collapsed(offset: widget.draft.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: ValueKey('story-reply-field-${widget.parentCommentId}'),
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '답글',
                border: OutlineInputBorder(),
              ),
              enabled: !widget.isSubmitting,
              onChanged: (content) => widget.onChanged(
                widget.parentCommentId,
                content,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppResponsiveActionWrap(
              children: [
                FilledButton.tonalIcon(
                  key: ValueKey(
                    'story-reply-submit-button-${widget.parentCommentId}',
                  ),
                  onPressed:
                      widget.canSubmit && !widget.isSubmitting && !_isSubmitting
                          ? _submit
                          : null,
                  icon: widget.isSubmitting || _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('답글 등록'),
                ),
                OutlinedButton.icon(
                  key: ValueKey(
                    'story-reply-cancel-button-${widget.parentCommentId}',
                  ),
                  onPressed: widget.isSubmitting
                      ? null
                      : () => widget.onCancel(widget.parentCommentId),
                  icon: const Icon(Icons.close),
                  label: const Text('취소'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(widget.parentCommentId);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _StoryEditorView extends StatelessWidget {
  const _StoryEditorView({
    required this.state,
    required this.controller,
  });

  final StoryState state;
  final StoryController controller;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      key: ValueKey('story-editor-${state.editingStoryId ?? 'new'}'),
      title: state.isEditingStory ? '스토리 수정' : '스토리 작성',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('story-title-field'),
            initialValue: state.storyTitle,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
            onChanged: controller.updateStoryTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey('story-content-field'),
            initialValue: state.storyContent,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: '본문',
              border: OutlineInputBorder(),
            ),
            onChanged: controller.updateStoryContent,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final category in StoryCategory.values.where(
                (category) => category != StoryCategory.all,
              ))
                ChoiceChip(
                  key: ValueKey('story-editor-category-${category.name}'),
                  label: Text(category.label),
                  selected: state.storyCategory == category,
                  onSelected: (_) => controller.updateStoryCategory(category),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppResponsiveActionWrap(
            children: [
              FilledButton(
                key: const ValueKey('story-submit-button'),
                onPressed: state.canSubmitStory ? controller.submitStory : null,
                child: Text(state.isEditingStory ? '수정 완료' : '등록'),
              ),
              OutlinedButton(
                key: const ValueKey('story-editor-cancel-button'),
                onPressed: controller.cancelEditor,
                child: const Text('취소'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MentionText extends StatelessWidget {
  const _MentionText({
    required this.text,
    super.key,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style;
    final mentionStyle = baseStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w800,
    );
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in _mentionPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: mentionStyle,
        ),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
    );
  }
}

final RegExp _mentionPattern = RegExp(r'@[0-9A-Za-z._\-가-힣]{2,30}');

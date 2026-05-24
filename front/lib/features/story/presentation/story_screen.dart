import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../application/story_controller.dart';
import '../domain/story_models.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({
    required this.controller,
    required this.onBack,
    super.key,
  });

  final StoryController controller;
  final VoidCallback onBack;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant StoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _loadIfNeeded();
    }
  }

  void _loadIfNeeded() {
    if (!widget.controller.state.hasLoaded) {
      Future<void>.microtask(widget.controller.loadStories);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;

        return AppScreen(
          title: '스토리',
          subtitle: '서로의 고민과 답변을 살펴봅니다.',
          onBack: widget.onBack,
          actions: [
            FilledButton.icon(
              key: const ValueKey('story-create-button'),
              onPressed: widget.controller.startCreate,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('글쓰기'),
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
        TextField(
          key: const ValueKey('story-search-field'),
          decoration: const InputDecoration(
            labelText: '제목 검색',
            border: OutlineInputBorder(),
          ),
          onChanged: controller.updateSearchQuery,
          onSubmitted: (_) => controller.loadStories(),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.tonal(
          key: const ValueKey('story-search-button'),
          onPressed: state.isListLoading ? null : controller.loadStories,
          child: const Text('검색'),
        ),
        const SizedBox(height: AppSpacing.md),
        _StoryCategoryFilter(
          selectedCategory: state.selectedCategory,
          onSelected: controller.selectCategory,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.isListLoading)
          const AppNotice(message: '스토리를 불러오는 중입니다.')
        else if (state.isEmpty)
          const AppNotice(message: '조건에 맞는 스토리가 없습니다.')
        else
          for (final story in state.stories) ...[
            _StoryListCard(
              story: story,
              onTap: () => controller.openStory(story),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
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
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final category in StoryCategory.values)
          ChoiceChip(
            key: ValueKey('story-category-${category.name}'),
            label: Text(category.label),
            selected: selectedCategory == category,
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
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('story-card-${story.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Pill(label: story.category.label),
                  _Pill(label: story.resolutionStatus.label),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                story.title,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                story.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${story.authorNickname} · 조회 ${story.viewCount}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
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
      return const AppNotice(message: '스토리를 불러오는 중입니다.');
    }

    if (story == null) {
      return const AppNotice(message: '스토리를 선택해 주세요.');
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
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    _Pill(label: story.category.label),
                    _Pill(label: story.resolutionStatus.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  story.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${story.authorNickname} · 조회 ${story.viewCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(story.content),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('story-report-button'),
                      onPressed: controller.selectStoryReportTarget,
                      child: const Text('신고'),
                    ),
                    if (canEdit) ...[
                      FilledButton.tonal(
                        key: const ValueKey('story-status-button'),
                        onPressed: state.isSubmitting
                            ? null
                            : controller.toggleSelectedResolutionStatus,
                        child: const Text('상태 변경'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('story-edit-button'),
                        onPressed: controller.startEditingSelectedStory,
                        child: const Text('수정'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('story-delete-button'),
                        onPressed: state.isSubmitting
                            ? null
                            : controller.deleteSelectedStory,
                        child: const Text('삭제'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _CommentComposer(state: state, controller: controller),
        const SizedBox(height: AppSpacing.md),
        _CommentList(state: state, controller: controller),
      ],
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
    if (widget.state.commentDraft.isEmpty && _textController.text.isNotEmpty) {
      _textController.clear();
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
      return const AppNotice(message: '아직 댓글이 없습니다.');
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
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
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
                Text(comment.content),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    TextButton(
                      key:
                          ValueKey('story-comment-report-button-${comment.id}'),
                      onPressed: () => controller.selectCommentReportTarget(
                        comment,
                      ),
                      child: const Text('신고'),
                    ),
                    if (canEdit) ...[
                      TextButton(
                        key:
                            ValueKey('story-comment-edit-button-${comment.id}'),
                        onPressed: () => controller.startEditingComment(
                          comment,
                        ),
                        child: const Text('수정'),
                      ),
                      TextButton(
                        key: ValueKey(
                            'story-comment-delete-button-${comment.id}'),
                        onPressed: state.isSubmitting
                            ? null
                            : () => controller.deleteComment(comment),
                        child: const Text('삭제'),
                      ),
                    ],
                  ],
                ),
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
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton(
                  key: const ValueKey('story-submit-button'),
                  onPressed:
                      state.canSubmitStory ? controller.submitStory : null,
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(label: label, tone: AppStatusTone.success);
  }
}

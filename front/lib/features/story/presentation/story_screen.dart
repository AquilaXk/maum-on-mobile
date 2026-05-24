import 'package:flutter/material.dart';

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
                      _StoryHeader(
                        onBack: widget.onBack,
                        onCreate: widget.controller.startCreate,
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

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({
    required this.onBack,
    required this.onCreate,
  });

  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('story-home-back-button'),
              tooltip: '홈으로',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '스토리',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            SizedBox(
              width: 96,
              child: FilledButton(
                key: const ValueKey('story-create-button'),
                onPressed: onCreate,
                child: const Text('글쓰기'),
              ),
            ),
          ],
        ),
      ],
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
        const SizedBox(height: 10),
        FilledButton.tonal(
          key: const ValueKey('story-search-button'),
          onPressed: state.isListLoading ? null : controller.loadStories,
          child: const Text('검색'),
        ),
        const SizedBox(height: 12),
        _StoryCategoryFilter(
          selectedCategory: state.selectedCategory,
          onSelected: controller.selectCategory,
        ),
        const SizedBox(height: 16),
        if (state.isListLoading)
          const _InlineNotice(message: '스토리를 불러오는 중입니다.')
        else if (state.isEmpty)
          const _InlineNotice(message: '조건에 맞는 스토리가 없습니다.')
        else
          for (final story in state.stories) ...[
            _StoryListCard(
              story: story,
              onTap: () => controller.openStory(story),
            ),
            const SizedBox(height: 10),
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
      spacing: 8,
      runSpacing: 8,
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
              const SizedBox(height: 8),
              Text(
                story.title,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                story.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
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
      return const _InlineNotice(message: '스토리를 불러오는 중입니다.');
    }

    if (story == null) {
      return const _InlineNotice(message: '스토리를 선택해 주세요.');
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
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Pill(label: story.category.label),
                    _Pill(label: story.resolutionStatus.label),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  story.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${story.authorNickname} · 조회 ${story.viewCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text(story.content),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
        const SizedBox(height: 18),
        _CommentComposer(state: state, controller: controller),
        const SizedBox(height: 14),
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
            const SizedBox(height: 10),
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
      return const _InlineNotice(message: '아직 댓글이 없습니다.');
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
          const SizedBox(height: 10),
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
              const SizedBox(height: 6),
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                const SizedBox(height: 10),
                for (final reply in comment.replies) ...[
                  _CommentTile(
                    comment: reply,
                    state: state,
                    controller: controller,
                    depth: depth + 1,
                  ),
                  const SizedBox(height: 8),
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
    return Card(
      key: ValueKey('story-editor-${state.editingStoryId ?? 'new'}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              state.isEditingStory ? '스토리 수정' : '스토리 작성',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('story-title-field'),
              initialValue: state.storyTitle,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              onChanged: controller.updateStoryTitle,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

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
          label,
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

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../../moderation/presentation/content_moderation_feedback_panel.dart';
import '../application/diary_controller.dart';
import '../domain/diary_models.dart';
import 'diary_image_picker.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    required this.controller,
    required this.imagePicker,
    required this.onBack,
    super.key,
  });

  final DiaryController controller;
  final DiaryImagePicker imagePicker;
  final VoidCallback onBack;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final GlobalKey _diaryFormAnchorKey = GlobalKey();
  final Map<String, TextEditingController> _textBlockControllers = {};
  bool _canOpenImageSettings = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.controller.state.title);
    _contentController =
        TextEditingController(text: widget.controller.state.content);
    widget.controller.addListener(_syncTextControllers);
    if (!widget.controller.state.hasLoaded &&
        !widget.controller.state.isLoading) {
      Future<void>.microtask(widget.controller.load);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTextControllers);
    _titleController.dispose();
    _contentController.dispose();
    for (final controller in _textBlockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncTextControllers() {
    _syncTextController(_titleController, widget.controller.state.title);
    final textBlocks = widget.controller.state.contentBlocks
        .where((block) => block.isText)
        .toList(growable: false);
    final primaryTextBlock = textBlocks.isEmpty ? null : textBlocks.first;
    _syncTextController(_contentController, primaryTextBlock?.text ?? '');

    final activeBlockIds = <String>{};
    for (final block in textBlocks) {
      if (block.id == primaryTextBlock?.id) {
        continue;
      }
      activeBlockIds.add(block.id);
      _syncTextController(_textControllerForBlock(block), block.text);
    }

    final staleBlockIds = _textBlockControllers.keys
        .where((blockId) => !activeBlockIds.contains(blockId))
        .toList(growable: false);
    for (final blockId in staleBlockIds) {
      _textBlockControllers.remove(blockId)?.dispose();
    }
  }

  void _syncTextController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  TextEditingController _textControllerForBlock(DiaryContentBlock block) {
    return _textBlockControllers.putIfAbsent(
      block.id,
      () => TextEditingController(text: block.text),
    );
  }

  Future<void> _pickImage(
    DiaryImageSource source, {
    String? replaceBlockId,
  }) async {
    setState(() {
      _canOpenImageSettings = false;
    });
    final result = await widget.imagePicker.pickImage(source);
    if (!mounted) {
      return;
    }

    switch (result.status) {
      case DiaryImagePickStatus.picked:
        final attachment = result.attachment;
        if (attachment == null) {
          widget.controller.showImageAttachmentFailure('이미지를 읽지 못했습니다.');
          return;
        }
        if (replaceBlockId == null) {
          widget.controller.attachImage(attachment);
        } else {
          widget.controller.replaceImageBlock(replaceBlockId, attachment);
        }
        return;
      case DiaryImagePickStatus.cancelled:
        return;
      case DiaryImagePickStatus.permissionDenied:
        setState(() {
          _canOpenImageSettings = result.canOpenSettings;
        });
        widget.controller.showImageAttachmentFailure(
          result.message ?? '${source.label} 권한이 허용되지 않았습니다.',
        );
        return;
      case DiaryImagePickStatus.tooLarge:
      case DiaryImagePickStatus.unsupportedFormat:
      case DiaryImagePickStatus.unavailable:
      case DiaryImagePickStatus.error:
        widget.controller.showImageAttachmentFailure(
          result.message ?? '이미지를 첨부하지 못했습니다.',
        );
        return;
    }
  }

  Future<void> _openImageSettings() async {
    final opened = await widget.imagePicker.openSettings();
    if (!opened) {
      widget.controller.showImageAttachmentFailure('설정 화면을 열지 못했습니다.');
    }
  }

  void _scrollToDiaryForm() {
    final formContext = _diaryFormAnchorKey.currentContext;
    if (formContext == null) {
      return;
    }

    unawaited(
      Scrollable.ensureVisible(
        formContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _confirmDelete(DiaryEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('기록을 삭제할까요?'),
          content: const Text('삭제한 기록은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              key: const ValueKey('diary-delete-cancel-button'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const ValueKey('diary-delete-confirm-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await widget.controller.deleteDiary(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;

        return AppScreen(
          title: '나의 기록',
          subtitle: _formatMonthLabel(state.visibleMonth),
          onBack: widget.onBack,
          onRefresh: widget.controller.load,
          actions: [
            IconButton(
              key: const ValueKey('diary-prev-month-button'),
              tooltip: '이전 달',
              onPressed: () => widget.controller.moveMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: const ValueKey('diary-next-month-button'),
              tooltip: '다음 달',
              onPressed: () => widget.controller.moveMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
          children: [
            if (state.moderationFeedback != null) ...[
              ContentModerationFeedbackPanel(
                feedback: state.moderationFeedback!,
                onRetry: widget.controller.submit,
                onDismiss: widget.controller.clearModerationFeedback,
              ),
              const SizedBox(height: AppSpacing.sm),
            ] else if (state.errorMessage != null) ...[
              AppNotice(
                message: state.errorMessage!,
                tone: AppNoticeTone.error,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (state.noticeMessage != null) ...[
              AppNotice(message: state.noticeMessage!),
              const SizedBox(height: AppSpacing.sm),
            ],
            _DiaryQuickCapturePanel(
              key: const ValueKey('diary-quick-capture-panel'),
              state: state,
              selectedDateLabel: _formatDateLabel(state.selectedDate),
              onWritePressed: _scrollToDiaryForm,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSectionCard(
              title: '월간 기록',
              child: _CalendarSection(
                state: state,
                onSelectDate: widget.controller.selectDate,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SelectedEntriesSection(
              entries: state.selectedDateEntries,
              selectedDateLabel: _formatDateLabel(state.selectedDate),
              onEdit: widget.controller.startEditing,
              onDelete: _confirmDelete,
            ),
            const SizedBox(height: AppSpacing.lg),
            _PublicEntriesSection(
              state: state,
              onLoadMore: widget.controller.loadMorePublicEntries,
            ),
            const SizedBox(height: AppSpacing.xl),
            KeyedSubtree(
              key: _diaryFormAnchorKey,
              child: _DiaryForm(
                state: state,
                titleController: _titleController,
                contentController: _contentController,
                textBlockControllerFor: _textControllerForBlock,
                onTitleChanged: widget.controller.updateTitle,
                onContentChanged: widget.controller.updateContent,
                onTextBlockChanged: widget.controller.updateTextBlock,
                onAddTextBlockAfter: widget.controller.addTextBlockAfter,
                onMoveBlock: widget.controller.moveContentBlock,
                onCategoryChanged: widget.controller.updateCategory,
                onPrivacyChanged: widget.controller.updatePrivacy,
                onPickImage: _pickImage,
                onReplaceImage: (blockId, source) =>
                    _pickImage(source, replaceBlockId: blockId),
                canOpenImageSettings: _canOpenImageSettings,
                onOpenImageSettings: _openImageSettings,
                onClearImage: () {
                  setState(() {
                    _canOpenImageSettings = false;
                  });
                  unawaited(widget.controller.clearImage());
                },
                onRemoveImageBlock: (blockId) {
                  setState(() {
                    _canOpenImageSettings = false;
                  });
                  unawaited(widget.controller.removeImageBlock(blockId));
                },
                onRetryImageBlock: widget.controller.retryImageBlockUpload,
                onReset: widget.controller.resetForm,
                onSubmit: widget.controller.submit,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiaryQuickCapturePanel extends StatelessWidget {
  const _DiaryQuickCapturePanel({
    required this.state,
    required this.selectedDateLabel,
    required this.onWritePressed,
    super.key,
  });

  final DiaryState state;
  final String selectedDateLabel;
  final VoidCallback onWritePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedCount = state.selectedDateEntries.length;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.primaryContainer.withValues(alpha: 0.68),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppStatusPill(label: selectedDateLabel),
                AppStatusPill(label: '선택한 날 $selectedCount개'),
                AppStatusPill(
                  label: state.isEditing ? '수정 중' : state.category.label,
                  tone: AppStatusTone.success,
                ),
                FilledButton.icon(
                  key: const ValueKey('diary-quick-write-button'),
                  onPressed: onWritePressed,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('오늘 기록 쓰기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({
    required this.state,
    required this.onSelectDate,
  });

  final DiaryState state;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final days = daysInMonth(state.visibleMonth);
    final counts = state.entryCountByDate;
    final firstWeekday = DateTime(
      state.visibleMonth.year,
      state.visibleMonth.month,
    ).weekday;
    final leadingSlots = firstWeekday == DateTime.sunday ? 0 : firstWeekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('일'),
            Text('월'),
            Text('화'),
            Text('수'),
            Text('목'),
            Text('금'),
            Text('토'),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.count(
          crossAxisCount: 7,
          childAspectRatio: 0.74,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var index = 0; index < leadingSlots; index += 1)
              const SizedBox.shrink(),
            for (final day in days)
              _CalendarDayButton(
                day: day,
                isSelected: dateKeyFromDate(day) == state.selectedDateKey,
                count: counts[dateKeyFromDate(day)] ?? 0,
                onTap: () => onSelectDate(day),
              ),
          ],
        ),
      ],
    );
  }
}

class _CalendarDayButton extends StatelessWidget {
  const _CalendarDayButton({
    required this.day,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  final DateTime day;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final dateKey = dateKeyFromDate(day);
    final semanticLabel = count > 0
        ? '${_formatDateLabel(day)}, 기록 $count개'
        : _formatDateLabel(day);

    return Semantics(
      key: ValueKey('diary-day-$dateKey'),
      button: true,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: isSelected ? colorScheme.primaryContainer : null,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${day.day}일',
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(height: 3),
                  _CalendarEntryMarker(
                    key: ValueKey('diary-day-$dateKey-entry-marker'),
                    isSelected: isSelected,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarEntryMarker extends StatelessWidget {
  const _CalendarEntryMarker({
    required this.isSelected,
    super.key,
  });

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.primary.withValues(alpha: 0.72),
        borderRadius: AppRadii.status,
      ),
      child: const SizedBox(width: 18, height: 5),
    );
  }
}

class _SelectedEntriesSection extends StatelessWidget {
  const _SelectedEntriesSection({
    required this.entries,
    required this.selectedDateLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final List<DiaryEntry> entries;
  final String selectedDateLabel;
  final ValueChanged<DiaryEntry> onEdit;
  final ValueChanged<DiaryEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('diary-selected-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInlineSectionHeader(
            icon: Icons.today_outlined,
            title: '선택한 날 기록',
            subtitle: selectedDateLabel,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (entries.isEmpty)
            const AppStateView.empty(
              title: '기록 없음',
              semanticLabel: '선택한 날짜 기록 비어 있음',
            )
          else
            for (final entry in entries) ...[
              AppContentCard(
                key: ValueKey('diary-entry-card-${entry.id}'),
                leadingIcon: Icons.edit_note_outlined,
                title: entry.title,
                subtitle: entry.createDate,
                badges: [
                  AppStatusPill(
                    label: entry.category.label,
                    tone: AppStatusTone.success,
                  ),
                  AppStatusPill(label: entry.isPrivate ? '나만 보기' : '공개'),
                ],
                content: _DiaryEntryContentPreview(entry: entry),
                actions: [
                  TextButton.icon(
                    onPressed: () => onEdit(entry),
                    icon: const Icon(Icons.edit),
                    label: const Text('수정'),
                  ),
                  TextButton.icon(
                    onPressed: () => onDelete(entry),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('삭제'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
        ],
      ),
    );
  }
}

class _PublicEntriesSection extends StatelessWidget {
  const _PublicEntriesSection({
    required this.state,
    required this.onLoadMore,
  });

  final DiaryState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('diary-public-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppInlineSectionHeader(
            icon: Icons.groups_outlined,
            title: '공개 기록',
          ),
          const SizedBox(height: AppSpacing.xs),
          if (state.isPublicLoading)
            const AppStateView.loading(
              title: '공개 기록을 불러오는 중입니다.',
              semanticLabel: '공개 기록 목록을 불러오는 중',
            )
          else ...[
            if (state.publicErrorMessage != null) ...[
              AppStateView.error(
                title: '공개 기록을 불러오지 못했습니다.',
                message: state.publicErrorMessage!,
                semanticLabel: '공개 기록 목록 오류',
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (state.isPublicEmpty)
              const AppStateView.empty(
                title: '공개 기록 없음',
                semanticLabel: '공개 기록 목록 비어 있음',
              ),
            for (final entry in state.publicEntries) ...[
              AppContentCard(
                key: ValueKey('diary-public-card-${entry.id}'),
                leadingIcon: Icons.groups_outlined,
                title: entry.title,
                subtitle: entry.nickname,
                badges: [
                  AppStatusPill(
                    label: entry.category.label,
                    tone: AppStatusTone.success,
                  ),
                ],
                content: _DiaryEntryContentPreview(entry: entry),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
          if (!state.isPublicLoading && state.publicEntries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            if (!state.isLastPublicPage)
              OutlinedButton.icon(
                key: const ValueKey('diary-public-load-more-button'),
                onPressed: state.isPublicLoadingMore ||
                        state.publicErrorMessage != null
                    ? null
                    : onLoadMore,
                icon: state.isPublicLoadingMore
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(state.isPublicLoadingMore ? '불러오는 중' : '더 보기'),
              ),
          ],
        ],
      ),
    );
  }
}

class _DiaryEntryContentPreview extends StatelessWidget {
  const _DiaryEntryContentPreview({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final blocks = entry.readableContentBlocks;
    final text = plainDiaryContentFromBlocks(blocks);
    final imageCount = blocks.where((block) => block.isImage).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty)
          Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
        if (imageCount > 0) ...[
          if (text.isNotEmpty) const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Chip(label: Text('이미지 $imageCount장')),
            ],
          ),
        ],
      ],
    );
  }
}

class _DiaryForm extends StatelessWidget {
  const _DiaryForm({
    required this.state,
    required this.titleController,
    required this.contentController,
    required this.textBlockControllerFor,
    required this.onTitleChanged,
    required this.onContentChanged,
    required this.onTextBlockChanged,
    required this.onAddTextBlockAfter,
    required this.onMoveBlock,
    required this.onCategoryChanged,
    required this.onPrivacyChanged,
    required this.onPickImage,
    required this.onReplaceImage,
    required this.canOpenImageSettings,
    required this.onOpenImageSettings,
    required this.onClearImage,
    required this.onRemoveImageBlock,
    required this.onRetryImageBlock,
    required this.onReset,
    required this.onSubmit,
  });

  final DiaryState state;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final TextEditingController Function(DiaryContentBlock block)
      textBlockControllerFor;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onContentChanged;
  final void Function(String blockId, String text) onTextBlockChanged;
  final ValueChanged<String> onAddTextBlockAfter;
  final void Function(String blockId, int delta) onMoveBlock;
  final ValueChanged<DiaryCategory> onCategoryChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final void Function(DiaryImageSource source) onPickImage;
  final void Function(String blockId, DiaryImageSource source) onReplaceImage;
  final bool canOpenImageSettings;
  final Future<void> Function() onOpenImageSettings;
  final VoidCallback onClearImage;
  final ValueChanged<String> onRemoveImageBlock;
  final ValueChanged<String> onRetryImageBlock;
  final VoidCallback onReset;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: state.isEditing ? '기록 수정하기' : '오늘의 기록',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              if (state.isEditing)
                IconButton(
                  key: const ValueKey('diary-edit-cancel-button'),
                  tooltip: '수정 취소',
                  onPressed: onReset,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('diary-title-field'),
            controller: titleController,
            onChanged: onTitleChanged,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ContentBlocksEditor(
            blocks: state.contentBlocks,
            primaryTextController: contentController,
            textBlockControllerFor: textBlockControllerFor,
            isUploadingImage: state.isUploadingImage,
            uploadProgress: state.imageUploadProgress,
            canOpenImageSettings: canOpenImageSettings,
            onPrimaryTextChanged: onContentChanged,
            onTextBlockChanged: onTextBlockChanged,
            onAddTextBlockAfter: onAddTextBlockAfter,
            onMoveBlock: onMoveBlock,
            onPickImage: onPickImage,
            onReplaceImage: onReplaceImage,
            onOpenImageSettings: onOpenImageSettings,
            onClearImage: onClearImage,
            onRemoveImageBlock: onRemoveImageBlock,
            onRetryImageBlock: onRetryImageBlock,
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<DiaryCategory>(
            key: ValueKey('diary-category-${state.category.name}'),
            initialValue: state.category,
            decoration: const InputDecoration(
              labelText: '카테고리',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final category in DiaryCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(category.label),
                ),
            ],
            onChanged: (category) {
              if (category != null) {
                onCategoryChanged(category);
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('나만 보기'),
            value: state.isPrivate,
            onChanged: onPrivacyChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('diary-submit-button'),
            onPressed: state.isSubmitting ? null : onSubmit,
            child: Text(
              state.isUploadingImage
                  ? '이미지 업로드 중'
                  : state.isSubmitting
                      ? '저장 중'
                      : '저장',
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentBlocksEditor extends StatelessWidget {
  const _ContentBlocksEditor({
    required this.blocks,
    required this.primaryTextController,
    required this.textBlockControllerFor,
    required this.isUploadingImage,
    required this.uploadProgress,
    required this.canOpenImageSettings,
    required this.onPrimaryTextChanged,
    required this.onTextBlockChanged,
    required this.onAddTextBlockAfter,
    required this.onMoveBlock,
    required this.onPickImage,
    required this.onReplaceImage,
    required this.onOpenImageSettings,
    required this.onClearImage,
    required this.onRemoveImageBlock,
    required this.onRetryImageBlock,
  });

  final List<DiaryContentBlock> blocks;
  final TextEditingController primaryTextController;
  final TextEditingController Function(DiaryContentBlock block)
      textBlockControllerFor;
  final bool isUploadingImage;
  final double? uploadProgress;
  final bool canOpenImageSettings;
  final ValueChanged<String> onPrimaryTextChanged;
  final void Function(String blockId, String text) onTextBlockChanged;
  final ValueChanged<String> onAddTextBlockAfter;
  final void Function(String blockId, int delta) onMoveBlock;
  final void Function(DiaryImageSource source) onPickImage;
  final void Function(String blockId, DiaryImageSource source) onReplaceImage;
  final Future<void> Function() onOpenImageSettings;
  final VoidCallback onClearImage;
  final ValueChanged<String> onRemoveImageBlock;
  final ValueChanged<String> onRetryImageBlock;

  @override
  Widget build(BuildContext context) {
    final textBlocks = blocks.where((block) => block.isText).toList();
    final primaryTextBlock = textBlocks.isEmpty ? null : textBlocks.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < blocks.length; index += 1) ...[
          if (blocks[index].isText)
            _TextBlockField(
              key: ValueKey('diary-text-block-widget-${blocks[index].id}'),
              block: blocks[index],
              controller: blocks[index].id == primaryTextBlock?.id
                  ? primaryTextController
                  : textBlockControllerFor(blocks[index]),
              isPrimary: blocks[index].id == primaryTextBlock?.id,
              canMoveUp: index > 0,
              canMoveDown: index < blocks.length - 1,
              onChanged: blocks[index].id == primaryTextBlock?.id
                  ? onPrimaryTextChanged
                  : (text) => onTextBlockChanged(blocks[index].id, text),
              onAddTextBlockAfter: () => onAddTextBlockAfter(blocks[index].id),
              onMoveUp: () => onMoveBlock(blocks[index].id, -1),
              onMoveDown: () => onMoveBlock(blocks[index].id, 1),
            )
          else
            _ImageBlockPanel(
              key: ValueKey('diary-image-block-widget-${blocks[index].id}'),
              block: blocks[index],
              isUploadingImage: isUploadingImage,
              uploadProgress: uploadProgress,
              canMoveUp: index > 0,
              canMoveDown: index < blocks.length - 1,
              onMoveUp: () => onMoveBlock(blocks[index].id, -1),
              onMoveDown: () => onMoveBlock(blocks[index].id, 1),
              onReplaceImage: (source) => onReplaceImage(
                blocks[index].id,
                source,
              ),
              onAddTextBlockAfter: () => onAddTextBlockAfter(blocks[index].id),
              onRetryImageBlock: () => onRetryImageBlock(blocks[index].id),
              onRemoveImageBlock: () => onRemoveImageBlock(blocks[index].id),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppResponsiveActionWrap(
          children: [
            OutlinedButton.icon(
              key: const ValueKey('diary-image-camera-button'),
              onPressed: isUploadingImage
                  ? null
                  : () => onPickImage(DiaryImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('촬영'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('diary-image-gallery-button'),
              onPressed: isUploadingImage
                  ? null
                  : () => onPickImage(DiaryImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('앨범'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('diary-clear-images-button'),
              onPressed:
                  blocks.any((block) => block.isImage) ? onClearImage : null,
              icon: const Icon(Icons.hide_image_outlined),
              label: const Text('이미지 모두 제거'),
            ),
          ],
        ),
        if (canOpenImageSettings) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('diary-image-settings-button'),
              onPressed: onOpenImageSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('권한 설정 열기'),
            ),
          ),
        ],
      ],
    );
  }
}

class _TextBlockField extends StatelessWidget {
  const _TextBlockField({
    required this.block,
    required this.controller,
    required this.isPrimary,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onChanged,
    required this.onAddTextBlockAfter,
    required this.onMoveUp,
    required this.onMoveDown,
    super.key,
  });

  final DiaryContentBlock block;
  final TextEditingController controller;
  final bool isPrimary;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<String> onChanged;
  final VoidCallback onAddTextBlockAfter;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: isPrimary
              ? const ValueKey('diary-content-field')
              : ValueKey('diary-text-block-${block.id}'),
          controller: controller,
          onChanged: onChanged,
          minLines: isPrimary ? 5 : 3,
          maxLines: isPrimary ? 8 : 6,
          decoration: InputDecoration(
            labelText: isPrimary ? '본문' : '추가 본문',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _BlockToolbar(
          canMoveUp: canMoveUp,
          canMoveDown: canMoveDown,
          onMoveUp: onMoveUp,
          onMoveDown: onMoveDown,
          trailing: TextButton.icon(
            key: ValueKey('diary-add-text-after-${block.id}'),
            onPressed: onAddTextBlockAfter,
            icon: const Icon(Icons.add),
            label: const Text('본문 추가'),
          ),
        ),
      ],
    );
  }
}

class _ImageBlockPanel extends StatelessWidget {
  const _ImageBlockPanel({
    required this.block,
    required this.isUploadingImage,
    required this.uploadProgress,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onReplaceImage,
    required this.onAddTextBlockAfter,
    required this.onRetryImageBlock,
    required this.onRemoveImageBlock,
    super.key,
  });

  final DiaryContentBlock block;
  final bool isUploadingImage;
  final double? uploadProgress;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<DiaryImageSource> onReplaceImage;
  final VoidCallback onAddTextBlockAfter;
  final VoidCallback onRetryImageBlock;
  final VoidCallback onRemoveImageBlock;

  @override
  Widget build(BuildContext context) {
    final image = block.image;
    final byteSize = block.displayByteSize;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(block.uploadStatus.label)),
                if (block.displaySource != null)
                  Chip(label: Text(block.displaySource!.label)),
                if (byteSize != null)
                  Chip(label: Text(_formatByteSize(byteSize))),
                if (image?.wasCompressed == true)
                  const Chip(label: Text('압축됨')),
              ],
            ),
            if (isUploadingImage &&
                block.uploadStatus ==
                    DiaryImageBlockUploadStatus.uploading) ...[
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(value: uploadProgress),
            ],
            const SizedBox(height: AppSpacing.xs),
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  Uint8List.fromList(image.bytes),
                  key: ValueKey('diary-image-preview-${block.id}'),
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _ImageFallbackLabel(filename: image.filename);
                  },
                ),
              )
            else if (block.imageUrl != null)
              const AppNotice(message: '기존 이미지가 유지됩니다.')
            else
              _ImageFallbackLabel(filename: block.displayFilename),
            if (block.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.xs),
              AppNotice(
                message: block.errorMessage!,
                tone: AppNoticeTone.error,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            _BlockToolbar(
              canMoveUp: canMoveUp,
              canMoveDown: canMoveDown,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
              trailing: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  IconButton(
                    key: ValueKey('diary-replace-gallery-${block.id}'),
                    tooltip: '앨범 이미지로 교체',
                    onPressed: isUploadingImage
                        ? null
                        : () => onReplaceImage(DiaryImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                  IconButton(
                    key: ValueKey('diary-replace-camera-${block.id}'),
                    tooltip: '촬영 이미지로 교체',
                    onPressed: isUploadingImage
                        ? null
                        : () => onReplaceImage(DiaryImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                  ),
                  if (block.uploadStatus == DiaryImageBlockUploadStatus.failed)
                    IconButton(
                      key: ValueKey('diary-retry-image-${block.id}'),
                      tooltip: '이미지 업로드 다시 시도',
                      onPressed: block.image == null ? null : onRetryImageBlock,
                      icon: const Icon(Icons.refresh),
                    ),
                  IconButton(
                    key: ValueKey('diary-remove-image-${block.id}'),
                    tooltip: '이미지 제거',
                    onPressed: isUploadingImage ? null : onRemoveImageBlock,
                    icon: const Icon(Icons.close),
                  ),
                  TextButton.icon(
                    key: ValueKey('diary-add-text-after-${block.id}'),
                    onPressed: onAddTextBlockAfter,
                    icon: const Icon(Icons.add),
                    label: const Text('본문 추가'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockToolbar extends StatelessWidget {
  const _BlockToolbar({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.trailing,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: '위로 이동',
          onPressed: canMoveUp ? onMoveUp : null,
          icon: const Icon(Icons.arrow_upward),
        ),
        IconButton(
          tooltip: '아래로 이동',
          onPressed: canMoveDown ? onMoveDown : null,
          icon: const Icon(Icons.arrow_downward),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: trailing,
          ),
        ),
      ],
    );
  }
}

class _ImageFallbackLabel extends StatelessWidget {
  const _ImageFallbackLabel({required this.filename});

  final String filename;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(filename, overflow: TextOverflow.ellipsis),
    );
  }
}

String _formatMonthLabel(DateTime date) {
  return '${date.year}년 ${date.month}월';
}

String _formatDateLabel(DateTime date) {
  return '${date.year}년 ${date.month}월 ${date.day}일';
}

String _formatByteSize(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).ceil()}KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

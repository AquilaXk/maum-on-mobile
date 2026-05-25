import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
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
    super.dispose();
  }

  void _syncTextControllers() {
    _syncTextController(_titleController, widget.controller.state.title);
    _syncTextController(_contentController, widget.controller.state.content);
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

  Future<void> _pickImage(DiaryImageSource source) async {
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
        widget.controller.attachImage(attachment);
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
            if (state.errorMessage != null) ...[
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
            _DiaryForm(
              state: state,
              titleController: _titleController,
              contentController: _contentController,
              onTitleChanged: widget.controller.updateTitle,
              onContentChanged: widget.controller.updateContent,
              onCategoryChanged: widget.controller.updateCategory,
              onPrivacyChanged: widget.controller.updatePrivacy,
              onPickImage: _pickImage,
              canOpenImageSettings: _canOpenImageSettings,
              onOpenImageSettings: _openImageSettings,
              onClearImage: () {
                setState(() {
                  _canOpenImageSettings = false;
                });
                unawaited(widget.controller.clearImage());
              },
              onReset: widget.controller.resetForm,
              onSubmit: widget.controller.submit,
            ),
          ],
        );
      },
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
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      key: ValueKey('diary-day-${dateKeyFromDate(day)}'),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: isSelected ? colorScheme.primaryContainer : null,
      ),
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}'),
          if (count > 0)
            Text(
              '$count',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(selectedDateLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        if (entries.isEmpty)
          const AppStateView.empty(
            title: '선택한 날짜에 작성한 기록이 없습니다.',
            message: '아래 입력 영역에서 오늘의 마음을 기록할 수 있습니다.',
            semanticLabel: '선택한 날짜 기록 비어 있음',
          )
        else
          for (final entry in entries) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(entry.content,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(label: Text(entry.category.label)),
                        Chip(label: Text(entry.isPrivate ? '나만 보기' : '공개')),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
      ],
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('공개 기록', style: theme.textTheme.titleMedium),
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
              title: '아직 공개된 기록이 없습니다.',
              message: '공개 기록이 생기면 이곳에 표시됩니다.',
              semanticLabel: '공개 기록 목록 비어 있음',
            ),
          for (final entry in state.publicEntries) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(label: Text(entry.category.label)),
                        Text(
                          entry.nickname,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(entry.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      entry.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
        if (!state.isPublicLoading && state.publicEntries.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          if (state.isLastPublicPage)
            const AppNotice(message: '마지막 공개 기록입니다.')
          else
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
    );
  }
}

class _DiaryForm extends StatelessWidget {
  const _DiaryForm({
    required this.state,
    required this.titleController,
    required this.contentController,
    required this.onTitleChanged,
    required this.onContentChanged,
    required this.onCategoryChanged,
    required this.onPrivacyChanged,
    required this.onPickImage,
    required this.canOpenImageSettings,
    required this.onOpenImageSettings,
    required this.onClearImage,
    required this.onReset,
    required this.onSubmit,
  });

  final DiaryState state;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onContentChanged;
  final ValueChanged<DiaryCategory> onCategoryChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<DiaryImageSource> onPickImage;
  final bool canOpenImageSettings;
  final Future<void> Function() onOpenImageSettings;
  final VoidCallback onClearImage;
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
          TextField(
            key: const ValueKey('diary-content-field'),
            controller: contentController,
            onChanged: onContentChanged,
            minLines: 5,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '본문',
              border: OutlineInputBorder(),
            ),
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
          _ImagePreview(
            selectedImage: state.selectedImage,
            imageUrl: state.imageUrl,
            isUploadingImage: state.isUploadingImage,
            uploadProgress: state.imageUploadProgress,
            onPickImage: onPickImage,
            canOpenImageSettings: canOpenImageSettings,
            onOpenImageSettings: onOpenImageSettings,
            onClearImage: onClearImage,
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

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.selectedImage,
    required this.imageUrl,
    required this.isUploadingImage,
    required this.uploadProgress,
    required this.onPickImage,
    required this.canOpenImageSettings,
    required this.onOpenImageSettings,
    required this.onClearImage,
  });

  final DiaryImageAttachment? selectedImage;
  final String? imageUrl;
  final bool isUploadingImage;
  final double? uploadProgress;
  final ValueChanged<DiaryImageSource> onPickImage;
  final bool canOpenImageSettings;
  final Future<void> Function() onOpenImageSettings;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    final image = selectedImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
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
        if (image != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Chip(label: Text(image.source.label)),
              Chip(label: Text(_formatByteSize(image.byteSize))),
              if (image.wasCompressed) const Chip(label: Text('압축됨')),
            ],
          ),
        ),
        if (isUploadingImage) ...[
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(value: uploadProgress),
        ],
        if (image != null) ...[
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              Uint8List.fromList(image.bytes),
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 80,
                  alignment: Alignment.center,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(image.filename),
                );
              },
            ),
          ),
          TextButton.icon(
            onPressed: onClearImage,
            icon: const Icon(Icons.close),
            label: const Text('이미지 제거'),
          ),
        ] else if (imageUrl != null) ...[
          const SizedBox(height: AppSpacing.xs),
          const AppNotice(message: '기존 이미지가 유지됩니다.'),
          TextButton.icon(
            onPressed: onClearImage,
            icon: const Icon(Icons.close),
            label: const Text('이미지 제거'),
          ),
        ],
      ],
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

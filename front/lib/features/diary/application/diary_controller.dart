import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../draft_recovery/data/draft_recovery_repository.dart';
import '../../draft_recovery/domain/draft_recovery_models.dart';
import '../../moderation/data/content_moderation_repository.dart';
import '../../moderation/domain/content_moderation_models.dart';
import '../data/diary_image_repository.dart';
import '../data/diary_repository.dart';
import '../domain/diary_models.dart';

class DiaryState {
  const DiaryState({
    required this.visibleMonth,
    required this.selectedDate,
    this.entries = const [],
    this.publicEntries = const [],
    this.isLoading = false,
    this.isPublicLoading = false,
    this.isPublicLoadingMore = false,
    this.publicPage = 0,
    this.isLastPublicPage = true,
    this.isSubmitting = false,
    this.isUploadingImage = false,
    this.imageUploadProgress,
    this.hasLoaded = false,
    this.editingDiaryId,
    this.title = '',
    this.content = '',
    this.category = DiaryCategory.daily,
    this.isPrivate = true,
    this.imageUrl,
    this.selectedImage,
    this.contentBlocks = const [
      DiaryContentBlock(id: 'text-0', type: DiaryContentBlockType.text),
    ],
    this.errorMessage,
    this.publicErrorMessage,
    this.noticeMessage,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<DiaryEntry> entries;
  final List<DiaryEntry> publicEntries;
  final bool isLoading;
  final bool isPublicLoading;
  final bool isPublicLoadingMore;
  final int publicPage;
  final bool isLastPublicPage;
  final bool isSubmitting;
  final bool isUploadingImage;
  final double? imageUploadProgress;
  final bool hasLoaded;
  final int? editingDiaryId;
  final String title;
  final String content;
  final DiaryCategory category;
  final bool isPrivate;
  final String? imageUrl;
  final DiaryImageAttachment? selectedImage;
  final List<DiaryContentBlock> contentBlocks;
  final String? errorMessage;
  final String? publicErrorMessage;
  final String? noticeMessage;

  bool get isPublicEmpty =>
      hasLoaded &&
      !isPublicLoading &&
      !isPublicLoadingMore &&
      publicErrorMessage == null &&
      publicEntries.isEmpty;

  bool get canLoadMorePublicEntries {
    return hasLoaded &&
        publicEntries.isNotEmpty &&
        !isPublicLoading &&
        !isPublicLoadingMore &&
        !isLastPublicPage &&
        publicErrorMessage == null;
  }

  String get visibleMonthKey => monthKeyFromDate(visibleMonth);

  String get selectedDateKey => dateKeyFromDate(selectedDate);

  bool get isEditing => editingDiaryId != null;

  List<DiaryContentBlock> get imageBlocks {
    return contentBlocks
        .where((block) => block.isImage)
        .toList(growable: false);
  }

  bool get hasUploadableImage {
    return imageBlocks.any((block) => block.image != null);
  }

  bool get canSubmit =>
      title.trim().isNotEmpty &&
      plainDiaryContentFromBlocks(contentBlocks).trim().isNotEmpty &&
      !isSubmitting &&
      !isUploadingImage;

  List<DiaryEntry> get selectedDateEntries {
    return entries
        .where((entry) => entry.dateKey == selectedDateKey)
        .toList(growable: false);
  }

  Map<String, int> get entryCountByDate {
    final counts = <String, int>{};
    for (final entry in entries) {
      counts[entry.dateKey] = (counts[entry.dateKey] ?? 0) + 1;
    }
    return counts;
  }

  DiaryState copyWith({
    DateTime? visibleMonth,
    DateTime? selectedDate,
    List<DiaryEntry>? entries,
    List<DiaryEntry>? publicEntries,
    bool? isLoading,
    bool? isPublicLoading,
    bool? isPublicLoadingMore,
    int? publicPage,
    bool? isLastPublicPage,
    bool? isSubmitting,
    bool? isUploadingImage,
    double? imageUploadProgress,
    bool clearImageUploadProgress = false,
    bool? hasLoaded,
    int? editingDiaryId,
    bool clearEditingDiaryId = false,
    String? title,
    String? content,
    DiaryCategory? category,
    bool? isPrivate,
    String? imageUrl,
    bool clearImageUrl = false,
    DiaryImageAttachment? selectedImage,
    bool clearSelectedImage = false,
    List<DiaryContentBlock>? contentBlocks,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? publicErrorMessage,
    bool clearPublicErrorMessage = false,
    String? noticeMessage,
    bool clearNoticeMessage = false,
  }) {
    return DiaryState(
      visibleMonth: visibleMonth ?? this.visibleMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      entries: entries ?? this.entries,
      publicEntries: publicEntries ?? this.publicEntries,
      isLoading: isLoading ?? this.isLoading,
      isPublicLoading: isPublicLoading ?? this.isPublicLoading,
      isPublicLoadingMore: isPublicLoadingMore ?? this.isPublicLoadingMore,
      publicPage: publicPage ?? this.publicPage,
      isLastPublicPage: isLastPublicPage ?? this.isLastPublicPage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      imageUploadProgress: clearImageUploadProgress
          ? null
          : imageUploadProgress ?? this.imageUploadProgress,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      editingDiaryId:
          clearEditingDiaryId ? null : editingDiaryId ?? this.editingDiaryId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      isPrivate: isPrivate ?? this.isPrivate,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      selectedImage:
          clearSelectedImage ? null : selectedImage ?? this.selectedImage,
      contentBlocks: contentBlocks ?? this.contentBlocks,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      publicErrorMessage: clearPublicErrorMessage
          ? null
          : publicErrorMessage ?? this.publicErrorMessage,
      noticeMessage:
          clearNoticeMessage ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

class DiaryController extends ChangeNotifier {
  DiaryController({
    required DiaryRepository diaryRepository,
    required DiaryImageRepository imageRepository,
    ContentModerationRepository? moderationRepository,
    int currentMemberId = 0,
    DraftRecoveryRepository? draftRepository,
    DateTime? now,
    VoidCallback? onUnauthorized,
  })  : _diaryRepository = diaryRepository,
        _imageRepository = imageRepository,
        _moderationRepository = moderationRepository,
        _currentMemberId = currentMemberId,
        _draftRepository = draftRepository,
        _onUnauthorized = onUnauthorized,
        _state = DiaryState(
          visibleMonth: firstDayOfMonth(now ?? DateTime.now()),
          selectedDate: now ?? DateTime.now(),
        );

  final DiaryRepository _diaryRepository;
  final DiaryImageRepository _imageRepository;
  final ContentModerationRepository? _moderationRepository;
  final int _currentMemberId;
  final DraftRecoveryRepository? _draftRepository;
  final VoidCallback? _onUnauthorized;

  DiaryState _state;
  bool _isDisposed = false;
  int _nextBlockOrdinal = 1;
  final Set<String> _temporaryUploadedImageUrls = {};

  DiaryState get state => _state;

  DraftKey get _draftKey => DraftKey(
        memberId: _currentMemberId,
        surface: DraftSurface.diary,
      );

  Future<void> restoreDraft() async {
    final entry = await _draftRepository?.read(_draftKey);
    if (entry == null || entry.fields.isEmpty) {
      return;
    }

    final content = entry.fields['content'] ?? '';
    final imageUrl = entry.fields['imageUrl']?.isEmpty == true
        ? null
        : entry.fields['imageUrl'];
    final contentBlocks = decodeDiaryContentBlocks(
      entry.fields['contentBlocks'],
      fallbackContent: content,
      fallbackImageUrl: imageUrl,
    );
    _bumpNextBlockOrdinal(contentBlocks);
    _setState(
      _state.copyWith(
        title: entry.fields['title'] ?? '',
        content: plainDiaryContentFromBlocks(contentBlocks),
        category: _categoryFromDraft(entry.fields['category']),
        isPrivate: entry.fields['isPrivate'] != 'false',
        imageUrl: primaryDiaryImageUrlFromBlocks(contentBlocks),
        contentBlocks: contentBlocks,
        noticeMessage: '임시 저장된 기록을 복원했습니다.',
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> load() async {
    await _loadMonth(_state.visibleMonth);
  }

  Future<void> loadMorePublicEntries() async {
    if (!_state.canLoadMorePublicEntries) {
      return;
    }

    _setState(
      _state.copyWith(
        isPublicLoadingMore: true,
        clearPublicErrorMessage: true,
      ),
    );

    try {
      final page = await _diaryRepository.fetchPublicDiaries(
        page: _state.publicPage + 1,
        size: 20,
      );
      _setState(
        _state.copyWith(
          publicEntries: _mergePublicEntries(_state.publicEntries, page.items),
          publicPage: page.page,
          isLastPublicPage: page.last,
          isPublicLoadingMore: false,
          clearPublicErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          isPublicLoadingMore: false,
          publicErrorMessage: _messageFromError(
            error,
            '공개 기록을 더 불러오지 못했습니다.',
          ),
        ),
      );
    }
  }

  Future<void> moveMonth(int delta) async {
    final nextMonth = addMonths(_state.visibleMonth, delta);
    _setState(
      _state.copyWith(
        visibleMonth: firstDayOfMonth(nextMonth),
        selectedDate: firstDayOfMonth(nextMonth),
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
    await _loadMonth(nextMonth);
  }

  void selectDate(DateTime date) {
    _setState(_state.copyWith(selectedDate: date));
  }

  void updateTitle(String title) {
    _setState(_state.copyWith(title: title, clearErrorMessage: true));
    _saveDraft();
  }

  void updateContent(String content) {
    final contentBlocks = _updatePrimaryTextBlock(_state.contentBlocks, content);
    _setState(
      _state.copyWith(
        content: plainDiaryContentFromBlocks(contentBlocks),
        contentBlocks: contentBlocks,
        clearErrorMessage: true,
      ),
    );
    _saveDraft();
  }

  void updateTextBlock(String blockId, String text) {
    final contentBlocks = _state.contentBlocks
        .map(
          (block) => block.id == blockId && block.isText
              ? block.copyWith(text: text)
              : block,
        )
        .toList(growable: false);
    _setState(
      _state.copyWith(
        content: plainDiaryContentFromBlocks(contentBlocks),
        contentBlocks: ensureDiaryTextBlock(contentBlocks),
        clearErrorMessage: true,
      ),
    );
    _saveDraft();
  }

  void updateCategory(DiaryCategory category) {
    _setState(_state.copyWith(category: category));
    _saveDraft();
  }

  void updatePrivacy(bool isPrivate) {
    _setState(_state.copyWith(isPrivate: isPrivate));
    _saveDraft();
  }

  void addTextBlockAfter(String blockId) {
    final next = DiaryContentBlock.text(id: _nextBlockId('text'));
    final blocks = [..._state.contentBlocks];
    final index = blocks.indexWhere((block) => block.id == blockId);
    blocks.insert(index < 0 ? blocks.length : index + 1, next);
    _setState(
      _state.copyWith(
        contentBlocks: ensureDiaryTextBlock(blocks),
        noticeMessage: '본문 블록을 추가했습니다.',
        clearErrorMessage: true,
      ),
    );
    _saveDraft();
  }

  void attachImage(DiaryImageAttachment image) {
    final imageBlock = DiaryContentBlock.image(
      id: _nextBlockId('image'),
      image: image,
    );
    final contentBlocks = ensureDiaryTextBlock([
      ..._state.contentBlocks,
      imageBlock,
    ]);
    _setState(
      _state.copyWith(
        selectedImage: image,
        clearImageUrl: true,
        contentBlocks: contentBlocks,
        clearErrorMessage: true,
        noticeMessage: image.wasCompressed
            ? '이미지 용량을 줄여 첨부했습니다.'
            : '이미지를 첨부했습니다.',
      ),
    );
    _saveDraft();
  }

  void replaceImageBlock(String blockId, DiaryImageAttachment image) {
    final block = _findBlockById(blockId);
    if (block == null || !block.isImage) {
      return;
    }
    final temporaryUrl = _temporaryUploadedImageUrlIfTracked(block.imageUrl);
    final contentBlocks = _state.contentBlocks
        .map(
          (candidate) => candidate.id == blockId
              ? DiaryContentBlock.image(
                  id: candidate.id,
                  image: image,
                  uploadStatus: DiaryImageBlockUploadStatus.pending,
                )
              : candidate,
        )
        .toList(growable: false);
    final primaryImageUrl = primaryDiaryImageUrlFromBlocks(contentBlocks);
    _setState(
      _state.copyWith(
        selectedImage: image,
        imageUrl: primaryImageUrl,
        clearImageUrl: primaryImageUrl == null,
        contentBlocks: ensureDiaryTextBlock(contentBlocks),
        clearErrorMessage: true,
        noticeMessage: image.wasCompressed
            ? '이미지 용량을 줄여 교체했습니다.'
            : '이미지를 교체했습니다.',
      ),
    );
    _saveDraft();
    if (temporaryUrl != null) {
      unawaited(_deleteTemporaryImage(temporaryUrl));
    }
  }

  void retryImageBlockUpload(String blockId) {
    final contentBlocks = _state.contentBlocks
        .map(
          (block) => block.id == blockId && block.isImage
              ? block.copyWith(
                  uploadStatus: DiaryImageBlockUploadStatus.pending,
                  clearUploadProgress: true,
                  clearErrorMessage: true,
                )
              : block,
        )
        .toList(growable: false);
    _setState(
      _state.copyWith(
        contentBlocks: ensureDiaryTextBlock(contentBlocks),
        noticeMessage: '저장하면 이미지 업로드를 다시 시도합니다.',
        clearErrorMessage: true,
      ),
    );
    _saveDraft();
  }

  Future<void> removeImageBlock(String blockId) async {
    final block = _findBlockById(blockId);
    if (block == null || !block.isImage) {
      return;
    }
    final temporaryUrl = _temporaryUploadedImageUrlIfTracked(block.imageUrl);
    final contentBlocks = _state.contentBlocks
        .where((candidate) => candidate.id != blockId)
        .toList(growable: false);
    final primaryImageUrl = primaryDiaryImageUrlFromBlocks(contentBlocks);
    final selectedImage = _firstSelectedImage(contentBlocks);
    _setState(
      _state.copyWith(
        contentBlocks: ensureDiaryTextBlock(contentBlocks),
        imageUrl: primaryImageUrl,
        selectedImage: selectedImage,
        clearImageUrl: primaryImageUrl == null,
        clearSelectedImage: selectedImage == null,
        clearErrorMessage: true,
      ),
    );
    _saveDraft();
    if (temporaryUrl != null) {
      await _deleteTemporaryImage(temporaryUrl);
    }
  }

  void moveContentBlock(String blockId, int delta) {
    if (delta == 0 || _state.contentBlocks.length < 2) {
      return;
    }

    final blocks = [..._state.contentBlocks];
    final index = blocks.indexWhere((block) => block.id == blockId);
    if (index < 0) {
      return;
    }

    final nextIndex = (index + delta).clamp(0, blocks.length - 1).toInt();
    if (nextIndex == index) {
      return;
    }

    final block = blocks.removeAt(index);
    blocks.insert(nextIndex, block);
    final contentBlocks = ensureDiaryTextBlock(blocks);
    _setState(
      _state.copyWith(
        content: plainDiaryContentFromBlocks(contentBlocks),
        contentBlocks: contentBlocks,
        clearErrorMessage: true,
      ),
    );
    _saveDraft();
  }

  void showImageAttachmentFailure(String message) {
    _setState(
      _state.copyWith(
        errorMessage: message,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> clearImage() async {
    final temporaryUrls = _takeTemporaryUploadedImageUrlsIfCurrent();
    final contentBlocks = _state.contentBlocks
        .where((block) => !block.isImage)
        .toList(growable: false);
    _setState(
      _state.copyWith(
        clearSelectedImage: true,
        clearImageUrl: true,
        contentBlocks: ensureDiaryTextBlock(contentBlocks),
      ),
    );
    _saveDraft();
    for (final temporaryUrl in temporaryUrls) {
      await _deleteTemporaryImage(temporaryUrl);
    }
  }

  void startEditing(DiaryEntry entry) {
    final temporaryUrls = _takeTemporaryUploadedImageUrlsIfCurrent();
    final contentBlocks = ensureDiaryTextBlock(entry.readableContentBlocks);
    _bumpNextBlockOrdinal(contentBlocks);
    _setState(
      _state.copyWith(
        editingDiaryId: entry.id,
        title: entry.title,
        content: plainDiaryContentFromBlocks(contentBlocks),
        category: entry.category,
        isPrivate: entry.isPrivate,
        imageUrl: primaryDiaryImageUrlFromBlocks(contentBlocks),
        contentBlocks: contentBlocks,
        clearSelectedImage: true,
        noticeMessage: '수정 모드로 전환되었습니다.',
        clearErrorMessage: true,
      ),
    );
    for (final temporaryUrl in temporaryUrls) {
      unawaited(_deleteTemporaryImage(temporaryUrl));
    }
  }

  void resetForm() {
    final temporaryUrls = _takeTemporaryUploadedImageUrlsIfCurrent();
    _nextBlockOrdinal = 1;
    _setState(
      _state.copyWith(
        clearEditingDiaryId: true,
        title: '',
        content: '',
        category: DiaryCategory.daily,
        isPrivate: true,
        clearImageUrl: true,
        clearSelectedImage: true,
        contentBlocks: const [
          DiaryContentBlock(id: 'text-0', type: DiaryContentBlockType.text),
        ],
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
    unawaited(_draftRepository?.delete(_draftKey));
    for (final temporaryUrl in temporaryUrls) {
      unawaited(_deleteTemporaryImage(temporaryUrl));
    }
  }

  Future<void> submit() async {
    if (_state.isSubmitting) {
      return;
    }

    final title = _state.title.trim();
    final contentBlocks = ensureDiaryTextBlock(_state.contentBlocks);
    final content = plainDiaryContentFromBlocks(contentBlocks).trim();
    if (title.isEmpty || content.isEmpty) {
      _setState(
        _state.copyWith(
          errorMessage: '제목과 본문을 입력해 주세요.',
          clearNoticeMessage: true,
        ),
      );
      return;
    }

    final editingId = _state.editingDiaryId;

    _setState(
      _state.copyWith(
        isSubmitting: true,
        isUploadingImage: false,
        clearImageUploadProgress: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      if (!await _ensureModerationAllowed('$title\n$content')) {
        return;
      }

      final uploadedBlocks = await _uploadImageBlocksIfNeeded();
      final uploadedImageUrl = primaryDiaryImageUrlFromBlocks(uploadedBlocks);
      final draft = DiaryDraft(
        title: title,
        content: content,
        category: _state.category,
        isPrivate: _state.isPrivate,
        imageUrl: uploadedImageUrl,
        contentBlocks: uploadedBlocks,
      );

      if (editingId == null) {
        await _diaryRepository.createDiary(draft);
      } else {
        await _diaryRepository.updateDiary(editingId, draft);
      }

      await _draftRepository?.delete(_draftKey);
      _resetFormSilently();
      await _loadMonth(_state.visibleMonth, showLoading: false);
      _setState(
        _state.copyWith(
          isSubmitting: false,
          isUploadingImage: false,
          clearImageUploadProgress: true,
          noticeMessage:
              editingId == null ? '오늘의 기록이 저장되었습니다.' : '기록이 수정되었습니다.',
        ),
      );
    } on Object catch (error) {
      await _markDraftFailed(error);
      _handleError(
        error,
        nextAction: !_state.hasUploadableImage
            ? '잠시 후 다시 저장해 주세요.'
            : '선택한 이미지는 유지됩니다. 다시 저장해 주세요.',
      );
      _setState(
        _state.copyWith(
          isSubmitting: false,
          isUploadingImage: false,
          clearImageUploadProgress: true,
        ),
      );
    }
  }

  Future<List<DiaryContentBlock>> _uploadImageBlocksIfNeeded() async {
    var blocks = ensureDiaryTextBlock(_state.contentBlocks);
    final uploadIndexes = <int>[
      for (var index = 0; index < blocks.length; index += 1)
        if (blocks[index].isImage && blocks[index].image != null) index,
    ];
    if (uploadIndexes.isEmpty) {
      return blocks;
    }

    for (var order = 0; order < uploadIndexes.length; order += 1) {
      final index = uploadIndexes[order];
      final block = blocks[index];
      final image = block.image;
      if (image == null) {
        continue;
      }

      blocks = _replaceBlockAt(
        blocks,
        index,
        block.copyWith(
          uploadStatus: DiaryImageBlockUploadStatus.uploading,
          uploadProgress: order / uploadIndexes.length,
          clearErrorMessage: true,
        ),
      );
      _setState(
        _state.copyWith(
          contentBlocks: blocks,
          isUploadingImage: true,
          imageUploadProgress: order / uploadIndexes.length,
          clearErrorMessage: true,
        ),
      );

      try {
        final uploadedImage = await _imageRepository.uploadImage(image);
        _temporaryUploadedImageUrls.add(uploadedImage.imageUrl);
        blocks = _replaceBlockAt(
          blocks,
          index,
          block.copyWith(
            imageUrl: uploadedImage.imageUrl,
            clearImage: true,
            uploadStatus: DiaryImageBlockUploadStatus.uploaded,
            uploadProgress: 1.0,
            clearErrorMessage: true,
            filename: image.filename,
            byteSize: image.byteSize,
            source: image.source,
            contentType: image.contentType,
          ),
        );
        final primaryImageUrl = primaryDiaryImageUrlFromBlocks(blocks);
        final selectedImage = _firstSelectedImage(blocks);
        _setState(
          _state.copyWith(
            imageUrl: primaryImageUrl,
            selectedImage: selectedImage,
            clearSelectedImage: selectedImage == null,
            contentBlocks: blocks,
            isUploadingImage: order < uploadIndexes.length - 1,
            imageUploadProgress: (order + 1) / uploadIndexes.length,
          ),
        );
      } on Object catch (error) {
        blocks = _replaceBlockAt(
          blocks,
          index,
          block.copyWith(
            uploadStatus: DiaryImageBlockUploadStatus.failed,
            clearUploadProgress: true,
            errorMessage: _messageFromError(error, '이미지 업로드에 실패했습니다.'),
          ),
        );
        _setState(
          _state.copyWith(
            contentBlocks: blocks,
            isUploadingImage: false,
            clearImageUploadProgress: true,
          ),
        );
        rethrow;
      }
    }

    final primaryImageUrl = primaryDiaryImageUrlFromBlocks(blocks);
    final selectedImage = _firstSelectedImage(blocks);
    _setState(
      _state.copyWith(
        imageUrl: primaryImageUrl,
        selectedImage: selectedImage,
        clearSelectedImage: selectedImage == null,
        contentBlocks: blocks,
        isUploadingImage: false,
        imageUploadProgress: 1.0,
      ),
    );
    return blocks;
  }

  Future<bool> _ensureModerationAllowed(String text) async {
    final repository = _moderationRepository;
    if (repository == null) {
      return true;
    }

    final result = await repository.reviewText(
      targetType: ContentModerationTarget.diary,
      text: text,
    );
    if (result.allowed) {
      if (result.riskLevel != ContentModerationRiskLevel.low) {
        _setState(_state.copyWith(noticeMessage: result.message));
      }
      return true;
    }

    _setState(
      _state.copyWith(
        isSubmitting: false,
        isUploadingImage: false,
        clearImageUploadProgress: true,
        errorMessage: result.message,
        clearNoticeMessage: true,
      ),
    );
    return false;
  }

  Future<void> deleteDiary(DiaryEntry entry) async {
    try {
      await _diaryRepository.deleteDiary(entry.id);
      await _loadMonth(_state.visibleMonth, showLoading: false);
      _setState(_state.copyWith(noticeMessage: '기록이 삭제되었습니다.'));
    } on Object catch (error) {
      _handleError(error);
    }
  }

  Future<void> _loadMonth(DateTime month, {bool showLoading = true}) async {
    if (showLoading) {
      _setState(
        _state.copyWith(
          isLoading: true,
          isPublicLoading: true,
          isPublicLoadingMore: false,
          clearErrorMessage: true,
          clearPublicErrorMessage: true,
          clearNoticeMessage: true,
        ),
      );
    }

    await _loadMyDiaries(month);
    await _loadPublicDiaries();

    _setState(
      _state.copyWith(
        isLoading: false,
        isPublicLoading: false,
        hasLoaded: true,
      ),
    );
  }

  Future<void> _loadMyDiaries(DateTime month) async {
    try {
      final page = await _diaryRepository.fetchDiaries(page: 0, size: 100);
      final monthKey = monthKeyFromDate(month);
      final filtered = page.items
          .where((entry) => entry.dateKey.startsWith(monthKey))
          .toList(growable: false);

      _setState(
        _state.copyWith(
          visibleMonth: firstDayOfMonth(month),
          entries: filtered,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
    }
  }

  Future<void> _loadPublicDiaries() async {
    try {
      final page = await _diaryRepository.fetchPublicDiaries(page: 0, size: 20);
      _setState(
        _state.copyWith(
          publicEntries: page.items,
          publicPage: page.page,
          isLastPublicPage: page.last,
          clearPublicErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          publicErrorMessage: _messageFromError(
            error,
            '공개 기록을 불러오지 못했습니다.',
          ),
        ),
      );
    }
  }

  void _resetFormSilently() {
    _temporaryUploadedImageUrls.clear();
    _nextBlockOrdinal = 1;
    _state = _state.copyWith(
      clearEditingDiaryId: true,
      title: '',
      content: '',
      category: DiaryCategory.daily,
      isPrivate: true,
      clearImageUrl: true,
      clearSelectedImage: true,
      contentBlocks: const [
        DiaryContentBlock(id: 'text-0', type: DiaryContentBlockType.text),
      ],
      isUploadingImage: false,
      clearImageUploadProgress: true,
    );
  }

  void _saveDraft() {
    final repository = _draftRepository;
    if (repository == null) {
      return;
    }
    unawaited(repository.saveEditing(_draftKey, fields: _draftFields()));
  }

  Future<void> _markDraftFailed(Object error) async {
    final repository = _draftRepository;
    if (repository == null) {
      return;
    }
    await repository.markFailed(
      _draftKey,
      fields: _draftFields(),
      failureMessage: _messageFromError(error, '요청을 처리하지 못했습니다.'),
    );
  }

  Map<String, String> _draftFields() {
    final selectedImage = _state.selectedImage;
    return {
      'title': _state.title,
      'content': plainDiaryContentFromBlocks(_state.contentBlocks),
      'contentBlocks': encodeDiaryContentBlocks(_state.contentBlocks),
      'category': _state.category.name,
      'isPrivate': _state.isPrivate.toString(),
      'imageUrl': primaryDiaryImageUrlFromBlocks(_state.contentBlocks) ?? '',
      'imageFilename': selectedImage?.filename ?? '',
      'imageByteLength': selectedImage?.bytes.length.toString() ?? '',
      'imageSource': selectedImage?.source.name ?? '',
      'imageContentType': selectedImage?.contentType ?? '',
    };
  }

  DiaryCategory _categoryFromDraft(String? value) {
    return DiaryCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => DiaryCategory.daily,
    );
  }

  Future<void> _deleteTemporaryImage(String imageUrl) async {
    try {
      await _imageRepository.deleteImage(imageUrl);
    } on Object {
      // 사용자가 화면을 계속 조작할 수 있도록 임시 파일 정리 실패는 저장 흐름과 분리한다.
    }
  }

  DiaryContentBlock? _findBlockById(String blockId) {
    for (final block in _state.contentBlocks) {
      if (block.id == blockId) {
        return block;
      }
    }

    return null;
  }

  List<String> _takeTemporaryUploadedImageUrlsIfCurrent() {
    final currentUrls = _state.contentBlocks
        .where((block) => block.isImage)
        .map((block) => block.imageUrl)
        .whereType<String>()
        .toSet();
    final temporaryUrls = _temporaryUploadedImageUrls
        .where((url) => currentUrls.contains(url))
        .toList(growable: false);
    _temporaryUploadedImageUrls.removeAll(temporaryUrls);
    return temporaryUrls;
  }

  String? _temporaryUploadedImageUrlIfTracked(String? imageUrl) {
    if (imageUrl == null || !_temporaryUploadedImageUrls.remove(imageUrl)) {
      return null;
    }

    return imageUrl;
  }

  String _nextBlockId(String prefix) {
    final id = '$prefix-$_nextBlockOrdinal';
    _nextBlockOrdinal += 1;
    return id;
  }

  void _bumpNextBlockOrdinal(List<DiaryContentBlock> blocks) {
    for (final block in blocks) {
      final segments = block.id.split('-');
      final ordinal = int.tryParse(segments.last);
      if (ordinal != null && ordinal >= _nextBlockOrdinal) {
        _nextBlockOrdinal = ordinal + 1;
      }
    }
  }

  void _handleError(
    Object error, {
    bool clearSelectedImage = false,
    String? nextAction,
  }) {
    if (error is ApiClientException) {
      if (error.kind == ApiErrorKind.unauthorized) {
        _onUnauthorized?.call();
      }
      _setState(
        _state.copyWith(
          errorMessage: _errorMessageWithAction(error.message, nextAction),
          clearSelectedImage: clearSelectedImage,
          clearNoticeMessage: true,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        errorMessage: _errorMessageWithAction(
          '요청을 처리하지 못했습니다.',
          nextAction,
        ),
        clearSelectedImage: clearSelectedImage,
        clearNoticeMessage: true,
      ),
    );
  }

  String _messageFromError(Object error, String fallback) {
    if (error is ApiClientException) {
      return error.message;
    }

    return fallback;
  }

  void _setState(DiaryState nextState) {
    if (_isDisposed) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  List<DiaryEntry> _mergePublicEntries(
    List<DiaryEntry> current,
    List<DiaryEntry> next,
  ) {
    final seenIds = current.map((entry) => entry.id).toSet();
    return [
      ...current,
      for (final entry in next)
        if (seenIds.add(entry.id)) entry,
    ];
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

List<DiaryContentBlock> _updatePrimaryTextBlock(
  List<DiaryContentBlock> blocks,
  String content,
) {
  final normalized = ensureDiaryTextBlock(blocks);
  var didUpdate = false;
  final next = <DiaryContentBlock>[];
  for (final block in normalized) {
    if (!didUpdate && block.isText) {
      next.add(block.copyWith(text: content));
      didUpdate = true;
    } else {
      next.add(block);
    }
  }

  return ensureDiaryTextBlock(next);
}

List<DiaryContentBlock> _replaceBlockAt(
  List<DiaryContentBlock> blocks,
  int index,
  DiaryContentBlock block,
) {
  return [
    for (var current = 0; current < blocks.length; current += 1)
      current == index ? block : blocks[current],
  ];
}

DiaryImageAttachment? _firstSelectedImage(List<DiaryContentBlock> blocks) {
  for (final block in blocks) {
    final image = block.image;
    if (block.isImage && image != null) {
      return image;
    }
  }

  return null;
}

String _errorMessageWithAction(String message, String? nextAction) {
  final trimmedMessage = message.trim();
  final trimmedAction = nextAction?.trim() ?? '';
  if (trimmedAction.isEmpty) {
    return trimmedMessage.isEmpty ? '요청을 처리하지 못했습니다.' : trimmedMessage;
  }

  final base =
      trimmedMessage.isEmpty ? '요청을 처리하지 못했습니다.' : trimmedMessage;
  return '$base $trimmedAction';
}

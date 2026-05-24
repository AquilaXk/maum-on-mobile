import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../data/diary_repository.dart';
import '../domain/diary_models.dart';

class DiaryState {
  const DiaryState({
    required this.visibleMonth,
    required this.selectedDate,
    this.entries = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.hasLoaded = false,
    this.editingDiaryId,
    this.title = '',
    this.content = '',
    this.category = DiaryCategory.daily,
    this.isPrivate = true,
    this.imageUrl,
    this.selectedImage,
    this.errorMessage,
    this.noticeMessage,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<DiaryEntry> entries;
  final bool isLoading;
  final bool isSubmitting;
  final bool hasLoaded;
  final int? editingDiaryId;
  final String title;
  final String content;
  final DiaryCategory category;
  final bool isPrivate;
  final String? imageUrl;
  final DiaryImageAttachment? selectedImage;
  final String? errorMessage;
  final String? noticeMessage;

  String get visibleMonthKey => monthKeyFromDate(visibleMonth);

  String get selectedDateKey => dateKeyFromDate(selectedDate);

  bool get isEditing => editingDiaryId != null;

  bool get canSubmit =>
      title.trim().isNotEmpty && content.trim().isNotEmpty && !isSubmitting;

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
    bool? isLoading,
    bool? isSubmitting,
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
    String? errorMessage,
    bool clearErrorMessage = false,
    String? noticeMessage,
    bool clearNoticeMessage = false,
  }) {
    return DiaryState(
      visibleMonth: visibleMonth ?? this.visibleMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
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
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      noticeMessage:
          clearNoticeMessage ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

class DiaryController extends ChangeNotifier {
  DiaryController({
    required DiaryRepository diaryRepository,
    DateTime? now,
    VoidCallback? onUnauthorized,
  })  : _diaryRepository = diaryRepository,
        _onUnauthorized = onUnauthorized,
        _state = DiaryState(
          visibleMonth: firstDayOfMonth(now ?? DateTime.now()),
          selectedDate: now ?? DateTime.now(),
        );

  final DiaryRepository _diaryRepository;
  final VoidCallback? _onUnauthorized;

  DiaryState _state;
  bool _isDisposed = false;

  DiaryState get state => _state;

  Future<void> load() async {
    await _loadMonth(_state.visibleMonth);
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
  }

  void updateContent(String content) {
    _setState(_state.copyWith(content: content, clearErrorMessage: true));
  }

  void updateCategory(DiaryCategory category) {
    _setState(_state.copyWith(category: category));
  }

  void updatePrivacy(bool isPrivate) {
    _setState(_state.copyWith(isPrivate: isPrivate));
  }

  void attachImage(DiaryImageAttachment image) {
    _setState(
      _state.copyWith(
        selectedImage: image,
        clearImageUrl: true,
        clearErrorMessage: true,
      ),
    );
  }

  void clearImage() {
    _setState(_state.copyWith(clearSelectedImage: true, clearImageUrl: true));
  }

  void startEditing(DiaryEntry entry) {
    _setState(
      _state.copyWith(
        editingDiaryId: entry.id,
        title: entry.title,
        content: entry.content,
        category: entry.category,
        isPrivate: entry.isPrivate,
        imageUrl: entry.imageUrl,
        clearSelectedImage: true,
        noticeMessage: '수정 모드로 전환되었습니다.',
        clearErrorMessage: true,
      ),
    );
  }

  void resetForm() {
    _setState(
      _state.copyWith(
        clearEditingDiaryId: true,
        title: '',
        content: '',
        category: DiaryCategory.daily,
        isPrivate: true,
        clearImageUrl: true,
        clearSelectedImage: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> submit() async {
    if (_state.isSubmitting) {
      return;
    }

    final title = _state.title.trim();
    final content = _state.content.trim();
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
    final draft = DiaryDraft(
      title: title,
      content: content,
      category: _state.category,
      isPrivate: _state.isPrivate,
      imageUrl: _state.imageUrl,
      image: _state.selectedImage,
    );

    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      if (editingId == null) {
        await _diaryRepository.createDiary(draft);
      } else {
        await _diaryRepository.updateDiary(editingId, draft);
      }

      _resetFormSilently();
      await _loadMonth(_state.visibleMonth, showLoading: false);
      _setState(
        _state.copyWith(
          isSubmitting: false,
          noticeMessage:
              editingId == null ? '오늘의 기록이 저장되었습니다.' : '기록이 수정되었습니다.',
        ),
      );
    } on Object catch (error) {
      _handleError(
        error,
        clearSelectedImage: draft.image != null,
        nextAction: draft.image == null
            ? '잠시 후 다시 저장해 주세요.'
            : '이미지를 다시 선택한 뒤 저장해 주세요.',
      );
      _setState(_state.copyWith(isSubmitting: false));
    }
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
          clearErrorMessage: true,
          clearNoticeMessage: true,
        ),
      );
    }

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
          isLoading: false,
          hasLoaded: true,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isLoading: false));
    }
  }

  void _resetFormSilently() {
    _state = _state.copyWith(
      clearEditingDiaryId: true,
      title: '',
      content: '',
      category: DiaryCategory.daily,
      isPrivate: true,
      clearImageUrl: true,
      clearSelectedImage: true,
    );
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

  void _setState(DiaryState nextState) {
    if (_isDisposed) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
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

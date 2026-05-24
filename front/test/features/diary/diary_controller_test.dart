import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/diary/application/diary_controller.dart';
import 'package:maum_on_mobile_front/features/diary/data/diary_repository.dart';
import 'package:maum_on_mobile_front/features/diary/domain/diary_models.dart';

void main() {
  group('DiaryController', () {
    test('loads current month entries and selected date details', () async {
      final controller = DiaryController(
        diaryRepository: _FakeDiaryRepository(
          pages: [
            _page([
              _entry(id: 1, title: '월요일', createDate: '2026-05-18T08:00:00'),
              _entry(id: 2, title: '다음달', createDate: '2026-06-01T08:00:00'),
            ]),
          ],
        ),
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      controller.selectDate(DateTime(2026, 5, 18));

      expect(controller.state.visibleMonthKey, '2026-05');
      expect(controller.state.entries, hasLength(1));
      expect(controller.state.selectedDateEntries.single.title, '월요일');
      expect(controller.state.isLoading, isFalse);
    });

    test('moves months and reloads the visible month', () async {
      final repository = _FakeDiaryRepository(
        pages: [
          _page(
              [_entry(id: 1, title: '5월', createDate: '2026-05-18T08:00:00')]),
          _page(
              [_entry(id: 2, title: '6월', createDate: '2026-06-01T08:00:00')]),
        ],
      );
      final controller = DiaryController(
        diaryRepository: repository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      await controller.moveMonth(1);

      expect(controller.state.visibleMonthKey, '2026-06');
      expect(controller.state.entries.single.title, '6월');
      expect(repository.fetchRequests, [
        const DiaryFetchRequest(page: 0, size: 100),
        const DiaryFetchRequest(page: 0, size: 100),
      ]);
    });

    test('creates a diary and refreshes the calendar', () async {
      final repository = _FakeDiaryRepository(
        pages: [
          _page([]),
          _page(
              [_entry(id: 9, title: '저장됨', createDate: '2026-05-20T12:00:00')]),
        ],
        createdId: 9,
      );
      final controller = DiaryController(
        diaryRepository: repository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      controller.updateTitle('저장됨');
      controller.updateContent('오늘의 마음입니다.');
      controller.updateCategory(DiaryCategory.daily);
      controller.updatePrivacy(false);
      await controller.submit();

      expect(repository.createdDrafts.single.title, '저장됨');
      expect(controller.state.entries.single.id, 9);
      expect(controller.state.noticeMessage, '오늘의 기록이 저장되었습니다.');
      expect(controller.state.isSubmitting, isFalse);
    });

    test('validates required draft fields before submit', () async {
      final repository = _FakeDiaryRepository(pages: [_page([])]);
      final controller = DiaryController(
        diaryRepository: repository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      await controller.submit();

      expect(repository.createdDrafts, isEmpty);
      expect(controller.state.errorMessage, '제목과 본문을 입력해 주세요.');
    });

    test('updates the editing diary and refreshes the calendar', () async {
      final original =
          _entry(id: 4, title: '원본', createDate: '2026-05-20T12:00:00');
      final repository = _FakeDiaryRepository(
        pages: [
          _page([original]),
          _page([original.copyWith(title: '수정됨')]),
        ],
      );
      final controller = DiaryController(
        diaryRepository: repository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      controller.startEditing(original);
      controller.updateTitle('수정됨');
      await controller.submit();

      expect(repository.updatedDrafts.single.id, 4);
      expect(repository.updatedDrafts.single.draft.title, '수정됨');
      expect(controller.state.entries.single.title, '수정됨');
    });

    test('deletes a diary and refreshes the calendar', () async {
      final deleted =
          _entry(id: 3, title: '삭제됨', createDate: '2026-05-20T12:00:00');
      final repository = _FakeDiaryRepository(
        pages: [
          _page([deleted]),
          _page([]),
        ],
      );
      final controller = DiaryController(
        diaryRepository: repository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      await controller.deleteDiary(deleted);

      expect(repository.deletedIds, [3]);
      expect(controller.state.entries, isEmpty);
      expect(controller.state.noticeMessage, '기록이 삭제되었습니다.');
    });

    test('stores image attachment in the draft before submit', () async {
      final repository = _FakeDiaryRepository(
        pages: [_page([]), _page([])],
        createdId: 11,
      );
      final controller = DiaryController(
        diaryRepository: repository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      controller.updateTitle('이미지 기록');
      controller.updateContent('첨부 포함');
      controller.attachImage(
        const DiaryImageAttachment(filename: 'mind.png', bytes: [9]),
      );
      await controller.submit();

      expect(repository.createdDrafts.single.image?.filename, 'mind.png');
      expect(controller.state.selectedImage?.filename, isNull);
    });

    test('clears temporary image and explains next action on upload failure',
        () async {
      final repository = _FakeDiaryRepository(
        pages: [_page([])],
        createError: const ApiClientException(
          kind: ApiErrorKind.server,
          message: '파일이 너무 큽니다.',
        ),
      );
      final controller = DiaryController(
        diaryRepository: repository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      controller.updateTitle('이미지 기록');
      controller.updateContent('첨부 포함');
      controller.attachImage(
        const DiaryImageAttachment(filename: 'mind.png', bytes: [9]),
      );
      await controller.submit();

      expect(controller.state.selectedImage, isNull);
      expect(controller.state.isSubmitting, isFalse);
      expect(
        controller.state.errorMessage,
        '파일이 너무 큽니다. 이미지를 다시 선택한 뒤 저장해 주세요.',
      );
    });

    test('invokes unauthorized callback on expired auth', () async {
      var unauthorizedCount = 0;
      final controller = DiaryController(
        diaryRepository: _FakeDiaryRepository(
          fetchError: const ApiClientException(
            kind: ApiErrorKind.unauthorized,
            message: '다시 로그인해 주세요.',
          ),
        ),
        now: DateTime(2026, 5, 20),
        onUnauthorized: () => unauthorizedCount += 1,
      );

      await controller.load();

      expect(unauthorizedCount, 1);
      expect(controller.state.errorMessage, '다시 로그인해 주세요.');
    });
  });
}

PageResponse<DiaryEntry> _page(List<DiaryEntry> items) {
  return PageResponse(
    items: items,
    page: 0,
    size: 100,
    totalElements: items.length,
    totalPages: 1,
    last: true,
  );
}

DiaryEntry _entry({
  required int id,
  required String title,
  required String createDate,
}) {
  return DiaryEntry(
    id: id,
    title: title,
    content: '본문입니다.',
    category: DiaryCategory.daily,
    nickname: '마음이',
    imageUrl: null,
    isPrivate: true,
    createDate: createDate,
    modifyDate: createDate,
  );
}

class _FakeDiaryRepository implements DiaryRepository {
  _FakeDiaryRepository({
    this.pages = const [],
    this.createdId = 1,
    this.fetchError,
    this.createError,
  });

  final List<PageResponse<DiaryEntry>> pages;
  final int createdId;
  final Object? fetchError;
  final Object? createError;
  final List<DiaryFetchRequest> fetchRequests = [];
  final List<DiaryDraft> createdDrafts = [];
  final List<({int id, DiaryDraft draft})> updatedDrafts = [];
  final List<int> deletedIds = [];

  @override
  Future<PageResponse<DiaryEntry>> fetchDiaries({
    int page = 0,
    int size = 100,
  }) async {
    fetchRequests.add(DiaryFetchRequest(page: page, size: size));
    final error = fetchError;
    if (error != null) {
      throw error;
    }
    return pages.removeAt(0);
  }

  @override
  Future<DiaryEntry> fetchDiary(int id) {
    throw UnimplementedError();
  }

  @override
  Future<int> createDiary(DiaryDraft draft) async {
    final error = createError;
    if (error != null) {
      throw error;
    }
    createdDrafts.add(draft);
    return createdId;
  }

  @override
  Future<void> updateDiary(int id, DiaryDraft draft) async {
    updatedDrafts.add((id: id, draft: draft));
  }

  @override
  Future<void> deleteDiary(int id) async {
    deletedIds.add(id);
  }
}

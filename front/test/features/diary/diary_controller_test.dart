import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/diary/application/diary_controller.dart';
import 'package:maum_on_mobile_front/features/diary/data/diary_image_repository.dart';
import 'package:maum_on_mobile_front/features/diary/data/diary_repository.dart';
import 'package:maum_on_mobile_front/features/diary/domain/diary_models.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/data/draft_recovery_repository.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/domain/draft_recovery_models.dart';
import 'package:maum_on_mobile_front/features/moderation/data/content_moderation_repository.dart';
import 'package:maum_on_mobile_front/features/moderation/domain/content_moderation_models.dart';

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
          publicPages: [
            _page([
              _entry(
                id: 3,
                title: '공개 기록',
                createDate: '2026-05-19T08:00:00',
                isPrivate: false,
              ),
            ]),
          ],
        ),
        imageRepository: _FakeDiaryImageRepository(),
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      controller.selectDate(DateTime(2026, 5, 18));

      expect(controller.state.visibleMonthKey, '2026-05');
      expect(controller.state.entries, hasLength(1));
      expect(controller.state.selectedDateEntries.single.title, '월요일');
      expect(controller.state.publicEntries.single.title, '공개 기록');
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.isPublicLoading, isFalse);
    });

    test('keeps my diary data visible when public diary load fails', () async {
      final controller = DiaryController(
        diaryRepository: _FakeDiaryRepository(
          pages: [
            _page([
              _entry(id: 1, title: '내 기록', createDate: '2026-05-20T08:00:00'),
            ]),
          ],
          publicFetchError: const ApiClientException(
            kind: ApiErrorKind.network,
            message: '공개 기록을 불러오지 못했습니다.',
          ),
        ),
        imageRepository: _FakeDiaryImageRepository(),
        now: DateTime(2026, 5, 20),
      );

      await controller.load();

      expect(controller.state.entries.single.title, '내 기록');
      expect(controller.state.publicEntries, isEmpty);
      expect(controller.state.publicErrorMessage, '공개 기록을 불러오지 못했습니다.');
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
        imageRepository: _FakeDiaryImageRepository(),
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
        imageRepository: _FakeDiaryImageRepository(),
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
        imageRepository: _FakeDiaryImageRepository(),
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      await controller.submit();

      expect(repository.createdDrafts, isEmpty);
      expect(controller.state.errorMessage, '제목과 본문을 입력해 주세요.');
    });

    test('blocks high-risk diary text before upload and save', () async {
      final repository = _FakeDiaryRepository(pages: [_page([])]);
      final imageRepository = _FakeDiaryImageRepository();
      final moderationRepository = _FakeContentModerationRepository(
        result: const ContentModerationResult(
          allowed: false,
          riskLevel: ContentModerationRiskLevel.high,
          message: '위험도가 높은 표현이 포함되어 수정이 필요합니다.',
          categories: [ContentModerationCategory.personalInfo],
        ),
      );
      final controller = DiaryController(
        diaryRepository: repository,
        imageRepository: imageRepository,
        moderationRepository: moderationRepository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      controller.updateTitle('연락처 기록');
      controller.updateContent('010-1234-5678');
      controller.attachImage(
        const DiaryImageAttachment(filename: 'mind.png', bytes: [9]),
      );
      await controller.submit();

      expect(repository.createdDrafts, isEmpty);
      expect(imageRepository.uploadedImages, isEmpty);
      expect(moderationRepository.requests.single.targetType,
          ContentModerationTarget.diary);
      expect(controller.state.errorMessage, '위험도가 높은 표현이 포함되어 수정이 필요합니다.');
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
        imageRepository: _FakeDiaryImageRepository(),
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
        imageRepository: _FakeDiaryImageRepository(),
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      await controller.deleteDiary(deleted);

      expect(repository.deletedIds, [3]);
      expect(controller.state.entries, isEmpty);
      expect(controller.state.noticeMessage, '기록이 삭제되었습니다.');
    });

    test('uploads selected image and saves diary with uploaded image URL',
        () async {
      final repository = _FakeDiaryRepository(
        pages: [_page([]), _page([])],
        createdId: 11,
      );
      final imageRepository = _FakeDiaryImageRepository(
        uploadedUrl: '/images/uploads/uploaded-mind.png',
      );
      final controller = DiaryController(
        diaryRepository: repository,
        imageRepository: imageRepository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      controller.updateTitle('이미지 기록');
      controller.updateContent('첨부 포함');
      controller.attachImage(
        const DiaryImageAttachment(filename: 'mind.png', bytes: [9]),
      );
      await controller.submit();

      expect(imageRepository.uploadedImages.single.filename, 'mind.png');
      expect(repository.createdDrafts.single.image, isNull);
      expect(
        repository.createdDrafts.single.imageUrl,
        '/images/uploads/uploaded-mind.png',
      );
      expect(controller.state.selectedImage?.filename, isNull);
    });

    test('keeps selected image and explains retry on upload failure',
        () async {
      final repository = _FakeDiaryRepository(pages: [_page([])]);
      final imageRepository = _FakeDiaryImageRepository(
        uploadError: const ApiClientException(
          kind: ApiErrorKind.server,
          message: '파일이 너무 큽니다.',
        ),
      );
      final controller = DiaryController(
        diaryRepository: repository,
        imageRepository: imageRepository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      controller.updateTitle('이미지 기록');
      controller.updateContent('첨부 포함');
      controller.attachImage(
        const DiaryImageAttachment(filename: 'mind.png', bytes: [9]),
      );
      await controller.submit();

      expect(repository.createdDrafts, isEmpty);
      expect(controller.state.selectedImage?.filename, 'mind.png');
      expect(controller.state.isSubmitting, isFalse);
      expect(
        controller.state.errorMessage,
        '파일이 너무 큽니다. 선택한 이미지는 유지됩니다. 다시 저장해 주세요.',
      );
    });

    test('deletes temporary uploaded image when user clears it after save failure',
        () async {
      final repository = _FakeDiaryRepository(
        pages: [_page([])],
        createError: const ApiClientException(
          kind: ApiErrorKind.server,
          message: '저장 실패',
        ),
      );
      final imageRepository = _FakeDiaryImageRepository(
        uploadedUrl: '/images/uploads/temp-mind.png',
      );
      final controller = DiaryController(
        diaryRepository: repository,
        imageRepository: imageRepository,
        now: DateTime(2026, 5, 20),
      );

      await controller.load();
      controller.updateTitle('이미지 기록');
      controller.updateContent('첨부 포함');
      controller.attachImage(
        const DiaryImageAttachment(filename: 'mind.png', bytes: [9]),
      );
      await controller.submit();
      await controller.clearImage();

      expect(imageRepository.deletedUrls, ['/images/uploads/temp-mind.png']);
      expect(controller.state.imageUrl, isNull);
    });

    test('restores member-scoped draft and marks failed diary for retry',
        () async {
      final draftRepository = StorageDraftRecoveryRepository(
        storage: MemoryDraftRecoveryStorage(),
      );
      const key = DraftKey(memberId: 7, surface: DraftSurface.diary);
      await draftRepository.saveEditing(
        key,
        fields: {
          'title': '임시 기록',
          'content': '닫았다가 다시 열어도 남을 내용',
          'category': 'etc',
          'isPrivate': 'false',
          'imageFilename': 'mind.png',
          'imageByteLength': '3',
        },
      );
      final controller = DiaryController(
        diaryRepository: _FakeDiaryRepository(
          pages: [_page([])],
          createError: const ApiClientException(
            kind: ApiErrorKind.network,
            message: '네트워크 연결을 확인해 주세요.',
          ),
        ),
        imageRepository: _FakeDiaryImageRepository(),
        currentMemberId: 7,
        draftRepository: draftRepository,
        now: DateTime(2026, 5, 20),
      );

      await controller.restoreDraft();

      expect(controller.state.title, '임시 기록');
      expect(controller.state.content, '닫았다가 다시 열어도 남을 내용');
      expect(controller.state.category, DiaryCategory.etc);
      expect(controller.state.isPrivate, isFalse);
      expect(controller.state.noticeMessage, contains('임시 저장'));

      await controller.submit();

      final failed = await draftRepository.listFailed(
        memberId: 7,
        surface: DraftSurface.diary,
      );
      expect(failed.single.fields['title'], '임시 기록');
      expect(failed.single.failureMessage, '네트워크 연결을 확인해 주세요.');
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
        imageRepository: _FakeDiaryImageRepository(),
        now: DateTime(2026, 5, 20),
        onUnauthorized: () => unauthorizedCount += 1,
      );

      await controller.load();

      expect(unauthorizedCount, 1);
      expect(controller.state.errorMessage, '다시 로그인해 주세요.');
    });
  });
}

class _FakeDiaryImageRepository implements DiaryImageRepository {
  _FakeDiaryImageRepository({
    this.uploadedUrl = '/images/uploads/mind.png',
    this.uploadError,
  });

  final String uploadedUrl;
  final Object? uploadError;
  final List<DiaryImageAttachment> uploadedImages = [];
  final List<String> deletedUrls = [];

  @override
  Future<UploadedDiaryImage> uploadImage(DiaryImageAttachment image) async {
    uploadedImages.add(image);
    final error = uploadError;
    if (error != null) {
      throw error;
    }

    return UploadedDiaryImage(
      imageUrl: uploadedUrl,
      originalFilename: image.filename,
      contentType: 'image/png',
      byteSize: image.bytes.length,
      status: 'TEMPORARY',
    );
  }

  @override
  Future<void> deleteImage(String imageUrl) async {
    deletedUrls.add(imageUrl);
  }
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
  bool isPrivate = true,
}) {
  return DiaryEntry(
    id: id,
    title: title,
    content: '본문입니다.',
    category: DiaryCategory.daily,
    nickname: '마음이',
    imageUrl: null,
    isPrivate: isPrivate,
    createDate: createDate,
    modifyDate: createDate,
  );
}

class _FakeDiaryRepository implements DiaryRepository {
  _FakeDiaryRepository({
    this.pages = const [],
    this.publicPages = const [],
    this.createdId = 1,
    this.fetchError,
    this.publicFetchError,
    this.createError,
  });

  final List<PageResponse<DiaryEntry>> pages;
  final List<PageResponse<DiaryEntry>> publicPages;
  final int createdId;
  final Object? fetchError;
  final Object? publicFetchError;
  final Object? createError;
  final List<DiaryFetchRequest> fetchRequests = [];
  final List<DiaryFetchRequest> publicFetchRequests = [];
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
  Future<PageResponse<DiaryEntry>> fetchPublicDiaries({
    int page = 0,
    int size = 20,
  }) async {
    publicFetchRequests.add(DiaryFetchRequest(page: page, size: size));
    final error = publicFetchError;
    if (error != null) {
      throw error;
    }
    if (publicPages.isEmpty) {
      return _page([]);
    }
    return publicPages.removeAt(0);
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

class _FakeContentModerationRepository implements ContentModerationRepository {
  _FakeContentModerationRepository({required this.result});

  final ContentModerationResult result;
  final List<ContentModerationRequest> requests = [];

  @override
  Future<ContentModerationResult> reviewText({
    required ContentModerationTarget targetType,
    required String text,
  }) async {
    requests.add(ContentModerationRequest(targetType: targetType, text: text));
    return result;
  }
}

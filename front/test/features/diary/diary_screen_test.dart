import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/diary/application/diary_controller.dart';
import 'package:maum_on_mobile_front/features/diary/data/diary_image_repository.dart';
import 'package:maum_on_mobile_front/features/diary/data/diary_repository.dart';
import 'package:maum_on_mobile_front/features/diary/domain/diary_models.dart';
import 'package:maum_on_mobile_front/features/diary/presentation/diary_image_picker.dart';
import 'package:maum_on_mobile_front/features/diary/presentation/diary_screen.dart';

void main() {
  testWidgets('renders diary calendar, form, and selected date entries',
      (tester) async {
    final controller = DiaryController(
      diaryRepository: _FakeDiaryRepository(
        pages: [
          _page([
            _entry(id: 1, title: '오늘의 기록', createDate: '2026-05-20T08:00:00'),
          ]),
        ],
        publicPages: [
          _page([
            _entry(
              id: 2,
              title: '함께 읽는 기록',
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
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          controller: controller,
          imagePicker: const _FakeDiaryImagePicker(),
          onBack: () {},
        ),
      ),
    );

    expect(find.text('2026년 5월'), findsOneWidget);
    expect(find.text('오늘의 기록'), findsWidgets);
    expect(find.text('공개 기록'), findsOneWidget);
    expect(find.text('함께 읽는 기록'), findsOneWidget);
    expect(find.byKey(const ValueKey('diary-title-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('diary-submit-button')), findsOneWidget);
  });

  testWidgets('picks an image and submits a diary', (tester) async {
    final repository = _FakeDiaryRepository(
      pages: [_page([]), _page([])],
      createdId: 10,
    );
    final controller = DiaryController(
      diaryRepository: repository,
      imageRepository: _FakeDiaryImageRepository(),
      now: DateTime(2026, 5, 20),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          controller: controller,
          imagePicker: const _FakeDiaryImagePicker(
            attachment: DiaryImageAttachment(filename: 'mind.png', bytes: [1]),
          ),
          onBack: () {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('diary-title-field')),
      '이미지 기록',
    );
    await tester.enterText(
      find.byKey(const ValueKey('diary-content-field')),
      '사진이 있는 기록',
    );
    await tester
        .ensureVisible(find.byKey(const ValueKey('diary-image-pick-button')));
    await tester.tap(find.byKey(const ValueKey('diary-image-pick-button')));
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('diary-submit-button')));
    await tester.tap(find.byKey(const ValueKey('diary-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('mind.png'), findsNothing);
    expect(repository.createdDrafts.single.image, isNull);
    expect(repository.createdDrafts.single.imageUrl, '/images/uploads/mind.png');
  });

  testWidgets('shows validation feedback for an empty diary', (tester) async {
    final controller = DiaryController(
      diaryRepository: _FakeDiaryRepository(pages: [_page([])]),
      imageRepository: _FakeDiaryImageRepository(),
      now: DateTime(2026, 5, 20),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          controller: controller,
          imagePicker: const _FakeDiaryImagePicker(),
          onBack: () {},
        ),
      ),
    );

    await tester
        .ensureVisible(find.byKey(const ValueKey('diary-submit-button')));
    await tester.tap(find.byKey(const ValueKey('diary-submit-button')));
    await tester.pump();

    expect(find.text('제목과 본문을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('cancels editing and clears the form', (tester) async {
    final entry = _entry(
      id: 1,
      title: '수정할 기록',
      createDate: '2026-05-20T08:00:00',
    );
    final controller = DiaryController(
      diaryRepository: _FakeDiaryRepository(pages: [_page([entry])]),
      imageRepository: _FakeDiaryImageRepository(),
      now: DateTime(2026, 5, 20),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          controller: controller,
          imagePicker: const _FakeDiaryImagePicker(),
          onBack: () {},
        ),
      ),
    );

    final editButton = find.widgetWithText(TextButton, '수정');
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pump();
    expect(controller.state.isEditing, isTrue);

    await tester.tap(find.byKey(const ValueKey('diary-edit-cancel-button')));
    await tester.pump();

    final titleFinder = find.byKey(const ValueKey('diary-title-field'));
    final titleField = tester.widget<TextField>(titleFinder);
    expect(controller.state.isEditing, isFalse);
    expect(titleField.controller?.text, isEmpty);
  });

  testWidgets('confirms deletion before removing a diary', (tester) async {
    final entry = _entry(
      id: 1,
      title: '삭제할 기록',
      createDate: '2026-05-20T08:00:00',
    );
    final repository = _FakeDiaryRepository(
      pages: [_page([entry]), _page([])],
    );
    final controller = DiaryController(
      diaryRepository: repository,
      imageRepository: _FakeDiaryImageRepository(),
      now: DateTime(2026, 5, 20),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          controller: controller,
          imagePicker: const _FakeDiaryImagePicker(),
          onBack: () {},
        ),
      ),
    );

    final deleteButton = find.widgetWithText(TextButton, '삭제');
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('기록을 삭제할까요?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('diary-delete-cancel-button')));
    await tester.pumpAndSettle();
    expect(repository.deletedIds, isEmpty);

    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diary-delete-confirm-button')));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, [1]);
    expect(find.text('기록이 삭제되었습니다.'), findsOneWidget);
  });
}

class _FakeDiaryImageRepository implements DiaryImageRepository {
  final List<DiaryImageAttachment> uploadedImages = [];

  @override
  Future<UploadedDiaryImage> uploadImage(DiaryImageAttachment image) async {
    uploadedImages.add(image);
    return UploadedDiaryImage(
      imageUrl: '/images/uploads/${image.filename}',
      originalFilename: image.filename,
      contentType: 'image/png',
      byteSize: image.bytes.length,
      status: 'TEMPORARY',
    );
  }

  @override
  Future<void> deleteImage(String imageUrl) async {}
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
    required this.pages,
    this.publicPages = const [],
    this.createdId = 1,
  });

  final List<PageResponse<DiaryEntry>> pages;
  final List<PageResponse<DiaryEntry>> publicPages;
  final int createdId;
  final List<DiaryDraft> createdDrafts = [];
  final List<int> deletedIds = [];

  @override
  Future<PageResponse<DiaryEntry>> fetchDiaries({
    int page = 0,
    int size = 100,
  }) async {
    return pages.removeAt(0);
  }

  @override
  Future<PageResponse<DiaryEntry>> fetchPublicDiaries({
    int page = 0,
    int size = 20,
  }) async {
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
    createdDrafts.add(draft);
    return createdId;
  }

  @override
  Future<void> updateDiary(int id, DiaryDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteDiary(int id) {
    deletedIds.add(id);
    return Future<void>.value();
  }
}

class _FakeDiaryImagePicker implements DiaryImagePicker {
  const _FakeDiaryImagePicker({this.attachment});

  final DiaryImageAttachment? attachment;

  @override
  Future<DiaryImageAttachment?> pickImage() async {
    return attachment;
  }
}

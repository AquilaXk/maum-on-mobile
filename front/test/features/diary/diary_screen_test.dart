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
  testWidgets('shows compact write entry controls on a phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = DiaryController(
      diaryRepository: _FakeDiaryRepository(
        pages: [
          _page([
            _entry(id: 1, title: '오늘의 기록', createDate: '2026-05-20T08:00:00'),
          ]),
        ],
        publicPages: [_page([])],
      ),
      imageRepository: _FakeDiaryImageRepository(),
      now: DateTime(2026, 5, 20),
    );

    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          controller: controller,
          imagePicker: _FakeDiaryImagePicker(),
          onBack: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('diary-quick-capture-panel')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('diary-quick-write-button')), findsOneWidget);
    expect(find.text('오늘 기록 쓰기'), findsOneWidget);
    expect(find.text('선택한 날 1개'), findsOneWidget);
  });

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
          imagePicker: _FakeDiaryImagePicker(),
          onBack: () {},
        ),
      ),
    );

    expect(find.text('2026년 5월'), findsOneWidget);
    expect(find.byKey(const ValueKey('diary-quick-capture-panel')),
        findsOneWidget);
    expect(find.text('오늘의 기록 흐름'), findsOneWidget);
    expect(find.text('선택한 날을 확인하고, 바로 이어서 기록하세요.'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('diary-selected-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('diary-public-section')), findsOneWidget);
    expect(find.text('오늘의 기록'), findsWidgets);
    expect(find.text('공개 기록'), findsOneWidget);
    expect(find.text('함께 읽는 기록'), findsOneWidget);
    expect(find.byKey(const ValueKey('diary-title-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('diary-submit-button')), findsOneWidget);
  });

  testWidgets('picks a gallery image and submits a diary', (tester) async {
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
          imagePicker: _FakeDiaryImagePicker(
            attachment:
                const DiaryImageAttachment(filename: 'mind.png', bytes: [1]),
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
    await tester.ensureVisible(
        find.byKey(const ValueKey('diary-image-gallery-button')));
    await tester.tap(find.byKey(const ValueKey('diary-image-gallery-button')));
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('diary-submit-button')));
    await tester.tap(find.byKey(const ValueKey('diary-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('mind.png'), findsNothing);
    expect(repository.createdDrafts.single.image, isNull);
    expect(
        repository.createdDrafts.single.imageUrl, '/images/uploads/mind.png');
  });

  testWidgets('adds multiple image and text blocks from the editor',
      (tester) async {
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
          imagePicker: _FakeDiaryImagePicker(
            attachments: [
              const DiaryImageAttachment(filename: 'first.png', bytes: [1]),
              const DiaryImageAttachment(filename: 'second.png', bytes: [2]),
            ],
          ),
          onBack: () {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('diary-content-field')),
      '첫 문단',
    );
    await tester.ensureVisible(
        find.byKey(const ValueKey('diary-image-gallery-button')));
    await tester.tap(find.byKey(const ValueKey('diary-image-gallery-button')));
    await tester.pump();

    final firstImageId = controller.state.imageBlocks.single.id;
    await tester.ensureVisible(
      find.byKey(ValueKey('diary-add-text-after-$firstImageId')),
    );
    await tester
        .tap(find.byKey(ValueKey('diary-add-text-after-$firstImageId')));
    await tester.pump();

    final extraTextBlock =
        controller.state.contentBlocks.where((block) => block.isText).last;
    await tester.enterText(
      find.byKey(ValueKey('diary-text-block-${extraTextBlock.id}')),
      '뒤 문단',
    );
    await tester.ensureVisible(
        find.byKey(const ValueKey('diary-image-gallery-button')));
    await tester.tap(find.byKey(const ValueKey('diary-image-gallery-button')));
    await tester.pump();

    expect(controller.state.imageBlocks, hasLength(2));
    expect(controller.state.content, '첫 문단\n\n뒤 문단');
    expect(
      controller.state.contentBlocks.map((block) => block.type),
      [
        DiaryContentBlockType.text,
        DiaryContentBlockType.image,
        DiaryContentBlockType.text,
        DiaryContentBlockType.image,
      ],
    );
  });

  testWidgets('camera action requests the camera source', (tester) async {
    final picker = _FakeDiaryImagePicker(
      attachment:
          const DiaryImageAttachment(filename: 'camera.jpg', bytes: [1]),
    );
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
          imagePicker: picker,
          onBack: () {},
        ),
      ),
    );

    await tester
        .ensureVisible(find.byKey(const ValueKey('diary-image-camera-button')));
    await tester.tap(find.byKey(const ValueKey('diary-image-camera-button')));
    await tester.pump();

    expect(picker.requestedSources, [DiaryImageSource.camera]);
    expect(controller.state.selectedImage?.filename, 'camera.jpg');
  });

  testWidgets('shows permission settings action when image access is denied',
      (tester) async {
    final picker = _FakeDiaryImagePicker(
      result: const DiaryImagePickResult.permissionDenied(
        message: '사진 권한이 허용되지 않았습니다.',
        canOpenSettings: true,
      ),
    );
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
          imagePicker: picker,
          onBack: () {},
        ),
      ),
    );

    await tester.ensureVisible(
        find.byKey(const ValueKey('diary-image-gallery-button')));
    await tester.tap(find.byKey(const ValueKey('diary-image-gallery-button')));
    await tester.pump();

    expect(find.text('사진 권한이 허용되지 않았습니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('diary-image-settings-button')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('diary-image-settings-button')));
    await tester.pump();

    expect(picker.openSettingsCount, 1);
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
          imagePicker: _FakeDiaryImagePicker(),
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

  testWidgets('loads the next public diary page from the list footer',
      (tester) async {
    final controller = DiaryController(
      diaryRepository: _FakeDiaryRepository(
        pages: [_page([])],
        publicPages: [
          _page(
            [
              _entry(
                id: 1,
                title: '처음 공개 기록',
                createDate: '2026-05-20T08:00:00',
                isPrivate: false,
              ),
            ],
            totalPages: 2,
            last: false,
          ),
          _page(
            [
              _entry(
                id: 2,
                title: '다음 공개 기록',
                createDate: '2026-05-21T08:00:00',
                isPrivate: false,
              ),
            ],
            page: 1,
            totalPages: 2,
          ),
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
          imagePicker: _FakeDiaryImagePicker(),
          onBack: () {},
        ),
      ),
    );

    expect(find.text('처음 공개 기록'), findsOneWidget);
    expect(find.text('다음 공개 기록'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('diary-public-load-more-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('diary-public-load-more-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('처음 공개 기록'), findsOneWidget);
    expect(find.text('다음 공개 기록'), findsOneWidget);
    expect(find.text('마지막 공개 기록입니다.'), findsOneWidget);
  });

  testWidgets('cancels editing and clears the form', (tester) async {
    final entry = _entry(
      id: 1,
      title: '수정할 기록',
      createDate: '2026-05-20T08:00:00',
    );
    final controller = DiaryController(
      diaryRepository: _FakeDiaryRepository(pages: [
        _page([entry])
      ]),
      imageRepository: _FakeDiaryImageRepository(),
      now: DateTime(2026, 5, 20),
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: DiaryScreen(
          controller: controller,
          imagePicker: _FakeDiaryImagePicker(),
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
      pages: [
        _page([entry]),
        _page([])
      ],
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
          imagePicker: _FakeDiaryImagePicker(),
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

PageResponse<DiaryEntry> _page(
  List<DiaryEntry> items, {
  int page = 0,
  int totalPages = 1,
  bool last = true,
}) {
  return PageResponse(
    items: items,
    page: page,
    size: 100,
    totalElements: items.length,
    totalPages: totalPages,
    last: last,
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
  _FakeDiaryImagePicker({
    this.attachment,
    List<DiaryImageAttachment>? attachments,
    DiaryImagePickResult? result,
  })  : attachments = attachments ?? const [],
        result = result ??
            (attachment == null
                ? const DiaryImagePickResult.cancelled()
                : DiaryImagePickResult.picked(attachment));

  final DiaryImageAttachment? attachment;
  final List<DiaryImageAttachment> attachments;
  final DiaryImagePickResult result;
  final List<DiaryImageSource> requestedSources = [];
  int openSettingsCount = 0;

  @override
  Future<DiaryImagePickResult> pickImage(DiaryImageSource source) async {
    requestedSources.add(source);
    if (attachments.isNotEmpty) {
      return DiaryImagePickResult.picked(attachments.removeAt(0));
    }
    return result;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount += 1;
    return true;
  }
}

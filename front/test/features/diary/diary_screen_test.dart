import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_response.dart';
import 'package:maum_on_mobile_front/features/diary/application/diary_controller.dart';
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
      ),
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
    expect(repository.createdDrafts.single.image?.filename, 'mind.png');
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
    required this.pages,
    this.createdId = 1,
  });

  final List<PageResponse<DiaryEntry>> pages;
  final int createdId;
  final List<DiaryDraft> createdDrafts = [];

  @override
  Future<PageResponse<DiaryEntry>> fetchDiaries({
    int page = 0,
    int size = 100,
  }) async {
    return pages.removeAt(0);
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
    throw UnimplementedError();
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

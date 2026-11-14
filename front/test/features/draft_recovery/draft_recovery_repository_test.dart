import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/data/draft_recovery_repository.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/domain/draft_recovery_models.dart';

void main() {
  group('DraftRecoveryRepository', () {
    test('stores drafts per member and surface', () async {
      final repository = StorageDraftRecoveryRepository(
        storage: MemoryDraftRecoveryStorage(),
      );
      final diaryKey = const DraftKey(
        memberId: 7,
        surface: DraftSurface.diary,
      );
      final otherMemberKey = const DraftKey(
        memberId: 8,
        surface: DraftSurface.diary,
      );

      await repository.saveEditing(
        diaryKey,
        fields: {'title': '내 기록', 'content': '복원할 본문'},
      );
      await repository.saveEditing(
        otherMemberKey,
        fields: {'title': '다른 계정', 'content': '보이면 안 됨'},
      );

      expect((await repository.read(diaryKey))?.fields['title'], '내 기록');
      expect((await repository.read(otherMemberKey))?.fields['title'], '다른 계정');
      expect(
        (await repository.listFailed(memberId: 7, surface: DraftSurface.diary)),
        isEmpty,
      );
    });

    test('tracks failed items and clears a member on logout', () async {
      final repository = StorageDraftRecoveryRepository(
        storage: MemoryDraftRecoveryStorage(),
      );
      const storyKey = DraftKey(
        memberId: 7,
        surface: DraftSurface.story,
      );
      const commentKey = DraftKey(
        memberId: 7,
        surface: DraftSurface.storyComment,
        scopeId: '42',
      );

      await repository.markFailed(
        storyKey,
        fields: {'title': '실패 글', 'content': '재시도할 본문'},
        failureMessage: '네트워크 오류',
      );
      await repository.saveEditing(
        commentKey,
        fields: {'content': '작성 중 댓글'},
      );

      final failed = await repository.listFailed(memberId: 7);
      expect(failed.single.key.surface, DraftSurface.story);
      expect(failed.single.status, DraftRecoveryStatus.failed);

      await repository.clearMember(7);

      expect(await repository.read(storyKey), isNull);
      expect(await repository.read(commentKey), isNull);
      expect(await repository.listFailed(memberId: 7), isEmpty);
    });

    test('uses per-member key index before reading failed drafts cleanly',
        () async {
      final storage = _CountingDraftRecoveryStorage();
      final repository = StorageDraftRecoveryRepository(storage: storage);
      const memberOneKey = DraftKey(
        memberId: 11,
        surface: DraftSurface.letter,
      );
      const memberTwoKey = DraftKey(
        memberId: 22,
        surface: DraftSurface.story,
      );

      await repository.markFailed(
        memberOneKey,
        fields: {'title': '실패 편지', 'content': '본문'},
        failureMessage: '일시 오류',
      );
      await repository.saveEditing(
        memberTwoKey,
        fields: {'title': '다른 계정', 'content': '작성 중'},
      );
      storage.readAllCount = 0;

      final failed = await repository.listFailed(memberId: 11);
      expect(failed.single.key.storageKey, memberOneKey.storageKey);
      expect(storage.readAllCount, 0);

      await repository.clearMember(11);
      expect(storage.readAllCount, 0);
      expect(await repository.read(memberOneKey), isNull);
      expect((await repository.read(memberTwoKey))?.fields['title'], '다른 계정');
    });

    test('migrates pre-index legacy drafts on first member scan', () async {
      final storage = _CountingDraftRecoveryStorage();
      final repository = StorageDraftRecoveryRepository(storage: storage);
      const legacyKey = DraftKey(
        memberId: 33,
        surface: DraftSurface.diary,
      );
      await storage.write(
        legacyKey.storageKey,
        '{"memberId":33,"surface":"diary","scopeId":"","fields":{"title":"레거시","content":"본문"},"status":"failed","failureMessage":"오류","updatedAt":"2026-05-24T08:00:00.000"}',
      );

      final firstFailed = await repository.listFailed(memberId: 33);
      expect(firstFailed.single.key.storageKey, legacyKey.storageKey);
      expect(storage.readAllCount, 1);

      storage.readAllCount = 0;
      final secondFailed = await repository.listFailed(memberId: 33);
      expect(secondFailed.single.key.storageKey, legacyKey.storageKey);
      expect(storage.readAllCount, 0);
    });

    test(
        'preserves pre-index legacy drafts when writing a new key and clears them on logout',
        () async {
      final storage = _CountingDraftRecoveryStorage();
      final repository = StorageDraftRecoveryRepository(storage: storage);
      const legacyFailedKey = DraftKey(
        memberId: 44,
        surface: DraftSurface.diary,
      );
      const newEditingKey = DraftKey(
        memberId: 44,
        surface: DraftSurface.story,
      );
      await storage.write(
        legacyFailedKey.storageKey,
        '{"memberId":44,"surface":"diary","scopeId":"","fields":{"title":"이전 실패","content":"본문"},"status":"failed","failureMessage":"네트워크 오류","updatedAt":"2026-05-24T08:00:00.000"}',
      );

      await repository.saveEditing(
        newEditingKey,
        fields: {'title': '새 글', 'content': '임시 저장'},
      );

      final failed = await repository.listFailed(memberId: 44);
      expect(failed.single.key.storageKey, legacyFailedKey.storageKey);

      await repository.clearMember(44);
      expect(await repository.read(legacyFailedKey), isNull);
      expect(await repository.read(newEditingKey), isNull);
      expect(await repository.listFailed(memberId: 44), isEmpty);
    });

    test('serializes concurrent index writes for the same member', () async {
      final storage = _CountingDraftRecoveryStorage(yieldOnRead: true);
      final repository = StorageDraftRecoveryRepository(storage: storage);
      const firstKey = DraftKey(memberId: 55, surface: DraftSurface.diary);
      const secondKey = DraftKey(memberId: 55, surface: DraftSurface.story);
      const thirdKey = DraftKey(
        memberId: 55,
        surface: DraftSurface.storyComment,
        scopeId: '99',
      );

      await Future.wait([
        repository.markFailed(
          firstKey,
          fields: {'title': '일기', 'content': '본문1'},
          failureMessage: '오류1',
        ),
        repository.markFailed(
          secondKey,
          fields: {'title': '사연', 'content': '본문2'},
          failureMessage: '오류2',
        ),
        repository.markFailed(
          thirdKey,
          fields: {'content': '본문3'},
          failureMessage: '오류3',
        ),
      ]);

      final failedKeys = (await repository.listFailed(memberId: 55))
          .map((entry) => entry.key.storageKey)
          .toSet();
      expect(
        failedKeys,
        {firstKey.storageKey, secondKey.storageKey, thirdKey.storageKey},
      );
    });
  });
}

class _CountingDraftRecoveryStorage implements DraftRecoveryStorage {
  _CountingDraftRecoveryStorage({this.yieldOnRead = false});

  final bool yieldOnRead;
  final Map<String, String> _values = {};
  int readAllCount = 0;

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    if (yieldOnRead) {
      await Future<void>.delayed(Duration.zero);
    }
    return _values[key];
  }

  @override
  Future<Map<String, String>> readAll() async {
    readAllCount += 1;
    return Map<String, String>.unmodifiable(_values);
  }

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

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
  });
}

class _CountingDraftRecoveryStorage implements DraftRecoveryStorage {
  final Map<String, String> _values = {};
  int readAllCount = 0;

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

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

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
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/settings/application/settings_controller.dart';
import 'package:maum_on_mobile_front/features/settings/data/settings_repository.dart';
import 'package:maum_on_mobile_front/features/settings/domain/settings_models.dart';

void main() {
  group('SettingsController', () {
    test('loads settings and saves nickname, email, password, and random toggle',
        () async {
      final repository = _FakeSettingsRepository();
      final controller = SettingsController(repository: repository);

      await controller.load();
      controller.updateNicknameDraft('새 닉네임');
      await controller.saveNickname();
      controller.updateEmailDraft('new@example.com');
      await controller.saveEmail();
      controller
        ..updateCurrentPasswordDraft('old-password')
        ..updateNewPasswordDraft('new-password');
      await controller.savePassword();
      await controller.toggleRandomSetting();
      await controller.requestDataExport();
      await controller.downloadDataExport();

      expect(repository.nicknameUpdates, ['새 닉네임']);
      expect(repository.emailUpdates, ['new@example.com']);
      expect(repository.passwordUpdates.single.newPassword, 'new-password');
      expect(repository.randomToggleCount, 1);
      expect(repository.exportRequestCount, 1);
      expect(repository.downloadedExportIds, [1]);
      expect(controller.state.downloadedExport?.filename, 'maum-on-data-export-1.json');
      expect(controller.state.settings!.randomReceiveAllowed, isFalse);
    });

    test('blocks social account email and password changes', () async {
      final repository = _FakeSettingsRepository(
        initialSettings: const MemberSettings(
          id: 7,
          email: 'social@example.com',
          nickname: '소셜',
          randomReceiveAllowed: true,
          socialAccount: true,
        ),
      );
      final controller = SettingsController(repository: repository);

      await controller.load();
      controller.updateEmailDraft('changed@example.com');
      await controller.saveEmail();
      controller
        ..updateCurrentPasswordDraft('old-password')
        ..updateNewPasswordDraft('new-password');
      await controller.savePassword();

      expect(repository.emailUpdates, isEmpty);
      expect(repository.passwordUpdates, isEmpty);
      expect(controller.state.errorMessage, '소셜 계정은 이 항목을 변경할 수 없습니다.');
    });

    test('withdraws and invokes session cleanup callback', () async {
      var cleaned = false;
      final repository = _FakeSettingsRepository();
      final controller = SettingsController(
        repository: repository,
        onWithdrawn: () async {
          cleaned = true;
        },
      );

      await controller.load();
      controller
        ..requestWithdrawal()
        ..updateWithdrawPasswordDraft('old-password');
      await controller.confirmWithdrawal();

      expect(repository.withdrawPasswords, ['old-password']);
      expect(cleaned, isTrue);
      expect(controller.state.isWithdrawn, isTrue);
    });
  });
}

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({
    this.initialSettings = const MemberSettings(
      id: 7,
      email: 'me@example.com',
      nickname: '마음이',
      randomReceiveAllowed: true,
      socialAccount: false,
    ),
  });

  final MemberSettings initialSettings;
  final List<String> nicknameUpdates = [];
  final List<String> emailUpdates = [];
  final List<PasswordChangeDraft> passwordUpdates = [];
  final List<String?> withdrawPasswords = [];
  int randomToggleCount = 0;
  int exportRequestCount = 0;
  final List<int> fetchedExportIds = [];
  final List<int> downloadedExportIds = [];

  @override
  Future<MemberSettings> fetchSettings() async => initialSettings;

  @override
  Future<MemberSettings> updateNickname(String nickname) async {
    nicknameUpdates.add(nickname);
    return initialSettings.copyWith(nickname: nickname);
  }

  @override
  Future<MemberSettings> updateEmail(String email) async {
    emailUpdates.add(email);
    return initialSettings.copyWith(email: email);
  }

  @override
  Future<MemberSettings> updatePassword(PasswordChangeDraft draft) async {
    passwordUpdates.add(draft);
    return initialSettings;
  }

  @override
  Future<MemberSettings> toggleRandomSetting() async {
    randomToggleCount += 1;
    return initialSettings.copyWith(randomReceiveAllowed: false);
  }

  @override
  Future<MemberDataExportJob> requestDataExport() async {
    exportRequestCount += 1;
    return const MemberDataExportJob(
      id: 1,
      status: MemberDataExportStatus.completed,
      requestedAt: '2026-05-26T00:00:00Z',
      completedAt: '2026-05-26T00:00:00Z',
      expiresAt: '2026-05-27T00:00:00Z',
      downloadUrl: '/api/v1/members/me/data-exports/1/download',
    );
  }

  @override
  Future<MemberDataExportJob> fetchDataExportStatus(int exportId) async {
    fetchedExportIds.add(exportId);
    return MemberDataExportJob(
      id: exportId,
      status: MemberDataExportStatus.completed,
      requestedAt: '2026-05-26T00:00:00Z',
      completedAt: '2026-05-26T00:00:00Z',
      expiresAt: '2026-05-27T00:00:00Z',
      downloadUrl: '/api/v1/members/me/data-exports/$exportId/download',
    );
  }

  @override
  Future<MemberDataExportFile> downloadDataExport(int exportId) async {
    downloadedExportIds.add(exportId);
    return MemberDataExportFile(
      filename: 'maum-on-data-export-$exportId.json',
      contentType: 'application/json',
      content: '{"account":{}}',
      expiresAt: '2026-05-27T00:00:00Z',
    );
  }

  @override
  Future<void> withdraw({String? currentPassword}) async {
    withdrawPasswords.add(currentPassword);
  }
}

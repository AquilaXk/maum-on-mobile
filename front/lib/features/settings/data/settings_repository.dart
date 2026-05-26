import '../../../core/network/api_client.dart';
import '../domain/settings_models.dart';

abstract interface class SettingsRepository {
  Future<MemberSettings> fetchSettings();

  Future<MemberSettings> updateNickname(String nickname);

  Future<MemberSettings> updateEmail(String email);

  Future<MemberSettings> updatePassword(PasswordChangeDraft draft);

  Future<MemberSettings> toggleRandomSetting();

  Future<MemberDataExportJob> requestDataExport();

  Future<MemberDataExportJob> fetchDataExportStatus(int exportId);

  Future<MemberDataExportFile> downloadDataExport(int exportId);

  Future<void> withdraw({String? currentPassword});
}

class ApiSettingsRepository implements SettingsRepository {
  const ApiSettingsRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<MemberSettings> fetchSettings() {
    return _apiClient.get<MemberSettings>(
      '/api/v1/members/me',
      parser: MemberSettings.fromJson,
    );
  }

  @override
  Future<MemberSettings> updateNickname(String nickname) {
    return _apiClient.patch<MemberSettings>(
      '/api/v1/members/me/profile',
      body: {'nickname': nickname.trim()},
      parser: MemberSettings.fromJson,
    );
  }

  @override
  Future<MemberSettings> updateEmail(String email) {
    return _apiClient.patch<MemberSettings>(
      '/api/v1/members/me/email',
      body: {'email': email.trim()},
      parser: MemberSettings.fromJson,
    );
  }

  @override
  Future<MemberSettings> updatePassword(PasswordChangeDraft draft) {
    return _apiClient.patch<MemberSettings>(
      '/api/v1/members/me/password',
      body: draft.toJson(),
      parser: MemberSettings.fromJson,
    );
  }

  @override
  Future<MemberSettings> toggleRandomSetting() {
    return _apiClient.patch<MemberSettings>(
      '/api/v1/members/me/random-setting',
      parser: MemberSettings.fromJson,
    );
  }

  @override
  Future<MemberDataExportJob> requestDataExport() {
    return _apiClient.post<MemberDataExportJob>(
      '/api/v1/members/me/data-exports',
      parser: MemberDataExportJob.fromJson,
    );
  }

  @override
  Future<MemberDataExportJob> fetchDataExportStatus(int exportId) {
    return _apiClient.get<MemberDataExportJob>(
      '/api/v1/members/me/data-exports/$exportId',
      parser: MemberDataExportJob.fromJson,
    );
  }

  @override
  Future<MemberDataExportFile> downloadDataExport(int exportId) {
    return _apiClient.get<MemberDataExportFile>(
      '/api/v1/members/me/data-exports/$exportId/download',
      parser: MemberDataExportFile.fromJson,
    );
  }

  @override
  Future<void> withdraw({String? currentPassword}) {
    final trimmedPassword = currentPassword?.trim() ?? '';
    return _apiClient.deleteVoid(
      '/api/v1/members/me',
      body: trimmedPassword.isEmpty
          ? null
          : {
              'currentPassword': trimmedPassword,
            },
    );
  }
}

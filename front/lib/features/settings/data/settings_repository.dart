import '../../../core/network/api_client.dart';
import '../domain/settings_models.dart';

abstract interface class SettingsRepository {
  Future<MemberSettings> fetchSettings();

  Future<MemberSettings> updateNickname(String nickname);

  Future<MemberSettings> updateEmail(String email);

  Future<MemberSettings> updatePassword(PasswordChangeDraft draft);

  Future<MemberSettings> toggleRandomSetting();

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

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/settings/data/settings_repository.dart';
import 'package:maum_on_mobile_front/features/settings/domain/settings_models.dart';

void main() {
  group('ApiSettingsRepository', () {
    test('loads current member settings', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'resultCode': '200-1',
          'data': _settingsJson(),
        }),
      ]);
      final repository = _repository(transport);

      final settings = await repository.fetchSettings();

      expect(transport.requests.single.path, '/api/v1/members/me');
      expect(transport.requests.single.method, ApiMethod.get);
      expect(settings.nickname, '마음이');
      expect(settings.randomReceiveAllowed, isTrue);
      expect(settings.socialAccount, isFalse);
    });

    test('sends profile, email, password, random setting, and withdrawal',
        () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'resultCode': '200-2',
          'data': _settingsJson(nickname: '새 닉네임'),
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-4',
          'data': _settingsJson(email: 'new@example.com'),
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-5',
          'data': _settingsJson(),
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-3',
          'data': _settingsJson(randomReceiveAllowed: false),
        }),
        const ApiTransportResponse(
          statusCode: 200,
          body: {'resultCode': '200-6'},
        ),
      ]);
      final repository = _repository(transport);

      await repository.updateNickname('새 닉네임');
      await repository.updateEmail('new@example.com');
      await repository.updatePassword(
        const PasswordChangeDraft(
          currentPassword: 'old-password',
          newPassword: 'new-password',
        ),
      );
      await repository.toggleRandomSetting();
      await repository.withdraw(currentPassword: 'old-password');

      expect(transport.requests[0].path, '/api/v1/members/me/profile');
      expect(transport.requests[0].body, {'nickname': '새 닉네임'});
      expect(transport.requests[1].path, '/api/v1/members/me/email');
      expect(transport.requests[1].body, {'email': 'new@example.com'});
      expect(transport.requests[2].path, '/api/v1/members/me/password');
      expect(transport.requests[2].body, {
        'currentPassword': 'old-password',
        'newPassword': 'new-password',
      });
      expect(transport.requests[3].path, '/api/v1/members/me/random-setting');
      expect(transport.requests[3].method, ApiMethod.patch);
      expect(transport.requests[4].path, '/api/v1/members/me');
      expect(transport.requests[4].method, ApiMethod.delete);
      expect(transport.requests[4].body, {'currentPassword': 'old-password'});
    });
  });
}

ApiSettingsRepository _repository(_FakeApiTransport transport) {
  return ApiSettingsRepository(
    apiClient: ApiClient(
      transport: transport,
      tokenStore: MemoryAuthTokenStore(),
    ),
  );
}

Map<String, Object?> _settingsJson({
  String email = 'me@example.com',
  String nickname = '마음이',
  bool randomReceiveAllowed = true,
  bool socialAccount = false,
}) {
  return {
    'id': 7,
    'email': email,
    'nickname': nickname,
    'randomReceiveAllowed': randomReceiveAllowed,
    'socialAccount': socialAccount,
  };
}

class _FakeApiTransport implements ApiTransport {
  _FakeApiTransport(this._responses);

  final List<ApiTransportResponse> _responses;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiTransportResponse> send(ApiRequest request) async {
    requests.add(request);

    if (_responses.isEmpty) {
      throw const ApiTransportException('No fake response configured');
    }

    return _responses.removeAt(0);
  }
}

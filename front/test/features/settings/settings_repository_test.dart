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
      expect(settings.retentionPolicy.exportExpiryHours, 24);
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

    test('requests, checks, and downloads member data export', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'resultCode': '200-1',
          'data': _exportJob(),
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-1',
          'data': _exportJob(),
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-1',
          'data': {
            'filename': 'maum-on-data-export-3.json',
            'contentType': 'application/json',
            'content': '{"account":{}}',
            'expiresAt': '2999-05-27T00:00:00Z',
          },
        }),
      ]);
      final repository = _repository(transport);

      final requested = await repository.requestDataExport();
      final status = await repository.fetchDataExportStatus(requested.id);
      final file = await repository.downloadDataExport(status.id);

      expect(requested.status, MemberDataExportStatus.completed);
      expect(file.filename, 'maum-on-data-export-3.json');
      expect(transport.requests.map((request) => request.path), [
        '/api/v1/members/me/data-exports',
        '/api/v1/members/me/data-exports/3',
        '/api/v1/members/me/data-exports/3/download',
      ]);
      expect(transport.requests.map((request) => request.method), [
        ApiMethod.post,
        ApiMethod.get,
        ApiMethod.get,
      ]);
    });

    test('keeps model defaults and disables expired data export download', () {
      const defaults = MemberRetentionPolicy();
      final partialPolicy = MemberRetentionPolicy.fromJson({
        'exportExpiryHours': 48,
      });
      const expiredExport = MemberDataExportJob(
        id: 4,
        status: MemberDataExportStatus.completed,
        requestedAt: '2026-05-26T00:00:00Z',
        completedAt: '2026-05-26T00:00:00Z',
        expiresAt: '2000-01-01T00:00:00Z',
      );
      const pendingExport = MemberDataExportJob(
        id: 5,
        status: MemberDataExportStatus.pending,
        requestedAt: '2026-05-26T00:00:00Z',
      );

      expect(
        partialPolicy.immediateDeletionItems,
        defaults.immediateDeletionItems,
      );
      expect(
        partialPolicy.anonymizedRetentionItems,
        defaults.anonymizedRetentionItems,
      );
      expect(partialPolicy.legalRetentionItems, defaults.legalRetentionItems);
      expect(partialPolicy.exportExpiryHours, 48);
      expect(expiredExport.canDownload, isFalse);
      expect(pendingExport.canDownload, isFalse);
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
    'retentionPolicy': {
      'immediateDeletionItems': ['세션 폐기'],
      'anonymizedRetentionItems': ['비식별 보존'],
      'legalRetentionItems': ['운영 보존'],
      'exportExpiryHours': 24,
    },
  };
}

Map<String, Object?> _exportJob() {
  return {
    'id': 3,
    'status': 'COMPLETED',
    'requestedAt': '2026-05-26T00:00:00Z',
    'completedAt': '2026-05-26T00:00:00Z',
    'expiresAt': '2999-05-27T00:00:00Z',
    'downloadUrl': '/api/v1/members/me/data-exports/3/download',
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

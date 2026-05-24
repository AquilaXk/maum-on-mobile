import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/moderation/data/content_moderation_repository.dart';
import 'package:maum_on_mobile_front/features/moderation/domain/content_moderation_models.dart';

void main() {
  test('reviews text through the moderation API', () async {
    final transport = _FakeApiTransport([
      ApiTransportResponse.ok({
        'resultCode': '200-1',
        'data': {
          'allowed': false,
          'riskLevel': 'HIGH',
          'message': '위험도가 높은 표현이 포함되어 수정이 필요합니다.',
          'categories': ['PROFANITY'],
        },
      }),
    ]);
    final repository = ApiContentModerationRepository(
      apiClient: ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      ),
    );

    final result = await repository.reviewText(
      targetType: ContentModerationTarget.story,
      text: '너 죽어 버려',
    );

    expect(result.allowed, isFalse);
    expect(result.riskLevel, ContentModerationRiskLevel.high);
    expect(result.categories, [ContentModerationCategory.profanity]);
    expect(transport.requests.single.path, '/api/v1/moderation/text');
    expect(transport.requests.single.method, ApiMethod.post);
    expect(transport.requests.single.body, {
      'targetType': 'STORY',
      'text': '너 죽어 버려',
    });
  });
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

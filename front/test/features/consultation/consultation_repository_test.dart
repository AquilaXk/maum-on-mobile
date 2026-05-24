import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/consultation/data/consultation_repository.dart';
import 'package:maum_on_mobile_front/features/consultation/domain/consultation_models.dart';

void main() {
  group('ApiConsultationRepository', () {
    test('sends chat messages to the consultation API', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'resultCode': '200-1'}),
      ]);
      final repository = _repository(
        transport,
        streamClient: _FakeConsultationStreamClient(),
      );

      await repository.sendMessage('도움이 필요해요');

      expect(transport.requests.single.path, '/api/v1/consultations/chat');
      expect(transport.requests.single.method, ApiMethod.post);
      expect(transport.requests.single.body, {'message': '도움이 필요해요'});
    });

    test('opens the consultation stream through the stream client', () async {
      final streamClient = _FakeConsultationStreamClient([
        const ConsultationStreamEvent.connect('connected'),
      ]);
      final repository = _repository(
        _FakeApiTransport([]),
        streamClient: streamClient,
      );

      final event = await repository.connect().first;

      expect(streamClient.connectCount, 1);
      expect(event.type, ConsultationStreamEventType.connect);
    });
  });
}

ApiConsultationRepository _repository(
  _FakeApiTransport transport, {
  required ConsultationStreamClient streamClient,
}) {
  return ApiConsultationRepository(
    apiClient: ApiClient(
      transport: transport,
      tokenStore: MemoryAuthTokenStore(),
    ),
    streamClient: streamClient,
  );
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

class _FakeConsultationStreamClient implements ConsultationStreamClient {
  _FakeConsultationStreamClient([this.events = const []]);

  final List<ConsultationStreamEvent> events;
  int connectCount = 0;

  @override
  Stream<ConsultationStreamEvent> connect() {
    connectCount += 1;
    return Stream<ConsultationStreamEvent>.fromIterable(events);
  }
}

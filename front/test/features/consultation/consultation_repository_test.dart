import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/core/network/api_config.dart';
import 'package:maum_on_mobile_front/features/consultation/data/consultation_repository.dart';
import 'package:maum_on_mobile_front/features/consultation/domain/consultation_models.dart';

void main() {
  group('ApiConsultationRepository', () {
    test('sends chat messages to the consultation API', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'accepted': false,
            'safety': {
              'category': 'SELF_HARM',
              'severity': 'CRITICAL',
              'actionPolicy': 'BLOCK_AND_ESCALATE',
              'message': '지금 안전이 가장 중요합니다.',
            },
          },
        }),
      ]);
      final repository = _repository(
        transport,
        streamClient: _FakeConsultationStreamClient(),
      );

      final result = await repository.sendMessage('도움이 필요해요');

      expect(transport.requests.single.path, '/api/v1/consultations/chat');
      expect(transport.requests.single.method, ApiMethod.post);
      expect(transport.requests.single.body, {'message': '도움이 필요해요'});
      expect(result.accepted, isFalse);
      expect(result.safety?.actionPolicy,
          ConsultationActionPolicy.blockAndEscalate);
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

    test('loads recent consultation messages from the API', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'messages': [
              {
                'id': 11,
                'role': 'USER',
                'content': '불안해요',
                'createdAt': '2026-05-25T00:00:00Z',
              },
              {
                'id': 12,
                'role': 'ASSISTANT',
                'content': '천천히 볼게요.',
                'createdAt': '2026-05-25T00:00:01Z',
              },
            ],
          },
        }),
      ]);
      final repository = _repository(
        transport,
        streamClient: _FakeConsultationStreamClient(),
      );

      final messages = await repository.loadRecentMessages();

      expect(transport.requests.single.path, '/api/v1/consultations/recent');
      expect(transport.requests.single.method, ApiMethod.get);
      expect(messages, hasLength(2));
      expect(messages.first.role, ConsultationMessageRole.user);
      expect(messages.last.content, '천천히 볼게요.');
    });

    test('deletes sensitive consultation messages', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {'deletedCount': 2},
        }),
      ]);
      final repository = _repository(
        transport,
        streamClient: _FakeConsultationStreamClient(),
      );

      final deletedCount = await repository.deleteSensitiveMessages();

      expect(transport.requests.single.path, '/api/v1/consultations/sensitive');
      expect(transport.requests.single.method, ApiMethod.delete);
      expect(deletedCount, 2);
    });
  });

  group('HttpConsultationStreamClient', () {
    test('streams SSE events with the saved bearer token', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final authHeaders = <String?>[];
      unawaited(
        server.forEach((request) async {
          authHeaders
              .add(request.headers.value(HttpHeaders.authorizationHeader));
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType('text', 'event-stream');
          request.response
              .add(utf8.encode('event: connect\ndata: connected\n\n'));
          await request.response.flush();
          request.response.add(
            utf8.encode(
              'event: chat\n'
              'data: {"requestId":"r1","sequence":0,"chunk":"함께 "}\n\n',
            ),
          );
          request.response.add(
            utf8.encode(
              'event: chat_done\n'
              'data: {"requestId":"r1","sequence":1,"done":true}\n\n',
            ),
          );
          await request.response.close();
        }),
      );

      final client = HttpConsultationStreamClient(
        apiConfig:
            ApiConfig(baseUrl: Uri.parse('http://127.0.0.1:${server.port}')),
        tokenStore: MemoryAuthTokenStore(
          initialTokens: const TokenPair(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
          ),
        ),
      );

      final events = await client.connect().toList();

      expect(authHeaders.single, 'Bearer access-token');
      expect(events.map((event) => event.type), [
        ConsultationStreamEventType.connect,
        ConsultationStreamEventType.chat,
        ConsultationStreamEventType.done,
      ]);
      expect(events[1].data, '함께 ');
      expect(events[1].requestId, 'r1');
      expect(events[1].sequence, 0);
    });

    test('clears expired tokens when the stream returns unauthorized',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      unawaited(
        server.forEach((request) async {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
        }),
      );
      final tokenStore = MemoryAuthTokenStore(
        initialTokens: const TokenPair(
          accessToken: 'expired-access-token',
          refreshToken: 'expired-refresh-token',
        ),
      );
      final client = HttpConsultationStreamClient(
        apiConfig:
            ApiConfig(baseUrl: Uri.parse('http://127.0.0.1:${server.port}')),
        tokenStore: tokenStore,
      );

      await expectLater(
        client.connect(),
        emitsError(
          isA<ApiClientException>()
              .having((error) => error.kind, 'kind', ApiErrorKind.unauthorized),
        ),
      );
      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
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

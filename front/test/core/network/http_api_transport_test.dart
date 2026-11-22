import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_config.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/http_api_transport.dart';
import 'package:maum_on_mobile_front/core/network/multipart_body.dart';
import 'package:maum_on_mobile_front/features/notification/data/notification_repository.dart';
import 'package:maum_on_mobile_front/features/notification/domain/notification_models.dart';

void main() {
  group('HttpApiTransport', () {
    late HttpServer server;
    late Uri baseUrl;
    late HttpApiTransport transport;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = Uri.parse('http://127.0.0.1:${server.port}');
      transport = HttpApiTransport.fromConfig(ApiConfig(baseUrl: baseUrl));
    });

    tearDown(() async {
      transport.close(force: true);
      await server.close(force: true);
    });

    test('sends GET with merged query parameters and decodes JSON response',
        () async {
      Uri? capturedUri;
      String? capturedMethod;
      String? capturedHeader;

      server.listen((request) async {
        capturedUri = request.uri;
        capturedMethod = request.method;
        capturedHeader = request.headers.value('x-trace-id');
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.headers.set('x-server-tag', 'ok');
        request.response.write(jsonEncode({'ok': true, 'count': 3}));
        await request.response.close();
      });

      final scopedTransport = HttpApiTransport.fromConfig(
        ApiConfig(baseUrl: Uri.parse('http://127.0.0.1:${server.port}/v1/')),
      );
      addTearDown(() => scopedTransport.close(force: true));

      final response = await scopedTransport.send(
        const ApiRequest(
          method: ApiMethod.get,
          path: '/items?existing=yes',
          headers: {'X-Trace-Id': 'trace-123'},
          queryParameters: {
            'page': 2,
            'tag': 'calm',
            'ignored': null,
          },
        ),
      );

      expect(capturedMethod, 'GET');
      expect(capturedHeader, 'trace-123');
      expect(capturedUri?.path, '/v1/items');
      expect(capturedUri?.queryParameters, {
        'existing': 'yes',
        'page': '2',
        'tag': 'calm',
      });
      expect(response.statusCode, 200);
      expect(response.body, {'ok': true, 'count': 3});
      expect(response.headers['x-server-tag'], ['ok']);
    });

    test('sends POST JSON and preserves plain text and empty body semantics',
        () async {
      final receivedBodies = <String>[];
      final receivedContentTypes = <String?>[];
      var callCount = 0;

      server.listen((request) async {
        callCount += 1;
        receivedContentTypes.add(request.headers.contentType?.toString());
        receivedBodies.add(await utf8.decoder.bind(request).join());

        if (callCount == 1) {
          request.response.statusCode = 201;
          request.response.write(jsonEncode({'id': 9}));
        } else if (callCount == 2) {
          request.response.statusCode = 502;
          request.response.write('upstream-plain-error');
        } else {
          request.response.statusCode = 204;
        }
        await request.response.close();
      });

      final first = await transport.send(
        const ApiRequest(
          method: ApiMethod.post,
          path: '/api/v1/diaries',
          body: {'title': '오늘', 'score': 4},
        ),
      );
      expect(first.statusCode, 201);
      expect(first.body, {'id': 9});
      expect(receivedContentTypes[0], contains('application/json'));
      expect(jsonDecode(receivedBodies[0]), {'title': '오늘', 'score': 4});

      final second = await transport.send(
        const ApiRequest(method: ApiMethod.post, path: '/api/v1/fallback'),
      );
      expect(second.statusCode, 502);
      expect(second.body, 'upstream-plain-error');

      final third = await transport.send(
        const ApiRequest(method: ApiMethod.delete, path: '/api/v1/item/1'),
      );
      expect(third.statusCode, 204);
      expect(third.body, isNull);
    });

    test('encodes RFC 7578 multipart body and sanitizes unsafe header tokens',
        () async {
      String? capturedContentType;
      String? capturedBody;

      server.listen((request) async {
        capturedContentType = request.headers.contentType?.toString();
        final bytes = await request.fold<List<int>>(
          <int>[],
          (acc, chunk) => acc..addAll(chunk),
        );
        capturedBody = latin1.decode(bytes);
        request.response.statusCode = 200;
        request.response.write(jsonEncode({'uploaded': true}));
        await request.response.close();
      });

      final response = await transport.send(
        ApiRequest(
          method: ApiMethod.post,
          path: '/api/v1/images/upload',
          multipart: MultipartBody(
            fields: const {'caption\r\nEvil: 1': 'hello'},
            textParts: const [
              MultipartTextPart(
                fieldName: 'meta"part',
                value: '{"kind":"diary"}',
                contentType: 'application/json\r\nX-Bad: 1',
              ),
            ],
            files: [
              MultipartFilePart(
                fieldName: 'image',
                filename: 'photo"\r\nX-Inject: bad.png',
                bytes: const [137, 80, 78, 71],
                contentType: 'image/png',
              ),
            ],
          ),
        ),
      );

      expect(response.statusCode, 200);
      expect(response.body, {'uploaded': true});
      expect(capturedContentType, startsWith('multipart/form-data; boundary='));
      expect(capturedBody, contains('name="caption__Evil: 1"'));
      expect(capturedBody, contains('name="meta_part"'));
      expect(capturedBody, contains('Content-Type: application/jsonX-Bad: 1'));
      expect(
        capturedBody,
        contains('name="image"; filename="photo___X-Inject: bad.png"'),
      );
      expect(capturedBody, contains('\r\n\r\nhello\r\n'));
      expect(capturedBody, contains('{"kind":"diary"}'));
    });

    test('rejects response payloads exceeding 10 MiB fail-closed', () async {
      server.listen((request) async {
        request.response.statusCode = 200;
        request.response.bufferOutput = false;
        final chunk = List<int>.filled(256 * 1024, 0x61); // 256 KiB
        // Stream 10.5 MiB without setting Content-Length to verify streaming cap.
        for (var i = 0; i < 42; i += 1) {
          request.response.add(chunk);
          await request.response.flush();
        }
        await request.response.close();
      });

      await expectLater(
        transport.send(
          const ApiRequest(method: ApiMethod.get, path: '/api/v1/huge'),
        ),
        throwsA(isA<ApiTransportException>()),
      );
    });

    test('wraps request timeouts and connection errors into ApiTransportException',
        () async {
      server.listen((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        try {
          request.response.statusCode = 200;
          await request.response.close();
        } on Object {
          // Client aborted on timeout.
        }
      });

      final fastTimeoutTransport = HttpApiTransport(
        config: ApiConfig(baseUrl: baseUrl),
        requestTimeout: const Duration(milliseconds: 50),
      );
      addTearDown(() => fastTimeoutTransport.close(force: true));

      await expectLater(
        fastTimeoutTransport.send(
          const ApiRequest(method: ApiMethod.get, path: '/api/v1/slow'),
        ),
        throwsA(isA<ApiTransportException>()),
      );

      final unusedServer =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = unusedServer.port;
      await unusedServer.close(force: true);

      final deadTransport = HttpApiTransport.fromConfig(
        ApiConfig(baseUrl: Uri.parse('http://127.0.0.1:$closedPort')),
      );
      addTearDown(() => deadTransport.close(force: true));

      await expectLater(
        deadTransport.send(
          const ApiRequest(method: ApiMethod.get, path: '/api/v1/down'),
        ),
        throwsA(isA<ApiTransportException>()),
      );
    });
  });

  group('HttpNotificationStreamClient', () {
    late HttpServer server;
    late HttpNotificationStreamClient streamClient;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      streamClient = HttpNotificationStreamClient(
        apiConfig: ApiConfig(
          baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );
    });

    tearDown(() async {
      streamClient.close(force: true);
      await server.close(force: true);
    });

    test('streams SSE events and verifies ticket query and Accept header',
        () async {
      Uri? capturedUri;
      String? capturedAccept;

      server.listen((request) async {
        capturedUri = request.uri;
        capturedAccept = request.headers.value('accept');
        request.response.statusCode = 200;
        request.response.headers.contentType =
            ContentType('text', 'event-stream', charset: 'utf-8');
        request.response.write('event: connect\ndata: connected\n\n');
        request.response.write(
          'event: new_letter\ndata: {"notificationId":12,"message":"새 편지","letterId":42}\n\n',
        );
        await request.response.close();
      });

      final events = await streamClient.connect('ticket-abc').toList();

      expect(capturedUri?.path, '/api/v1/notifications/subscribe');
      expect(capturedUri?.queryParameters['ticket'], 'ticket-abc');
      expect(capturedAccept, 'text/event-stream');
      expect(events, hasLength(2));
      expect(events[0].type, NotificationStreamEventType.connect);
      expect(events[0].message, 'connected');
      expect(events[1].type, NotificationStreamEventType.newLetter);
      expect(events[1].notificationId, 12);
      expect(events[1].letterId, 42);
      expect(events[1].message, '새 편지');
    });

    test('maps 401 and 403 to unauthorized and 500 to server ApiClientException',
        () async {
      var step = 0;
      server.listen((request) async {
        step += 1;
        request.response.statusCode = switch (step) {
          1 => 401,
          2 => 403,
          _ => 500,
        };
        await request.response.close();
      });

      await expectLater(
        streamClient.connect('expired').drain<void>(),
        throwsA(
          isA<ApiClientException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );

      await expectLater(
        streamClient.connect('forbidden').drain<void>(),
        throwsA(
          isA<ApiClientException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );

      await expectLater(
        streamClient.connect('server-err').drain<void>(),
        throwsA(
          isA<ApiClientException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.server)
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}

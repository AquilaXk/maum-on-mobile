import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/core/network/multipart_body.dart';

void main() {
  group('ApiClient', () {
    test('parses successful envelope data', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {'name': 'maum'},
        }),
      ]);
      final client = ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      );

      final result = await client.get<Map<String, Object?>>(
        '/profile',
        parser: (json) => json as Map<String, Object?>,
      );

      expect(result, {'name': 'maum'});
    });

    test('maps empty successful response to an empty response error', () async {
      final transport = _FakeApiTransport([
        const ApiTransportResponse(statusCode: 200),
      ]);
      final client = ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      );

      await expectLater(
        client.get<Map<String, Object?>>(
          '/profile',
          parser: (json) => json as Map<String, Object?>,
        ),
        throwsA(
          isA<ApiClientException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.emptyResponse,
          ),
        ),
      );
    });

    test('retries once after a successful token refresh', () async {
      final transport = _FakeApiTransport([
        const ApiTransportResponse(statusCode: 401),
        ApiTransportResponse.ok({
          'success': true,
          'data': {'id': 1},
        }),
      ]);
      final tokenStore = MemoryAuthTokenStore(
        initialTokens: const TokenPair(
          accessToken: 'old-access',
          refreshToken: 'refresh-token',
        ),
      );
      final client = ApiClient(
        transport: transport,
        tokenStore: tokenStore,
        tokenRefresher: const _StaticTokenRefresher(
          TokenPair(
            accessToken: 'new-access',
            refreshToken: 'new-refresh',
          ),
        ),
      );

      final result = await client.get<Map<String, Object?>>(
        '/me',
        parser: (json) => json as Map<String, Object?>,
      );

      expect(result, {'id': 1});
      expect(transport.requests, hasLength(2));
      expect(
          transport.requests[0].headers['Authorization'], 'Bearer old-access');
      expect(
          transport.requests[1].headers['Authorization'], 'Bearer new-access');
      expect(await tokenStore.readAccessToken(), 'new-access');
      expect(await tokenStore.readRefreshToken(), 'new-refresh');
    });

    test('clears tokens when refresh fails', () async {
      final transport = _FakeApiTransport([
        const ApiTransportResponse(statusCode: 401),
      ]);
      final tokenStore = MemoryAuthTokenStore(
        initialTokens: const TokenPair(
          accessToken: 'old-access',
          refreshToken: 'refresh-token',
        ),
      );
      final client = ApiClient(
        transport: transport,
        tokenStore: tokenStore,
        tokenRefresher: const _StaticTokenRefresher(null),
      );

      await expectLater(
        client.get<Map<String, Object?>>(
          '/me',
          parser: (json) => json as Map<String, Object?>,
        ),
        throwsA(
          isA<ApiClientException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.unauthorized,
          ),
        ),
      );
      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
    });

    test('clears tokens when refresh throws', () async {
      final transport = _FakeApiTransport([
        const ApiTransportResponse(statusCode: 401),
      ]);
      final tokenStore = MemoryAuthTokenStore(
        initialTokens: const TokenPair(
          accessToken: 'old-access',
          refreshToken: 'refresh-token',
        ),
      );
      final client = ApiClient(
        transport: transport,
        tokenStore: tokenStore,
        tokenRefresher: const _ThrowingTokenRefresher(),
      );

      await expectLater(
        client.get<Map<String, Object?>>(
          '/me',
          parser: (json) => json as Map<String, Object?>,
        ),
        throwsA(
          isA<ApiClientException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.unauthorized,
          ),
        ),
      );
      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
    });

    test('maps forbidden response to a screen-ready error', () async {
      final transport = _FakeApiTransport([
        const ApiTransportResponse(
          statusCode: 403,
          body: {
            'success': false,
            'error': {'code': 'FORBIDDEN', 'message': '권한이 없습니다.'},
          },
        ),
      ]);
      final client = ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      );

      await expectLater(
        client.get<Map<String, Object?>>(
          '/admin',
          parser: (json) => json as Map<String, Object?>,
        ),
        throwsA(
          isA<ApiClientException>()
              .having((error) => error.kind, 'kind', ApiErrorKind.forbidden)
              .having((error) => error.message, 'message', '권한이 없습니다.'),
        ),
      );
    });

    test('parses page envelopes', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'content': [
              {'title': 'first'},
              {'title': 'second'},
            ],
            'page': 1,
            'size': 2,
            'totalElements': 5,
            'totalPages': 3,
            'last': false,
          },
        }),
      ]);
      final client = ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      );

      final page = await client.getPage<String>(
        '/stories',
        itemParser: (json) =>
            (json as Map<String, Object?>)['title']! as String,
      );

      expect(page.items, ['first', 'second']);
      expect(page.page, 1);
      expect(page.totalElements, 5);
      expect(page.last, isFalse);
    });

    test('sends image multipart requests through the transport', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {'uploaded': true},
        }),
      ]);
      final client = ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      );
      final image = MultipartFilePart(
        fieldName: 'image',
        filename: 'diary.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final result = await client.postMultipart<Map<String, Object?>>(
        '/images',
        multipart: MultipartBody.image(image),
        parser: (json) => json as Map<String, Object?>,
      );

      expect(result, {'uploaded': true});
      expect(transport.requests.single.method, ApiMethod.post);
      expect(transport.requests.single.multipart?.files.single.filename,
          'diary.png');
      expect(
          transport.requests.single.multipart?.files.single.bytes, [1, 2, 3]);
    });

    test('sends JSON and image multipart parts through the transport',
        () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {'updated': true},
        }),
      ]);
      final client = ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      );

      await client.putMultipart<Map<String, Object?>>(
        '/diaries/1',
        multipart: MultipartBody(
          textParts: const [
            MultipartTextPart(
              fieldName: 'data',
              value: '{"title":"오늘"}',
              contentType: 'application/json',
            ),
          ],
          files: [
            MultipartFilePart(
              fieldName: 'image',
              filename: 'diary.png',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
        ),
        parser: (json) => json as Map<String, Object?>,
      );

      final multipart = transport.requests.single.multipart!;
      expect(transport.requests.single.method, ApiMethod.put);
      expect(multipart.textParts.single.fieldName, 'data');
      expect(multipart.textParts.single.contentType, 'application/json');
      expect(multipart.files.single.fieldName, 'image');
    });

    test('sends delete requests through the transport', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'success': true}),
      ]);
      final client = ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      );

      await client.deleteVoid('/diaries/1');

      expect(transport.requests.single.method, ApiMethod.delete);
      expect(transport.requests.single.path, '/diaries/1');
    });

    test('sends JSON put and patch void requests through the transport',
        () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'resultCode': '200-3'}),
        ApiTransportResponse.ok({'resultCode': '200-5'}),
      ]);
      final client = ApiClient(
        transport: transport,
        tokenStore: MemoryAuthTokenStore(),
      );

      await client.putVoid('/posts/1', body: {'title': '수정'});
      await client.patchVoid(
        '/posts/1/resolution-status',
        body: {'resolutionStatus': 'RESOLVED'},
      );

      expect(transport.requests[0].method, ApiMethod.put);
      expect(transport.requests[0].body, {'title': '수정'});
      expect(transport.requests[1].method, ApiMethod.patch);
      expect(transport.requests[1].body, {'resolutionStatus': 'RESOLVED'});
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

class _StaticTokenRefresher implements AuthTokenRefresher {
  const _StaticTokenRefresher(this._tokens);

  final TokenPair? _tokens;

  @override
  Future<TokenPair?> refresh(String refreshToken) async => _tokens;
}

class _ThrowingTokenRefresher implements AuthTokenRefresher {
  const _ThrowingTokenRefresher();

  @override
  Future<TokenPair?> refresh(String refreshToken) {
    throw StateError('Refresh failed.');
  }
}

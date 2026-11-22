import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'api_config.dart';
import 'api_transport.dart';
import 'http_transport_codec.dart';

ManagedApiTransport createHttpApiTransport(
  ApiConfig config, {
  Duration connectTimeout = defaultConnectTimeout,
  Duration requestTimeout = defaultRequestTimeout,
  int maxResponseBytes = defaultMaxResponseBytes,
}) {
  return HttpApiTransportIo(
    baseUrl: config.baseUrl,
    connectTimeout: connectTimeout,
    requestTimeout: requestTimeout,
    maxResponseBytes: maxResponseBytes,
  );
}

class HttpApiTransportIo implements ManagedApiTransport {
  HttpApiTransportIo({
    required Uri baseUrl,
    this.connectTimeout = defaultConnectTimeout,
    this.requestTimeout = defaultRequestTimeout,
    this.maxResponseBytes = defaultMaxResponseBytes,
    HttpClient? httpClient,
  })  : assert(maxResponseBytes > 0),
        _baseUrl = baseUrl,
        _ownsClient = httpClient == null,
        _httpClient =
            httpClient ?? (HttpClient()..connectionTimeout = connectTimeout);

  final Uri _baseUrl;
  final Duration connectTimeout;
  final Duration requestTimeout;
  final int maxResponseBytes;
  final HttpClient _httpClient;
  final bool _ownsClient;

  @override
  void close({bool force = false}) {
    if (_ownsClient) {
      _httpClient.close(force: force);
    }
  }

  @override
  Future<ApiTransportResponse> send(ApiRequest request) async {
    HttpClientRequest? activeRequest;
    try {
      return await _sendInternal(
        request,
        onRequestOpened: (opened) {
          activeRequest = opened;
        },
      ).timeout(
        requestTimeout,
        onTimeout: () {
          activeRequest?.abort();
          throw TimeoutException(
            'HTTP request timed out after ${requestTimeout.inMilliseconds}ms.',
            requestTimeout,
          );
        },
      );
    } on ApiTransportException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiTransportException(
        error.message ?? 'Network request timed out.',
        error,
      );
    } on SocketException catch (error) {
      throw ApiTransportException(error.message, error);
    } on HttpException catch (error) {
      throw ApiTransportException(error.message, error);
    } on FormatException catch (error) {
      throw ApiTransportException(error.message, error);
    }
  }

  Future<ApiTransportResponse> _sendInternal(
    ApiRequest request, {
    required void Function(HttpClientRequest request) onRequestOpened,
  }) async {
    validateRequestHeaders(request.headers);
    final uri = resolveApiUri(
      _baseUrl,
      request.path,
      request.queryParameters,
    );
    final ioRequest = await _httpClient.openUrl(
      httpMethodName(request.method),
      uri,
    );
    onRequestOpened(ioRequest);

    for (final entry in request.headers.entries) {
      ioRequest.headers.set(entry.key, entry.value);
    }

    if (request.multipart != null) {
      final encoded = encodeMultipartBody(request.multipart!);
      ioRequest.headers.set(
        HttpHeaders.contentTypeHeader,
        encoded.defaultContentType!,
      );
      ioRequest.contentLength = encoded.bytes.length;
      ioRequest.add(encoded.bytes);
    } else if (request.body != null) {
      final encoded = encodeRequestBody(request.body)!;
      if (!hasHeaderIgnoreCase(request.headers, HttpHeaders.contentTypeHeader) &&
          encoded.defaultContentType != null) {
        ioRequest.headers.set(
          HttpHeaders.contentTypeHeader,
          encoded.defaultContentType!,
        );
      }
      ioRequest.contentLength = encoded.bytes.length;
      ioRequest.add(encoded.bytes);
    }

    final response = await ioRequest.close();
    final contentLength = response.contentLength;
    if (contentLength > maxResponseBytes) {
      ioRequest.abort();
      throw ApiTransportException(
        'Response payload exceeds $maxResponseBytes byte limit.',
      );
    }

    final bytesBuilder = BytesBuilder(copy: false);
    var totalBytes = 0;
    await for (final chunk in response) {
      totalBytes += chunk.length;
      if (totalBytes > maxResponseBytes) {
        ioRequest.abort();
        throw ApiTransportException(
          'Response payload exceeds $maxResponseBytes byte limit.',
        );
      }
      bytesBuilder.add(chunk);
    }

    final responseHeaders = <String, List<String>>{};
    response.headers.forEach((name, values) {
      responseHeaders[name] = List<String>.unmodifiable(values);
    });

    final decodedBody = decodeResponseBytes(bytesBuilder.takeBytes());
    return ApiTransportResponse(
      statusCode: response.statusCode,
      body: decodedBody,
      headers: Map.unmodifiable(responseHeaders),
    );
  }
}

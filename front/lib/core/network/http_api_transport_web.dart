import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'api_config.dart';
import 'api_transport.dart';
import 'http_transport_codec.dart';
import 'multipart_body.dart';

ManagedApiTransport createHttpApiTransport(
  ApiConfig config, {
  Duration connectTimeout = defaultConnectTimeout,
  Duration requestTimeout = defaultRequestTimeout,
  int maxResponseBytes = defaultMaxResponseBytes,
}) {
  return HttpApiTransportWeb(
    baseUrl: config.baseUrl,
    requestTimeout: requestTimeout,
    maxResponseBytes: maxResponseBytes,
  );
}

class HttpApiTransportWeb implements ManagedApiTransport {
  HttpApiTransportWeb({
    required Uri baseUrl,
    this.requestTimeout = defaultRequestTimeout,
    this.maxResponseBytes = defaultMaxResponseBytes,
  })  : assert(maxResponseBytes > 0),
        _baseUrl = baseUrl;

  final Uri _baseUrl;
  final Duration requestTimeout;
  final int maxResponseBytes;

  @override
  void close({bool force = false}) {}

  @override
  Future<ApiTransportResponse> send(ApiRequest request) async {
    validateRequestHeaders(request.headers);
    final uri = resolveApiUri(
      _baseUrl,
      request.path,
      request.queryParameters,
    );

    final abortController = _JSAbortController();
    final timeoutTimer = Timer(requestTimeout, () {
      abortController.abort('Request timed out.'.toJS);
    });

    try {
      final jsHeaders = _JSHeaders();
      for (final entry in request.headers.entries) {
        if (request.multipart != null &&
            entry.key.toLowerCase() == 'content-type') {
          continue;
        }
        jsHeaders.append(entry.key.toJS, entry.value.toJS);
      }

      JSAny? jsBody;
      if (request.multipart != null) {
        jsBody = _buildFormData(request.multipart!);
      } else if (request.body != null) {
        final encoded = encodeRequestBody(request.body)!;
        if (!hasHeaderIgnoreCase(request.headers, 'content-type') &&
            encoded.defaultContentType != null) {
          jsHeaders.append('Content-Type'.toJS, encoded.defaultContentType!.toJS);
        }
        jsBody = encoded.bytes.toJS;
      }

      final init = _JSRequestInit(
        method: httpMethodName(request.method).toJS,
        headers: jsHeaders,
        body: jsBody,
        signal: abortController.signal,
      );

      final response = await _jsFetch(uri.toString().toJS, init).toDart.timeout(
        requestTimeout,
        onTimeout: () {
          abortController.abort('Request timed out.'.toJS);
          throw TimeoutException('Network request timed out.', requestTimeout);
        },
      );

      final headersMap = <String, List<String>>{};
      response.headers.forEach(
        ((JSString value, JSString name) {
          final key = name.toDart;
          headersMap.putIfAbsent(key, () => <String>[]).add(value.toDart);
        }).toJS,
      );

      final contentLengthRaw = headersMap['content-length']?.firstOrNull;
      final declaredLength =
          contentLengthRaw == null ? null : int.tryParse(contentLengthRaw.trim());
      if (declaredLength != null && declaredLength > maxResponseBytes) {
        abortController.abort('Response payload exceeded limit.'.toJS);
        throw ApiTransportException(
          'Response payload exceeds $maxResponseBytes byte limit.',
        );
      }

      final bytes = await _readResponseBytes(response, abortController);
      final body = decodeResponseBytes(bytes);

      return ApiTransportResponse(
        statusCode: response.status,
        body: body,
        headers: Map.unmodifiable(
          headersMap.map(
            (key, values) => MapEntry(key, List<String>.unmodifiable(values)),
          ),
        ),
      );
    } on ApiTransportException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiTransportException(
        error.message ?? 'Network request timed out.',
        error,
      );
    } on FormatException catch (error) {
      throw ApiTransportException(error.message, error);
    } on Object catch (error) {
      throw ApiTransportException('Network request failed.', error);
    } finally {
      timeoutTimer.cancel();
    }
  }

  _JSFormData _buildFormData(MultipartBody multipart) {
    final formData = _JSFormData();
    for (final entry in multipart.fields.entries) {
      formData.appendString(
        sanitizeMultipartToken(entry.key).toJS,
        entry.value.toJS,
      );
    }

    for (final part in multipart.textParts) {
      final safeName = sanitizeMultipartToken(part.fieldName);
      final safeType = sanitizeHeaderValue(part.contentType);
      if (safeType == null) {
        formData.appendString(safeName.toJS, part.value.toJS);
      } else {
        final encodedBytes = Uint8List.fromList(utf8.encode(part.value));
        final blob = _JSBlob(
          <JSAny>[encodedBytes.toJS].toJS,
          _JSBlobPropertyBag(type: safeType.toJS),
        );
        formData.appendBlob(safeName.toJS, blob);
      }
    }

    for (final file in multipart.files) {
      final safeName = sanitizeMultipartToken(file.fieldName);
      final safeFilename = sanitizeMultipartToken(file.filename);
      final safeType =
          sanitizeHeaderValue(file.contentType) ?? 'application/octet-stream';
      final blob = _JSBlob(
        <JSAny>[Uint8List.fromList(file.bytes).toJS].toJS,
        _JSBlobPropertyBag(type: safeType.toJS),
      );
      formData.appendBlob(safeName.toJS, blob, safeFilename.toJS);
    }

    return formData;
  }

  Future<Uint8List> _readResponseBytes(
    _JSResponse response,
    _JSAbortController abortController,
  ) async {
    final stream = response.body;
    if (stream == null) {
      final buffer = (await response.arrayBuffer().toDart).toDart;
      final bytes = buffer.asUint8List();
      if (bytes.length > maxResponseBytes) {
        throw ApiTransportException(
          'Response payload exceeds $maxResponseBytes byte limit.',
        );
      }
      return bytes;
    }

    final reader = stream.getReader();
    final builder = BytesBuilder(copy: false);
    var totalBytes = 0;

    while (true) {
      final result = await reader.read().toDart.timeout(
        requestTimeout,
        onTimeout: () {
          abortController.abort('Request timed out.'.toJS);
          throw TimeoutException('Network response timed out.', requestTimeout);
        },
      );
      if (result.done) {
        break;
      }
      final chunk = result.value?.toDart;
      if (chunk == null || chunk.isEmpty) {
        continue;
      }
      totalBytes += chunk.length;
      if (totalBytes > maxResponseBytes) {
        try {
          await reader.cancel('Response limit exceeded.'.toJS).toDart;
        } on Object {
          // Ignore cancellation error after exceeding cap.
        }
        throw ApiTransportException(
          'Response payload exceeds $maxResponseBytes byte limit.',
        );
      }
      builder.add(chunk);
    }

    return builder.takeBytes();
  }
}

@JS('fetch')
external JSPromise<_JSResponse> _jsFetch(JSString input, [_JSRequestInit? init]);

@JS('AbortController')
extension type _JSAbortController._(JSObject _) implements JSObject {
  external factory _JSAbortController();
  external JSObject get signal;
  external void abort([JSAny? reason]);
}

@JS('Headers')
extension type _JSHeaders._(JSObject _) implements JSObject {
  external factory _JSHeaders();
  external void append(JSString name, JSString value);
  external void forEach(JSFunction callback);
}

@JS('FormData')
extension type _JSFormData._(JSObject _) implements JSObject {
  external factory _JSFormData();
  @JS('append')
  external void appendString(JSString name, JSString value);
  @JS('append')
  external void appendBlob(JSString name, _JSBlob value, [JSString filename]);
}

@JS('Blob')
extension type _JSBlob._(JSObject _) implements JSObject {
  external factory _JSBlob(
    JSArray<JSAny> blobParts, [
    _JSBlobPropertyBag? options,
  ]);
}

extension type _JSBlobPropertyBag._(JSObject _) implements JSObject {
  external factory _JSBlobPropertyBag({JSString type});
}

extension type _JSRequestInit._(JSObject _) implements JSObject {
  external factory _JSRequestInit({
    JSString method,
    _JSHeaders headers,
    JSAny? body,
    JSObject signal,
  });
}

extension type _JSResponse._(JSObject _) implements JSObject {
  external int get status;
  external _JSHeaders get headers;
  external _JSReadableStream? get body;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _JSReadableStream._(JSObject _) implements JSObject {
  external _JSReadableStreamDefaultReader getReader();
}

extension type _JSReadableStreamDefaultReader._(JSObject _)
    implements JSObject {
  external JSPromise<_JSReadResult> read();
  external JSPromise<JSAny?> cancel([JSAny? reason]);
}

extension type _JSReadResult._(JSObject _) implements JSObject {
  external bool get done;
  external JSUint8Array? get value;
}

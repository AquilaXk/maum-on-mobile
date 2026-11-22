import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'api_transport.dart';
import 'multipart_body.dart';

abstract interface class ManagedApiTransport implements ApiTransport {
  void close({bool force = false});
}

const int defaultMaxResponseBytes = 10 * 1024 * 1024;
const Duration defaultConnectTimeout = Duration(seconds: 5);
const Duration defaultRequestTimeout = Duration(seconds: 10);

final RegExp _trailingSlashPattern = RegExp(r'/+$');
final RegExp _multipartUnsafeTokenPattern = RegExp(r'[\r\n"]');
final RegExp _headerControlPattern = RegExp(r'[\r\n\x00]');
final Random _boundaryRandom = Random.secure();

String httpMethodName(ApiMethod method) {
  return switch (method) {
    ApiMethod.get => 'GET',
    ApiMethod.post => 'POST',
    ApiMethod.put => 'PUT',
    ApiMethod.patch => 'PATCH',
    ApiMethod.delete => 'DELETE',
  };
}

Uri resolveApiUri(
  Uri baseUrl,
  String path, [
  Map<String, Object?> queryParameters = const {},
]) {
  final parsedPath = Uri.parse(path);
  final baseString = baseUrl.toString().replaceFirst(_trailingSlashPattern, '');
  final pathOnly = parsedPath.path;
  final normalizedPath =
      pathOnly.startsWith('/') ? pathOnly.substring(1) : pathOnly;
  final joined = normalizedPath.isEmpty
      ? Uri.parse(baseString)
      : Uri.parse('$baseString/$normalizedPath');

  final merged = <String, List<String>>{};
  for (final entry in baseUrl.queryParametersAll.entries) {
    merged[entry.key] = List<String>.from(entry.value);
  }
  for (final entry in parsedPath.queryParametersAll.entries) {
    merged[entry.key] = List<String>.from(entry.value);
  }
  for (final entry in queryParameters.entries) {
    final value = entry.value;
    if (value == null) {
      continue;
    }
    if (value is Iterable) {
      final values = <String>[
        for (final item in value)
          if (item != null) item.toString(),
      ];
      if (values.isNotEmpty) {
        merged[entry.key] = values;
      }
    } else {
      merged[entry.key] = [value.toString()];
    }
  }

  return joined.replace(
    queryParameters: merged.isEmpty ? null : merged,
  );
}

bool hasHeaderIgnoreCase(Map<String, String> headers, String targetName) {
  final lowerTarget = targetName.toLowerCase();
  for (final key in headers.keys) {
    if (key.toLowerCase() == lowerTarget) {
      return true;
    }
  }
  return false;
}

void validateRequestHeaders(Map<String, String> headers) {
  for (final entry in headers.entries) {
    if (_headerControlPattern.hasMatch(entry.key) ||
        _headerControlPattern.hasMatch(entry.value)) {
      throw const ApiTransportException('Invalid control character in header.');
    }
  }
}

String sanitizeMultipartToken(String value) {
  return value.replaceAll(_multipartUnsafeTokenPattern, '_');
}

String? sanitizeHeaderValue(String? value) {
  if (value == null) {
    return null;
  }
  final sanitized = value.replaceAll(_headerControlPattern, '').trim();
  return sanitized.isEmpty ? null : sanitized;
}

String generateMultipartBoundary() {
  final buffer = StringBuffer('----maumOnBoundary');
  for (var i = 0; i < 6; i += 1) {
    final word = _boundaryRandom.nextInt(0x10000);
    buffer.write(word.toRadixString(16).padLeft(4, '0'));
  }
  return sanitizeMultipartToken(buffer.toString());
}

class EncodedRequestBody {
  const EncodedRequestBody({
    required this.bytes,
    this.defaultContentType,
  });

  final Uint8List bytes;
  final String? defaultContentType;
}

EncodedRequestBody? encodeRequestBody(Object? body) {
  if (body == null) {
    return null;
  }
  if (body is Uint8List) {
    return EncodedRequestBody(
      bytes: body,
      defaultContentType: 'application/octet-stream',
    );
  }
  if (body is List<int>) {
    return EncodedRequestBody(
      bytes: Uint8List.fromList(body),
      defaultContentType: 'application/octet-stream',
    );
  }
  if (body is String) {
    return EncodedRequestBody(
      bytes: Uint8List.fromList(utf8.encode(body)),
      defaultContentType: 'application/json; charset=utf-8',
    );
  }
  return EncodedRequestBody(
    bytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    defaultContentType: 'application/json; charset=utf-8',
  );
}

EncodedRequestBody encodeMultipartBody(MultipartBody body) {
  final boundary = generateMultipartBoundary();
  final builder = BytesBuilder(copy: false);

  void writeAscii(String text) {
    builder.add(utf8.encode(text));
  }

  for (final entry in body.fields.entries) {
    final safeName = sanitizeMultipartToken(entry.key);
    writeAscii('--$boundary\r\n');
    writeAscii('Content-Disposition: form-data; name="$safeName"\r\n\r\n');
    builder.add(utf8.encode(entry.value));
    writeAscii('\r\n');
  }

  for (final part in body.textParts) {
    final safeName = sanitizeMultipartToken(part.fieldName);
    final safeType = sanitizeHeaderValue(part.contentType);
    writeAscii('--$boundary\r\n');
    writeAscii('Content-Disposition: form-data; name="$safeName"\r\n');
    if (safeType != null) {
      writeAscii('Content-Type: $safeType\r\n');
    }
    writeAscii('\r\n');
    builder.add(utf8.encode(part.value));
    writeAscii('\r\n');
  }

  for (final file in body.files) {
    final safeName = sanitizeMultipartToken(file.fieldName);
    final safeFilename = sanitizeMultipartToken(file.filename);
    final safeType = sanitizeHeaderValue(file.contentType);
    writeAscii('--$boundary\r\n');
    writeAscii(
      'Content-Disposition: form-data; name="$safeName"; filename="$safeFilename"\r\n',
    );
    if (safeType != null) {
      writeAscii('Content-Type: $safeType\r\n');
    }
    writeAscii('\r\n');
    builder.add(file.bytes);
    writeAscii('\r\n');
  }

  writeAscii('--$boundary--\r\n');

  return EncodedRequestBody(
    bytes: builder.takeBytes(),
    defaultContentType: 'multipart/form-data; boundary=$boundary',
  );
}

Object? decodeResponseBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    return null;
  }
  final text = utf8.decode(bytes);
  if (text.trim().isEmpty) {
    return null;
  }
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}

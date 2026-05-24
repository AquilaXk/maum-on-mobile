import 'api_error.dart';

class ApiEnvelope<T> {
  const ApiEnvelope({
    required this.success,
    this.data,
    this.error,
  });

  factory ApiEnvelope.fromJson(
    Object? json,
    T Function(Object? json) parser,
  ) {
    if (json is! Map) {
      throw const FormatException('Expected API envelope object.');
    }

    final map = _stringKeyedMap(json);
    final success = map['success'];

    if (success is bool) {
      return ApiEnvelope<T>(
        success: success,
        data: success ? parser(map['data']) : null,
        error: success ? null : ApiErrorBody.fromJson(map['error']),
      );
    }

    final resultCode = map['resultCode'];
    if (resultCode is String) {
      return ApiEnvelope<T>(
        success: resultCode.startsWith('2'),
        data: resultCode.startsWith('2') ? parser(map['data']) : null,
        error: resultCode.startsWith('2')
            ? null
            : ApiErrorBody(
                code: resultCode,
                message: map['msg']?.toString() ?? '요청을 처리하지 못했습니다.',
              ),
      );
    }

    throw const FormatException('Expected API envelope success flag.');
  }

  static ApiEnvelope<void> voidEnvelope(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected API envelope object.');
    }

    final map = _stringKeyedMap(json);
    final success = map['success'];
    if (success is bool) {
      return ApiEnvelope<void>(
        success: success,
        error: success ? null : ApiErrorBody.fromJson(map['error']),
      );
    }

    final resultCode = map['resultCode'];
    if (resultCode is String) {
      return ApiEnvelope<void>(
        success: resultCode.startsWith('2'),
        error: resultCode.startsWith('2')
            ? null
            : ApiErrorBody(
                code: resultCode,
                message: map['msg']?.toString() ?? '요청을 처리하지 못했습니다.',
              ),
      );
    }

    throw const FormatException('Expected API envelope success flag.');
  }

  final bool success;
  final T? data;
  final ApiErrorBody? error;
}

class PageResponse<T> {
  const PageResponse({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory PageResponse.fromJson(
    Object? json,
    T Function(Object? json) itemParser,
  ) {
    if (json is! Map) {
      throw const FormatException('Expected page response object.');
    }

    final map = _stringKeyedMap(json);
    final rawItems = map['content'] ?? map['items'];

    if (rawItems is! List) {
      throw const FormatException('Expected page response items.');
    }

    return PageResponse<T>(
      items: rawItems.map(itemParser).toList(growable: false),
      page: _readInt(map, 'page'),
      size: _readInt(map, 'size'),
      totalElements: _readInt(map, 'totalElements'),
      totalPages: _readInt(map, 'totalPages'),
      last: map['last'] == true,
    );
  }

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;
}

int _readInt(Map<String, Object?> map, String key) {
  final value = map[key];

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return 0;
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

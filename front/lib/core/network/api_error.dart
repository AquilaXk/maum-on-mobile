enum ApiErrorKind {
  unauthorized,
  forbidden,
  network,
  emptyResponse,
  server,
  unknown,
}

class ApiClientException implements Exception {
  const ApiClientException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.fieldErrors = const [],
    this.cause,
  });

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final List<ApiFieldError> fieldErrors;
  final Object? cause;

  @override
  String toString() => 'ApiClientException($kind, $message)';
}

class ApiErrorBody {
  const ApiErrorBody({
    this.code,
    required this.message,
    this.fieldErrors = const [],
  });

  factory ApiErrorBody.fromJson(Object? json) {
    if (json == null) {
      return const ApiErrorBody(message: '요청을 처리하지 못했습니다.');
    }

    if (json is String) {
      return ApiErrorBody(message: json);
    }

    if (json is! Map) {
      return const ApiErrorBody(message: '요청을 처리하지 못했습니다.');
    }

    final map = _stringKeyedMap(json);
    final rawFieldErrors = map['fieldErrors'] ?? map['errors'];

    return ApiErrorBody(
      code: (map['code'] ?? map['resultCode'])?.toString(),
      message: (map['message'] ?? map['msg'])?.toString() ??
          '요청을 처리하지 못했습니다.',
      fieldErrors: rawFieldErrors is List
          ? rawFieldErrors.map(ApiFieldError.fromJson).toList(growable: false)
          : const [],
    );
  }

  final String? code;
  final String message;
  final List<ApiFieldError> fieldErrors;
}

class ApiFieldError {
  const ApiFieldError({
    required this.field,
    required this.message,
  });

  factory ApiFieldError.fromJson(Object? json) {
    if (json is! Map) {
      return const ApiFieldError(field: '', message: '');
    }

    final map = _stringKeyedMap(json);
    return ApiFieldError(
      field: map['field']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
    );
  }

  final String field;
  final String message;
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

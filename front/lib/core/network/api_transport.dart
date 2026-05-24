import 'multipart_body.dart';

enum ApiMethod {
  get,
  post,
  put,
  patch,
  delete,
}

class ApiRequest {
  const ApiRequest({
    required this.method,
    required this.path,
    this.headers = const {},
    this.queryParameters = const {},
    this.body,
    this.multipart,
    this.requiresAuth = true,
    this.retryOnUnauthorized = true,
  });

  final ApiMethod method;
  final String path;
  final Map<String, String> headers;
  final Map<String, Object?> queryParameters;
  final Object? body;
  final MultipartBody? multipart;
  final bool requiresAuth;
  final bool retryOnUnauthorized;

  ApiRequest copyWith({
    Map<String, String>? headers,
  }) {
    return ApiRequest(
      method: method,
      path: path,
      headers: headers ?? this.headers,
      queryParameters: queryParameters,
      body: body,
      multipart: multipart,
      requiresAuth: requiresAuth,
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }
}

abstract interface class ApiTransport {
  Future<ApiTransportResponse> send(ApiRequest request);
}

class ApiTransportResponse {
  const ApiTransportResponse({
    required this.statusCode,
    this.body,
    this.headers = const {},
  });

  factory ApiTransportResponse.ok(Object? body) {
    return ApiTransportResponse(statusCode: 200, body: body);
  }

  final int statusCode;
  final Object? body;
  final Map<String, List<String>> headers;

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
}

class ApiTransportException implements Exception {
  const ApiTransportException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ApiTransportException($message)';
}

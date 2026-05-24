import 'api_error.dart';
import 'api_response.dart';
import 'api_transport.dart';
import 'auth_token_store.dart';
import 'multipart_body.dart';

class ApiClient {
  const ApiClient({
    required this.transport,
    required this.tokenStore,
    this.tokenRefresher,
  });

  final ApiTransport transport;
  final AuthTokenStore tokenStore;
  final AuthTokenRefresher? tokenRefresher;

  Future<T> get<T>(
    String path, {
    required T Function(Object? json) parser,
    Map<String, Object?> queryParameters = const {},
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) {
    return _send(
      ApiRequest(
        method: ApiMethod.get,
        path: path,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        retryOnUnauthorized: retryOnUnauthorized,
      ),
      parser,
    );
  }

  Future<T> post<T>(
    String path, {
    required T Function(Object? json) parser,
    Object? body,
    Map<String, Object?> queryParameters = const {},
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) {
    return _send(
      ApiRequest(
        method: ApiMethod.post,
        path: path,
        body: body,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        retryOnUnauthorized: retryOnUnauthorized,
      ),
      parser,
    );
  }

  Future<void> postVoid(
    String path, {
    Object? body,
    Map<String, Object?> queryParameters = const {},
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) {
    return _sendVoid(
      ApiRequest(
        method: ApiMethod.post,
        path: path,
        body: body,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        retryOnUnauthorized: retryOnUnauthorized,
      ),
    );
  }

  Future<void> putVoid(
    String path, {
    Object? body,
    Map<String, Object?> queryParameters = const {},
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) {
    return _sendVoid(
      ApiRequest(
        method: ApiMethod.put,
        path: path,
        body: body,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        retryOnUnauthorized: retryOnUnauthorized,
      ),
    );
  }

  Future<void> patchVoid(
    String path, {
    Object? body,
    Map<String, Object?> queryParameters = const {},
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) {
    return _sendVoid(
      ApiRequest(
        method: ApiMethod.patch,
        path: path,
        body: body,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        retryOnUnauthorized: retryOnUnauthorized,
      ),
    );
  }

  Future<PageResponse<T>> getPage<T>(
    String path, {
    required T Function(Object? json) itemParser,
    Map<String, Object?> queryParameters = const {},
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) {
    return get<PageResponse<T>>(
      path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      retryOnUnauthorized: retryOnUnauthorized,
      parser: (json) => PageResponse.fromJson(json, itemParser),
    );
  }

  Future<T> postMultipart<T>(
    String path, {
    required MultipartBody multipart,
    required T Function(Object? json) parser,
    Map<String, Object?> queryParameters = const {},
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) {
    return _send(
      ApiRequest(
        method: ApiMethod.post,
        path: path,
        queryParameters: queryParameters,
        multipart: multipart,
        requiresAuth: requiresAuth,
        retryOnUnauthorized: retryOnUnauthorized,
      ),
      parser,
    );
  }

  Future<T> putMultipart<T>(
    String path, {
    required MultipartBody multipart,
    required T Function(Object? json) parser,
    Map<String, Object?> queryParameters = const {},
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) {
    return _send(
      ApiRequest(
        method: ApiMethod.put,
        path: path,
        queryParameters: queryParameters,
        multipart: multipart,
        requiresAuth: requiresAuth,
        retryOnUnauthorized: retryOnUnauthorized,
      ),
      parser,
    );
  }

  Future<void> putMultipartVoid(
    String path, {
    required MultipartBody multipart,
    Map<String, Object?> queryParameters = const {},
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) {
    return _sendVoid(
      ApiRequest(
        method: ApiMethod.put,
        path: path,
        queryParameters: queryParameters,
        multipart: multipart,
        requiresAuth: requiresAuth,
        retryOnUnauthorized: retryOnUnauthorized,
      ),
    );
  }

  Future<void> deleteVoid(
    String path, {
    Map<String, Object?> queryParameters = const {},
    bool requiresAuth = true,
    bool retryOnUnauthorized = true,
  }) {
    return _sendVoid(
      ApiRequest(
        method: ApiMethod.delete,
        path: path,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        retryOnUnauthorized: retryOnUnauthorized,
      ),
    );
  }

  Future<T> _send<T>(
    ApiRequest request,
    T Function(Object? json) parser, {
    bool hasRetried = false,
  }) async {
    final preparedRequest = await _applyAuthorization(request);
    final response = await _sendTransport(preparedRequest);

    if (response.statusCode == 401 && request.retryOnUnauthorized) {
      return _handleUnauthorized(request, parser, hasRetried: hasRetried);
    }

    if (response.statusCode == 401) {
      await tokenStore.clear();
      throw _exceptionFromResponse(response, ApiErrorKind.unauthorized);
    }

    if (response.statusCode == 403) {
      throw _exceptionFromResponse(response, ApiErrorKind.forbidden);
    }

    if (!response.isSuccessful) {
      throw _exceptionFromResponse(response, ApiErrorKind.server);
    }

    if (response.body == null) {
      throw const ApiClientException(
        kind: ApiErrorKind.emptyResponse,
        message: '응답 데이터가 없습니다.',
      );
    }

    try {
      final envelope = ApiEnvelope<T>.fromJson(response.body, parser);

      if (!envelope.success) {
        throw _exceptionFromError(
          envelope.error,
          response.statusCode,
          ApiErrorKind.server,
        );
      }

      final data = envelope.data;
      if (data == null) {
        throw const ApiClientException(
          kind: ApiErrorKind.emptyResponse,
          message: '응답 데이터가 없습니다.',
        );
      }

      return data;
    } on ApiClientException {
      rethrow;
    } on FormatException catch (error) {
      throw ApiClientException(
        kind: ApiErrorKind.unknown,
        message: '응답 형식을 확인할 수 없습니다.',
        statusCode: response.statusCode,
        cause: error,
      );
    }
  }

  Future<void> _sendVoid(ApiRequest request) async {
    final preparedRequest = await _applyAuthorization(request);
    final response = await _sendTransport(preparedRequest);

    if (response.statusCode == 401 && request.retryOnUnauthorized) {
      await _handleUnauthorized<void>(
        request,
        (_) {},
        hasRetried: false,
      );
      return;
    }

    if (response.statusCode == 401) {
      await tokenStore.clear();
      throw _exceptionFromResponse(response, ApiErrorKind.unauthorized);
    }

    if (response.statusCode == 403) {
      throw _exceptionFromResponse(response, ApiErrorKind.forbidden);
    }

    if (!response.isSuccessful) {
      throw _exceptionFromResponse(response, ApiErrorKind.server);
    }

    if (response.body == null) {
      return;
    }

    try {
      final envelope = ApiEnvelope.voidEnvelope(response.body);
      if (!envelope.success) {
        throw _exceptionFromError(
          envelope.error,
          response.statusCode,
          ApiErrorKind.server,
        );
      }
    } on ApiClientException {
      rethrow;
    } on FormatException catch (error) {
      throw ApiClientException(
        kind: ApiErrorKind.unknown,
        message: '응답 형식을 확인할 수 없습니다.',
        statusCode: response.statusCode,
        cause: error,
      );
    }
  }

  Future<ApiTransportResponse> _sendTransport(ApiRequest request) async {
    try {
      return await transport.send(request);
    } on ApiTransportException catch (error) {
      throw ApiClientException(
        kind: ApiErrorKind.network,
        message: '네트워크 연결을 확인해 주세요.',
        cause: error,
      );
    }
  }

  Future<ApiRequest> _applyAuthorization(ApiRequest request) async {
    if (!request.requiresAuth) {
      return request;
    }

    final accessToken = await tokenStore.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return request;
    }

    return request.copyWith(
      headers: {
        ...request.headers,
        'Authorization': 'Bearer $accessToken',
      },
    );
  }

  Future<T> _handleUnauthorized<T>(
    ApiRequest request,
    T Function(Object? json) parser, {
    required bool hasRetried,
  }) async {
    if (hasRetried || tokenRefresher == null) {
      await tokenStore.clear();
      throw const ApiClientException(
        kind: ApiErrorKind.unauthorized,
        message: '다시 로그인해 주세요.',
        statusCode: 401,
      );
    }

    final refreshToken = await tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await tokenStore.clear();
      throw const ApiClientException(
        kind: ApiErrorKind.unauthorized,
        message: '다시 로그인해 주세요.',
        statusCode: 401,
      );
    }

    final TokenPair? refreshedTokens;
    try {
      refreshedTokens = await tokenRefresher!.refresh(refreshToken);
    } on Object catch (error) {
      await tokenStore.clear();
      throw ApiClientException(
        kind: ApiErrorKind.unauthorized,
        message: '다시 로그인해 주세요.',
        statusCode: 401,
        cause: error,
      );
    }

    if (refreshedTokens == null) {
      await tokenStore.clear();
      throw const ApiClientException(
        kind: ApiErrorKind.unauthorized,
        message: '다시 로그인해 주세요.',
        statusCode: 401,
      );
    }

    await tokenStore.saveTokens(refreshedTokens);
    return _send(request, parser, hasRetried: true);
  }

  ApiClientException _exceptionFromResponse(
    ApiTransportResponse response,
    ApiErrorKind fallbackKind,
  ) {
    final error = _errorFromBody(response.body);
    return _exceptionFromError(error, response.statusCode, fallbackKind);
  }

  ApiClientException _exceptionFromError(
    ApiErrorBody? error,
    int statusCode,
    ApiErrorKind fallbackKind,
  ) {
    return ApiClientException(
      kind: fallbackKind,
      message: error?.message ?? '요청을 처리하지 못했습니다.',
      statusCode: statusCode,
      code: error?.code,
      fieldErrors: error?.fieldErrors ?? const [],
    );
  }

  ApiErrorBody? _errorFromBody(Object? body) {
    if (body is Map) {
      final rawError = body['error'];
      return ApiErrorBody.fromJson(rawError ?? body);
    }

    if (body is String) {
      return ApiErrorBody(message: body);
    }

    return null;
  }
}

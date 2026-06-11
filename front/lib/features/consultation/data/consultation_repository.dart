import 'dart:async';
import 'dart:io';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/network/sse_event_parser.dart';
import '../domain/consultation_models.dart';

abstract interface class ConsultationRepository {
  Stream<ConsultationStreamEvent> connect();

  Future<ConsultationSendResult> sendMessage(String message);

  Future<List<ConsultationMessage>> loadRecentMessages();

  Future<int> deleteSensitiveMessages();
}

abstract interface class ConsultationStreamClient {
  Stream<ConsultationStreamEvent> connect();
}

class ApiConsultationRepository implements ConsultationRepository {
  const ApiConsultationRepository({
    required ApiClient apiClient,
    required ConsultationStreamClient streamClient,
  })  : _apiClient = apiClient,
        _streamClient = streamClient;

  final ApiClient _apiClient;
  final ConsultationStreamClient _streamClient;

  @override
  Stream<ConsultationStreamEvent> connect() {
    return _streamClient.connect();
  }

  @override
  Future<ConsultationSendResult> sendMessage(String message) {
    return _apiClient.post<ConsultationSendResult>(
      '/api/v1/consultations/chat',
      body: {'message': message},
      parser: ConsultationSendResult.fromJson,
    );
  }

  @override
  Future<List<ConsultationMessage>> loadRecentMessages() {
    return _apiClient.get<List<ConsultationMessage>>(
      '/api/v1/consultations/recent',
      parser: (json) {
        if (json is! Map) {
          throw const FormatException('Expected consultation history object.');
        }
        final messages = json['messages'];
        if (messages is! List) {
          throw const FormatException('Expected consultation messages list.');
        }
        return messages
            .map(ConsultationMessage.fromJson)
            .toList(growable: false);
      },
    );
  }

  @override
  Future<int> deleteSensitiveMessages() {
    return _apiClient.delete<int>(
      '/api/v1/consultations/sensitive',
      parser: (json) {
        if (json is! Map) {
          throw const FormatException('Expected sensitive delete result.');
        }
        final deletedCount = json['deletedCount'];
        if (deletedCount is int) {
          return deletedCount;
        }
        if (deletedCount is num) {
          return deletedCount.toInt();
        }
        return int.tryParse(deletedCount?.toString() ?? '') ?? 0;
      },
    );
  }
}

class HttpConsultationStreamClient implements ConsultationStreamClient {
  HttpConsultationStreamClient({
    required ApiConfig apiConfig,
    required AuthTokenStore tokenStore,
    HttpClient? httpClient,
  })  : _baseUrl = apiConfig.baseUrl,
        _tokenStore = tokenStore,
        _httpClient =
            httpClient ?? (HttpClient()..connectionTimeout = _connectTimeout);

  final Uri _baseUrl;
  final AuthTokenStore _tokenStore;
  final HttpClient _httpClient;

  @override
  Stream<ConsultationStreamEvent> connect() async* {
    try {
      final accessToken = await _tokenStore.readAccessToken();
      final request = await _httpClient.getUrl(
        _resolveApiPath(_baseUrl, '/api/v1/consultations/connect'),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      if (accessToken != null && accessToken.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      }

      final response = await request.close();
      final statusCode = response.statusCode;
      if (statusCode == HttpStatus.unauthorized) {
        await _tokenStore.clear();
        await response.drain<void>();
        throw const ApiClientException(
          kind: ApiErrorKind.unauthorized,
          message: '다시 로그인해 주세요.',
          statusCode: HttpStatus.unauthorized,
        );
      }

      if (statusCode < 200 || statusCode >= 300) {
        await response.drain<void>();
        throw ApiClientException(
          kind: ApiErrorKind.server,
          message: 'AI 상담 연결을 시작하지 못했습니다.',
          statusCode: statusCode,
        );
      }

      yield* const SseEventParser().parse(response).map(
            (event) => ConsultationStreamEvent.fromSse(
              event: event.event,
              data: event.data,
            ),
          );
    } on ApiClientException {
      rethrow;
    } on SocketException {
      throw const ApiClientException(
        kind: ApiErrorKind.network,
        message: 'AI 상담 연결을 시작하지 못했습니다. 네트워크 상태를 확인해 주세요.',
      );
    } on TimeoutException {
      throw const ApiClientException(
        kind: ApiErrorKind.network,
        message: 'AI 상담 연결 시간이 초과되었습니다. 네트워크 상태를 확인해 주세요.',
      );
    } on HttpException {
      throw const ApiClientException(
        kind: ApiErrorKind.server,
        message: 'AI 상담 연결이 종료되었습니다. 다시 연결해 주세요.',
      );
    }
  }
}

Uri _resolveApiPath(Uri baseUrl, String path) {
  final base = baseUrl.toString().replaceFirst(RegExp(r'/$'), '');
  final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
  return Uri.parse('$base/$normalizedPath');
}

const _connectTimeout = Duration(seconds: 5);

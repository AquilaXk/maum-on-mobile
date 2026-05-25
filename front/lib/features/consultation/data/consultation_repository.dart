import 'package:dio/dio.dart';

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

class DioConsultationStreamClient implements ConsultationStreamClient {
  DioConsultationStreamClient({
    required ApiConfig apiConfig,
    required AuthTokenStore tokenStore,
    Dio? dio,
  })  : _tokenStore = tokenStore,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: apiConfig.baseUrl.toString(),
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: Duration.zero,
                validateStatus: (_) => true,
              ),
            );

  final AuthTokenStore _tokenStore;
  final Dio _dio;

  @override
  Stream<ConsultationStreamEvent> connect() async* {
    final accessToken = await _tokenStore.readAccessToken();
    final headers = <String, String>{'Accept': 'text/event-stream'};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await _dio.get<ResponseBody>(
      '/api/v1/consultations/connect',
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 401) {
      await _tokenStore.clear();
      throw const ApiClientException(
        kind: ApiErrorKind.unauthorized,
        message: '다시 로그인해 주세요.',
        statusCode: 401,
      );
    }

    if (statusCode < 200 || statusCode >= 300) {
      throw ApiClientException(
        kind: ApiErrorKind.server,
        message: '상담 연결을 시작하지 못했습니다.',
        statusCode: statusCode,
      );
    }

    final body = response.data;
    if (body == null) {
      throw const ApiClientException(
        kind: ApiErrorKind.emptyResponse,
        message: '상담 연결 응답이 없습니다.',
      );
    }

    yield* const SseEventParser().parse(body.stream).map(
          (event) => ConsultationStreamEvent.fromSse(
            event: event.event,
            data: event.data,
          ),
        );
  }
}

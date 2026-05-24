import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/auth_token_store.dart';
import '../domain/consultation_models.dart';

abstract interface class ConsultationRepository {
  Stream<ConsultationStreamEvent> connect();

  Future<void> sendMessage(String message);
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
  Future<void> sendMessage(String message) {
    return _apiClient.postVoid(
      '/api/v1/consultations/chat',
      body: {'message': message},
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

    yield* _parseSse(body.stream);
  }

  Stream<ConsultationStreamEvent> _parseSse(
      Stream<List<int>> byteStream) async* {
    final builder = _SseEventBuilder();
    var pending = '';

    await for (final chunk in byteStream.transform(utf8.decoder)) {
      pending += chunk;

      while (true) {
        final lineBreakIndex = pending.indexOf('\n');
        if (lineBreakIndex == -1) {
          break;
        }

        var line = pending.substring(0, lineBreakIndex);
        pending = pending.substring(lineBreakIndex + 1);
        if (line.endsWith('\r')) {
          line = line.substring(0, line.length - 1);
        }

        final event = builder.consume(line);
        if (event != null) {
          yield event;
        }
      }
    }

    if (pending.isNotEmpty) {
      final event = builder.consume(pending);
      if (event != null) {
        yield event;
      }
    }

    final event = builder.flush();
    if (event != null) {
      yield event;
    }
  }
}

class _SseEventBuilder {
  String _eventName = 'message';
  final List<String> _dataLines = [];

  ConsultationStreamEvent? consume(String line) {
    if (line.isEmpty) {
      return flush();
    }

    if (line.startsWith(':')) {
      return null;
    }

    final separatorIndex = line.indexOf(':');
    final field =
        separatorIndex == -1 ? line : line.substring(0, separatorIndex);
    var value = separatorIndex == -1 ? '' : line.substring(separatorIndex + 1);
    if (value.startsWith(' ')) {
      value = value.substring(1);
    }

    if (field == 'event') {
      _eventName = value;
    } else if (field == 'data') {
      _dataLines.add(value);
    }

    return null;
  }

  ConsultationStreamEvent? flush() {
    if (_dataLines.isEmpty) {
      _eventName = 'message';
      return null;
    }

    final event = ConsultationStreamEvent.fromSse(
      event: _eventName,
      data: _dataLines.join('\n'),
    );
    _eventName = 'message';
    _dataLines.clear();
    return event;
  }
}

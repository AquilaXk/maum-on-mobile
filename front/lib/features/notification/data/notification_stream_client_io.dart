import 'dart:async';
import 'dart:io';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/http_transport_codec.dart';
import '../../../core/network/sse_event_parser.dart';
import '../domain/notification_models.dart';
import 'notification_stream_client.dart';

ManagedNotificationStreamClient createNotificationStreamClient({
  required ApiConfig apiConfig,
}) {
  return IoNotificationStreamClient(apiConfig: apiConfig);
}

class IoNotificationStreamClient implements ManagedNotificationStreamClient {
  IoNotificationStreamClient({
    required ApiConfig apiConfig,
    HttpClient? httpClient,
  })  : _baseUrl = apiConfig.baseUrl,
        _ownsHttpClient = httpClient == null,
        _httpClient = httpClient ??
            (HttpClient()..connectionTimeout = defaultConnectTimeout);

  final Uri _baseUrl;
  final HttpClient _httpClient;
  final bool _ownsHttpClient;

  @override
  void close({bool force = true}) {
    if (_ownsHttpClient) {
      _httpClient.close(force: force);
    }
  }

  @override
  Stream<NotificationStreamEvent> connect(String ticket) async* {
    try {
      final uri = resolveApiUri(
        _baseUrl,
        '/api/v1/notifications/subscribe',
        {'ticket': ticket},
      );
      final request = await _httpClient.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');

      final response = await request.close();
      final statusCode = response.statusCode;

      if (statusCode == HttpStatus.unauthorized ||
          statusCode == HttpStatus.forbidden) {
        await response.drain<void>();
        throw ApiClientException(
          kind: ApiErrorKind.unauthorized,
          message: '알림 연결 권한을 확인해 주세요.',
          statusCode: statusCode,
        );
      }

      if (statusCode < 200 || statusCode >= 300) {
        await response.drain<void>();
        throw ApiClientException(
          kind: ApiErrorKind.server,
          message: '알림 연결을 시작하지 못했습니다.',
          statusCode: statusCode,
        );
      }

      yield* const SseEventParser().parse(response).map(
            (event) => NotificationStreamEvent.fromSse(
              event: event.event,
              data: event.data,
            ),
          );
    } on ApiClientException {
      rethrow;
    } on SocketException catch (error) {
      throw ApiClientException(
        kind: ApiErrorKind.network,
        message: '알림 연결을 시작하지 못했습니다. 네트워크 상태를 확인해 주세요.',
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw ApiClientException(
        kind: ApiErrorKind.network,
        message: '알림 연결 시간이 초과되었습니다. 네트워크 상태를 확인해 주세요.',
        cause: error,
      );
    } on HttpException catch (error) {
      throw ApiClientException(
        kind: ApiErrorKind.server,
        message: '알림 연결이 종료되었습니다. 다시 연결해 주세요.',
        cause: error,
      );
    }
  }
}

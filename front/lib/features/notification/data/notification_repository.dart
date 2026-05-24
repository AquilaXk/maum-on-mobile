import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/sse_event_parser.dart';
import '../domain/notification_models.dart';

abstract interface class NotificationRepository {
  Future<List<NotificationItem>> fetchNotifications();

  Future<NotificationItem> markRead(int notificationId);

  Future<NotificationBulkReadResult> markAllRead();

  Future<NotificationDeviceTokenResult> registerDeviceToken({
    required NotificationDevicePlatform platform,
    required String token,
  });

  Future<bool> unregisterDeviceToken(String token);

  Future<NotificationSubscriptionTicket> requestSubscriptionTicket();

  Stream<NotificationStreamEvent> connect(String ticket);
}

abstract interface class NotificationStreamClient {
  Stream<NotificationStreamEvent> connect(String ticket);
}

class ApiNotificationRepository implements NotificationRepository {
  const ApiNotificationRepository({
    required ApiClient apiClient,
    required NotificationStreamClient streamClient,
  })  : _apiClient = apiClient,
        _streamClient = streamClient;

  final ApiClient _apiClient;
  final NotificationStreamClient _streamClient;

  @override
  Future<List<NotificationItem>> fetchNotifications() {
    return _apiClient.get<List<NotificationItem>>(
      '/api/v1/notifications',
      parser: (json) {
        if (json is! List) {
          throw const FormatException('Expected notification list.');
        }

        return json.map(NotificationItem.fromJson).toList(growable: false);
      },
    );
  }

  @override
  Future<NotificationItem> markRead(int notificationId) {
    return _apiClient.post<NotificationItem>(
      '/api/v1/notifications/$notificationId/read',
      parser: NotificationItem.fromJson,
    );
  }

  @override
  Future<NotificationBulkReadResult> markAllRead() {
    return _apiClient.post<NotificationBulkReadResult>(
      '/api/v1/notifications/read-all',
      parser: NotificationBulkReadResult.fromJson,
    );
  }

  @override
  Future<NotificationDeviceTokenResult> registerDeviceToken({
    required NotificationDevicePlatform platform,
    required String token,
  }) {
    return _apiClient.post<NotificationDeviceTokenResult>(
      '/api/v1/notifications/device-tokens',
      body: {
        'platform': platform.apiValue,
        'token': token,
      },
      parser: NotificationDeviceTokenResult.fromJson,
    );
  }

  @override
  Future<bool> unregisterDeviceToken(String token) {
    return _apiClient.delete<bool>(
      '/api/v1/notifications/device-tokens',
      body: {'token': token},
      parser: (json) => json == true,
    );
  }

  @override
  Future<NotificationSubscriptionTicket> requestSubscriptionTicket() {
    return _apiClient.post<NotificationSubscriptionTicket>(
      '/api/v1/notifications/subscribe-ticket',
      parser: NotificationSubscriptionTicket.fromJson,
    );
  }

  @override
  Stream<NotificationStreamEvent> connect(String ticket) {
    return _streamClient.connect(ticket);
  }
}

class DioNotificationStreamClient implements NotificationStreamClient {
  DioNotificationStreamClient({
    required ApiConfig apiConfig,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: apiConfig.baseUrl.toString(),
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: Duration.zero,
                validateStatus: (_) => true,
              ),
            );

  final Dio _dio;

  @override
  Stream<NotificationStreamEvent> connect(String ticket) async* {
    final response = await _dio.get<ResponseBody>(
      '/api/v1/notifications/subscribe',
      queryParameters: {'ticket': ticket},
      options: Options(
        responseType: ResponseType.stream,
        headers: const {'Accept': 'text/event-stream'},
      ),
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 401 || statusCode == 403) {
      throw ApiClientException(
        kind: ApiErrorKind.unauthorized,
        message: '알림 연결 권한을 확인해 주세요.',
        statusCode: statusCode,
      );
    }

    if (statusCode < 200 || statusCode >= 300) {
      throw ApiClientException(
        kind: ApiErrorKind.server,
        message: '알림 연결을 시작하지 못했습니다.',
        statusCode: statusCode,
      );
    }

    final body = response.data;
    if (body == null) {
      throw const ApiClientException(
        kind: ApiErrorKind.emptyResponse,
        message: '알림 연결 응답이 없습니다.',
      );
    }

    yield* const SseEventParser().parse(body.stream).map(
          (event) => NotificationStreamEvent.fromSse(
            event: event.event,
            data: event.data,
          ),
        );
  }
}

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../domain/notification_models.dart';
import 'notification_stream_client.dart';
import 'notification_stream_client_stub.dart'
    if (dart.library.io) 'notification_stream_client_io.dart'
    if (dart.library.js_interop) 'notification_stream_client_web.dart' as impl;

export 'notification_stream_client.dart' show NotificationStreamClient;

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

class HttpNotificationStreamClient implements ManagedNotificationStreamClient {
  HttpNotificationStreamClient({
    required ApiConfig apiConfig,
  }) : _delegate = impl.createNotificationStreamClient(apiConfig: apiConfig);

  final ManagedNotificationStreamClient _delegate;

  @override
  void close({bool force = true}) {
    _delegate.close(force: force);
  }

  @override
  Stream<NotificationStreamEvent> connect(String ticket) {
    return _delegate.connect(ticket);
  }
}

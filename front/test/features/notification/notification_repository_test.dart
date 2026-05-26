import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/notification/data/notification_repository.dart';
import 'package:maum_on_mobile_front/features/notification/domain/notification_models.dart';
import 'package:maum_on_mobile_front/features/report/data/report_repository.dart';
import 'package:maum_on_mobile_front/features/report/domain/report_models.dart';

void main() {
  group('ApiNotificationRepository', () {
    test('fetches notification list from the notification API', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'resultCode': '200-1',
          'data': [
            {
              'id': 7,
              'content': '새로운 랜덤 편지가 도착했습니다!',
              'type': 'new_letter',
              'targetType': 'LETTER',
              'targetId': 42,
              'routeKey': 'letter',
              'isRead': false,
              'createDate': '2026-05-24T09:00:00',
              'readAt': null,
            },
          ],
        }),
      ]);
      final repository = _notificationRepository(transport);

      final notifications = await repository.fetchNotifications();

      expect(transport.requests.single.path, '/api/v1/notifications');
      expect(transport.requests.single.method, ApiMethod.get);
      expect(notifications.single.id, 7);
      expect(notifications.single.content, '새로운 랜덤 편지가 도착했습니다!');
      expect(notifications.single.type, 'new_letter');
      expect(notifications.single.targetType, 'LETTER');
      expect(notifications.single.targetId, 42);
      expect(notifications.single.routeKey, 'letter');
      expect(notifications.single.tapPayload.destination,
          NotificationTapDestination.letter);
      expect(notifications.single.tapPayload.letterId, 42);
      expect(notifications.single.isRead, isFalse);
      expect(notifications.single.readAt, isNull);
    });

    test('marks notifications as read and registers device tokens', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'resultCode': '200-1',
          'data': {
            'id': 7,
            'content': '새로운 랜덤 편지가 도착했습니다!',
            'type': 'new_letter',
            'targetType': 'LETTER',
            'targetId': 42,
            'routeKey': 'letter',
            'isRead': true,
            'createdAt': '2026-05-24T09:00:00',
            'readAt': '2026-05-24T09:01:00',
          },
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-2',
          'data': {'updatedCount': 3},
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-3',
          'data': {
            'platform': 'ANDROID',
            'enabled': true,
            'updatedAt': '2026-05-24T09:02:00',
          },
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-4',
          'data': true,
        }),
      ]);
      final repository = _notificationRepository(transport);

      final notification = await repository.markRead(7);
      final readAll = await repository.markAllRead();
      final token = await repository.registerDeviceToken(
        platform: NotificationDevicePlatform.android,
        token: 'android-token-123456',
      );
      final removed = await repository.unregisterDeviceToken(
        'android-token-123456',
      );

      expect(transport.requests[0].path, '/api/v1/notifications/7/read');
      expect(transport.requests[0].method, ApiMethod.post);
      expect(notification.isRead, isTrue);
      expect(notification.tapPayload.letterId, 42);
      expect(notification.readAt, '2026-05-24T09:01:00');
      expect(transport.requests[1].path, '/api/v1/notifications/read-all');
      expect(readAll.updatedCount, 3);
      expect(transport.requests[2].path, '/api/v1/notifications/device-tokens');
      expect(transport.requests[2].method, ApiMethod.post);
      expect(transport.requests[2].body, {
        'platform': 'ANDROID',
        'token': 'android-token-123456',
      });
      expect(token.platform, NotificationDevicePlatform.android);
      expect(token.enabled, isTrue);
      expect(transport.requests[3].path, '/api/v1/notifications/device-tokens');
      expect(transport.requests[3].method, ApiMethod.delete);
      expect(transport.requests[3].body, {'token': 'android-token-123456'});
      expect(removed, isTrue);
    });

    test('requests a subscription ticket before opening the stream', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'resultCode': '200-2',
          'data': {
            'ticket': 'ticket-123',
            'expiresInSeconds': 60,
          },
        }),
      ]);
      final streamClient = _FakeNotificationStreamClient();
      final repository = _notificationRepository(
        transport,
        streamClient: streamClient,
      );

      final ticket = await repository.requestSubscriptionTicket();
      await repository.connect(ticket.ticket).drain<void>();

      expect(
        transport.requests.single.path,
        '/api/v1/notifications/subscribe-ticket',
      );
      expect(transport.requests.single.method, ApiMethod.post);
      expect(ticket.expiresInSeconds, 60);
      expect(streamClient.tickets, ['ticket-123']);
    });
  });

  group('ApiReportRepository', () {
    test('submits a report payload and returns the report id', () async {
      final transport = _FakeApiTransport([
        const ApiTransportResponse(
          statusCode: 201,
          body: {
            'resultCode': '201-1',
            'data': 42,
          },
        ),
      ]);
      final repository = ApiReportRepository(
        apiClient: ApiClient(
          transport: transport,
          tokenStore: MemoryAuthTokenStore(),
        ),
      );

      final reportId = await repository.createReport(
        const ReportDraft(
          target: ReportTarget(
            type: ReportTargetType.letter,
            id: 12,
            label: '도착한 편지',
          ),
          reason: ReportReasonCode.other,
          content: '반복적으로 불편한 표현이 있습니다.',
        ),
      );

      expect(reportId, 42);
      expect(transport.requests.single.path, '/api/v1/reports');
      expect(transport.requests.single.method, ApiMethod.post);
      expect(transport.requests.single.body, {
        'targetId': 12,
        'targetType': 'LETTER',
        'reason': 'OTHER',
        'content': '반복적으로 불편한 표현이 있습니다.',
      });
    });
  });
}

ApiNotificationRepository _notificationRepository(
  _FakeApiTransport transport, {
  NotificationStreamClient? streamClient,
}) {
  return ApiNotificationRepository(
    apiClient: ApiClient(
      transport: transport,
      tokenStore: MemoryAuthTokenStore(),
    ),
    streamClient: streamClient ?? _FakeNotificationStreamClient(),
  );
}

class _FakeApiTransport implements ApiTransport {
  _FakeApiTransport(this._responses);

  final List<ApiTransportResponse> _responses;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiTransportResponse> send(ApiRequest request) async {
    requests.add(request);

    if (_responses.isEmpty) {
      throw const ApiTransportException('No fake response configured');
    }

    return _responses.removeAt(0);
  }
}

class _FakeNotificationStreamClient implements NotificationStreamClient {
  final List<String> tickets = [];

  @override
  Stream<NotificationStreamEvent> connect(String ticket) {
    tickets.add(ticket);
    return const Stream<NotificationStreamEvent>.empty();
  }
}

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
              'isRead': false,
              'createDate': '2026-05-24T09:00:00',
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
      expect(notifications.single.isRead, isFalse);
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

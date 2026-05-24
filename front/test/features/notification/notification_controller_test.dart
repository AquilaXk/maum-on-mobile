import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/notification/application/notification_controller.dart';
import 'package:maum_on_mobile_front/features/notification/data/notification_repository.dart';
import 'package:maum_on_mobile_front/features/notification/data/push_notification_permission_client.dart';
import 'package:maum_on_mobile_front/features/notification/domain/notification_models.dart';

void main() {
  group('NotificationController', () {
    test('loads notifications and prepends streamed notification events',
        () async {
      final repository = _FakeNotificationRepository(
        notificationsQueue: [
          [
            const NotificationItem(
              id: 1,
              content: '상대방이 편지를 읽었습니다.',
              isRead: false,
              createdAt: '2026-05-24T09:00:00',
            ),
          ],
          const [],
        ],
      );
      final controller = NotificationController(repository: repository);

      await controller.load();
      await controller.connect();
      repository.emit(
        const NotificationStreamEvent.newLetter(
          '새로운 랜덤 편지가 도착했습니다!',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.ticketRequestCount, 1);
      expect(repository.connectTickets, ['ticket-1']);
      expect(controller.state.connectionState,
          NotificationConnectionState.connecting);
      expect(controller.state.notifications.first.content,
          '새로운 랜덤 편지가 도착했습니다!');
      expect(controller.state.notifications.last.content, '상대방이 편지를 읽었습니다.');
    });

    test('prepends report processing events from the notification stream',
        () async {
      final repository = _FakeNotificationRepository(
        notificationsQueue: [
          const [],
          const [],
        ],
      );
      final controller = NotificationController(repository: repository);

      await controller.load();
      await controller.connect();
      repository.emit(
        const NotificationStreamEvent.reportStatus(
          '신고 처리 결과가 등록되었습니다: RESOLVED',
          status: 'RESOLVED',
          reportId: 9,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.notifications.first.content,
          '신고 처리 결과가 등록되었습니다: RESOLVED');
      expect(controller.state.noticeMessage, '신고 처리 결과가 등록되었습니다: RESOLVED');
    });

    test('deduplicates streamed events by server notification id', () async {
      final repository = _FakeNotificationRepository(
        notificationsQueue: [
          const [],
          const [],
          const [],
        ],
      );
      final controller = NotificationController(repository: repository);

      await controller.load();
      await controller.connect();
      repository.emit(
        const NotificationStreamEvent.reportStatus(
          '신고 처리 결과가 등록되었습니다: RESOLVED',
          status: 'RESOLVED',
          reportId: 9,
          notificationId: 77,
          createdAt: '2026-05-24T09:00:00',
        ),
      );
      repository.emit(
        const NotificationStreamEvent.reportStatus(
          '신고 처리 결과가 등록되었습니다: RESOLVED',
          status: 'RESOLVED',
          reportId: 9,
          notificationId: 77,
          createdAt: '2026-05-24T09:00:00',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.notifications, hasLength(1));
      expect(controller.state.notifications.single.id, 77);
      expect(controller.state.lastReceivedAt, '2026-05-24T09:00:00');
    });

    test('marks one notification and then marks all notifications as read',
        () async {
      final repository = _FakeNotificationRepository(
        notificationsQueue: [
          [
            const NotificationItem(
              id: 3,
              content: '상대방이 편지를 읽었습니다.',
              isRead: false,
              createdAt: '2026-05-24T09:00:00',
            ),
            const NotificationItem(
              id: 4,
              content: '보낸 편지에 답장이 도착했습니다!',
              isRead: false,
              createdAt: '2026-05-24T09:01:00',
            ),
          ],
        ],
      );
      final controller = NotificationController(repository: repository);

      await controller.load();
      await controller.markAsRead(controller.state.notifications.first);
      await controller.markAllRead();

      expect(repository.markReadIds, [3]);
      expect(repository.markAllReadCount, 1);
      expect(controller.state.notifications.every((item) => item.isRead), isTrue);
    });

    test('requests push permission and registers the device token', () async {
      final repository = _FakeNotificationRepository();
      final permissionClient = _FakePushNotificationPermissionClient(
        const PushNotificationPermissionResult(
          granted: true,
          platform: NotificationDevicePlatform.ios,
          token: 'ios-token-1234567890',
        ),
      );
      final controller = NotificationController(
        repository: repository,
        pushPermissionClient: permissionClient,
      );

      await controller.requestPushPermission();

      expect(permissionClient.requestCount, 1);
      expect(repository.registeredTokens, ['IOS:ios-token-1234567890']);
      expect(
        controller.state.pushNotificationState,
        PushNotificationState.registered,
      );
    });

    test('does not request duplicate tickets while connecting', () async {
      final ticketCompleter = Completer<NotificationSubscriptionTicket>();
      final repository = _FakeNotificationRepository(
        ticketCompleter: ticketCompleter,
      );
      final controller = NotificationController(repository: repository);

      unawaited(controller.connect());
      await controller.connect();

      expect(repository.ticketRequestCount, 1);

      ticketCompleter.complete(
        const NotificationSubscriptionTicket(
          ticket: 'ticket-1',
          expiresInSeconds: 60,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    });

    test('surfaces ticket failures without opening a stream', () async {
      final repository = _FakeNotificationRepository(
        ticketError: const ApiClientException(
          kind: ApiErrorKind.server,
          message: '티켓을 발급하지 못했습니다.',
          statusCode: 500,
        ),
      );
      final controller = NotificationController(repository: repository);

      await controller.connect();

      expect(repository.connectTickets, isEmpty);
      expect(
        controller.state.connectionState,
        NotificationConnectionState.error,
      );
      expect(controller.state.errorMessage, '티켓을 발급하지 못했습니다.');
    });

    test('closes and restores the stream around app lifecycle changes',
        () async {
      final repository = _FakeNotificationRepository();
      final controller = NotificationController(
        repository: repository,
        reconnectDelay: Duration.zero,
      );

      await controller.connect();
      repository.emit(const NotificationStreamEvent.connect('연결되었습니다!'));

      controller.handleLifecycleState(AppLifecycleState.paused);

      expect(repository.cancelCount, 1);
      expect(controller.state.connectionState, NotificationConnectionState.idle);

      controller.handleLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(repository.ticketRequestCount, 2);
    });

    test('refreshes and reconnects after an open stream fails', () async {
      final repository = _FakeNotificationRepository(
        notificationsQueue: [
          const [],
          const [],
        ],
      );
      final controller = NotificationController(
        repository: repository,
        reconnectDelay: Duration.zero,
      );

      await controller.connect();
      repository.emit(const NotificationStreamEvent.connect('연결되었습니다!'));
      repository.emitError(const ApiClientException(
        kind: ApiErrorKind.network,
        message: '네트워크 연결을 확인해 주세요.',
      ));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.ticketRequestCount, 2);
      expect(repository.fetchCount, 1);
      expect(controller.state.connectionState,
          NotificationConnectionState.connecting);
    });
  });
}

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository({
    List<List<NotificationItem>> notificationsQueue = const [
      [],
    ],
    Completer<NotificationSubscriptionTicket>? ticketCompleter,
    this.ticketError,
  })  : _notificationsQueue =
            List<List<NotificationItem>>.of(notificationsQueue),
        _ticketCompleter = ticketCompleter;

  final List<List<NotificationItem>> _notificationsQueue;
  final Completer<NotificationSubscriptionTicket>? _ticketCompleter;
  final Object? ticketError;
  final List<String> connectTickets = [];
  final List<int> markReadIds = [];
  final List<String> registeredTokens = [];
  int ticketRequestCount = 0;
  int fetchCount = 0;
  int cancelCount = 0;
  int markAllReadCount = 0;
  StreamController<NotificationStreamEvent>? _controller;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    fetchCount += 1;
    if (_notificationsQueue.isEmpty) {
      return const [];
    }

    return _notificationsQueue.removeAt(0);
  }

  @override
  Future<NotificationItem> markRead(int notificationId) async {
    markReadIds.add(notificationId);
    return NotificationItem(
      id: notificationId,
      content: '상대방이 편지를 읽었습니다.',
      isRead: true,
      createdAt: '2026-05-24T09:00:00',
      readAt: '2026-05-24T09:02:00',
    );
  }

  @override
  Future<NotificationBulkReadResult> markAllRead() async {
    markAllReadCount += 1;
    return const NotificationBulkReadResult(updatedCount: 1);
  }

  @override
  Future<NotificationDeviceTokenResult> registerDeviceToken({
    required NotificationDevicePlatform platform,
    required String token,
  }) async {
    registeredTokens.add('${platform.apiValue}:$token');
    return NotificationDeviceTokenResult(
      platform: platform,
      enabled: true,
      updatedAt: '2026-05-24T09:03:00',
    );
  }

  @override
  Future<bool> unregisterDeviceToken(String token) async {
    registeredTokens.removeWhere((registered) => registered.endsWith(':$token'));
    return true;
  }

  @override
  Future<NotificationSubscriptionTicket> requestSubscriptionTicket() async {
    ticketRequestCount += 1;
    final error = ticketError;
    if (error != null) {
      throw error;
    }
    final completer = _ticketCompleter;
    if (completer != null) {
      return completer.future;
    }

    return NotificationSubscriptionTicket(
      ticket: 'ticket-$ticketRequestCount',
      expiresInSeconds: 60,
    );
  }

  @override
  Stream<NotificationStreamEvent> connect(String ticket) {
    connectTickets.add(ticket);
    _controller = StreamController<NotificationStreamEvent>(
      sync: true,
      onCancel: () {
        cancelCount += 1;
      },
    );
    return _controller!.stream;
  }

  void emit(NotificationStreamEvent event) {
    _controller?.add(event);
  }

  void emitError(Object error) {
    _controller?.addError(error);
  }
}

class _FakePushNotificationPermissionClient
    implements PushNotificationPermissionClient {
  _FakePushNotificationPermissionClient(this.result);

  final PushNotificationPermissionResult result;
  int requestCount = 0;

  @override
  Future<PushNotificationPermissionResult> requestPermission() async {
    requestCount += 1;
    return result;
  }
}

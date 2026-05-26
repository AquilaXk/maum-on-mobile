import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/notification/application/notification_controller.dart';
import 'package:maum_on_mobile_front/features/notification/data/notification_repository.dart';
import 'package:maum_on_mobile_front/features/notification/data/push_notification_permission_client.dart';
import 'package:maum_on_mobile_front/features/notification/domain/notification_models.dart';

void main() {
  test('maps notification tap payloads to authenticated routes', () {
    expect(
      NotificationTapPayload.fromJson({
        'type': 'reply_arrival',
        'letterId': 7,
      }).destination,
      NotificationTapDestination.letter,
    );
    final targetPayload = NotificationTapPayload.fromJson({
      'type': 'new_letter',
      'targetType': 'LETTER',
      'targetId': '9',
      'routeKey': 'letter',
      'notificationId': '17',
    });
    expect(targetPayload.destination, NotificationTapDestination.letter);
    expect(targetPayload.letterId, 9);
    expect(targetPayload.targetType, 'LETTER');
    expect(targetPayload.targetId, 9);
    expect(targetPayload.notificationId, 17);
    final legacyLetterPayload = NotificationTapPayload.fromJson({
      'type': 'new_letter',
      'targetId': '11',
      'routeKey': 'new_letter',
    });
    expect(legacyLetterPayload.destination, NotificationTapDestination.letter);
    expect(legacyLetterPayload.letterId, 11);
    final storyTargetPayload = NotificationTapPayload.fromJson({
      'targetType': 'POST',
      'targetId': '21',
    });
    expect(storyTargetPayload.destination, NotificationTapDestination.story);
    expect(storyTargetPayload.storyId, 21);
    expect(
      NotificationTapPayload.fromJson({'event': 'consultation_reply'})
          .destination,
      NotificationTapDestination.consultation,
    );
    final legacyReportPayload = NotificationTapPayload.fromJson({
      'event': 'report_status',
      'targetId': '12',
    });
    expect(
      legacyReportPayload.destination,
      NotificationTapDestination.operations,
    );
    expect(legacyReportPayload.reportId, 12);
    expect(
      NotificationTapPayload.fromJson({'routeKey': 'diary'}).destination,
      NotificationTapDestination.diary,
    );
    expect(
      NotificationTapPayload.fromJson({'routeKey': 'story'}).destination,
      NotificationTapDestination.story,
    );
    expect(
      NotificationTapPayload.fromJson({'routeKey': 'settings'}).destination,
      NotificationTapDestination.settings,
    );
    expect(
      NotificationTapPayload.fromJson({'route': 'notifications'}).destination,
      NotificationTapDestination.notifications,
    );
  });

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

    test('opens unread notifications by marking read once before navigation',
        () async {
      final markReadCompleter = Completer<NotificationItem>();
      final repository = _FakeNotificationRepository(
        notificationsQueue: [
          [
            const NotificationItem(
              id: 8,
              content: '보낸 편지에 답장이 도착했습니다!',
              type: 'reply_arrival',
              targetType: 'LETTER',
              targetId: 8,
              routeKey: 'letter',
              isRead: false,
              createdAt: '2026-05-24T09:00:00',
            ),
          ],
        ],
        markReadCompleter: markReadCompleter,
      );
      final controller = NotificationController(repository: repository);

      await controller.load();
      final firstOpen = controller.openNotification(
        controller.state.notifications.single,
      );
      final secondOpen = controller.openNotification(
        controller.state.notifications.single,
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.markReadIds, [8]);

      markReadCompleter.complete(
        const NotificationItem(
          id: 8,
          content: '보낸 편지에 답장이 도착했습니다!',
          type: 'reply_arrival',
          targetType: 'LETTER',
          targetId: 8,
          routeKey: 'letter',
          isRead: true,
          createdAt: '2026-05-24T09:00:00',
          readAt: '2026-05-24T09:01:00',
        ),
      );

      final opened = await firstOpen;
      expect(await secondOpen, isNull);
      expect(opened?.isRead, isTrue);
      expect(opened?.tapPayload.destination, NotificationTapDestination.letter);
      expect(controller.state.notifications.single.isRead, isTrue);
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

    test('replaces refreshed push tokens and unregisters on cleanup', () async {
      final repository = _FakeNotificationRepository();
      final permissionClient = _QueuePushNotificationPermissionClient([
        const PushNotificationPermissionResult(
          granted: true,
          platform: NotificationDevicePlatform.android,
          token: 'android-token-a',
        ),
        const PushNotificationPermissionResult(
          granted: true,
          platform: NotificationDevicePlatform.android,
          token: 'android-token-b',
        ),
        const PushNotificationPermissionResult(
          granted: true,
          platform: NotificationDevicePlatform.android,
          token: 'android-token-b',
        ),
      ]);
      final controller = NotificationController(
        repository: repository,
        pushPermissionClient: permissionClient,
      );

      await controller.requestPushPermission();
      await controller.requestPushPermission();
      await controller.unregisterRegisteredDeviceToken();

      expect(repository.registrationRequests, [
        'ANDROID:android-token-a',
        'ANDROID:android-token-b',
      ]);
      expect(repository.registeredTokens, isEmpty);
      expect(repository.unregisteredTokens, [
        'android-token-a',
        'android-token-b',
      ]);
    });

    test('opens device notification settings after a denied permission',
        () async {
      final repository = _FakeNotificationRepository();
      final permissionClient = _FakePushNotificationPermissionClient(
        const PushNotificationPermissionResult(
          granted: false,
          platform: NotificationDevicePlatform.ios,
          message: '권한 거부',
          canOpenSettings: true,
        ),
      );
      final controller = NotificationController(
        repository: repository,
        pushPermissionClient: permissionClient,
      );

      await controller.requestPushPermission();
      await controller.openPushNotificationSettings();

      expect(
        controller.state.pushNotificationState,
        PushNotificationState.denied,
      );
      expect(controller.state.canOpenPushSettings, isTrue);
      expect(permissionClient.openSettingsCount, 1);
      expect(controller.state.noticeMessage, '설정에서 알림 권한을 확인해 주세요.');
    });

    test('does not mark push status registered without a token', () async {
      final controller = NotificationController(
        repository: _FakeNotificationRepository(),
        pushPermissionClient: _FakePushNotificationPermissionClient(
          const PushNotificationPermissionResult(
            granted: true,
            platform: NotificationDevicePlatform.android,
            message: '토큰 없음',
            canOpenSettings: true,
          ),
        ),
      );

      await controller.syncPushPermissionStatus();

      expect(
        controller.state.pushNotificationState,
        PushNotificationState.error,
      );
      expect(controller.state.errorMessage, '토큰 없음');
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
    Completer<NotificationItem>? markReadCompleter,
    this.ticketError,
  })  : _notificationsQueue =
            List<List<NotificationItem>>.of(notificationsQueue),
        _ticketCompleter = ticketCompleter,
        _markReadCompleter = markReadCompleter;

  final List<List<NotificationItem>> _notificationsQueue;
  final Completer<NotificationSubscriptionTicket>? _ticketCompleter;
  final Completer<NotificationItem>? _markReadCompleter;
  final Object? ticketError;
  final List<String> connectTickets = [];
  final List<int> markReadIds = [];
  final List<String> registrationRequests = [];
  final List<String> registeredTokens = [];
  final List<String> unregisteredTokens = [];
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
    final completer = _markReadCompleter;
    if (completer != null) {
      return completer.future;
    }

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
    final value = '${platform.apiValue}:$token';
    registrationRequests.add(value);
    registeredTokens.add(value);
    return NotificationDeviceTokenResult(
      platform: platform,
      enabled: true,
      updatedAt: '2026-05-24T09:03:00',
    );
  }

  @override
  Future<bool> unregisterDeviceToken(String token) async {
    unregisteredTokens.add(token);
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
  final StreamController<NotificationTapPayload> _tapController =
      StreamController<NotificationTapPayload>.broadcast();
  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  Future<PushNotificationPermissionResult> requestPermission() async {
    requestCount += 1;
    return result;
  }

  @override
  Future<PushNotificationPermissionResult> getPermissionStatus() async {
    return result;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount += 1;
    return true;
  }

  @override
  Future<NotificationTapPayload?> takeInitialNotificationTap() async => null;

  @override
  Stream<NotificationTapPayload> get notificationTaps => _tapController.stream;
}

class _QueuePushNotificationPermissionClient
    implements PushNotificationPermissionClient {
  _QueuePushNotificationPermissionClient(this.results);

  final List<PushNotificationPermissionResult> results;
  final StreamController<NotificationTapPayload> _tapController =
      StreamController<NotificationTapPayload>.broadcast();

  @override
  Future<PushNotificationPermissionResult> requestPermission() async {
    return results.removeAt(0);
  }

  @override
  Future<PushNotificationPermissionResult> getPermissionStatus() async {
    return results.first;
  }

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<NotificationTapPayload?> takeInitialNotificationTap() async => null;

  @override
  Stream<NotificationTapPayload> get notificationTaps => _tapController.stream;
}

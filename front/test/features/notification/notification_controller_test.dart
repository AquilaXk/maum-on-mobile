import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/notification/application/notification_controller.dart';
import 'package:maum_on_mobile_front/features/notification/data/notification_repository.dart';
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
      final controller = NotificationController(repository: repository);

      await controller.connect();
      repository.emit(const NotificationStreamEvent.connect('연결되었습니다!'));

      controller.handleLifecycleState(AppLifecycleState.paused);

      expect(repository.cancelCount, 1);
      expect(controller.state.connectionState, NotificationConnectionState.idle);

      controller.handleLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(repository.ticketRequestCount, 2);
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
  int ticketRequestCount = 0;
  int cancelCount = 0;
  StreamController<NotificationStreamEvent>? _controller;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    if (_notificationsQueue.isEmpty) {
      return const [];
    }

    return _notificationsQueue.removeAt(0);
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
}

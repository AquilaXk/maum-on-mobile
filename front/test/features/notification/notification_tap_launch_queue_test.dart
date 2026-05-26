import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/notification/application/notification_tap_launch_queue.dart';
import 'package:maum_on_mobile_front/features/notification/domain/notification_models.dart';

void main() {
  group('NotificationTapLaunchQueue', () {
    test('queues cold-start story taps until session restore completes', () {
      final queue = NotificationTapLaunchQueue();

      final resolution = queue.resolve(
        const NotificationTapPayload(
          destination: NotificationTapDestination.story,
          notificationId: 92,
          targetType: 'POST',
          targetId: 21,
        ),
        source: NotificationTapLaunchSource.coldStart,
        authState: NotificationTapAuthState.restoring,
      );

      expect(resolution.shouldNavigateNow, isFalse);
      expect(
          resolution.pendingTap?.source, NotificationTapLaunchSource.coldStart);
      expect(resolution.pendingTap?.payload.storyId, 21);
      expect(resolution.noticeMessage, '로그인 확인 후 알림으로 이동합니다.');

      final pendingTap = queue.consumePendingTap();
      expect(pendingTap?.payload.destination, NotificationTapDestination.story);
      expect(pendingTap?.payload.storyId, 21);
      expect(queue.consumePendingTap(), isNull);
    });

    test('routes background letter taps immediately while authenticated', () {
      final queue = NotificationTapLaunchQueue();

      final resolution = queue.resolve(
        const NotificationTapPayload(
          destination: NotificationTapDestination.letter,
          notificationId: 91,
          letterId: 7,
        ),
        source: NotificationTapLaunchSource.background,
        authState: NotificationTapAuthState.authenticated,
      );

      expect(resolution.shouldNavigateNow, isTrue);
      expect(resolution.tap?.source, NotificationTapLaunchSource.background);
      expect(resolution.tap?.payload.letterId, 7);
      expect(resolution.errorMessage, isNull);
    });

    test('falls back with a recoverable message when payload target is invalid',
        () {
      final queue = NotificationTapLaunchQueue();

      final resolution = queue.resolve(
        const NotificationTapPayload(
          destination: NotificationTapDestination.letter,
          notificationId: 12,
        ),
        source: NotificationTapLaunchSource.foreground,
        authState: NotificationTapAuthState.authenticated,
      );

      expect(resolution.shouldNavigateNow, isTrue);
      expect(resolution.tap?.payload.destination,
          NotificationTapDestination.notifications);
      expect(
        resolution.errorMessage,
        '알림 정보를 확인할 수 없습니다. 알림 목록에서 다시 선택해 주세요.',
      );
      expect(queue.consumePendingTap(), isNull);
    });

    test('keeps one pending tap when the same notification arrives twice', () {
      final queue = NotificationTapLaunchQueue();
      const payload = NotificationTapPayload(
        destination: NotificationTapDestination.letter,
        notificationId: 91,
        letterId: 5,
      );

      final first = queue.resolve(
        payload,
        source: NotificationTapLaunchSource.coldStart,
        authState: NotificationTapAuthState.restoring,
      );
      final duplicate = queue.resolve(
        payload,
        source: NotificationTapLaunchSource.background,
        authState: NotificationTapAuthState.restoring,
      );

      expect(first.pendingTap?.payload.letterId, 5);
      expect(duplicate.isDuplicate, isTrue);
      expect(duplicate.pendingTap, isNull);
      expect(queue.consumePendingTap()?.payload.letterId, 5);
      expect(queue.consumePendingTap(), isNull);
    });

    test('queues expired-auth operations taps with a sign-in recovery message',
        () {
      final queue = NotificationTapLaunchQueue();

      final resolution = queue.resolve(
        const NotificationTapPayload(
          destination: NotificationTapDestination.operations,
          notificationId: 30,
          reportId: 9,
        ),
        source: NotificationTapLaunchSource.coldStart,
        authState: NotificationTapAuthState.expired,
      );

      expect(resolution.shouldNavigateNow, isFalse);
      expect(
        resolution.errorMessage,
        '로그인이 만료되었습니다. 다시 로그인하면 알림으로 이동합니다.',
      );
      expect(resolution.pendingTap?.payload.reportId, 9);
      expect(queue.consumePendingTap()?.payload.reportId, 9);
    });
  });
}

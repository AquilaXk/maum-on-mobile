import '../domain/notification_models.dart';

enum NotificationTapLaunchSource {
  coldStart,
  background,
  foreground,
}

enum NotificationTapAuthState {
  restoring,
  authenticated,
  expired,
}

class NotificationTapLaunch {
  const NotificationTapLaunch({
    required this.payload,
    required this.source,
    required this.dedupeKey,
  });

  final NotificationTapPayload payload;
  final NotificationTapLaunchSource source;
  final String dedupeKey;
}

class NotificationTapLaunchResolution {
  const NotificationTapLaunchResolution({
    this.tap,
    this.pendingTap,
    this.noticeMessage,
    this.errorMessage,
    this.isDuplicate = false,
  });

  final NotificationTapLaunch? tap;
  final NotificationTapLaunch? pendingTap;
  final String? noticeMessage;
  final String? errorMessage;
  final bool isDuplicate;

  bool get shouldNavigateNow => tap != null && !isDuplicate;
}

class NotificationTapLaunchQueue {
  final Set<String> _seenTapKeys = <String>{};
  NotificationTapLaunch? _pendingTap;

  NotificationTapLaunch? get pendingTap => _pendingTap;

  NotificationTapLaunchResolution resolve(
    NotificationTapPayload payload, {
    required NotificationTapLaunchSource source,
    required NotificationTapAuthState authState,
  }) {
    final tap = NotificationTapLaunch(
      payload: payload,
      source: source,
      dedupeKey: _dedupeKey(payload),
    );
    if (!_seenTapKeys.add(tap.dedupeKey)) {
      return const NotificationTapLaunchResolution(isDuplicate: true);
    }

    final invalidMessage = _invalidPayloadMessage(payload);
    if (invalidMessage != null) {
      return NotificationTapLaunchResolution(
        tap: NotificationTapLaunch(
          payload: const NotificationTapPayload(
            destination: NotificationTapDestination.notifications,
          ),
          source: source,
          dedupeKey: tap.dedupeKey,
        ),
        errorMessage: invalidMessage,
      );
    }

    if (authState == NotificationTapAuthState.authenticated) {
      return NotificationTapLaunchResolution(tap: tap);
    }

    _pendingTap = tap;
    return NotificationTapLaunchResolution(
      pendingTap: tap,
      noticeMessage: authState == NotificationTapAuthState.restoring
          ? '로그인 확인 후 알림으로 이동합니다.'
          : null,
      errorMessage: authState == NotificationTapAuthState.expired
          ? '로그인이 만료되었습니다. 다시 로그인하면 알림으로 이동합니다.'
          : null,
    );
  }

  NotificationTapLaunch? consumePendingTap() {
    final tap = _pendingTap;
    _pendingTap = null;
    return tap;
  }

  String _dedupeKey(NotificationTapPayload payload) {
    final notificationId = payload.notificationId;
    if (notificationId != null && notificationId > 0) {
      return 'notification:$notificationId';
    }

    return [
      payload.destination.name,
      payload.letterId,
      payload.reportId,
      payload.storyId,
      payload.diaryId,
      payload.consultationId,
      payload.targetType,
      payload.targetId,
      payload.routeKey,
      payload.rawType,
    ].join('|');
  }

  String? _invalidPayloadMessage(NotificationTapPayload payload) {
    final missingTarget = switch (payload.destination) {
      NotificationTapDestination.letter =>
        payload.letterId == null || payload.letterId! <= 0,
      NotificationTapDestination.story => payload.hasTargetReference &&
          (payload.storyId == null || payload.storyId! <= 0),
      NotificationTapDestination.diary => payload.hasTargetReference &&
          (payload.diaryId == null || payload.diaryId! <= 0),
      NotificationTapDestination.consultation => payload.hasTargetReference &&
          payload.normalizedTargetType == 'CONSULTATION' &&
          (payload.consultationId == null || payload.consultationId! <= 0),
      NotificationTapDestination.notifications ||
      NotificationTapDestination.settings =>
        false,
    };

    if (!missingTarget) {
      return null;
    }

    return '알림 정보를 확인할 수 없습니다. 알림 목록에서 다시 선택해 주세요.';
  }
}

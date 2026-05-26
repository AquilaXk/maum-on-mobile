import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../data/notification_repository.dart';
import '../data/push_notification_permission_client.dart';
import '../domain/notification_models.dart';

enum PushNotificationState {
  idle,
  requesting,
  registered,
  denied,
  error,
}

class NotificationState {
  const NotificationState({
    required this.notifications,
    this.connectionState = NotificationConnectionState.idle,
    this.pushNotificationState = PushNotificationState.idle,
    this.isLoading = false,
    this.hasLoaded = false,
    this.canOpenPushSettings = false,
    this.errorMessage,
    this.noticeMessage,
    this.lastReceivedAt,
  });

  final List<NotificationItem> notifications;
  final NotificationConnectionState connectionState;
  final PushNotificationState pushNotificationState;
  final bool isLoading;
  final bool hasLoaded;
  final bool canOpenPushSettings;
  final String? errorMessage;
  final String? noticeMessage;
  final String? lastReceivedAt;

  bool get isEmpty => hasLoaded && notifications.isEmpty;

  int get unreadCount {
    return notifications.where((notification) => !notification.isRead).length;
  }

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    NotificationConnectionState? connectionState,
    PushNotificationState? pushNotificationState,
    bool? isLoading,
    bool? hasLoaded,
    bool? canOpenPushSettings,
    String? errorMessage,
    String? noticeMessage,
    String? lastReceivedAt,
    bool clearErrorMessage = false,
    bool clearNoticeMessage = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      connectionState: connectionState ?? this.connectionState,
      pushNotificationState:
          pushNotificationState ?? this.pushNotificationState,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      canOpenPushSettings: canOpenPushSettings ?? this.canOpenPushSettings,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      noticeMessage:
          clearNoticeMessage ? null : noticeMessage ?? this.noticeMessage,
      lastReceivedAt: lastReceivedAt ?? this.lastReceivedAt,
    );
  }
}

class NotificationController extends ChangeNotifier {
  NotificationController({
    required NotificationRepository repository,
    PushNotificationPermissionClient? pushPermissionClient,
    Duration reconnectDelay = const Duration(seconds: 3),
    int maxReconnectAttempts = 3,
    VoidCallback? onUnauthorized,
  })  : _repository = repository,
        _pushPermissionClient = pushPermissionClient,
        _reconnectDelay = reconnectDelay,
        _maxReconnectAttempts = maxReconnectAttempts,
        _onUnauthorized = onUnauthorized,
        _state = const NotificationState(notifications: []);

  final NotificationRepository _repository;
  final PushNotificationPermissionClient? _pushPermissionClient;
  final Duration _reconnectDelay;
  final int _maxReconnectAttempts;
  final VoidCallback? _onUnauthorized;

  NotificationState _state;
  StreamSubscription<NotificationStreamEvent>? _streamSubscription;
  Timer? _reconnectTimer;
  bool _shouldRestoreConnection = false;
  bool _isConnecting = false;
  bool _isDisposed = false;
  int _localEventSequence = 0;
  int _reconnectAttempts = 0;
  String? _registeredDeviceToken;
  final Set<String> _seenStreamEventKeys = <String>{};
  final Set<int> _openingNotificationIds = <int>{};

  NotificationState get state => _state;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _setState(
        _state.copyWith(
          isLoading: true,
          clearErrorMessage: true,
          clearNoticeMessage: true,
        ),
      );
    }

    try {
      final notifications = await _repository.fetchNotifications();
      for (final notification in notifications) {
        _seenStreamEventKeys.add('notification:${notification.id}');
      }
      _setState(
        _state.copyWith(
          notifications: silent
              ? _mergeNotifications(_state.notifications, notifications)
              : notifications,
          isLoading: false,
          hasLoaded: true,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(
        _state.copyWith(
          isLoading: false,
          hasLoaded: true,
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  Future<void> markAsRead(NotificationItem notification) async {
    if (notification.isRead || notification.id <= 0) {
      return;
    }

    try {
      final updated = await _repository.markRead(notification.id);
      _replaceNotification(updated.withRoutingFrom(notification));
    } on Object catch (error) {
      _handleError(error);
      _setState(
        _state.copyWith(errorMessage: _messageFromError(error)),
      );
    }
  }

  Future<NotificationItem?> openNotification(
    NotificationItem notification,
  ) async {
    if (notification.id <= 0 || notification.isRead) {
      return notification;
    }

    if (!_openingNotificationIds.add(notification.id)) {
      return null;
    }

    try {
      final updated = await _repository.markRead(notification.id);
      final routed = updated.withRoutingFrom(notification);
      _replaceNotification(routed);
      return routed;
    } on Object catch (error) {
      _handleError(error);
      _setState(
        _state.copyWith(errorMessage: _messageFromError(error)),
      );
      return null;
    } finally {
      _openingNotificationIds.remove(notification.id);
    }
  }

  Future<void> markAllRead() async {
    if (_state.unreadCount == 0) {
      return;
    }

    try {
      await _repository.markAllRead();
      final now = DateTime.now().toIso8601String();
      _setState(
        _state.copyWith(
          notifications: [
            for (final notification in _state.notifications)
              notification.copyWith(isRead: true, readAt: now),
          ],
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(
        _state.copyWith(errorMessage: _messageFromError(error)),
      );
    }
  }

  Future<void> requestPushPermission() async {
    final client = _pushPermissionClient;
    if (client == null) {
      _setState(
        _state.copyWith(
          pushNotificationState: PushNotificationState.error,
          errorMessage: '푸시 알림 권한을 요청할 수 없습니다.',
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        pushNotificationState: PushNotificationState.requesting,
        clearErrorMessage: true,
      ),
    );

    try {
      final permission = await client.requestPermission();
      final token = permission.token?.trim();
      if (!permission.granted) {
        _setState(
          _state.copyWith(
            pushNotificationState: PushNotificationState.denied,
            errorMessage: permission.message ?? '푸시 알림 권한이 허용되지 않았습니다.',
            canOpenPushSettings: permission.canOpenSettings,
          ),
        );
        return;
      }

      if (token == null || token.isEmpty) {
        _setState(
          _state.copyWith(
            pushNotificationState: PushNotificationState.error,
            errorMessage: permission.message ?? '푸시 토큰을 받을 수 없습니다.',
            canOpenPushSettings: permission.canOpenSettings,
          ),
        );
        return;
      }

      final previousToken = _registeredDeviceToken;
      if (previousToken != null && previousToken != token) {
        await _repository.unregisterDeviceToken(previousToken);
      }
      await _repository.registerDeviceToken(
        platform: permission.platform,
        token: token,
      );
      _registeredDeviceToken = token;
      _setState(
        _state.copyWith(
          pushNotificationState: PushNotificationState.registered,
          noticeMessage: '푸시 알림이 켜졌습니다.',
          canOpenPushSettings: permission.canOpenSettings,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(
        _state.copyWith(
          pushNotificationState: PushNotificationState.error,
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  Future<void> syncPushPermissionStatus() async {
    final client = _pushPermissionClient;
    if (client == null) {
      return;
    }

    try {
      final permission = await client.getPermissionStatus();
      final token = permission.token?.trim();
      if (!permission.granted) {
        _setState(
          _state.copyWith(
            pushNotificationState: PushNotificationState.denied,
            canOpenPushSettings: permission.canOpenSettings,
            errorMessage:
                permission.message ?? '푸시 알림 권한이 허용되지 않았습니다.',
          ),
        );
        return;
      }

      if (token == null || token.isEmpty) {
        _setState(
          _state.copyWith(
            pushNotificationState: PushNotificationState.error,
            canOpenPushSettings: permission.canOpenSettings,
            errorMessage: permission.message ?? '푸시 토큰을 받을 수 없습니다.',
          ),
        );
        return;
      }

      _registeredDeviceToken = token;
      _setState(
        _state.copyWith(
          pushNotificationState: PushNotificationState.registered,
          canOpenPushSettings: permission.canOpenSettings,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          pushNotificationState: PushNotificationState.error,
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  Future<void> openPushNotificationSettings() async {
    final client = _pushPermissionClient;
    if (client == null) {
      _setState(
        _state.copyWith(errorMessage: '알림 설정을 열 수 없습니다.'),
      );
      return;
    }

    final opened = await client.openSettings();
    _setState(
      _state.copyWith(
        noticeMessage: opened ? '설정에서 알림 권한을 확인해 주세요.' : null,
        errorMessage: opened ? null : '알림 설정을 열 수 없습니다.',
        clearErrorMessage: opened,
        clearNoticeMessage: !opened,
      ),
    );
  }

  void showNotice(String message) {
    _setState(
      _state.copyWith(
        noticeMessage: message,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> unregisterRegisteredDeviceToken() async {
    final client = _pushPermissionClient;
    final knownToken = _registeredDeviceToken;
    String? token = knownToken;
    if ((token == null || token.isEmpty) && client != null) {
      try {
        token = (await client.getPermissionStatus()).token?.trim();
      } on Object {
        token = null;
      }
    }

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _repository.unregisterDeviceToken(token);
    } on Object catch (error) {
      if (!_isDisposed) {
        _setState(
          _state.copyWith(errorMessage: _messageFromError(error)),
        );
      }
      return;
    }
    if (_registeredDeviceToken == token) {
      _registeredDeviceToken = null;
    }
    _setState(
      _state.copyWith(
        pushNotificationState: PushNotificationState.idle,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> connect() async {
    if (_streamSubscription != null || _isConnecting) {
      return;
    }

    _shouldRestoreConnection = true;
    _isConnecting = true;
    _reconnectTimer?.cancel();
    _setState(
      _state.copyWith(
        connectionState: NotificationConnectionState.connecting,
        clearErrorMessage: true,
      ),
    );

    try {
      final ticket = await _repository.requestSubscriptionTicket();
      if (_isDisposed) {
        return;
      }

      _streamSubscription = _repository.connect(ticket.ticket).listen(
            _handleStreamEvent,
            onError: (Object error) => _handleStreamError(error),
            onDone: _handleStreamDone,
          );
    } on Object catch (error) {
      _handleStreamError(error, canRestore: false);
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> reconnect() async {
    _shouldRestoreConnection = true;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    await _cancelStream();
    await connect();
  }

  void close() {
    _shouldRestoreConnection = false;
    _reconnectTimer?.cancel();
    _cancelStreamForLifecycle(
      connectionState: NotificationConnectionState.idle,
      clearErrorMessage: true,
    );
  }

  void handleLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      unawaited(load(silent: true));
      unawaited(syncPushPermissionStatus());
      if (_shouldRestoreConnection &&
          _streamSubscription == null &&
          !_isConnecting) {
        unawaited(connect());
      }
      return;
    }

    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.detached) {
      if (_streamSubscription != null || _isConnecting) {
        _shouldRestoreConnection = true;
        _reconnectTimer?.cancel();
        _cancelStreamForLifecycle(
          connectionState: NotificationConnectionState.idle,
          clearErrorMessage: true,
        );
      }
    }
  }

  void _handleStreamEvent(NotificationStreamEvent event) {
    if (event.type == NotificationStreamEventType.connect) {
      _reconnectAttempts = 0;
      _setState(
        _state.copyWith(
          connectionState: NotificationConnectionState.connected,
          noticeMessage: '알림이 연결되었습니다.',
          clearErrorMessage: true,
        ),
      );
      return;
    }

    if (!event.shouldDisplay || !_seenStreamEventKeys.add(event.dedupeKey)) {
      return;
    }

    final createdAt = event.createdAt ?? DateTime.now().toIso8601String();
    final notification = NotificationItem(
      id: event.notificationId ?? --_localEventSequence,
      content: event.message,
      type: event.notificationType ?? event.type.notificationType,
      targetType: event.targetType ?? event.type.defaultTargetType,
      targetId: event.targetId ?? event.letterId ?? event.reportId,
      routeKey: event.routeKey ?? event.type.defaultRouteKey,
      isRead: false,
      createdAt: createdAt,
    );
    _setState(
      _state.copyWith(
        notifications: [
          notification,
          ..._state.notifications.where(
            (item) => item.id != notification.id,
          ),
        ],
        noticeMessage: event.message,
        lastReceivedAt: createdAt,
        clearErrorMessage: true,
      ),
    );
    unawaited(load(silent: true));
  }

  void _handleStreamError(Object error, {bool canRestore = true}) {
    final currentSubscription = _streamSubscription;
    _streamSubscription = null;
    _isConnecting = false;
    if (currentSubscription != null) {
      unawaited(currentSubscription.cancel());
    }

    _handleError(error);
    _setState(
      _state.copyWith(
        connectionState: NotificationConnectionState.error,
        errorMessage: _messageFromError(error),
      ),
    );
    if (canRestore) {
      _scheduleReconnect();
    }
  }

  void _handleStreamDone() {
    _streamSubscription = null;
    _isConnecting = false;
    _setState(
      _state.copyWith(
        connectionState: NotificationConnectionState.error,
        errorMessage: '알림 연결이 종료되었습니다. 다시 연결해 주세요.',
      ),
    );
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldRestoreConnection ||
        _isDisposed ||
        _reconnectAttempts >= _maxReconnectAttempts ||
        _reconnectTimer != null) {
      return;
    }

    _reconnectAttempts += 1;
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectTimer = null;
      if (_isDisposed || !_shouldRestoreConnection) {
        return;
      }
      unawaited(load(silent: true));
      unawaited(connect());
    });
  }

  void _replaceNotification(NotificationItem updated) {
    _setState(
      _state.copyWith(
        notifications: [
          for (final notification in _state.notifications)
            notification.id == updated.id ? updated : notification,
        ],
        clearErrorMessage: true,
      ),
    );
  }

  List<NotificationItem> _mergeNotifications(
    List<NotificationItem> current,
    List<NotificationItem> fetched,
  ) {
    if (fetched.isEmpty) {
      return current;
    }

    final localOnly = current.where((notification) => notification.id < 0);
    final fetchedIds = fetched.map((notification) => notification.id).toSet();
    final stillLocal = localOnly.where(
      (notification) => !fetchedIds.contains(-notification.id),
    );
    return [...stillLocal, ...fetched];
  }

  void _handleError(Object error) {
    if (error is ApiClientException &&
        error.kind == ApiErrorKind.unauthorized) {
      _onUnauthorized?.call();
    }
  }

  Future<void> _cancelStream() async {
    final subscription = _streamSubscription;
    _streamSubscription = null;
    _isConnecting = false;
    if (subscription != null) {
      await subscription.cancel();
    }
  }

  void _cancelStreamForLifecycle({
    required NotificationConnectionState connectionState,
    required bool clearErrorMessage,
  }) {
    final subscription = _streamSubscription;
    _streamSubscription = null;
    _isConnecting = false;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _setState(
      _state.copyWith(
        connectionState: connectionState,
        clearErrorMessage: clearErrorMessage,
      ),
    );
  }

  String _messageFromError(Object error) {
    if (error is ApiClientException) {
      return error.message;
    }

    return '알림을 처리하지 못했습니다.';
  }

  void _setState(NotificationState state) {
    if (_isDisposed) {
      return;
    }

    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    unawaited(_cancelStream());
    super.dispose();
  }
}

extension on NotificationItem {
  NotificationItem withRoutingFrom(NotificationItem source) {
    if (hasExplicitRouting) {
      return this;
    }

    return copyWith(
      type: source.type,
      targetType: source.targetType,
      targetId: source.targetId,
      routeKey: source.routeKey,
    );
  }

  bool get hasExplicitRouting {
    return type != 'fallback' ||
        targetType != null ||
        targetId != null ||
        routeKey != 'notifications';
  }
}

extension on NotificationStreamEventType {
  String get notificationType {
    return switch (this) {
      NotificationStreamEventType.newLetter => 'new_letter',
      NotificationStreamEventType.letterRead => 'letter_read',
      NotificationStreamEventType.writingStatus => 'writing_status',
      NotificationStreamEventType.replyArrival => 'reply_arrival',
      NotificationStreamEventType.reportStatus => 'report_status',
      NotificationStreamEventType.consultationReply => 'consultation_reply',
      NotificationStreamEventType.connect || NotificationStreamEventType.unknown =>
        'fallback',
    };
  }

  String? get defaultTargetType {
    return switch (this) {
      NotificationStreamEventType.newLetter ||
      NotificationStreamEventType.letterRead ||
      NotificationStreamEventType.writingStatus ||
      NotificationStreamEventType.replyArrival =>
        'LETTER',
      NotificationStreamEventType.reportStatus => 'REPORT',
      NotificationStreamEventType.consultationReply => 'CONSULTATION',
      NotificationStreamEventType.connect || NotificationStreamEventType.unknown =>
        null,
    };
  }

  String get defaultRouteKey {
    return switch (this) {
      NotificationStreamEventType.newLetter ||
      NotificationStreamEventType.letterRead ||
      NotificationStreamEventType.writingStatus ||
      NotificationStreamEventType.replyArrival =>
        'letter',
      NotificationStreamEventType.consultationReply => 'consultation',
      NotificationStreamEventType.reportStatus ||
      NotificationStreamEventType.connect ||
      NotificationStreamEventType.unknown =>
        'notifications',
    };
  }
}

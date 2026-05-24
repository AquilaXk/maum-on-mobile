import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../data/notification_repository.dart';
import '../domain/notification_models.dart';

class NotificationState {
  const NotificationState({
    required this.notifications,
    this.connectionState = NotificationConnectionState.idle,
    this.isLoading = false,
    this.hasLoaded = false,
    this.errorMessage,
    this.noticeMessage,
  });

  final List<NotificationItem> notifications;
  final NotificationConnectionState connectionState;
  final bool isLoading;
  final bool hasLoaded;
  final String? errorMessage;
  final String? noticeMessage;

  bool get isEmpty => hasLoaded && notifications.isEmpty;

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    NotificationConnectionState? connectionState,
    bool? isLoading,
    bool? hasLoaded,
    String? errorMessage,
    String? noticeMessage,
    bool clearErrorMessage = false,
    bool clearNoticeMessage = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      connectionState: connectionState ?? this.connectionState,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      noticeMessage:
          clearNoticeMessage ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

class NotificationController extends ChangeNotifier {
  NotificationController({
    required NotificationRepository repository,
    VoidCallback? onUnauthorized,
  })  : _repository = repository,
        _onUnauthorized = onUnauthorized,
        _state = const NotificationState(notifications: []);

  final NotificationRepository _repository;
  final VoidCallback? _onUnauthorized;

  NotificationState _state;
  StreamSubscription<NotificationStreamEvent>? _streamSubscription;
  bool _shouldRestoreConnection = false;
  bool _isConnecting = false;
  bool _isDisposed = false;
  int _localEventSequence = 0;

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
      final nextNotifications = silent && notifications.isEmpty
          ? _state.notifications
          : silent
              ? [
                  ..._state.notifications.where(
                    (notification) => notification.id < 0,
                  ),
                  ...notifications,
                ]
              : notifications;
      _setState(
        _state.copyWith(
          notifications: nextNotifications,
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

  Future<void> connect() async {
    if (_streamSubscription != null || _isConnecting) {
      return;
    }

    _shouldRestoreConnection = true;
    _isConnecting = true;
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
            onError: _handleStreamError,
            onDone: _handleStreamDone,
          );
    } on Object catch (error) {
      _handleStreamError(error);
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> reconnect() async {
    _shouldRestoreConnection = true;
    await _cancelStream();
    await connect();
  }

  void close() {
    _shouldRestoreConnection = false;
    _cancelStreamForLifecycle(
      connectionState: NotificationConnectionState.idle,
      clearErrorMessage: true,
    );
  }

  void handleLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
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
        _cancelStreamForLifecycle(
          connectionState: NotificationConnectionState.idle,
          clearErrorMessage: true,
        );
      }
    }
  }

  void _handleStreamEvent(NotificationStreamEvent event) {
    if (event.type == NotificationStreamEventType.connect) {
      _setState(
        _state.copyWith(
          connectionState: NotificationConnectionState.connected,
          noticeMessage: '알림이 연결되었습니다.',
          clearErrorMessage: true,
        ),
      );
      return;
    }

    if (!event.shouldDisplay) {
      return;
    }

    _localEventSequence -= 1;
    final notification = NotificationItem(
      id: _localEventSequence,
      content: event.message,
      isRead: false,
      createdAt: DateTime.now().toIso8601String(),
    );
    _setState(
      _state.copyWith(
        notifications: [
          notification,
          ..._state.notifications,
        ],
        noticeMessage: event.message,
        clearErrorMessage: true,
      ),
    );
    unawaited(load(silent: true));
  }

  void _handleStreamError(Object error) {
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
  }

  void _handleStreamDone() {
    _streamSubscription = null;
    _isConnecting = false;
    if (_state.connectionState == NotificationConnectionState.connected) {
      _setState(
        _state.copyWith(
          connectionState: NotificationConnectionState.error,
          errorMessage: '알림 연결이 종료되었습니다. 다시 연결해 주세요.',
        ),
      );
    }
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
    unawaited(_cancelStream());
    super.dispose();
  }
}

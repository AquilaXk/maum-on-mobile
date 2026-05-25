import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../domain/notification_models.dart';

const _pushNotificationChannelName = 'maum_on_mobile/push_notifications';

abstract interface class PushNotificationPermissionClient {
  Future<PushNotificationPermissionResult> requestPermission();

  Future<PushNotificationPermissionResult> getPermissionStatus();

  Future<bool> openSettings();

  Future<NotificationTapPayload?> takeInitialNotificationTap();

  Stream<NotificationTapPayload> get notificationTaps;
}

class PushNotificationPermissionResult {
  const PushNotificationPermissionResult({
    required this.granted,
    required this.platform,
    this.token,
    this.message,
    this.canOpenSettings = false,
  });

  final bool granted;
  final NotificationDevicePlatform platform;
  final String? token;
  final String? message;
  final bool canOpenSettings;
}

class MethodChannelPushNotificationPermissionClient
    implements PushNotificationPermissionClient {
  MethodChannelPushNotificationPermissionClient({
    MethodChannel channel = const MethodChannel(_pushNotificationChannelName),
  }) : _channel = channel {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final StreamController<NotificationTapPayload> _tapController =
      StreamController<NotificationTapPayload>.broadcast();

  @override
  Future<PushNotificationPermissionResult> requestPermission() async {
    return _invokePermissionMethod('requestPermission');
  }

  @override
  Future<PushNotificationPermissionResult> getPermissionStatus() async {
    return _invokePermissionMethod('getPermissionStatus');
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<NotificationTapPayload?> takeInitialNotificationTap() async {
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'consumeInitialPayload',
      );
      if (response == null || response.isEmpty) {
        return null;
      }
      return NotificationTapPayload.fromJson(response);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Stream<NotificationTapPayload> get notificationTaps => _tapController.stream;

  Future<PushNotificationPermissionResult> _invokePermissionMethod(
    String method,
  ) async {
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(method);
      return _permissionResultFromMap(response ?? const <String, Object?>{});
    } on MissingPluginException {
      return PushNotificationPermissionResult(
        granted: false,
        platform: _currentPlatform(),
        message: '이 기기에서 푸시 알림을 사용할 수 없습니다.',
      );
    }
  }

  PushNotificationPermissionResult _permissionResultFromMap(
    Map<String, Object?> map,
  ) {
    return PushNotificationPermissionResult(
      granted: map['granted'] == true,
      platform: NotificationDevicePlatform.fromJson(map['platform']),
      token: map['token']?.toString(),
      message: map['message']?.toString(),
      canOpenSettings: map['canOpenSettings'] == true,
    );
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'notificationTapped') {
      return;
    }

    _tapController.add(NotificationTapPayload.fromJson(call.arguments));
  }

  NotificationDevicePlatform _currentPlatform() {
    if (Platform.isIOS) {
      return NotificationDevicePlatform.ios;
    }

    return NotificationDevicePlatform.android;
  }
}

import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../domain/notification_models.dart';

const _pushNotificationChannelName = 'maum_on_mobile/push_notifications';

abstract interface class PushNotificationPermissionClient {
  Future<PushNotificationPermissionResult> requestPermission();
}

class PushNotificationPermissionResult {
  const PushNotificationPermissionResult({
    required this.granted,
    required this.platform,
    this.token,
    this.message,
  });

  final bool granted;
  final NotificationDevicePlatform platform;
  final String? token;
  final String? message;
}

class MethodChannelPushNotificationPermissionClient
    implements PushNotificationPermissionClient {
  const MethodChannelPushNotificationPermissionClient({
    MethodChannel channel = const MethodChannel(_pushNotificationChannelName),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<PushNotificationPermissionResult> requestPermission() async {
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'requestPermission',
      );
      final map = response ?? const <String, Object?>{};
      return PushNotificationPermissionResult(
        granted: map['granted'] == true,
        platform: NotificationDevicePlatform.fromJson(map['platform']),
        token: map['token']?.toString(),
        message: map['message']?.toString(),
      );
    } on MissingPluginException {
      return PushNotificationPermissionResult(
        granted: false,
        platform: _currentPlatform(),
        message: '이 기기에서 푸시 알림을 사용할 수 없습니다.',
      );
    }
  }

  NotificationDevicePlatform _currentPlatform() {
    if (Platform.isIOS) {
      return NotificationDevicePlatform.ios;
    }

    return NotificationDevicePlatform.android;
  }
}

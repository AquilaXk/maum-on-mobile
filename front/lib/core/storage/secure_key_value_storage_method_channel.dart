import 'package:flutter/services.dart';

import 'secure_key_value_storage_interface.dart';

const String secureStorageChannelName = 'maum_on_mobile/secure_storage';

class MethodChannelSecureKeyValueStorage implements SecureKeyValueStorage {
  const MethodChannelSecureKeyValueStorage({
    MethodChannel channel = defaultChannel,
  }) : _channel = channel;

  static const MethodChannel defaultChannel =
      MethodChannel(secureStorageChannelName);

  final MethodChannel _channel;

  @override
  Future<String?> read(String key) async {
    validateSecureStorageKey(key);
    try {
      return await _channel.invokeMethod<String>(
        'read',
        <String, Object?>{'key': key},
      );
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    validateSecureStorageKey(key);
    validateSecureStorageValue(value);
    try {
      await _channel.invokeMethod<void>(
        'write',
        <String, Object?>{'key': key, 'value': value},
      );
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> delete(String key) async {
    validateSecureStorageKey(key);
    try {
      await _channel.invokeMethod<void>(
        'delete',
        <String, Object?>{'key': key},
      );
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<Map<String, String>> readAll() async {
    try {
      final result = await _channel.invokeMapMethod<String, String>('readAll');
      if (result == null || result.isEmpty) {
        return const <String, String>{};
      }
      return Map<String, String>.unmodifiable(result);
    } on MissingPluginException {
      return const <String, String>{};
    }
  }
}

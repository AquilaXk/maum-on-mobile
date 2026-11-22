import 'dart:js_interop';

import 'secure_key_value_storage_interface.dart';

class DefaultSecureKeyValueStorage implements SecureKeyValueStorage {
  const DefaultSecureKeyValueStorage();

  static const String _keyPrefix = 'maum_on.secure.';

  @override
  Future<String?> read(String key) async {
    validateSecureStorageKey(key);
    final storage = _sessionStorage;
    if (storage == null) {
      return null;
    }
    return storage.getItem('$_keyPrefix$key'.toJS)?.toDart;
  }

  @override
  Future<void> write(String key, String value) async {
    validateSecureStorageKey(key);
    validateSecureStorageValue(value);
    final storage = _sessionStorage;
    if (storage == null) {
      throw StateError('Web sessionStorage is unavailable.');
    }
    storage.setItem('$_keyPrefix$key'.toJS, value.toJS);
  }

  @override
  Future<void> delete(String key) async {
    validateSecureStorageKey(key);
    final storage = _sessionStorage;
    if (storage == null) {
      return;
    }
    storage.removeItem('$_keyPrefix$key'.toJS);
  }

  @override
  Future<Map<String, String>> readAll() async {
    final storage = _sessionStorage;
    if (storage == null) {
      return const <String, String>{};
    }
    final result = <String, String>{};
    final count = storage.length;
    for (var i = 0; i < count; i += 1) {
      final rawKey = storage.key(i)?.toDart;
      if (rawKey == null || !rawKey.startsWith(_keyPrefix)) {
        continue;
      }
      final rawValue = storage.getItem(rawKey.toJS)?.toDart;
      if (rawValue != null) {
        result[rawKey.substring(_keyPrefix.length)] = rawValue;
      }
    }
    return Map<String, String>.unmodifiable(result);
  }
}

@JS('sessionStorage')
external _JSSessionStorage? get _sessionStorage;

extension type _JSSessionStorage._(JSObject _) implements JSObject {
  external int get length;
  external JSString? key(int index);
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
  external void removeItem(JSString key);
}

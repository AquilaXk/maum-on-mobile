import 'secure_key_value_storage_interface.dart';
import 'secure_key_value_storage_stub.dart'
    if (dart.library.io) 'secure_key_value_storage_io.dart'
    if (dart.library.js_interop) 'secure_key_value_storage_web.dart' as impl;

export 'secure_key_value_storage_interface.dart'
    show
        SecureKeyValueStorage,
        maxSecureStorageKeyLength,
        maxSecureStorageValueLength;
export 'secure_key_value_storage_method_channel.dart'
    show MethodChannelSecureKeyValueStorage, secureStorageChannelName;

class PlatformSecureKeyValueStorage implements SecureKeyValueStorage {
  const PlatformSecureKeyValueStorage();

  static const impl.DefaultSecureKeyValueStorage _delegate =
      impl.DefaultSecureKeyValueStorage();

  @override
  Future<String?> read(String key) => _delegate.read(key);

  @override
  Future<void> write(String key, String value) => _delegate.write(key, value);

  @override
  Future<void> delete(String key) => _delegate.delete(key);

  @override
  Future<Map<String, String>> readAll() => _delegate.readAll();
}

import 'secure_key_value_storage_interface.dart';

class DefaultSecureKeyValueStorage implements SecureKeyValueStorage {
  const DefaultSecureKeyValueStorage();

  @override
  Future<String?> read(String key) {
    throw UnsupportedError(
      'SecureKeyValueStorage is not supported on this platform.',
    );
  }

  @override
  Future<void> write(String key, String value) {
    throw UnsupportedError(
      'SecureKeyValueStorage is not supported on this platform.',
    );
  }

  @override
  Future<void> delete(String key) {
    throw UnsupportedError(
      'SecureKeyValueStorage is not supported on this platform.',
    );
  }

  @override
  Future<Map<String, String>> readAll() {
    throw UnsupportedError(
      'SecureKeyValueStorage is not supported on this platform.',
    );
  }
}

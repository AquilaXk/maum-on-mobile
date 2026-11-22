const int maxSecureStorageKeyLength = 256;
const int maxSecureStorageValueLength = 262144;

abstract interface class SecureKeyValueStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<Map<String, String>> readAll();
}

void validateSecureStorageKey(String key) {
  if (key.isEmpty || key.length > maxSecureStorageKeyLength) {
    throw ArgumentError.value(
      key.length,
      'key',
      'Secure storage key length must be between 1 and $maxSecureStorageKeyLength.',
    );
  }
}

void validateSecureStorageValue(String value) {
  if (value.length > maxSecureStorageValueLength) {
    throw ArgumentError(
      'Secure storage value exceeds maximum length of $maxSecureStorageValueLength.',
    );
  }
}

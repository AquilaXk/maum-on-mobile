import 'dart:math';

final Random _idempotencyRandom = Random.secure();
int _idempotencyCounter = 0;

/// Generates a bounded per-action idempotency key matching backend `160` char limit.
String createIdempotencyKey(String scope) {
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final sequence = (_idempotencyCounter = (_idempotencyCounter + 1) & 0xFFFF)
      .toRadixString(16)
      .padLeft(4, '0');
  final entropyA =
      _idempotencyRandom.nextInt(1 << 30).toRadixString(36).padLeft(6, '0');
  final entropyB =
      _idempotencyRandom.nextInt(1 << 30).toRadixString(36).padLeft(6, '0');
  return '$scope-$timestamp-$sequence-$entropyA$entropyB';
}

/// Reuses a deterministic key across retries of the same payload and clears on success/edit.
class ScopedIdempotencyKey {
  ScopedIdempotencyKey(this.scope);

  final String scope;
  String? _fingerprint;
  String? _key;

  String keyFor(String fingerprint) {
    final existing = _key;
    if (existing != null && _fingerprint == fingerprint) {
      return existing;
    }
    _fingerprint = fingerprint;
    final created = createIdempotencyKey(scope);
    _key = created;
    return created;
  }

  void clear() {
    _fingerprint = null;
    _key = null;
  }
}

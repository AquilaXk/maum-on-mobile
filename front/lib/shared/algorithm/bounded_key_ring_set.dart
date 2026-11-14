import 'dart:collection';

/// Fixed-capacity circular deduplication set with O(1) lookup and bounded memory.
///
/// Once [capacity] unique elements are stored, inserting a new distinct element
/// evicts the oldest entry in ring order. Re-inserting an already present
/// element does not allocate or disturb ring slots and returns `false`.
class BoundedKeyRingSet<T> {
  BoundedKeyRingSet({this.capacity = 512})
      : assert(capacity > 0, 'capacity must be positive'),
        _ring = List<T?>.filled(capacity, null);

  final int capacity;
  final Set<T> _entries = HashSet<T>();
  final List<T?> _ring;
  int _nextSlot = 0;

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  bool contains(T value) => _entries.contains(value);

  bool add(T value) {
    if (_entries.contains(value)) {
      return false;
    }

    if (_entries.length >= capacity) {
      final evicted = _ring[_nextSlot];
      _entries.remove(evicted);
    }

    _ring[_nextSlot] = value;
    _nextSlot += 1;
    if (_nextSlot == capacity) {
      _nextSlot = 0;
    }
    _entries.add(value);
    return true;
  }

  void clear() {
    _entries.clear();
    _ring.fillRange(0, _ring.length, null);
    _nextSlot = 0;
  }
}

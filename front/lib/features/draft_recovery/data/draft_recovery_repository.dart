import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/draft_recovery_models.dart';

abstract interface class DraftRecoveryRepository {
  Future<DraftEntry?> read(DraftKey key);

  Future<void> saveEditing(
    DraftKey key, {
    required Map<String, String> fields,
  });

  Future<void> markFailed(
    DraftKey key, {
    required Map<String, String> fields,
    required String failureMessage,
  });

  Future<List<DraftEntry>> listFailed({
    required int memberId,
    DraftSurface? surface,
  });

  Future<void> delete(DraftKey key);

  Future<void> clearMember(int memberId);
}

abstract interface class DraftRecoveryStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<Map<String, String>> readAll();
}

class StorageDraftRecoveryRepository implements DraftRecoveryRepository {
  const StorageDraftRecoveryRepository({required DraftRecoveryStorage storage})
      : _storage = storage;

  final DraftRecoveryStorage _storage;

  static const String _memberIndexPrefix = 'maum_on.draft.v1.index.';

  String _memberIndexKey(int memberId) => '$_memberIndexPrefix$memberId';

  @override
  Future<DraftEntry?> read(DraftKey key) async {
    final raw = await _storage.read(key.storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return _decode(raw);
  }

  @override
  Future<void> saveEditing(
    DraftKey key, {
    required Map<String, String> fields,
  }) {
    if (_isEmptyDraft(fields)) {
      return delete(key);
    }
    return _write(
      DraftEntry(
        key: key,
        fields: _cleanFields(fields),
        status: DraftRecoveryStatus.editing,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> markFailed(
    DraftKey key, {
    required Map<String, String> fields,
    required String failureMessage,
  }) {
    return _write(
      DraftEntry(
        key: key,
        fields: _cleanFields(fields),
        status: DraftRecoveryStatus.failed,
        failureMessage: failureMessage,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<DraftEntry>> listFailed({
    required int memberId,
    DraftSurface? surface,
  }) async {
    final entries = await _readMemberEntries(memberId);
    return entries
        .where((entry) => surface == null || entry.key.surface == surface)
        .where((entry) => entry.status == DraftRecoveryStatus.failed)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> delete(DraftKey key) async {
    await _storage.delete(key.storageKey);
    await _removeKeyFromIndex(key.memberId, key.storageKey);
  }

  @override
  Future<void> clearMember(int memberId) async {
    final indexedKeys = await _readMemberIndex(memberId);
    if (indexedKeys != null) {
      for (final storageKey in indexedKeys) {
        await _storage.delete(storageKey);
      }
      await _storage.delete(_memberIndexKey(memberId));
      return;
    }

    final entries = await _readAllEntries();
    for (final entry in entries) {
      if (entry.key.memberId == memberId) {
        await _storage.delete(entry.key.storageKey);
      }
    }
    await _storage.delete(_memberIndexKey(memberId));
  }

  Future<void> _write(DraftEntry entry) async {
    await _storage.write(entry.key.storageKey, jsonEncode(entry.toJson()));
    await _addKeyToIndex(entry.key.memberId, entry.key.storageKey);
  }

  Future<List<DraftEntry>> _readMemberEntries(int memberId) async {
    final indexedKeys = await _readMemberIndex(memberId);
    if (indexedKeys != null) {
      if (indexedKeys.isEmpty) {
        return const [];
      }
      final raws = await Future.wait(indexedKeys.map(_storage.read));
      final entries = <DraftEntry>[];
      final activeKeys = <String>[];
      for (var index = 0; index < indexedKeys.length; index += 1) {
        final raw = raws[index];
        if (raw == null || raw.isEmpty) {
          continue;
        }
        final entry = _decodeOrNull(raw);
        if (entry != null && entry.key.memberId == memberId) {
          entries.add(entry);
          activeKeys.add(indexedKeys[index]);
        }
      }
      if (activeKeys.length != indexedKeys.length) {
        await _writeMemberIndex(memberId, activeKeys);
      }
      return entries;
    }

    final allEntries = await _readAllEntries();
    final memberEntries = <DraftEntry>[];
    final memberKeys = <String>[];
    for (final entry in allEntries) {
      if (entry.key.memberId == memberId) {
        memberEntries.add(entry);
        memberKeys.add(entry.key.storageKey);
      }
    }
    await _writeMemberIndex(memberId, memberKeys);
    return memberEntries;
  }

  Future<List<String>?> _readMemberIndex(int memberId) async {
    final raw = await _storage.read(_memberIndexKey(memberId));
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return null;
      }
      return decoded.map((item) => item.toString()).toList(growable: true);
    } on Object {
      return null;
    }
  }

  Future<void> _writeMemberIndex(int memberId, List<String> keys) async {
    if (keys.isEmpty) {
      await _storage.delete(_memberIndexKey(memberId));
      return;
    }
    await _storage.write(_memberIndexKey(memberId), jsonEncode(keys));
  }

  Future<void> _addKeyToIndex(int memberId, String storageKey) async {
    final existing = await _readMemberIndex(memberId) ?? <String>[];
    if (existing.contains(storageKey)) {
      return;
    }
    existing.add(storageKey);
    await _writeMemberIndex(memberId, existing);
  }

  Future<void> _removeKeyFromIndex(int memberId, String storageKey) async {
    final existing = await _readMemberIndex(memberId);
    if (existing == null || !existing.contains(storageKey)) {
      return;
    }
    existing.remove(storageKey);
    await _writeMemberIndex(memberId, existing);
  }

  Future<List<DraftEntry>> _readAllEntries() async {
    final values = await _storage.readAll();
    final entries = <DraftEntry>[];
    for (final entry in values.entries) {
      if (entry.key.startsWith(_memberIndexPrefix)) {
        continue;
      }
      final parsed = _decodeOrNull(entry.value);
      if (parsed != null) {
        entries.add(parsed);
      }
    }
    return entries;
  }

  DraftEntry _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Expected draft recovery entry.');
    }
    return DraftEntry.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  DraftEntry? _decodeOrNull(String raw) {
    try {
      return _decode(raw);
    } on Object {
      return null;
    }
  }

  bool _isEmptyDraft(Map<String, String> fields) {
    final meaningfulFields = _cleanFields(fields).entries.where(
      (entry) => entry.key != 'category' && entry.key != 'isPrivate',
    );
    return meaningfulFields.every((entry) => entry.value.trim().isEmpty);
  }

  Map<String, String> _cleanFields(Map<String, String> fields) {
    return Map.unmodifiable(
      fields.map((key, value) => MapEntry(key, value.trim())),
    );
  }
}

class MemoryDraftRecoveryStorage implements DraftRecoveryStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async {
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map.unmodifiable(_values);
  }
}

class SecureDraftRecoveryStorage implements DraftRecoveryStorage {
  const SecureDraftRecoveryStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }

  @override
  Future<Map<String, String>> readAll() {
    return _storage.readAll();
  }
}

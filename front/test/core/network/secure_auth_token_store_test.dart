import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/core/network/secure_auth_token_store.dart';

void main() {
  group('SecureAuthTokenStore', () {
    test('caches tokens in memory after first read and updates on save/clear',
        () async {
      final storage = _CountingSecureStorage(
        initialValues: {
          'auth.accessToken': 'initial-access',
          'auth.refreshToken': 'initial-refresh',
        },
      );
      final store = SecureAuthTokenStore(storage: storage);

      expect(await store.readAccessToken(), 'initial-access');
      expect(await store.readAccessToken(), 'initial-access');
      expect(await store.readRefreshToken(), 'initial-refresh');
      expect(await store.readRefreshToken(), 'initial-refresh');
      expect(storage.readCount, 2);

      await store.saveTokens(
        const TokenPair(
          accessToken: 'next-access',
          refreshToken: 'next-refresh',
        ),
      );
      expect(await store.readAccessToken(), 'next-access');
      expect(await store.readRefreshToken(), 'next-refresh');
      expect(storage.writeCount, 2);
      expect(storage.readCount, 2);

      await store.clear();
      expect(await store.readAccessToken(), isNull);
      expect(await store.readRefreshToken(), isNull);
      expect(storage.deleteCount, 2);
      expect(storage.readCount, 2);
    });

    test('prevents slow in-flight read from overwriting newer save or clear',
        () async {
      final readGate = Completer<void>();
      final storage = _CountingSecureStorage(
        initialValues: {
          'auth.accessToken': 'stale-access',
          'auth.refreshToken': 'stale-refresh',
        },
        readGate: readGate,
      );
      final store = SecureAuthTokenStore(storage: storage);

      final pendingRead = store.readAccessToken();
      await store.saveTokens(
        const TokenPair(
          accessToken: 'fresh-access',
          refreshToken: 'fresh-refresh',
        ),
      );
      readGate.complete();

      expect(await pendingRead, 'fresh-access');
      expect(await store.readAccessToken(), 'fresh-access');
      expect(await store.readRefreshToken(), 'fresh-refresh');

      final secondReadGate = Completer<void>();
      storage.readGate = secondReadGate;
      final freshStore = SecureAuthTokenStore(storage: storage);
      final staleBeforeClear = freshStore.readAccessToken();
      await freshStore.clear();
      secondReadGate.complete();

      expect(await staleBeforeClear, isNull);
      expect(await freshStore.readAccessToken(), isNull);
    });
  });
}

class _CountingSecureStorage extends Fake implements FlutterSecureStorage {
  _CountingSecureStorage({
    Map<String, String> initialValues = const {},
    this.readGate,
  }) : values = Map<String, String>.of(initialValues);

  final Map<String, String> values;
  Completer<void>? readGate;
  int readCount = 0;
  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    readCount += 1;
    final snapshot = values[key];
    final gate = readGate;
    if (gate != null && !gate.isCompleted) {
      await gate.future;
    }
    return snapshot;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writeCount += 1;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deleteCount += 1;
    values.remove(key);
  }
}

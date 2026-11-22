import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/storage/secure_key_value_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(secureStorageChannelName);
  late Map<String, String> backingStore;
  late List<MethodCall> calls;

  setUp(() {
    backingStore = <String, String>{};
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = call.arguments as Map<Object?, Object?>?;
      return switch (call.method) {
        'read' => backingStore[args?['key']?.toString()],
        'write' => () {
            backingStore[args!['key']!.toString()] = args['value']!.toString();
            return null;
          }(),
        'delete' => () {
            backingStore.remove(args!['key']!.toString());
            return null;
          }(),
        'readAll' => Map<String, String>.from(backingStore),
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('SecureKeyValueStorage', () {
    const storage = PlatformSecureKeyValueStorage();

    test('performs read, write, delete, and readAll round-trips', () async {
      expect(await storage.read('auth.accessToken'), isNull);
      expect(await storage.readAll(), isEmpty);

      await storage.write('auth.accessToken', 'token-1');
      await storage.write('auth.refreshToken', 'refresh-1');

      expect(await storage.read('auth.accessToken'), 'token-1');
      expect(await storage.readAll(), {
        'auth.accessToken': 'token-1',
        'auth.refreshToken': 'refresh-1',
      });

      await storage.delete('auth.accessToken');
      expect(await storage.read('auth.accessToken'), isNull);
      expect(await storage.readAll(), {'auth.refreshToken': 'refresh-1'});
    });

    test('enforces key and value bounds fail-closed without calling native channel',
        () async {
      await expectLater(storage.read(''), throwsArgumentError);
      await expectLater(
        storage.read('k' * (maxSecureStorageKeyLength + 1)),
        throwsArgumentError,
      );
      await expectLater(
        storage.write('valid', 'v' * (maxSecureStorageValueLength + 1)),
        throwsArgumentError,
      );
      await expectLater(storage.delete(''), throwsArgumentError);
      expect(calls, isEmpty);

      final maxKey = 'k' * maxSecureStorageKeyLength;
      final maxValue = 'v' * maxSecureStorageValueLength;
      await storage.write(maxKey, maxValue);
      expect(await storage.read(maxKey), maxValue);
    });

    test('propagates PlatformException on native failures', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'SECURE_STORAGE_WRITE_FAILED',
          message: 'KeyStore unavailable',
        );
      });

      await expectLater(
        storage.write('auth.accessToken', 'secret'),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        storage.delete('auth.accessToken'),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        storage.read('auth.accessToken'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('handles MissingPluginException gracefully in headless environments',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      expect(await storage.read('auth.accessToken'), isNull);
      expect(await storage.readAll(), isEmpty);
      await storage.write('auth.accessToken', 'secret');
      await storage.delete('auth.accessToken');
    });
  });
}

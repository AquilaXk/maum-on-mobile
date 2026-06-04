import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('uses the Android emulator host when no dart define is supplied', () {
      final config = ApiConfig.fromEnvironment(
        baseUrl: '',
        targetPlatform: TargetPlatform.android,
      );

      expect(config.baseUrl, Uri.parse('http://10.0.2.2:8080'));
    });

    test('uses loopback for iOS simulator when no dart define is supplied', () {
      final config = ApiConfig.fromEnvironment(
        baseUrl: '',
        targetPlatform: TargetPlatform.iOS,
      );

      expect(config.baseUrl, Uri.parse('http://127.0.0.1:8080'));
    });

    test('uses localhost for desktop/web local runs without dart define', () {
      final config = ApiConfig.fromEnvironment(
        baseUrl: '',
        targetPlatform: TargetPlatform.macOS,
      );

      expect(config.baseUrl, Uri.parse('http://localhost:8080'));
    });

    test('uses an injected API_BASE_URL value', () {
      final config = ApiConfig.fromEnvironment(
        baseUrl: 'https://api.maumon.example',
      );

      expect(config.baseUrl, Uri.parse('https://api.maumon.example'));
    });

    test('rejects an empty API_BASE_URL value', () {
      expect(
        () => ApiConfig.fromEnvironment(baseUrl: ' '),
        throwsA(isA<StateError>()),
      );
    });
  });
}

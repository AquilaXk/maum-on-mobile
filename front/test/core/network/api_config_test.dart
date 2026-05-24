import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('uses the local API endpoint when no dart define is supplied', () {
      final config = ApiConfig.fromEnvironment();

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

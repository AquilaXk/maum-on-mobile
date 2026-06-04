import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
  });

  factory ApiConfig.fromEnvironment({
    String baseUrl = const String.fromEnvironment('API_BASE_URL'),
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
  }) {
    final normalizedBaseUrl = baseUrl.trim();

    if (baseUrl.isNotEmpty && normalizedBaseUrl.isEmpty) {
      throw StateError('API_BASE_URL must be provided with --dart-define.');
    }

    return ApiConfig(
      baseUrl: Uri.parse(
        normalizedBaseUrl.isEmpty
            ? _localDevelopmentBaseUrl(
                targetPlatform: targetPlatform ?? defaultTargetPlatform,
                isWeb: isWeb,
              )
            : normalizedBaseUrl,
      ),
    );
  }

  final Uri baseUrl;
}

String _localDevelopmentBaseUrl({
  required TargetPlatform targetPlatform,
  required bool isWeb,
}) {
  if (isWeb) {
    return 'http://localhost:8080';
  }

  return switch (targetPlatform) {
    TargetPlatform.android => 'http://10.0.2.2:8080',
    TargetPlatform.iOS => 'http://127.0.0.1:8080',
    _ => 'http://localhost:8080',
  };
}

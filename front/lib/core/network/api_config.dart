import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
  });

  factory ApiConfig.fromEnvironment({
    String baseUrl = const String.fromEnvironment('API_BASE_URL'),
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
    bool isReleaseMode = kReleaseMode,
  }) {
    final normalizedBaseUrl = baseUrl.trim();
    final platform = targetPlatform ?? defaultTargetPlatform;

    if (baseUrl.isNotEmpty && normalizedBaseUrl.isEmpty) {
      throw StateError('API_BASE_URL must be provided with --dart-define.');
    }

    if (normalizedBaseUrl.isEmpty &&
        isReleaseMode &&
        (platform == TargetPlatform.android ||
            platform == TargetPlatform.iOS)) {
      throw StateError(
        'API_BASE_URL must be provided with --dart-define for mobile release builds.',
      );
    }

    return ApiConfig(
      baseUrl: Uri.parse(
        normalizedBaseUrl.isEmpty
            ? _localDevelopmentBaseUrl(
                targetPlatform: platform,
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

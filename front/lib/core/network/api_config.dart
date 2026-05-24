class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
  });

  factory ApiConfig.fromEnvironment({
    String baseUrl = const String.fromEnvironment('API_BASE_URL'),
  }) {
    final normalizedBaseUrl = baseUrl.trim();

    if (normalizedBaseUrl.isEmpty) {
      throw StateError('API_BASE_URL must be provided with --dart-define.');
    }

    return ApiConfig(baseUrl: Uri.parse(normalizedBaseUrl));
  }

  final Uri baseUrl;
}

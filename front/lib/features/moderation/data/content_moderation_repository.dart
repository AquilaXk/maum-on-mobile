import '../../../core/network/api_client.dart';
import '../domain/content_moderation_models.dart';

abstract interface class ContentModerationRepository {
  Future<ContentModerationResult> reviewText({
    required ContentModerationTarget targetType,
    required String text,
  });
}

class ApiContentModerationRepository implements ContentModerationRepository {
  const ApiContentModerationRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<ContentModerationResult> reviewText({
    required ContentModerationTarget targetType,
    required String text,
  }) {
    return _apiClient.post<ContentModerationResult>(
      '/api/v1/moderation/text',
      body: ContentModerationRequest(
        targetType: targetType,
        text: text,
      ).toJson(),
      parser: ContentModerationResult.fromJson,
    );
  }
}

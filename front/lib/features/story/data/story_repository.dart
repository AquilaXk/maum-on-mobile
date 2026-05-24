import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/story_models.dart';

abstract interface class StoryRepository {
  Future<PageResponse<StorySummary>> fetchStories({
    String? title,
    StoryCategory category = StoryCategory.all,
    int page = 0,
    int size = 20,
  });

  Future<StoryDetail> fetchStory(int id);

  Future<int> createStory(StoryDraft draft);

  Future<void> updateStory(int id, StoryDraft draft);

  Future<void> deleteStory(int id);

  Future<void> updateResolutionStatus(
    int id,
    StoryResolutionStatus status,
  );

  Future<PageResponse<StoryComment>> fetchComments(
    int postId, {
    int page = 0,
    int size = 20,
  });

  Future<void> createComment({
    required int postId,
    required int authorId,
    required String content,
    int? parentCommentId,
  });

  Future<void> updateComment(int commentId, String content);

  Future<void> deleteComment(int commentId);
}

class ApiStoryRepository implements StoryRepository {
  const ApiStoryRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<PageResponse<StorySummary>> fetchStories({
    String? title,
    StoryCategory category = StoryCategory.all,
    int page = 0,
    int size = 20,
  }) {
    final trimmedTitle = title?.trim() ?? '';

    return _apiClient.getPage<StorySummary>(
      '/api/v1/posts',
      itemParser: StorySummary.fromJson,
      queryParameters: {
        'page': page,
        'size': size,
        if (trimmedTitle.isNotEmpty) 'title': trimmedTitle,
        if (category.apiValue != null) 'category': category.apiValue,
      },
      requiresAuth: false,
      retryOnUnauthorized: false,
    );
  }

  @override
  Future<StoryDetail> fetchStory(int id) {
    return _apiClient.get<StoryDetail>(
      '/api/v1/posts/$id',
      parser: StoryDetail.fromJson,
      requiresAuth: false,
      retryOnUnauthorized: false,
    );
  }

  @override
  Future<int> createStory(StoryDraft draft) {
    return _apiClient.post<int>(
      '/api/v1/posts',
      body: draft.toJson(),
      parser: _readCreatedId,
    );
  }

  @override
  Future<void> updateStory(int id, StoryDraft draft) {
    return _apiClient.putVoid('/api/v1/posts/$id', body: draft.toJson());
  }

  @override
  Future<void> deleteStory(int id) {
    return _apiClient.deleteVoid('/api/v1/posts/$id');
  }

  @override
  Future<void> updateResolutionStatus(
    int id,
    StoryResolutionStatus status,
  ) {
    return _apiClient.patchVoid(
      '/api/v1/posts/$id/resolution-status',
      body: {'resolutionStatus': status.apiValue},
    );
  }

  @override
  Future<PageResponse<StoryComment>> fetchComments(
    int postId, {
    int page = 0,
    int size = 20,
  }) {
    return _apiClient.getPage<StoryComment>(
      '/api/v1/posts/$postId/comments',
      itemParser: StoryComment.fromJson,
      queryParameters: {
        'page': page,
        'size': size,
      },
      requiresAuth: false,
      retryOnUnauthorized: false,
    );
  }

  @override
  Future<void> createComment({
    required int postId,
    required int authorId,
    required String content,
    int? parentCommentId,
  }) {
    return _apiClient.postVoid(
      '/api/v1/posts/$postId/comments',
      body: {
        'content': content,
        'authorId': authorId,
        'parentCommentId': parentCommentId,
      },
    );
  }

  @override
  Future<void> updateComment(int commentId, String content) {
    return _apiClient.putVoid(
      '/api/v1/comments/$commentId',
      body: {'content': content},
    );
  }

  @override
  Future<void> deleteComment(int commentId) {
    return _apiClient.deleteVoid('/api/v1/comments/$commentId');
  }

  int _readCreatedId(Object? json) {
    if (json is int) {
      return json;
    }

    if (json is num) {
      return json.toInt();
    }

    return int.tryParse(json?.toString() ?? '') ?? 0;
  }
}

import '../../../core/network/api_client.dart';
import '../domain/home_models.dart';

abstract interface class HomeRepository {
  Future<HomeStats> fetchStats();

  Future<HomeStoryPage> fetchStories({
    HomeStoryCategory category = HomeStoryCategory.all,
  });
}

class ApiHomeRepository implements HomeRepository {
  const ApiHomeRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<HomeStats> fetchStats() {
    return _apiClient.get<HomeStats>(
      '/api/v1/home/stats',
      requiresAuth: false,
      retryOnUnauthorized: false,
      parser: HomeStats.fromJson,
    );
  }

  @override
  Future<HomeStoryPage> fetchStories({
    HomeStoryCategory category = HomeStoryCategory.all,
  }) {
    final queryParameters = <String, Object?>{
      'page': 0,
      'size': 8,
      if (category.apiValue != null) 'category': category.apiValue,
    };

    return _apiClient.get<HomeStoryPage>(
      '/api/v1/posts',
      queryParameters: queryParameters,
      requiresAuth: false,
      retryOnUnauthorized: false,
      parser: HomeStoryPage.fromJson,
    );
  }
}

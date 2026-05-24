import '../../../core/network/api_client.dart';
import '../domain/letter_models.dart';

abstract interface class LetterRepository {
  Future<int> createLetter(LetterDraft draft);

  Future<LetterListPage> fetchReceivedLetters({
    int page = 0,
    int size = 20,
  });

  Future<LetterListPage> fetchSentLetters({
    int page = 0,
    int size = 20,
  });

  Future<LetterDetail> fetchLetter(int id);

  Future<LetterStats> fetchStats();

  Future<void> replyLetter(int id, String replyContent);

  Future<void> acceptLetter(int id);

  Future<void> rejectLetter(int id);

  Future<void> markWriting(int id);

  Future<LetterStatus> fetchLiveStatus(int id);
}

class ApiLetterRepository implements LetterRepository {
  const ApiLetterRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<int> createLetter(LetterDraft draft) {
    return _apiClient.post<int>(
      '/api/v1/letters',
      body: draft.toJson(),
      parser: _readCreatedId,
    );
  }

  @override
  Future<LetterListPage> fetchReceivedLetters({
    int page = 0,
    int size = 20,
  }) {
    return _apiClient.get<LetterListPage>(
      '/api/v1/letters/received',
      parser: LetterListPage.fromJson,
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  @override
  Future<LetterListPage> fetchSentLetters({
    int page = 0,
    int size = 20,
  }) {
    return _apiClient.get<LetterListPage>(
      '/api/v1/letters/sent',
      parser: LetterListPage.fromJson,
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  @override
  Future<LetterDetail> fetchLetter(int id) {
    return _apiClient.get<LetterDetail>(
      '/api/v1/letters/$id',
      parser: LetterDetail.fromJson,
    );
  }

  @override
  Future<LetterStats> fetchStats() {
    return _apiClient.get<LetterStats>(
      '/api/v1/letters/stats',
      parser: LetterStats.fromJson,
    );
  }

  @override
  Future<void> replyLetter(int id, String replyContent) {
    return _apiClient.postVoid(
      '/api/v1/letters/$id/reply',
      body: {'replyContent': replyContent},
    );
  }

  @override
  Future<void> acceptLetter(int id) {
    return _apiClient.postVoid('/api/v1/letters/$id/accept');
  }

  @override
  Future<void> rejectLetter(int id) {
    return _apiClient.postVoid('/api/v1/letters/$id/reject');
  }

  @override
  Future<void> markWriting(int id) {
    return _apiClient.postVoid('/api/v1/letters/$id/writing');
  }

  @override
  Future<LetterStatus> fetchLiveStatus(int id) {
    return _apiClient.get<LetterStatus>(
      '/api/v1/letters/$id/status',
      parser: LetterStatus.fromApiValue,
      requiresAuth: false,
      retryOnUnauthorized: false,
    );
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

import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/multipart_body.dart';
import '../domain/diary_models.dart';

abstract interface class DiaryRepository {
  Future<PageResponse<DiaryEntry>> fetchDiaries({
    int page = 0,
    int size = 100,
  });

  Future<PageResponse<DiaryEntry>> fetchPublicDiaries({
    int page = 0,
    int size = 20,
  });

  Future<DiaryEntry> fetchDiary(int id);

  Future<int> createDiary(DiaryDraft draft);

  Future<void> updateDiary(int id, DiaryDraft draft);

  Future<void> deleteDiary(int id);
}

class ApiDiaryRepository implements DiaryRepository {
  const ApiDiaryRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<PageResponse<DiaryEntry>> fetchDiaries({
    int page = 0,
    int size = 100,
  }) {
    return _apiClient.getPage<DiaryEntry>(
      '/api/v1/diaries',
      itemParser: DiaryEntry.fromJson,
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  @override
  Future<PageResponse<DiaryEntry>> fetchPublicDiaries({
    int page = 0,
    int size = 20,
  }) {
    return _apiClient.getPage<DiaryEntry>(
      '/api/v1/diaries/public',
      itemParser: DiaryEntry.fromJson,
      queryParameters: {
        'page': page,
        'size': size,
      },
      requiresAuth: false,
      retryOnUnauthorized: false,
    );
  }

  @override
  Future<DiaryEntry> fetchDiary(int id) {
    return _apiClient.get<DiaryEntry>(
      '/api/v1/diaries/$id',
      parser: DiaryEntry.fromJson,
    );
  }

  @override
  Future<int> createDiary(DiaryDraft draft) {
    return _apiClient.postMultipart<int>(
      '/api/v1/diaries',
      multipart: _multipartFromDraft(draft),
      parser: _readCreatedId,
    );
  }

  @override
  Future<void> updateDiary(int id, DiaryDraft draft) {
    return _apiClient.putMultipartVoid(
      '/api/v1/diaries/$id',
      multipart: _multipartFromDraft(draft),
    );
  }

  @override
  Future<void> deleteDiary(int id) {
    return _apiClient.deleteVoid('/api/v1/diaries/$id');
  }

  MultipartBody _multipartFromDraft(DiaryDraft draft) {
    return MultipartBody(
      textParts: [
        MultipartTextPart(
          fieldName: 'data',
          value: jsonEncode({
            'title': draft.title,
            'content': draft.content,
            'categoryName': draft.category.label,
            'isPrivate': draft.isPrivate,
            'imageUrl': draft.imageUrl,
            'contentBlocks': draft.contentBlocks
                .map((block) => block.toJson())
                .toList(growable: false),
          }),
          contentType: 'application/json',
        ),
      ],
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

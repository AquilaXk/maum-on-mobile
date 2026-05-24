import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/diary/data/diary_repository.dart';
import 'package:maum_on_mobile_front/features/diary/domain/diary_models.dart';

void main() {
  group('ApiDiaryRepository', () {
    test('loads authenticated diary page', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'content': [_diaryJson(id: 1, title: '오늘의 기록')],
            'number': 0,
            'size': 30,
            'totalElements': 1,
            'totalPages': 1,
            'last': true,
          },
        }),
      ]);
      final repository = _repository(transport);

      final page = await repository.fetchDiaries(page: 0, size: 30);

      expect(page.items.single.title, '오늘의 기록');
      expect(transport.requests.single.method, ApiMethod.get);
      expect(transport.requests.single.path, '/api/v1/diaries');
      expect(
          transport.requests.single.queryParameters, {'page': 0, 'size': 30});
      expect(transport.requests.single.requiresAuth, isTrue);
    });

    test('loads public diary page without auth retry', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'content': [_diaryJson(id: 2, title: '공개 기록')],
            'page': 0,
            'size': 20,
            'totalElements': 1,
            'totalPages': 1,
            'last': true,
          },
        }),
      ]);
      final repository = _repository(transport);

      final page = await repository.fetchPublicDiaries(page: 0, size: 20);

      expect(page.items.single.title, '공개 기록');
      expect(transport.requests.single.method, ApiMethod.get);
      expect(transport.requests.single.path, '/api/v1/diaries/public');
      expect(
          transport.requests.single.queryParameters, {'page': 0, 'size': 20});
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
    });

    test('creates a diary with JSON data and image multipart parts', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'success': true, 'data': 7}),
      ]);
      final repository = _repository(transport);

      final id = await repository.createDiary(
        const DiaryDraft(
          title: '새 기록',
          content: '본문입니다.',
          category: DiaryCategory.daily,
          isPrivate: true,
          image: DiaryImageAttachment(
            filename: 'diary.png',
            bytes: [1, 2, 3],
          ),
        ),
      );

      final request = transport.requests.single;
      final multipart = request.multipart!;
      expect(id, 7);
      expect(request.method, ApiMethod.post);
      expect(request.path, '/api/v1/diaries');
      expect(multipart.textParts.single.fieldName, 'data');
      expect(multipart.textParts.single.contentType, 'application/json');
      expect(multipart.textParts.single.value, contains('"title":"새 기록"'));
      expect(multipart.textParts.single.value, contains('"categoryName":"일상"'));
      expect(multipart.files.single.fieldName, 'image');
      expect(multipart.files.single.filename, 'diary.png');
      expect(multipart.files.single.bytes, [1, 2, 3]);
    });

    test('updates a diary through PUT multipart', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'success': true}),
      ]);
      final repository = _repository(transport);

      await repository.updateDiary(
        3,
        const DiaryDraft(
          title: '수정 기록',
          content: '수정 본문',
          category: DiaryCategory.family,
          isPrivate: false,
          imageUrl: '/images/old.png',
        ),
      );

      final request = transport.requests.single;
      expect(request.method, ApiMethod.put);
      expect(request.path, '/api/v1/diaries/3');
      expect(request.multipart?.textParts.single.value,
          contains('"imageUrl":"/images/old.png"'));
      expect(request.multipart?.files, isEmpty);
    });

    test('deletes a diary through DELETE', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'success': true}),
      ]);
      final repository = _repository(transport);

      await repository.deleteDiary(5);

      expect(transport.requests.single.method, ApiMethod.delete);
      expect(transport.requests.single.path, '/api/v1/diaries/5');
    });
  });
}

ApiDiaryRepository _repository(_FakeApiTransport transport) {
  return ApiDiaryRepository(
    apiClient: ApiClient(
      transport: transport,
      tokenStore: MemoryAuthTokenStore(),
    ),
  );
}

Map<String, Object?> _diaryJson({
  required int id,
  required String title,
}) {
  return {
    'id': id,
    'title': title,
    'content': '본문입니다.',
    'categoryName': '일상',
    'nickname': '마음이',
    'imageUrl': '/images/diary.png',
    'isPrivate': true,
    'createDate': '2026-05-18T08:30:00',
    'modifyDate': '2026-05-18T09:00:00',
  };
}

class _FakeApiTransport implements ApiTransport {
  _FakeApiTransport(this._responses);

  final List<ApiTransportResponse> _responses;
  final List<ApiRequest> requests = [];

  @override
  Future<ApiTransportResponse> send(ApiRequest request) async {
    requests.add(request);

    if (_responses.isEmpty) {
      throw const ApiTransportException('No fake response configured');
    }

    return _responses.removeAt(0);
  }
}

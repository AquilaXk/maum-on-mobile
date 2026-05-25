import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/home/data/home_repository.dart';
import 'package:maum_on_mobile_front/features/home/domain/home_models.dart';

void main() {
  group('ApiHomeRepository', () {
    test('loads public home stats without auth retry', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'todayWorryCount': 18,
            'todayLetterCount': 42,
            'todayDiaryCount': 11,
            'summary': {
              'recoveryMessage': '오전에는 천천히 마음을 열어보세요.',
              'primaryActionLabel': '오늘 마음 기록하기',
              'primaryActionSurface': 'diary',
              'feedMessage': '고민 이야기가 가장 활발합니다.',
            },
            'categorySummaries': [
              {'category': 'WORRY', 'label': '고민', 'count': 7},
            ],
            'popularStories': [
              {
                'id': 5,
                'title': '많이 읽힌 이야기',
                'category': 'WORRY',
                'label': '고민',
                'viewCount': 99,
                'nickname': '마음이',
              },
            ],
          },
        }),
      ]);
      final repository = ApiHomeRepository(
        apiClient: ApiClient(
          transport: transport,
          tokenStore: MemoryAuthTokenStore(),
        ),
      );

      final stats = await repository.fetchStats();

      expect(stats.todayWorryCount, 18);
      expect(stats.summary.recoveryMessage, '오전에는 천천히 마음을 열어보세요.');
      expect(stats.summary.primaryActionSurface, HomeActionSurface.diary);
      expect(stats.categorySummaries.single.count, 7);
      expect(stats.popularStories.single.title, '많이 읽힌 이야기');
      expect(transport.requests.single.path, '/api/v1/home/stats');
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
    });

    test('loads public story feed cards', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'content': [_postJson(id: 1, category: 'WORRY')],
            'last': true,
          },
        }),
      ]);
      final repository = ApiHomeRepository(
        apiClient: ApiClient(
          transport: transport,
          tokenStore: MemoryAuthTokenStore(),
        ),
      );

      final page = await repository.fetchStories();

      expect(page.items.single.title, '오늘 너무 지쳐요');
      expect(page.items.single.category, HomeStoryCategory.worry);
      expect(transport.requests.single.path, '/api/v1/posts');
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
      expect(transport.requests.single.queryParameters, {
        'page': 0,
        'size': 8,
      });
    });

    test('passes selected category to the feed request', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'content': <Object?>[],
            'last': true,
          },
        }),
      ]);
      final repository = ApiHomeRepository(
        apiClient: ApiClient(
          transport: transport,
          tokenStore: MemoryAuthTokenStore(),
        ),
      );

      await repository.fetchStories(category: HomeStoryCategory.question);

      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.retryOnUnauthorized, isFalse);
      expect(transport.requests.single.queryParameters['category'], 'QUESTION');
    });

    test('fails when a story category is unsupported', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'content': [_postJson(id: 1, category: 'UNKNOWN')],
            'last': true,
          },
        }),
      ]);
      final repository = ApiHomeRepository(
        apiClient: ApiClient(
          transport: transport,
          tokenStore: MemoryAuthTokenStore(),
        ),
      );

      expect(
        repository.fetchStories(),
        throwsA(
          isA<ApiClientException>()
              .having((error) => error.kind, 'kind', ApiErrorKind.unknown)
              .having(
                (error) => error.cause,
                'cause',
                isA<FormatException>().having(
                  (error) => error.message,
                  'message',
                  contains('UNKNOWN'),
                ),
              ),
        ),
      );
    });
  });
}

Map<String, Object?> _postJson({
  required int id,
  required String category,
}) {
  return {
    'id': id,
    'title': '오늘 너무 지쳐요',
    'viewCount': 42,
    'createDate': '2026-04-10T08:00:00',
    'modifyDate': '2026-04-10T09:10:00',
    'thumbnail': null,
    'summary': '누군가 제 이야기를 들어주면 좋겠어요.',
    'category': category,
    'resolutionStatus': 'ONGOING',
    'nickname': '마음온데모',
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

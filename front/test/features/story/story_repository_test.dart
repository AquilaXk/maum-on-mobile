import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/story/data/story_repository.dart';
import 'package:maum_on_mobile_front/features/story/domain/story_models.dart';

void main() {
  group('ApiStoryRepository', () {
    test('fetches story list with title and category filters', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'resultCode': '200-1',
          'data': {
            'content': [
              {
                'id': 1,
                'title': '잠이 오지 않는 밤',
                'summary': '밤마다 생각이 많아요.',
                'nickname': '마음이',
                'category': 'WORRY',
                'resolutionStatus': 'ONGOING',
                'viewCount': 3,
                'createDate': '2026-05-24T08:00:00',
                'modifyDate': '2026-05-24T08:00:00',
              },
            ],
            'page': 0,
            'size': 20,
            'totalElements': 1,
            'totalPages': 1,
            'last': true,
          },
        }),
      ]);
      final repository = _repository(transport);

      final page = await repository.fetchStories(
        title: '밤',
        category: StoryCategory.worry,
      );

      expect(page.items.single.title, '잠이 오지 않는 밤');
      expect(transport.requests.single.path, '/api/v1/posts');
      expect(transport.requests.single.requiresAuth, isFalse);
      expect(transport.requests.single.queryParameters['title'], '밤');
      expect(transport.requests.single.queryParameters['category'], 'WORRY');
    });

    test('fetches story detail and comments with permission fields', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'resultCode': '200-2',
          'data': {
            'id': 4,
            'title': '조금 긴 하루',
            'content': '긴 본문입니다.',
            'summary': '긴 본문입니다.',
            'nickname': '작성자',
            'category': 'DAILY',
            'resolutionStatus': 'RESOLVED',
            'viewCount': 7,
            'authorid': 9,
            'createDate': '2026-05-24T08:00:00',
            'modifyDate': '2026-05-24T09:00:00',
          },
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-3',
          'data': {
            'content': [
              {
                'id': 11,
                'content': '응원합니다.',
                'authorId': 9,
                'nickname': '작성자',
                'email': 'me@example.com',
                'postId': 4,
                'createDate': '2026-05-24T10:00:00',
                'modifyDate': '2026-05-24T10:00:00',
                'deleted': true,
                'replies': [
                  {
                    'id': 12,
                    'content': '고마워요.',
                    'authorId': 10,
                    'nickname': '친구',
                    'postId': 4,
                    'createDate': '2026-05-24T10:10:00',
                    'modifyDate': '2026-05-24T10:10:00',
                  },
                ],
              },
            ],
            'page': 0,
            'size': 20,
            'totalElements': 1,
            'totalPages': 1,
            'hasNext': false,
            'last': true,
          },
        }),
      ]);
      final repository = _repository(transport);

      final story = await repository.fetchStory(4);
      final comments = await repository.fetchComments(4);

      expect(story.canEdit(9), isTrue);
      expect(story.resolutionStatus, StoryResolutionStatus.resolved);
      expect(comments.hasNext, isFalse);
      expect(comments.items.single.deleted, isTrue);
      expect(comments.items.single.canEdit(9), isFalse);
      expect(comments.items.single.replies.single.content, '고마워요.');
    });

    test('sends story and comment mutations to the API paths', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'resultCode': '201-1', 'data': 15}),
        ApiTransportResponse.ok({'resultCode': '200-3'}),
        ApiTransportResponse.ok({'resultCode': '200-5'}),
        ApiTransportResponse.ok({'resultCode': '200-4'}),
        const ApiTransportResponse(statusCode: 201),
        const ApiTransportResponse(statusCode: 200),
        ApiTransportResponse.ok({'resultCode': '200-4'}),
      ]);
      final repository = _repository(transport);
      const draft = StoryDraft(
        title: '새 스토리',
        content: '새 본문',
        category: StoryCategory.question,
      );

      final createdId = await repository.createStory(draft);
      await repository.updateStory(15, draft);
      await repository.updateResolutionStatus(
        15,
        StoryResolutionStatus.resolved,
      );
      await repository.deleteStory(15);
      await repository.createComment(
        postId: 15,
        authorId: 7,
        content: '댓글',
      );
      await repository.updateComment(20, '수정 댓글');
      await repository.deleteComment(20);

      expect(createdId, 15);
      expect(transport.requests[0].method, ApiMethod.post);
      expect(transport.requests[0].path, '/api/v1/posts');
      expect(transport.requests[1].method, ApiMethod.put);
      expect(transport.requests[1].path, '/api/v1/posts/15');
      expect(transport.requests[2].method, ApiMethod.patch);
      expect(
        transport.requests[2].path,
        '/api/v1/posts/15/resolution-status',
      );
      expect(transport.requests[3].method, ApiMethod.delete);
      expect(transport.requests[4].path, '/api/v1/posts/15/comments');
      expect(transport.requests[4].body, {
        'content': '댓글',
        'authorId': 7,
        'parentCommentId': null,
      });
      expect(transport.requests[5].path, '/api/v1/comments/20');
      expect(transport.requests[6].method, ApiMethod.delete);
    });
  });
}

ApiStoryRepository _repository(_FakeApiTransport transport) {
  return ApiStoryRepository(
    apiClient: ApiClient(
      transport: transport,
      tokenStore: MemoryAuthTokenStore(),
    ),
  );
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

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/letter/data/letter_repository.dart';
import 'package:maum_on_mobile_front/features/letter/domain/letter_models.dart';

void main() {
  group('ApiLetterRepository', () {
    test('fetches stats, list, and detail responses', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'resultCode': '200',
          'data': {
            'receivedCount': 2,
            'randomReceiveAllowed': false,
            'latestReceivedLetter': {
              'id': 1,
              'title': '도착한 편지',
              'createdDate': '2026-05-24 10:00:00',
              'replied': false,
            },
            'latestSentLetter': {
              'id': 2,
              'title': '보낸 편지',
              'createdDate': '2026-05-24 09:00:00',
              'replied': true,
            },
          },
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-2',
          'data': {
            'letters': [
              {
                'id': 3,
                'title': '받은 편지',
                'createdDate': '2026-05-24T08:00:00',
                'status': 'SENT',
              },
            ],
            'totalPages': 1,
            'totalElements': 1,
            'currentPage': 0,
            'isFirst': true,
            'isLast': true,
          },
        }),
        ApiTransportResponse.ok({
          'resultCode': '200-4',
          'data': {
            'id': 3,
            'title': '받은 편지',
            'content': '마음 내용',
            'replyContent': null,
            'status': 'ACCEPTED',
            'replied': false,
            'createdDate': '2026-05-24T08:00:00',
          },
        }),
      ]);
      final repository = _repository(transport);

      final stats = await repository.fetchStats();
      final list = await repository.fetchReceivedLetters();
      final detail = await repository.fetchLetter(3);

      expect(stats.receivedCount, 2);
      expect(stats.randomReceiveAllowed, isFalse);
      expect(stats.latestSentLetter?.replied, isTrue);
      expect(list.items.single.status, LetterStatus.sent);
      expect(detail.status, LetterStatus.accepted);
      expect(transport.requests[1].path, '/api/v1/letters/received');
    });

    test('sends create and action requests to the API paths', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'resultCode': '200-1', 'data': 10}),
        ApiTransportResponse.ok({'resultCode': '200-5'}),
        ApiTransportResponse.ok({'resultCode': '200-5'}),
        ApiTransportResponse.ok({'resultCode': '200-8'}),
        ApiTransportResponse.ok({'resultCode': '200-6'}),
        ApiTransportResponse.ok({'resultCode': '200-7', 'data': 'WRITING'}),
      ]);
      final repository = _repository(transport);

      final id = await repository.createLetter(
        const LetterDraft(title: '제목', content: '본문'),
      );
      await repository.replyLetter(10, '답장');
      await repository.acceptLetter(10);
      await repository.rejectLetter(10);
      await repository.markWriting(10);
      final status = await repository.fetchLiveStatus(10);

      expect(id, 10);
      expect(status, LetterStatus.writing);
      expect(transport.requests[0].path, '/api/v1/letters');
      expect(transport.requests[0].body, {'title': '제목', 'content': '본문'});
      expect(transport.requests[1].path, '/api/v1/letters/10/reply');
      expect(transport.requests[2].path, '/api/v1/letters/10/accept');
      expect(transport.requests[3].path, '/api/v1/letters/10/reject');
      expect(transport.requests[4].path, '/api/v1/letters/10/writing');
      expect(transport.requests[5].requiresAuth, isFalse);
    });

    test('fails when the create response omits a valid id', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'resultCode': '200-1', 'data': 'invalid'}),
      ]);
      final repository = _repository(transport);

      expect(
        () => repository.createLetter(
          const LetterDraft(title: '제목', content: '본문'),
        ),
        throwsA(
          isA<ApiClientException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.unknown,
          ),
        ),
      );
    });
  });
}

ApiLetterRepository _repository(_FakeApiTransport transport) {
  return ApiLetterRepository(
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

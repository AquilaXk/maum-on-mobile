import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_client.dart';
import 'package:maum_on_mobile_front/core/network/api_transport.dart';
import 'package:maum_on_mobile_front/core/network/auth_token_store.dart';
import 'package:maum_on_mobile_front/features/diary/data/diary_image_repository.dart';
import 'package:maum_on_mobile_front/features/diary/domain/diary_models.dart';

void main() {
  group('ApiDiaryImageRepository', () {
    test('uploads selected image through the image endpoint', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({
          'success': true,
          'data': {
            'imageUrl': '/images/uploads/mind.png',
            'originalFilename': 'mind.png',
            'contentType': 'image/png',
            'byteSize': 3,
            'status': 'TEMPORARY',
          },
        }),
      ]);
      final repository = _repository(transport);

      final uploaded = await repository.uploadImage(
        const DiaryImageAttachment(
          filename: 'mind.png',
          bytes: [1, 2, 3],
          contentType: 'image/png',
        ),
      );

      final request = transport.requests.single;
      expect(uploaded.imageUrl, '/images/uploads/mind.png');
      expect(uploaded.originalFilename, 'mind.png');
      expect(uploaded.byteSize, 3);
      expect(request.method, ApiMethod.post);
      expect(request.path, '/api/v1/images/upload');
      expect(request.multipart?.files.single.fieldName, 'image');
      expect(request.multipart?.files.single.filename, 'mind.png');
      expect(request.multipart?.files.single.bytes, [1, 2, 3]);
      expect(request.multipart?.files.single.contentType, 'image/png');
    });

    test('deletes a temporary uploaded image by URL', () async {
      final transport = _FakeApiTransport([
        ApiTransportResponse.ok({'success': true, 'data': true}),
      ]);
      final repository = _repository(transport);

      await repository.deleteImage('/images/uploads/mind.png');

      final request = transport.requests.single;
      expect(request.method, ApiMethod.delete);
      expect(request.path, '/api/v1/images');
      expect(request.body, {'imageUrl': '/images/uploads/mind.png'});
    });
  });
}

ApiDiaryImageRepository _repository(_FakeApiTransport transport) {
  return ApiDiaryImageRepository(
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

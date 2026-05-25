import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/diary/domain/diary_models.dart';
import 'package:maum_on_mobile_front/features/diary/presentation/diary_image_picker.dart';

void main() {
  group('DiaryImageProcessor', () {
    test('accepts supported image within upload limits', () async {
      const processor = DiaryImageProcessor(
        maxOriginalBytes: 8,
        maxUploadBytes: 8,
      );

      final result = await processor.process(
        source: DiaryImageSource.gallery,
        filename: 'mind.jpg',
        bytes: [1, 2, 3],
        contentType: 'image/jpeg',
      );

      expect(result.status, DiaryImagePickStatus.picked);
      expect(result.attachment?.filename, 'mind.jpg');
      expect(result.attachment?.source, DiaryImageSource.gallery);
      expect(result.attachment?.contentType, 'image/jpeg');
    });

    test('rejects unsupported image extension before upload', () async {
      const processor = DiaryImageProcessor();

      final result = await processor.process(
        source: DiaryImageSource.gallery,
        filename: 'mind.gif',
        bytes: [1, 2, 3],
        contentType: 'image/gif',
      );

      expect(result.status, DiaryImagePickStatus.unsupportedFormat);
      expect(result.message, contains('지원하지 않는 이미지 형식'));
    });

    test('rejects image that exceeds original size limit', () async {
      const processor = DiaryImageProcessor(
        maxOriginalBytes: 2,
        maxUploadBytes: 2,
      );

      final result = await processor.process(
        source: DiaryImageSource.camera,
        filename: 'large.png',
        bytes: [1, 2, 3],
        contentType: 'image/png',
      );

      expect(result.status, DiaryImagePickStatus.tooLarge);
      expect(result.message, contains('이미지 용량'));
    });

    test('normalizes missing content type from extension', () async {
      const processor = DiaryImageProcessor();

      final result = await processor.process(
        source: DiaryImageSource.camera,
        filename: 'capture.webp',
        bytes: [1, 2, 3],
      );

      expect(result.status, DiaryImagePickStatus.picked);
      expect(result.attachment?.contentType, 'image/webp');
    });
  });
}

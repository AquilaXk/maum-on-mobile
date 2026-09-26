import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/diary/domain/diary_models.dart';

void main() {
  group('legacyDiaryContentBlocks & parseHtmlToDiaryContentBlocks', () {
    test('plain text without HTML produces standard text block and image block', () {
      final blocks = legacyDiaryContentBlocks(
        content: '순수 텍스트 내용입니다.',
        imageUrl: '/images/uploads/1/pic.jpg',
      );

      expect(blocks.length, 2);
      expect(blocks[0].isText, isTrue);
      expect(blocks[0].text, '순수 텍스트 내용입니다.');
      expect(blocks[1].isImage, isTrue);
      expect(blocks[1].imageUrl, '/images/uploads/1/pic.jpg');
    });

    test('web HTML with p and br tags strips raw tags cleanly', () {
      const html = '<p>안녕하세요.<br>오늘 하루도 고생 많았습니다.</p><p>내일도 힘내요!</p>';
      final blocks = legacyDiaryContentBlocks(content: html);

      expect(blocks.length, 1);
      expect(blocks[0].isText, isTrue);
      expect(blocks[0].text, contains('안녕하세요.'));
      expect(blocks[0].text, contains('오늘 하루도 고생 많았습니다.'));
      expect(blocks[0].text, contains('내일도 힘내요!'));
      expect(blocks[0].text.contains('<p>'), isFalse);
      expect(blocks[0].text.contains('</p>'), isFalse);
      expect(blocks[0].text.contains('<br>'), isFalse);
    });

    test('web HTML with img tags extracts text and image blocks in order', () {
      const html =
          '<p>첫 번째 글입니다.</p><figure><img src="/images/uploads/1/photo.jpg" alt="사진1" data-filename="photo.jpg" data-size="2048" /></figure><p>두 번째 글입니다.</p>';
      final blocks = legacyDiaryContentBlocks(content: html);

      expect(blocks.length, 3);
      expect(blocks[0].isText, isTrue);
      expect(blocks[0].text, '첫 번째 글입니다.');

      expect(blocks[1].isImage, isTrue);
      expect(blocks[1].imageUrl, '/images/uploads/1/photo.jpg');
      expect(blocks[1].filename, 'photo.jpg');
      expect(blocks[1].byteSize, 2048);

      expect(blocks[2].isText, isTrue);
      expect(blocks[2].text, '두 번째 글입니다.');
    });

    test('appends fallback imageUrl if not already present in HTML', () {
      const html = '<p>사진 없는 일기</p>';
      final blocks = legacyDiaryContentBlocks(
        content: html,
        imageUrl: '/images/uploads/fallback.png',
      );

      expect(blocks.length, 2);
      expect(blocks[0].text, '사진 없는 일기');
      expect(blocks[1].imageUrl, '/images/uploads/fallback.png');
    });
  });
}

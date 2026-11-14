import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/shared/algorithm/bitap_hangul_search.dart';
import 'package:maum_on_mobile_front/shared/algorithm/bounded_key_ring_set.dart';

void main() {
  group('computeTextBloom31', () {
    test('stays strictly within 31-bit non-negative integer range', () {
      const samples = [
        '',
        '오늘 마음을 기록해 본다.',
        'Very.Long/Email_Address@Example-Service.test 0123456789',
        'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ',
      ];

      for (final sample in samples) {
        final bloom = computeTextBloom31(sample);
        expect(bloom, greaterThanOrEqualTo(0));
        expect(bloom, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });

    test('folds Hangul syllables and Choseong into matching Bloom bits', () {
      final itemBloom = computeTextBloom31('오늘의 기록 작성');
      final exactQueryBloom = computeTextBloom31('기록');
      final choseongQueryBloom = computeTextBloom31('ㄱㄹ');
      final unrelatedQueryBloom = computeTextBloom31('ㅍㅎ');

      expect(itemBloom & exactQueryBloom, exactQueryBloom);
      expect(itemBloom & choseongQueryBloom, choseongQueryBloom);
      expect(itemBloom & unrelatedQueryBloom, isNot(unrelatedQueryBloom));
    });

    test('folds ASCII case into identical Bloom signatures', () {
      final lowerBloom = computeTextBloom31('maum on diary');
      final upperBloom = computeTextBloom31('MAUM');
      expect(lowerBloom & upperBloom, upperBloom);
    });
  });

  group('BitapHangulMatcher', () {
    test('matches exact Hangul, mixed ASCII, and Hangul Choseong queries', () {
      const titles = [
        '오늘의 감정 기록',
        '따뜻한 편지 한 통',
        'Maum On Breathing Guide',
        '산책 후 정리한 마음',
      ];
      final blooms = titles.map(computeTextBloom31).toList(growable: false);

      final exactMatcher = BitapHangulMatcher('감정 기록');
      expect(exactMatcher.matches(titles[0], textBloom: blooms[0]), isTrue);
      expect(exactMatcher.matches(titles[1], textBloom: blooms[1]), isFalse);

      final choseongMatcher = BitapHangulMatcher('ㄱㄹ');
      expect(choseongMatcher.matches(titles[0], textBloom: blooms[0]), isTrue);
      expect(choseongMatcher.matches(titles[1], textBloom: blooms[1]), isFalse);

      final caseMatcher = BitapHangulMatcher('breathing');
      expect(caseMatcher.matches(titles[2], textBloom: blooms[2]), isTrue);

      final fullChoseong = BitapHangulMatcher('ㅁㅇ');
      expect(fullChoseong.matches(titles[3], textBloom: blooms[3]), isTrue);
      expect(extractHangulChoseong('기록'), 'ㄱㄹ');
    });

    test('supports 1-edit-distance fuzzy match and respects Bloom gate', () {
      final matcher = BitapHangulMatcher('letter', maxErrors: 1);

      expect(matcher.matchDistance('send a letter'), 0);
      expect(matcher.matchDistance('send a leter'), 1); // 1 deletion
      expect(matcher.matchDistance('send a latter'), 1); // 1 substitution
      expect(matcher.matchDistance('send a lettter'), 1); // 1 insertion
      expect(matcher.matchDistance('completely unrelated'), -1);

      final koreanFuzzy = BitapHangulMatcher('마음일기', maxErrors: 1);
      expect(koreanFuzzy.matchDistance('오늘의 마음일기'), 0);
      expect(koreanFuzzy.matchDistance('오늘의 마음열기'), 1);
      expect(koreanFuzzy.matchDistance('편지함 목록'), -1);

      final textBloom = computeTextBloom31('오늘의 마음열기');
      expect(koreanFuzzy.mayMatchBloom(textBloom), isTrue);
      expect(koreanFuzzy.matches('오늘의 마음열기', textBloom: textBloom), isTrue);
    });

    test('handles empty queries and >31 char queries safely', () {
      final emptyMatcher = BitapHangulMatcher('   ');
      expect(emptyMatcher.isEmpty, isTrue);
      expect(emptyMatcher.matches('아무 글이나'), isTrue);

      final longQuery = List.filled(40, '가').join();
      final longMatcher = BitapHangulMatcher(longQuery, maxErrors: 0);
      expect(longMatcher.patternLength, 31);
      expect(longMatcher.matches('접두 ${List.filled(40, '가').join()} 후미'), isTrue);
      expect(longMatcher.matches(List.filled(20, '가').join()), isFalse);
    });
  });

  group('BoundedKeyRingSet', () {
    test('evicts oldest keys in ring order at fixed capacity', () {
      final set = BoundedKeyRingSet<String>(capacity: 3);

      expect(set.add('a'), isTrue);
      expect(set.add('b'), isTrue);
      expect(set.add('b'), isFalse);
      expect(set.add('c'), isTrue);
      expect(set.length, 3);
      expect(set.contains('a'), isTrue);

      expect(set.add('d'), isTrue);
      expect(set.length, 3);
      expect(set.contains('a'), isFalse);
      expect(set.contains('b'), isTrue);
      expect(set.contains('c'), isTrue);
      expect(set.contains('d'), isTrue);

      set.clear();
      expect(set.isEmpty, isTrue);
      expect(set.length, 0);
    });
  });
}

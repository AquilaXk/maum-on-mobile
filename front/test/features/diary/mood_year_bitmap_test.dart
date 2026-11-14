import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/diary/domain/mood_year_bitmap.dart';

void main() {
  group('MoodYearBitmap', () {
    test('uses exactly 288 bytes across Uint32List buffers', () {
      final bitmap = MoodYearBitmap(2026);
      expect(MoodYearBitmap.totalBytes, 288);
      expect(bitmap.byteLength, 288);
      expect(bitmap.presenceBits.length, 12);
      expect(bitmap.mood3Bits.length, 36);
      expect(bitmap.count2Bits.length, 24);
    });

    test('packs and queries presence, mood scores, and clamped counts in O(1)',
        () {
      final bitmap = MoodYearBitmap(2024); // leap year (366 days)
      final jan1 = DateTime(2024, 1, 1);
      final crossWordDay = DateTime(2024, 2, 11); // dayIndex = 41 -> bitOffset = 123 (shift 27) and 126
      final boundaryDay = DateTime(2024, 4, 5); // test shift > 29 boundary
      final dec31 = DateTime(2024, 12, 31); // dayIndex = 365

      bitmap.recordDay(jan1, moodScore: 1);
      bitmap.recordDay(jan1, moodScore: 5); // keeps first mood score, bumps count
      bitmap.recordDay(jan1, moodScore: 2);
      bitmap.recordDay(jan1);
      bitmap.recordDay(crossWordDay, moodScore: 4);
      bitmap.recordDay(boundaryDay, moodScore: 5);
      bitmap.recordDay(dec31, moodScore: 3);

      expect(bitmap.hasEntry(jan1), isTrue);
      expect(bitmap.moodScore(jan1), 1);
      expect(bitmap.entryCount(jan1), 3); // 4 entries clamped to 3

      expect(bitmap.hasEntry(crossWordDay), isTrue);
      expect(bitmap.moodScore(crossWordDay), 4);
      expect(bitmap.entryCount(crossWordDay), 1);

      expect(bitmap.hasEntry(boundaryDay), isTrue);
      expect(bitmap.moodScore(boundaryDay), 5);

      expect(bitmap.hasEntry(dec31), isTrue);
      expect(bitmap.moodScore(dec31), 3);
      expect(bitmap.entryCount(dec31), 1);

      // Verify word-boundary shift=30 and shift=31 dayIndexes (day 10 => bitOffset 30, day 21 => bitOffset 63)
      bitmap.recordDayIndex(10, moodScore: 2);
      bitmap.recordDayIndex(21, moodScore: 5);
      bitmap.recordDayIndex(31, moodScore: 4);
      bitmap.recordDayIndex(32, moodScore: 1);
      expect(bitmap.moodScoreAt(10), 2);
      expect(bitmap.moodScoreAt(21), 5);
      expect(bitmap.moodScoreAt(31), 4);
      expect(bitmap.moodScoreAt(32), 1);

      expect(bitmap.hasEntry(DateTime(2024, 6, 1)), isFalse);
      expect(bitmap.moodScore(DateTime(2024, 6, 1)), isNull);
      expect(bitmap.entryCount(DateTime(2024, 6, 1)), 0);
    });

    test('computes bitwise currentStreak, longestStreak, and moodDistribution across word boundaries',
        () {
      final bitmap = MoodYearBitmap(2026);
      // 35 consecutive days starting from day 20 (crosses 32-bit boundary at day 31->32 and fills a whole word/part)
      for (var d = 20; d < 55; d += 1) {
        bitmap.recordDayIndex(d, moodScore: (d % 5) + 1);
      }
      // Gap at day 55..59, then 4 days ending on March 5 (dayIndex = 31 + 28 + 5 - 1 = 63, spans word 1->2 boundary)
      for (var d = 61; d <= 65; d += 1) {
        bitmap.recordDayIndex(d, moodScore: 5);
      }

      expect(bitmap.currentStreakAt(65), 5);
      expect(bitmap.currentStreakAt(66), 0);
      expect(bitmap.currentStreakAt(66, includeYesterdayGrace: true), 5);
      expect(bitmap.longestStreak(), 35);

      final distribution = bitmap.moodDistribution();
      expect(distribution[1], 7);
      expect(distribution[2], 7);
      expect(distribution[3], 7);
      expect(distribution[4], 7);
      expect(distribution[5], 12);
    });

    test('packs calendar keys consistently and avoids String DateTime parsing allocations',
        () {
      expect(
        packDateKey(2026, 5, 20),
        packDateTimeKey(DateTime(2026, 5, 20)),
      );
      expect(
        tryPackDateKeyString('2026-05-20T09:15:30Z'),
        packDateKey(2026, 5, 20),
      );
      expect(tryPackDateKeyString('invalid-date'), isNull);
      expect(tryPackDateKeyString('2026-02-30T00:00:00'), isNull);
      expect(tryPackDateKeyString('2024-02-29T00:00:00'), packDateKey(2024, 2, 29));
    });
  });
}

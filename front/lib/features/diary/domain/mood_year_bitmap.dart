// SPDX-License-Identifier: MIT AND BSD-3-Clause
//
// Bit-packed annual diary & mood index inspired by:
// - devappmin/flutter_heatmap_calendar (MIT, https://github.com/devappmin/flutter_heatmap_calendar)
// - hashirshoaeb/star_book (MIT, https://github.com/hashirshoaeb/star_book)
// - contribution_heatmap (BSD-3-Clause, https://pub.dev/packages/contribution_heatmap)

import 'dart:typed_data';

const List<int> _cumDaysBeforeMonth = <int>[
  0,
  0,
  31,
  59,
  90,
  120,
  151,
  181,
  212,
  243,
  273,
  304,
  334,
];

const List<int> _monthDays = <int>[
  0,
  31,
  28,
  31,
  30,
  31,
  30,
  31,
  31,
  30,
  31,
  30,
  31,
];

/// Returns `true` if [year] is a Gregorian leap year.
bool isLeapYear(int year) {
  return (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
}

/// Packs `(year, month, day)` into a compact non-negative 31-bit integer key:
/// `(year << 9) | (month << 5) | day`.
int packDateKey(int year, int month, int day) {
  return (year << 9) | ((month & 0xF) << 5) | (day & 0x1F);
}

/// Packs a [DateTime] into a compact calendar-date integer key.
int packDateTimeKey(DateTime date) {
  return packDateKey(date.year, date.month, date.day);
}

/// Parses an ISO date prefix (`YYYY-MM-DD...`) into a packed integer key
/// without allocating a [DateTime], returning `null` if invalid.
int? tryPackDateKeyString(String rawDate) {
  if (rawDate.length < 10) {
    return null;
  }
  if (rawDate.codeUnitAt(4) != 45 || rawDate.codeUnitAt(7) != 45) {
    return null;
  }
  final year = _parseAsciiDigits(rawDate, 0, 4);
  final month = _parseAsciiDigits(rawDate, 5, 7);
  final day = _parseAsciiDigits(rawDate, 8, 10);
  if (year == null ||
      month == null ||
      day == null ||
      month < 1 ||
      month > 12 ||
      day < 1) {
    return null;
  }
  final maxDay =
      month == 2 && isLeapYear(year) ? 29 : _monthDays[month];
  if (day > maxDay) {
    return null;
  }
  return packDateKey(year, month, day);
}

int? _parseAsciiDigits(String text, int start, int end) {
  var value = 0;
  for (var i = start; i < end; i += 1) {
    final digit = text.codeUnitAt(i) - 48;
    if (digit < 0 || digit > 9) {
      return null;
    }
    value = value * 10 + digit;
  }
  return value;
}

/// Computes DST-immune zero-based day-of-year index (`0..365`).
int dayOfYearIndex(int year, int month, int day) {
  var index = _cumDaysBeforeMonth[month] + day - 1;
  if (month > 2 && isLeapYear(year)) {
    index += 1;
  }
  return index;
}

int daysInCalendarYear(int year) => isLeapYear(year) ? 366 : 365;

/// Fixed 288-byte bit-packed calendar index for up to 366 days of one year.
///
/// Storage layout (`Uint32List`, 72 words = 288 bytes):
/// - `presenceBits` (12 words = 48 bytes): 1 bit/day presence flag.
/// - `mood3Bits` (36 words = 144 bytes): 3 bits/day mood score (`0` = unset, `1..5`).
/// - `count2Bits` (24 words = 96 bytes): 2 bits/day entry density (`0..3`, clamped).
final class MoodYearBitmap {
  MoodYearBitmap(this.year)
      : _yearDays = daysInCalendarYear(year),
        presenceBits = Uint32List(presenceWordCount),
        mood3Bits = Uint32List(moodWordCount),
        count2Bits = Uint32List(countWordCount);

  static const int presenceWordCount = 12;
  static const int moodWordCount = 36;
  static const int countWordCount = 24;
  static const int totalBytes =
      (presenceWordCount + moodWordCount + countWordCount) * 4; // 288 bytes

  final int year;
  final int _yearDays;
  final Uint32List presenceBits;
  final Uint32List mood3Bits;
  final Uint32List count2Bits;

  int get byteLength =>
      presenceBits.lengthInBytes +
      mood3Bits.lengthInBytes +
      count2Bits.lengthInBytes;

  void recordDay(
    DateTime date, {
    int? moodScore,
    int count = 1,
  }) {
    if (date.year != year || count <= 0) {
      return;
    }
    recordDayIndex(
      dayOfYearIndex(date.year, date.month, date.day),
      moodScore: moodScore,
      countDelta: count,
    );
  }

  void recordDayIndex(
    int dayIndex, {
    int? moodScore,
    int countDelta = 1,
  }) {
    if (dayIndex < 0 || dayIndex >= _yearDays || countDelta <= 0) {
      return;
    }

    final presenceWord = dayIndex >> 5;
    final presenceShift = dayIndex & 31;
    presenceBits[presenceWord] = presenceBits[presenceWord] | (1 << presenceShift);

    final countWord = dayIndex >> 4;
    final countShift = (dayIndex & 15) << 1;
    final currentCount = (count2Bits[countWord] >>> countShift) & 3;
    final nextCount = currentCount + countDelta;
    final clampedCount = nextCount > 3 ? 3 : nextCount;
    count2Bits[countWord] =
        (count2Bits[countWord] & ~(3 << countShift)) |
        (clampedCount << countShift);

    if (moodScore != null && moodScore >= 1 && moodScore <= 5) {
      final existingMood = moodScoreAt(dayIndex);
      if (existingMood == null) {
        _writeMood3Bits(dayIndex, moodScore);
      }
    }
  }

  void _writeMood3Bits(int dayIndex, int moodScore) {
    final bitOffset = dayIndex * 3;
    final wordIdx = bitOffset >> 5;
    final shift = bitOffset & 31;
    final clampedMood = moodScore & 7;
    mood3Bits[wordIdx] =
        (mood3Bits[wordIdx] & ~(7 << shift)) | (clampedMood << shift);
    if (shift > 29) {
      final spill = 32 - shift;
      final nextMask = 7 >>> spill;
      mood3Bits[wordIdx + 1] =
          (mood3Bits[wordIdx + 1] & ~nextMask) | (clampedMood >>> spill);
    }
  }

  bool hasEntry(DateTime date) {
    if (date.year != year) {
      return false;
    }
    return hasEntryAt(dayOfYearIndex(date.year, date.month, date.day));
  }

  bool hasEntryAt(int dayIndex) {
    if (dayIndex < 0 || dayIndex >= _yearDays) {
      return false;
    }
    return ((presenceBits[dayIndex >> 5] >>> (dayIndex & 31)) & 1) != 0;
  }

  int? moodScore(DateTime date) {
    if (date.year != year) {
      return null;
    }
    return moodScoreAt(dayOfYearIndex(date.year, date.month, date.day));
  }

  int? moodScoreAt(int dayIndex) {
    if (dayIndex < 0 || dayIndex >= _yearDays) {
      return null;
    }
    final bitOffset = dayIndex * 3;
    final wordIdx = bitOffset >> 5;
    final shift = bitOffset & 31;
    var value = (mood3Bits[wordIdx] >>> shift) & 7;
    if (shift > 29) {
      final spill = 32 - shift;
      value = (value | (mood3Bits[wordIdx + 1] << spill)) & 7;
    }
    return value == 0 ? null : value;
  }

  int entryCount(DateTime date) {
    if (date.year != year) {
      return 0;
    }
    return entryCountAt(dayOfYearIndex(date.year, date.month, date.day));
  }

  int entryCountAt(int dayIndex) {
    if (dayIndex < 0 || dayIndex >= _yearDays) {
      return 0;
    }
    final countWord = dayIndex >> 4;
    final countShift = (dayIndex & 15) << 1;
    return (count2Bits[countWord] >>> countShift) & 3;
  }

  /// Counts consecutive recorded days ending strictly on [today] using
  /// word-level bitwise shifts across [presenceBits].
  int currentStreak(DateTime today) {
    if (today.year != year) {
      return 0;
    }
    final endIndex = dayOfYearIndex(today.year, today.month, today.day);
    return currentStreakAt(endIndex);
  }

  /// Counts consecutive recorded days ending strictly at [endIndex], or up to
  /// `endIndex - 1` when [includeYesterdayGrace] is `true` and [endIndex] has
  /// no entry yet.
  int currentStreakAt(
    int endIndex, {
    bool includeYesterdayGrace = false,
  }) {
    if (endIndex < 0 || endIndex >= _yearDays) {
      return 0;
    }

    var cursor = endIndex;
    if (!hasEntryAt(cursor)) {
      if (!includeYesterdayGrace || cursor == 0 || !hasEntryAt(cursor - 1)) {
        return 0;
      }
      cursor -= 1;
    }

    var wordIdx = cursor >> 5;
    final bitPos = cursor & 31;
    // Shift left so `bitPos` moves to bit 31, then fill nothing below; invert
    // to find highest zero via bit scan from MSB down using shifts.
    var aligned = presenceBits[wordIdx] << (31 - bitPos);
    var streak = 0;

    while (true) {
      // Count consecutive 1-bits downward from bit 31 using unsigned shifts.
      var wordStreak = 0;
      while ((aligned & 0x80000000) != 0) {
        wordStreak += 1;
        aligned = aligned << 1;
      }
      final availableBits = wordIdx == (cursor >> 5) ? bitPos + 1 : 32;
      if (wordStreak >= availableBits) {
        streak += availableBits;
        wordIdx -= 1;
        if (wordIdx < 0) {
          break;
        }
        if (presenceBits[wordIdx] == 0xFFFFFFFF) {
          streak += 32;
          wordIdx -= 1;
          if (wordIdx < 0) {
            break;
          }
        }
        aligned = presenceBits[wordIdx];
        continue;
      }
      streak += wordStreak;
      break;
    }
    return streak;
  }

  /// Computes the longest consecutive recorded day run in this year via
  /// bitwise word scanning over [presenceBits].
  int longestStreak() {
    var best = 0;
    var current = 0;
    for (var w = 0; w < presenceWordCount; w += 1) {
      var word = presenceBits[w];
      if (word == 0) {
        current = 0;
        continue;
      }
      final validBits =
          (w == presenceWordCount - 1) ? (_yearDays - (w << 5)) : 32;
      if (validBits == 32 && word == 0xFFFFFFFF) {
        current += 32;
        if (current > best) {
          best = current;
        }
        continue;
      }
      for (var bit = 0; bit < validBits; bit += 1) {
        if ((word & 1) != 0) {
          current += 1;
          if (current > best) {
            best = current;
          }
        } else {
          current = 0;
        }
        word = word >>> 1;
      }
    }
    return best;
  }

  /// Returns counts of days with each mood score (`1..5`).
  Map<int, int> moodDistribution() {
    var m1 = 0;
    var m2 = 0;
    var m3 = 0;
    var m4 = 0;
    var m5 = 0;

    for (var day = 0; day < _yearDays; day += 1) {
      if (!hasEntryAt(day)) {
        continue;
      }
      switch (moodScoreAt(day)) {
        case 1:
          m1 += 1;
        case 2:
          m2 += 1;
        case 3:
          m3 += 1;
        case 4:
          m4 += 1;
        case 5:
          m5 += 1;
      }
    }

    return <int, int>{
      1: m1,
      2: m2,
      3: m3,
      4: m4,
      5: m5,
    };
  }
}

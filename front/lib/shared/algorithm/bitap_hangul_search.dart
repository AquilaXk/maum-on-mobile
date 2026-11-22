// First-party clean-room implementation.
//
// Standard Baeza-Yates & Gonnet (1992) Shift-And Bitap 31-bit bit-parallel
// approximate string matching paired with Unicode U+AC00..U+D7A3 Hangul
// arithmetic syllable decomposition and Choseong extraction.

import 'dart:typed_data';

const int _mask31 = 0x7FFFFFFF;
const int _hangulSyllableBase = 0xAC00;
const int _hangulSyllableEnd = 0xD7A3;
const int _hangulSyllablesPerChoseong = 588; // 21 Jungseong * 28 Jongseong
const int _compatJamoBase = 0x3131;
const int _compatJamoEnd = 0x314E;
const int _choseongCount = 19;
const int _asciiTableSize = 128;

// Compatibility Jamo (U+3131..U+314E) to Choseong index (0..18), or -1 for
// cluster/final-only consonants.
const List<int> _compatToChoseong = <int>[
  0, // U+3131 ㄱ
  1, // U+3132 ㄲ
  -1, // U+3133 ㄳ
  2, // U+3134 ㄴ
  -1, // U+3135 ㄵ
  -1, // U+3136 ㄶ
  3, // U+3137 ㄷ
  4, // U+3138 ㄸ
  5, // U+3139 ㄹ
  -1, // U+313A ㄺ
  -1, // U+313B ㄻ
  -1, // U+313C ㄼ
  -1, // U+313D ㄽ
  -1, // U+313E ㄾ
  -1, // U+313F ㄿ
  -1, // U+3140 ㅀ
  6, // U+3141 ㅁ
  7, // U+3142 ㅂ
  8, // U+3143 ㅃ
  -1, // U+3144 ㅄ
  9, // U+3145 ㅅ
  10, // U+3146 ㅆ
  11, // U+3147 ㅇ
  12, // U+3148 ㅈ
  13, // U+3149 ㅉ
  14, // U+314A ㅊ
  15, // U+314B ㅋ
  16, // U+314C ㅌ
  17, // U+314D ㅍ
  18, // U+314E ㅎ
];

const List<int> _choseongCodeUnits = <int>[
  0x3131, // ㄱ
  0x3132, // ㄲ
  0x3134, // ㄴ
  0x3137, // ㄷ
  0x3138, // ㄸ
  0x3139, // ㄹ
  0x3141, // ㅁ
  0x3142, // ㅂ
  0x3143, // ㅃ
  0x3145, // ㅅ
  0x3146, // ㅆ
  0x3147, // ㅇ
  0x3148, // ㅈ
  0x3149, // ㅉ
  0x314A, // ㅊ
  0x314B, // ㅋ
  0x314C, // ㅌ
  0x314D, // ㅍ
  0x314E, // ㅎ
];

/// Returns the Hangul Choseong index (`0..18`) for a syllable or compatibility
/// Choseong code unit, or `-1` if [codeUnit] is not a Hangul Choseong/syllable.
int extractHangulChoseongIndex(int codeUnit) {
  if (codeUnit >= _hangulSyllableBase && codeUnit <= _hangulSyllableEnd) {
    return (codeUnit - _hangulSyllableBase) ~/ _hangulSyllablesPerChoseong;
  }
  if (codeUnit >= _compatJamoBase && codeUnit <= _compatJamoEnd) {
    return _compatToChoseong[codeUnit - _compatJamoBase];
  }
  return -1;
}

/// Extracts Hangul Choseong characters while passing non-Hangul characters through.
String extractHangulChoseong(String text) {
  if (text.isEmpty) {
    return text;
  }
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    final cu = text.codeUnitAt(i);
    if (cu >= _hangulSyllableBase && cu <= _hangulSyllableEnd) {
      final index = (cu - _hangulSyllableBase) ~/ _hangulSyllablesPerChoseong;
      buffer.writeCharCode(_choseongCodeUnits[index]);
    } else if (cu >= 65 && cu <= 90) {
      buffer.writeCharCode(cu + 32);
    } else {
      buffer.writeCharCode(cu);
    }
  }
  return buffer.toString();
}

int _normalizeCodeUnit(int codeUnit) {
  if (codeUnit >= 65 && codeUnit <= 90) {
    return codeUnit + 32;
  }
  return codeUnit;
}

/// Computes a web-safe 31-bit Bloom signature (`0..0x7FFFFFFF`) in a single
/// code-unit pass.
///
/// Full Hangul syllables and standalone Hangul Choseong characters fold into the
/// same Choseong bit positions so `(itemBloom & queryBloom) != queryBloom`
/// rejects non-matching items in one bitwise instruction without false
/// negatives on Choseong queries.
int computeTextBloom31(String text) {
  var signature = 0;
  final length = text.length;
  for (var i = 0; i < length; i += 1) {
    final cu = _normalizeCodeUnit(text.codeUnitAt(i));
    if (cu <= 32) {
      continue;
    }
    final choIndex = extractHangulChoseongIndex(cu);
    final bitIndex = choIndex >= 0 ? choIndex : (cu % 31);
    signature |= 1 << bitIndex;
  }
  return signature & _mask31;
}

/// SWAR popcount over a 31-bit non-negative integer (`0..0x7FFFFFFF`).
int popcount31(int value) {
  var x = value & _mask31;
  x = x - ((x >>> 1) & 0x55555555);
  x = (x & 0x33333333) + ((x >>> 2) & 0x33333333);
  x = (x + (x >>> 4)) & 0x0F0F0F0F;
  x = x + (x >>> 8);
  x = x + (x >>> 16);
  return x & 0x3F;
}

/// Compiled 31-bit Bitap matcher supporting exact substring search, Hangul
/// Choseong matching, and 1-edit-distance approximate matching.
final class BitapHangulMatcher {
  BitapHangulMatcher._({
    required this.normalizedQuery,
    required this.queryBloom,
    required this.patternLength,
    required this.effectiveMaxErrors,
    required Uint32List asciiMask,
    required Map<int, int> extraMask,
    required Uint32List choseongMask,
    required int patternMask,
    required int acceptMask,
  })  : _asciiMask = asciiMask,
        _extraMask = extraMask,
        _choseongMask = choseongMask,
        _patternMask = patternMask,
        _acceptMask = acceptMask;

  /// Compiles [rawQuery] into bit-parallel masks (`<= 31` units).
  factory BitapHangulMatcher(
    String rawQuery, {
    int maxErrors = 1,
  }) {
    final normalized = _normalizeQueryString(rawQuery);
    if (normalized.isEmpty) {
      return BitapHangulMatcher._(
        normalizedQuery: '',
        queryBloom: 0,
        patternLength: 0,
        effectiveMaxErrors: 0,
        asciiMask: Uint32List(_asciiTableSize),
        extraMask: const {},
        choseongMask: Uint32List(_choseongCount),
        patternMask: 0,
        acceptMask: 0,
      );
    }

    final patternLen = normalized.length > 31 ? 31 : normalized.length;
    final asciiMask = Uint32List(_asciiTableSize);
    final choseongMask = Uint32List(_choseongCount);
    final extraMask = <int, int>{};

    for (var i = 0; i < patternLen; i += 1) {
      final cu = normalized.codeUnitAt(i);
      final bit = 1 << i;
      if (cu >= _compatJamoBase && cu <= _compatJamoEnd) {
        final cho = _compatToChoseong[cu - _compatJamoBase];
        if (cho >= 0) {
          choseongMask[cho] = (choseongMask[cho] | bit) & _mask31;
        }
      }
      if (cu < _asciiTableSize) {
        asciiMask[cu] = (asciiMask[cu] | bit) & _mask31;
      } else {
        extraMask[cu] = ((extraMask[cu] ?? 0) | bit) & _mask31;
      }
    }

    final patternMask =
        patternLen == 31 ? _mask31 : ((1 << patternLen) - 1) & _mask31;
    final acceptMask = 1 << (patternLen - 1);
    final effectiveErrors =
        (patternLen >= 3 && maxErrors > 0) ? 1 : 0;

    return BitapHangulMatcher._(
      normalizedQuery: normalized,
      queryBloom: computeTextBloom31(normalized),
      patternLength: patternLen,
      effectiveMaxErrors: effectiveErrors,
      asciiMask: asciiMask,
      extraMask: extraMask,
      choseongMask: choseongMask,
      patternMask: patternMask,
      acceptMask: acceptMask,
    );
  }

  final String normalizedQuery;
  final int queryBloom;
  final int patternLength;
  final int effectiveMaxErrors;
  final Uint32List _asciiMask;
  final Map<int, int> _extraMask;
  final Uint32List _choseongMask;
  final int _patternMask;
  final int _acceptMask;

  bool get isEmpty => patternLength == 0;

  /// Fast O(1) Bloom prefilter check using a precomputed [textBloom].
  ///
  /// Returns `false` when [textBloom] guarantees [text] cannot match under the
  /// configured [effectiveMaxErrors].
  bool mayMatchBloom(int textBloom) {
    if (isEmpty) {
      return true;
    }
    if (effectiveMaxErrors == 0) {
      return (textBloom & queryBloom) == queryBloom;
    }
    return popcount31(queryBloom & ~textBloom) <= effectiveMaxErrors;
  }

  /// Returns whether [text] matches the compiled query.
  ///
  /// When [textBloom] is supplied, non-matching candidates are rejected via
  /// single-instruction bitwise filtering before scanning code units.
  bool matches(String text, {int? textBloom}) {
    if (isEmpty) {
      return true;
    }
    if (text.isEmpty) {
      return false;
    }
    if (textBloom != null && !mayMatchBloom(textBloom)) {
      return false;
    }
    return matchDistance(text) >= 0;
  }

  /// Returns `0` for an exact/Choseong match, `1` for a 1-edit approximate
  /// match (when enabled), or `-1` when [text] does not match.
  int matchDistance(String text) {
    if (isEmpty) {
      return 0;
    }
    if (text.isEmpty) {
      return -1;
    }

    if (effectiveMaxErrors == 0 && normalizedQuery.length > 31) {
      if (_normalizeQueryString(text).contains(normalizedQuery)) {
        return 0;
      }
      return extractHangulChoseong(text).contains(normalizedQuery) ? 0 : -1;
    }

    var r0 = 0;
    var r1 = effectiveMaxErrors > 0 ? 1 : 0;
    var foundApprox = false;

    final length = text.length;
    for (var i = 0; i < length; i += 1) {
      final rawCu = text.codeUnitAt(i);
      final cu = (rawCu >= 65 && rawCu <= 90) ? rawCu + 32 : rawCu;

      var charMask = cu < _asciiTableSize
          ? _asciiMask[cu]
          : (_extraMask[cu] ?? 0);
      if (cu >= _hangulSyllableBase && cu <= _hangulSyllableEnd) {
        final cho = (cu - _hangulSyllableBase) ~/ _hangulSyllablesPerChoseong;
        charMask |= _choseongMask[cho];
      }

      final prevR0 = r0;
      r0 = (((prevR0 << 1) | 1) & charMask) & _patternMask;
      if ((r0 & _acceptMask) != 0) {
        return 0;
      }

      if (effectiveMaxErrors > 0) {
        final prevR1 = r1;
        final matchedR1 = (((prevR1 << 1) | 1) & charMask) & _patternMask;
        final substitute = ((prevR0 << 1) | 1) & _patternMask;
        final delete = (r0 << 1) & _patternMask;
        final insert = prevR0;
        r1 = (matchedR1 | substitute | delete | insert) & _patternMask;
        if ((r1 & _acceptMask) != 0) {
          foundApprox = true;
        }
      }
    }

    return foundApprox ? 1 : -1;
  }
}

String _normalizeQueryString(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final length = trimmed.length;
  for (var i = 0; i < length; i += 1) {
    final cu = trimmed.codeUnitAt(i);
    if (cu >= 65 && cu <= 90) {
      final buffer = StringBuffer();
      if (i > 0) {
        buffer.write(trimmed.substring(0, i));
      }
      buffer.writeCharCode(cu + 32);
      for (var j = i + 1; j < length; j += 1) {
        final inner = trimmed.codeUnitAt(j);
        buffer.writeCharCode((inner >= 65 && inner <= 90) ? inner + 32 : inner);
      }
      return buffer.toString();
    }
  }
  return trimmed;
}

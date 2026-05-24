enum DiaryCategory {
  love(label: '연애'),
  friend(label: '친구'),
  career(label: '진로'),
  family(label: '가족'),
  work(label: '직장'),
  daily(label: '일상'),
  etc(label: '기타');

  const DiaryCategory({required this.label});

  final String label;

  static DiaryCategory fromApiValue(Object? value) {
    final text = value?.toString();
    for (final category in DiaryCategory.values) {
      if (category.label == text) {
        return category;
      }
    }

    return DiaryCategory.etc;
  }
}

class DiaryImageAttachment {
  const DiaryImageAttachment({
    required this.filename,
    required this.bytes,
  });

  final String filename;
  final List<int> bytes;
}

class DiaryDraft {
  const DiaryDraft({
    required this.title,
    required this.content,
    required this.category,
    required this.isPrivate,
    this.imageUrl,
    this.image,
  });

  final String title;
  final String content;
  final DiaryCategory category;
  final bool isPrivate;
  final String? imageUrl;
  final DiaryImageAttachment? image;
}

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.nickname,
    required this.imageUrl,
    required this.isPrivate,
    required this.createDate,
    required this.modifyDate,
  });

  factory DiaryEntry.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected diary object.');
    }

    final map = _stringKeyedMap(json);
    return DiaryEntry(
      id: _readInt(map, 'id'),
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      category: DiaryCategory.fromApiValue(map['categoryName']),
      nickname: _readNickname(map['nickname']),
      imageUrl: _readNullableString(map['imageUrl']),
      isPrivate: map['isPrivate'] == true,
      createDate: map['createDate']?.toString() ?? '',
      modifyDate: map['modifyDate']?.toString() ?? '',
    );
  }

  final int id;
  final String title;
  final String content;
  final DiaryCategory category;
  final String nickname;
  final String? imageUrl;
  final bool isPrivate;
  final String createDate;
  final String modifyDate;

  String get dateKey => dateKeyFromDateTime(createDate);

  DiaryEntry copyWith({
    String? title,
    String? content,
    DiaryCategory? category,
    String? nickname,
    String? imageUrl,
    bool clearImageUrl = false,
    bool? isPrivate,
    String? createDate,
    String? modifyDate,
  }) {
    return DiaryEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      nickname: nickname ?? this.nickname,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      createDate: createDate ?? this.createDate,
      modifyDate: modifyDate ?? this.modifyDate,
    );
  }
}

class DiaryFetchRequest {
  const DiaryFetchRequest({
    required this.page,
    required this.size,
  });

  final int page;
  final int size;

  @override
  bool operator ==(Object other) {
    return other is DiaryFetchRequest &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(page, size);
}

String dateKeyFromDateTime(String dateTime) {
  if (dateTime.length >= 10) {
    return dateTime.substring(0, 10);
  }

  return '';
}

String monthKeyFromDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

String dateKeyFromDate(DateTime date) {
  return '${monthKeyFromDate(date)}-${date.day.toString().padLeft(2, '0')}';
}

DateTime firstDayOfMonth(DateTime date) {
  return DateTime(date.year, date.month);
}

DateTime addMonths(DateTime date, int delta) {
  return DateTime(date.year, date.month + delta);
}

List<DateTime> daysInMonth(DateTime month) {
  final firstDay = firstDayOfMonth(month);
  final nextMonth = addMonths(firstDay, 1);
  final count = nextMonth.difference(firstDay).inDays;

  return [
    for (var day = 1; day <= count; day += 1)
      DateTime(month.year, month.month, day),
  ];
}

String _readNickname(Object? value) {
  final nickname = value?.toString().trim() ?? '';
  return nickname.isEmpty ? '익명' : nickname;
}

String? _readNullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _readInt(Map<String, Object?> map, String key) {
  final value = map[key];

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

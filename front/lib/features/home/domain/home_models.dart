enum HomeStoryCategory {
  all(label: '전체', apiValue: null),
  worry(label: '고민', apiValue: 'WORRY'),
  daily(label: '일상', apiValue: 'DAILY'),
  question(label: '질문', apiValue: 'QUESTION');

  const HomeStoryCategory({
    required this.label,
    required this.apiValue,
  });

  final String label;
  final String? apiValue;

  static HomeStoryCategory fromApiValue(Object? value) {
    return switch (value?.toString()) {
      'DAILY' => HomeStoryCategory.daily,
      'QUESTION' => HomeStoryCategory.question,
      'WORRY' || _ => HomeStoryCategory.worry,
    };
  }
}

class HomeStats {
  const HomeStats({
    required this.todayWorryCount,
    required this.todayLetterCount,
    required this.todayDiaryCount,
  });

  factory HomeStats.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected home stats object.');
    }

    final map = _stringKeyedMap(json);
    return HomeStats(
      todayWorryCount: _readInt(map, 'todayWorryCount'),
      todayLetterCount: _readInt(map, 'todayLetterCount'),
      todayDiaryCount: _readInt(map, 'todayDiaryCount'),
    );
  }

  final int todayWorryCount;
  final int todayLetterCount;
  final int todayDiaryCount;
}

class HomeStory {
  const HomeStory({
    required this.id,
    required this.title,
    required this.summary,
    required this.authorNickname,
    required this.category,
    required this.createdAt,
    required this.viewCount,
  });

  factory HomeStory.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected home story object.');
    }

    final map = _stringKeyedMap(json);
    return HomeStory(
      id: _readInt(map, 'id'),
      title: map['title']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
      authorNickname: _readNickname(map['nickname']),
      category: HomeStoryCategory.fromApiValue(map['category']),
      createdAt: map['createDate']?.toString() ?? '',
      viewCount: _readInt(map, 'viewCount'),
    );
  }

  final int id;
  final String title;
  final String summary;
  final String authorNickname;
  final HomeStoryCategory category;
  final String createdAt;
  final int viewCount;
}

class HomeStoryPage {
  const HomeStoryPage({
    required this.items,
    required this.last,
  });

  factory HomeStoryPage.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected story page object.');
    }

    final map = _stringKeyedMap(json);
    final rawItems = map['content'] ?? map['items'];

    if (rawItems is! List) {
      throw const FormatException('Expected story page items.');
    }

    return HomeStoryPage(
      items: rawItems.map(HomeStory.fromJson).toList(growable: false),
      last: map['last'] == true,
    );
  }

  final List<HomeStory> items;
  final bool last;
}

String _readNickname(Object? value) {
  final nickname = value?.toString().trim() ?? '';
  return nickname.isEmpty ? '익명' : nickname;
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

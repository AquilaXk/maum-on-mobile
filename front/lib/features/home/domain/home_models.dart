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
      'WORRY' => HomeStoryCategory.worry,
      _ => throw FormatException('Unknown home story category: $value'),
    };
  }
}

enum HomeActionSurface {
  diary(label: '마음 기록', actionLabel: '기록 이어가기'),
  story(label: '스토리', actionLabel: '스토리 이어가기'),
  letter(label: '비밀 편지', actionLabel: '편지 이어가기'),
  consultation(label: 'AI 상담', actionLabel: 'AI 상담 이어가기');

  const HomeActionSurface({
    required this.label,
    required this.actionLabel,
  });

  final String label;
  final String actionLabel;

  static HomeActionSurface fromApiValue(Object? value) {
    return switch (value?.toString().toLowerCase()) {
      'story' => HomeActionSurface.story,
      'letter' => HomeActionSurface.letter,
      'consultation' => HomeActionSurface.consultation,
      _ => HomeActionSurface.diary,
    };
  }
}

class HomeStats {
  const HomeStats({
    required this.todayWorryCount,
    required this.todayLetterCount,
    required this.todayDiaryCount,
    this.summary = const HomeSummary(),
    this.categorySummaries = const [],
    this.popularStories = const [],
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
      summary: HomeSummary.fromJson(map['summary']),
      categorySummaries: _readList(map['categorySummaries'])
          .map(HomeCategorySummary.fromJson)
          .toList(growable: false),
      popularStories: _readList(map['popularStories'])
          .map(HomePopularStory.fromJson)
          .toList(growable: false),
    );
  }

  final int todayWorryCount;
  final int todayLetterCount;
  final int todayDiaryCount;
  final HomeSummary summary;
  final List<HomeCategorySummary> categorySummaries;
  final List<HomePopularStory> popularStories;
}

class HomeSummary {
  const HomeSummary({
    this.recoveryMessage = '조금 느려도 괜찮아요. 오늘의 마음을 하나씩 살펴보세요.',
    this.primaryActionLabel = '오늘 마음 기록하기',
    this.primaryActionSurface = HomeActionSurface.diary,
    this.feedMessage = '',
  });

  factory HomeSummary.fromJson(Object? json) {
    if (json == null) {
      return const HomeSummary();
    }
    if (json is! Map) {
      throw const FormatException('Expected home summary object.');
    }

    final map = _stringKeyedMap(json);
    return HomeSummary(
      recoveryMessage: _readString(
        map,
        'recoveryMessage',
        fallback: '조금 느려도 괜찮아요. 오늘의 마음을 하나씩 살펴보세요.',
      ),
      primaryActionLabel: _readString(
        map,
        'primaryActionLabel',
        fallback: '오늘 마음 기록하기',
      ),
      primaryActionSurface: HomeActionSurface.fromApiValue(
        map['primaryActionSurface'],
      ),
      feedMessage: _readString(map, 'feedMessage'),
    );
  }

  final String recoveryMessage;
  final String primaryActionLabel;
  final HomeActionSurface primaryActionSurface;
  final String feedMessage;
}

class HomeCategorySummary {
  const HomeCategorySummary({
    required this.category,
    required this.label,
    required this.count,
  });

  factory HomeCategorySummary.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected home category summary object.');
    }

    final map = _stringKeyedMap(json);
    return HomeCategorySummary(
      category: HomeStoryCategory.fromApiValue(map['category']),
      label: _readString(map, 'label'),
      count: _readInt(map, 'count'),
    );
  }

  final HomeStoryCategory category;
  final String label;
  final int count;
}

class HomePopularStory {
  const HomePopularStory({
    required this.id,
    required this.title,
    required this.category,
    required this.label,
    required this.viewCount,
    required this.nickname,
  });

  factory HomePopularStory.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected home popular story object.');
    }

    final map = _stringKeyedMap(json);
    return HomePopularStory(
      id: _readInt(map, 'id'),
      title: _readString(map, 'title'),
      category: HomeStoryCategory.fromApiValue(map['category']),
      label: _readString(map, 'label'),
      viewCount: _readInt(map, 'viewCount'),
      nickname: _readNickname(map['nickname']),
    );
  }

  final int id;
  final String title;
  final HomeStoryCategory category;
  final String label;
  final int viewCount;
  final String nickname;
}

class HomeDraftSummary {
  const HomeDraftSummary({
    required this.surface,
    required this.title,
    required this.preview,
    required this.updatedAt,
    required this.failed,
  });

  final HomeActionSurface surface;
  final String title;
  final String preview;
  final DateTime updatedAt;
  final bool failed;
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

String _readString(
  Map<String, Object?> map,
  String key, {
  String fallback = '',
}) {
  final text = map[key]?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

List<Object?> _readList(Object? value) {
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw const FormatException('Expected list.');
  }
  return value.cast<Object?>();
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

enum StoryCategory {
  all(label: '전체', apiValue: null),
  worry(label: '고민', apiValue: 'WORRY'),
  daily(label: '일상', apiValue: 'DAILY'),
  question(label: '질문', apiValue: 'QUESTION');

  const StoryCategory({
    required this.label,
    required this.apiValue,
  });

  final String label;
  final String? apiValue;

  static StoryCategory fromApiValue(Object? value) {
    return switch (value?.toString()) {
      'WORRY' => StoryCategory.worry,
      'DAILY' => StoryCategory.daily,
      'QUESTION' => StoryCategory.question,
      _ => throw FormatException('Unknown story category: $value'),
    };
  }
}

enum StoryResolutionStatus {
  ongoing(label: '진행 중', apiValue: 'ONGOING'),
  resolved(label: '해결됨', apiValue: 'RESOLVED');

  const StoryResolutionStatus({
    required this.label,
    required this.apiValue,
  });

  final String label;
  final String apiValue;

  StoryResolutionStatus get toggled {
    return this == StoryResolutionStatus.ongoing
        ? StoryResolutionStatus.resolved
        : StoryResolutionStatus.ongoing;
  }

  static StoryResolutionStatus fromApiValue(Object? value) {
    return switch (value?.toString()) {
      'RESOLVED' => StoryResolutionStatus.resolved,
      'ONGOING' => StoryResolutionStatus.ongoing,
      _ => StoryResolutionStatus.ongoing,
    };
  }
}

class StoryDraft {
  const StoryDraft({
    required this.title,
    required this.content,
    required this.category,
    this.thumbnail,
  });

  final String title;
  final String content;
  final StoryCategory category;
  final String? thumbnail;

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'content': content,
      'thumbnail': thumbnail,
      'category': category.apiValue,
    };
  }
}

class StorySummary {
  const StorySummary({
    required this.id,
    required this.title,
    required this.summary,
    required this.authorNickname,
    required this.category,
    required this.resolutionStatus,
    required this.viewCount,
    required this.createDate,
    required this.modifyDate,
    this.thumbnail,
  });

  factory StorySummary.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected story summary object.');
    }

    final map = _stringKeyedMap(json);
    return StorySummary(
      id: _readInt(map, 'id'),
      title: map['title']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
      authorNickname: _readNickname(map['nickname']),
      category: StoryCategory.fromApiValue(map['category']),
      resolutionStatus:
          StoryResolutionStatus.fromApiValue(map['resolutionStatus']),
      viewCount: _readInt(map, 'viewCount'),
      createDate: map['createDate']?.toString() ?? '',
      modifyDate: map['modifyDate']?.toString() ?? '',
      thumbnail: _readNullableString(map['thumbnail']),
    );
  }

  final int id;
  final String title;
  final String summary;
  final String authorNickname;
  final StoryCategory category;
  final StoryResolutionStatus resolutionStatus;
  final int viewCount;
  final String createDate;
  final String modifyDate;
  final String? thumbnail;
}

class StoryDetail {
  const StoryDetail({
    required this.id,
    required this.title,
    required this.content,
    required this.summary,
    required this.authorNickname,
    required this.category,
    required this.resolutionStatus,
    required this.viewCount,
    required this.createDate,
    required this.modifyDate,
    this.thumbnail,
    this.authorId,
  });

  factory StoryDetail.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected story detail object.');
    }

    final map = _stringKeyedMap(json);
    return StoryDetail(
      id: _readInt(map, 'id'),
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
      authorNickname: _readNickname(map['nickname']),
      category: StoryCategory.fromApiValue(map['category']),
      resolutionStatus:
          StoryResolutionStatus.fromApiValue(map['resolutionStatus']),
      viewCount: _readInt(map, 'viewCount'),
      createDate: map['createDate']?.toString() ?? '',
      modifyDate: map['modifyDate']?.toString() ?? '',
      thumbnail: _readNullableString(map['thumbnail']),
      authorId: _readOptionalInt(map, 'authorId') ??
          _readOptionalInt(map, 'authorid') ??
          _readOptionalInt(map, 'memberId'),
    );
  }

  final int id;
  final String title;
  final String content;
  final String summary;
  final String authorNickname;
  final StoryCategory category;
  final StoryResolutionStatus resolutionStatus;
  final int viewCount;
  final String createDate;
  final String modifyDate;
  final String? thumbnail;
  final int? authorId;

  bool canEdit(int memberId) {
    return authorId != null && authorId == memberId;
  }
}

class StoryComment {
  const StoryComment({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorNickname,
    required this.postId,
    required this.createDate,
    required this.modifyDate,
    this.authorEmail,
    this.replies = const [],
  });

  factory StoryComment.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected story comment object.');
    }

    final map = _stringKeyedMap(json);
    final rawReplies = map['replies'];

    return StoryComment(
      id: _readInt(map, 'id'),
      content: map['content']?.toString() ?? '',
      authorId: _readInt(map, 'authorId'),
      authorNickname: _readNickname(map['nickname']),
      authorEmail: _readNullableString(map['email']),
      postId: _readInt(map, 'postId'),
      createDate: map['createDate']?.toString() ?? '',
      modifyDate: map['modifyDate']?.toString() ?? '',
      replies: rawReplies is List
          ? rawReplies.map(StoryComment.fromJson).toList(growable: false)
          : const [],
    );
  }

  final int id;
  final String content;
  final int authorId;
  final String authorNickname;
  final String? authorEmail;
  final int postId;
  final String createDate;
  final String modifyDate;
  final List<StoryComment> replies;

  bool canEdit(int memberId) {
    return authorId == memberId;
  }
}

class StoryReportTarget {
  const StoryReportTarget({
    required this.targetType,
    required this.targetId,
    required this.label,
  });

  final String targetType;
  final int targetId;
  final String label;
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
  return _readOptionalInt(map, key) ?? 0;
}

int? _readOptionalInt(Map<String, Object?> map, String key) {
  final value = map[key];

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

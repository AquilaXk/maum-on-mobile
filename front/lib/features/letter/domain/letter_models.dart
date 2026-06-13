enum LetterStatus {
  sent(label: '대기', apiValue: 'SENT'),
  accepted(label: '읽음', apiValue: 'ACCEPTED'),
  writing(label: '작성 중', apiValue: 'WRITING'),
  replied(label: '답장 완료', apiValue: 'REPLIED');

  const LetterStatus({
    required this.label,
    required this.apiValue,
  });

  final String label;
  final String apiValue;

  static LetterStatus fromApiValue(Object? value) {
    return switch (value?.toString()) {
      'ACCEPTED' => LetterStatus.accepted,
      'WRITING' => LetterStatus.writing,
      'REPLIED' => LetterStatus.replied,
      'SENT' => LetterStatus.sent,
      _ => LetterStatus.sent,
    };
  }
}

abstract final class LetterLimits {
  static const int titleMaxLength = 60;
  static const int contentMaxLength = 1000;
  static const int replyMaxLength = 1000;
}

enum LetterMailboxTab {
  received(label: '받은 편지함'),
  sent(label: '보낸 편지함');

  const LetterMailboxTab({required this.label});

  final String label;
}

class LetterDraft {
  const LetterDraft({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'content': content,
    };
  }
}

class LetterSummary {
  const LetterSummary({
    required this.id,
    required this.title,
    required this.createdDate,
    required this.status,
    this.content = '',
    this.senderNickname,
    this.replied = false,
  });

  factory LetterSummary.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected letter summary object.');
    }

    final map = _stringKeyedMap(json);
    final status = LetterStatus.fromApiValue(map['status']);
    return LetterSummary(
      id: _readInt(map, 'id'),
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      senderNickname: _readNullableString(map['senderNickname']),
      createdDate: map['createdDate']?.toString() ?? '',
      status: status,
      replied: map['replied'] == true || status == LetterStatus.replied,
    );
  }

  final int id;
  final String title;
  final String content;
  final String createdDate;
  final LetterStatus status;
  final String? senderNickname;
  final bool replied;
}

class LetterListPage {
  const LetterListPage({
    required this.items,
    required this.totalPages,
    required this.totalElements,
    required this.currentPage,
    required this.isFirst,
    required this.isLast,
  });

  factory LetterListPage.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected letter list object.');
    }

    final map = _stringKeyedMap(json);
    final rawItems = map['letters'];
    if (rawItems is! List) {
      throw const FormatException('Expected letter list items.');
    }

    return LetterListPage(
      items: rawItems.map(LetterSummary.fromJson).toList(growable: false),
      totalPages: _readInt(map, 'totalPages'),
      totalElements: _readInt(map, 'totalElements'),
      currentPage: _readInt(map, 'currentPage'),
      isFirst: map['isFirst'] == true,
      isLast: map['isLast'] == true,
    );
  }

  final List<LetterSummary> items;
  final int totalPages;
  final int totalElements;
  final int currentPage;
  final bool isFirst;
  final bool isLast;
}

class LetterDetail {
  const LetterDetail({
    required this.id,
    required this.title,
    required this.content,
    required this.status,
    required this.replied,
    required this.createdDate,
    this.replyContent,
    this.replyCreatedDate,
    this.senderNickname,
  });

  factory LetterDetail.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected letter detail object.');
    }

    final map = _stringKeyedMap(json);
    final status = LetterStatus.fromApiValue(map['status']);
    return LetterDetail(
      id: _readInt(map, 'id'),
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      replyContent: _readNullableString(map['replyContent']),
      status: status,
      replied: map['replied'] == true || status == LetterStatus.replied,
      createdDate: map['createdDate']?.toString() ?? '',
      replyCreatedDate: _readNullableString(
        map['replyCreatedDate'] ?? map['replyDate'],
      ),
      senderNickname: _readNullableString(map['senderNickname']),
    );
  }

  final int id;
  final String title;
  final String content;
  final String? replyContent;
  final LetterStatus status;
  final bool replied;
  final String createdDate;
  final String? replyCreatedDate;
  final String? senderNickname;

  LetterDetail copyWith({
    LetterStatus? status,
    bool? replied,
    String? replyContent,
    String? replyCreatedDate,
  }) {
    return LetterDetail(
      id: id,
      title: title,
      content: content,
      replyContent: replyContent ?? this.replyContent,
      status: status ?? this.status,
      replied: replied ?? this.replied,
      createdDate: createdDate,
      replyCreatedDate: replyCreatedDate ?? this.replyCreatedDate,
      senderNickname: senderNickname,
    );
  }
}

class LetterStats {
  const LetterStats({
    required this.receivedCount,
    required this.randomReceiveAllowed,
    this.latestReceivedLetter,
    this.latestSentLetter,
  });

  factory LetterStats.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected letter stats object.');
    }

    final map = _stringKeyedMap(json);
    return LetterStats(
      receivedCount: _readInt(map, 'receivedCount'),
      randomReceiveAllowed: _readBool(map, 'randomReceiveAllowed'),
      latestReceivedLetter: map['latestReceivedLetter'] == null
          ? null
          : LetterSummary.fromJson(map['latestReceivedLetter']),
      latestSentLetter: map['latestSentLetter'] == null
          ? null
          : LetterSummary.fromJson(map['latestSentLetter']),
    );
  }

  final int receivedCount;
  final bool randomReceiveAllowed;
  final LetterSummary? latestReceivedLetter;
  final LetterSummary? latestSentLetter;
}

class LetterReportTarget {
  const LetterReportTarget({
    required this.targetType,
    required this.targetId,
    required this.label,
  });

  final String targetType;
  final int targetId;
  final String label;
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

bool _readBool(Map<String, Object?> map, String key) {
  final value = map[key];

  if (value is bool) {
    return value;
  }

  return value?.toString().toLowerCase() == 'true';
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

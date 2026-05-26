import 'dart:convert';

enum NotificationConnectionState {
  idle,
  connecting,
  connected,
  error,
}

enum NotificationStreamEventType {
  connect,
  newLetter,
  letterRead,
  writingStatus,
  replyArrival,
  reportStatus,
  consultationReply,
  unknown,
}

enum NotificationDevicePlatform {
  android,
  ios;

  String get apiValue {
    return switch (this) {
      NotificationDevicePlatform.android => 'ANDROID',
      NotificationDevicePlatform.ios => 'IOS',
    };
  }

  static NotificationDevicePlatform fromJson(Object? value) {
    return switch (value?.toString().toUpperCase()) {
      'ANDROID' => NotificationDevicePlatform.android,
      'IOS' => NotificationDevicePlatform.ios,
      _ => throw FormatException('Unknown notification platform: $value'),
    };
  }
}

enum NotificationTapDestination {
  notifications,
  diary,
  story,
  letter,
  consultation,
  operations,
  settings,
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.type = 'fallback',
    this.targetType,
    this.targetId,
    this.routeKey = 'notifications',
    this.readAt,
  });

  factory NotificationItem.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected notification object.');
    }

    final map = _stringKeyedMap(json);
    return NotificationItem(
      id: _readInt(map, 'id'),
      content: map['content']?.toString() ?? '',
      type: _readNullableString(map['type']) ?? 'fallback',
      targetType: _readNullableString(map['targetType']),
      targetId: _readOptionalInt(map, 'targetId'),
      routeKey: _readNullableString(map['routeKey']) ?? 'notifications',
      isRead: map['isRead'] == true || map['read'] == true,
      createdAt: (map['createdAt'] ??
              map['createdDate'] ??
              map['createDate'] ??
              map['modifyDate'] ??
              '')
          .toString(),
      readAt: _readNullableString(map['readAt']),
    );
  }

  final int id;
  final String content;
  final String type;
  final String? targetType;
  final int? targetId;
  final String routeKey;
  final bool isRead;
  final String createdAt;
  final String? readAt;

  int? get letterId {
    return targetType?.toUpperCase() == 'LETTER' ? targetId : null;
  }

  int? get reportId {
    return targetType?.toUpperCase() == 'REPORT' ? targetId : null;
  }

  NotificationTapDestination get destination {
    return _destinationFromRouteKey(
      routeKey,
      fallbackType: type,
      targetType: targetType,
    );
  }

  NotificationTapPayload get tapPayload {
    return NotificationTapPayload(
      destination: destination,
      notificationId: id > 0 ? id : null,
      targetType: targetType,
      targetId: targetId,
      routeKey: routeKey,
      rawType: type,
    );
  }

  String get destinationLabel {
    return switch (destination) {
      NotificationTapDestination.diary => '일기',
      NotificationTapDestination.story => '이야기',
      NotificationTapDestination.letter => '편지',
      NotificationTapDestination.consultation => '상담',
      NotificationTapDestination.operations => '운영',
      NotificationTapDestination.settings => '설정',
      NotificationTapDestination.notifications => '알림',
    };
  }

  String get accessibilityLabel {
    final readState = isRead ? '읽은' : '읽지 않은';
    return '$readState 알림, $content, $destinationLabel로 이동';
  }

  NotificationItem copyWith({
    int? id,
    String? content,
    String? type,
    String? targetType,
    int? targetId,
    String? routeKey,
    bool? isRead,
    String? createdAt,
    String? readAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      routeKey: routeKey ?? this.routeKey,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

class NotificationTapPayload {
  const NotificationTapPayload({
    required this.destination,
    this.notificationId,
    int? letterId,
    int? reportId,
    this.targetType,
    this.targetId,
    this.routeKey,
    this.rawType,
  })  : _letterId = letterId,
        _reportId = reportId;

  factory NotificationTapPayload.fromJson(Object? json) {
    if (json is! Map) {
      return const NotificationTapPayload(
        destination: NotificationTapDestination.notifications,
      );
    }

    final map = _stringKeyedMap(json);
    final rawType = (map['type'] ?? map['event'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final routeKey = (map['routeKey'] ?? map['route'] ?? map['destination'])
        ?.toString()
        .trim()
        .toLowerCase();
    final targetType = map['targetType']?.toString().trim().toUpperCase();
    final targetId = _readOptionalInt(map, 'targetId');

    return NotificationTapPayload(
      destination: _destinationFromRouteKey(
        routeKey ?? '',
        fallbackType: rawType,
        targetType: targetType,
      ),
      notificationId: _readOptionalInt(map, 'notificationId'),
      letterId: _readOptionalInt(map, 'letterId') ??
          (targetType == 'LETTER' ? targetId : null),
      reportId: _readOptionalInt(map, 'reportId') ??
          (targetType == 'REPORT' ? targetId : null),
      targetType: targetType,
      targetId: targetId,
      routeKey: routeKey,
      rawType: rawType.isEmpty ? null : rawType,
    );
  }

  final NotificationTapDestination destination;
  final int? notificationId;
  final int? _letterId;
  final int? _reportId;
  final String? targetType;
  final int? targetId;
  final String? routeKey;
  final String? rawType;

  String get normalizedTargetType => targetType?.trim().toUpperCase() ?? '';

  int? get letterId {
    if (_letterId != null) {
      return _letterId;
    }
    if (targetId == null) {
      return null;
    }
    return switch (normalizedTargetType) {
      'LETTER' => targetId,
      '' when _inferredDestination == NotificationTapDestination.letter =>
        targetId,
      _ => null,
    };
  }

  int? get reportId {
    if (_reportId != null) {
      return _reportId;
    }
    if (targetId == null) {
      return null;
    }
    return switch (normalizedTargetType) {
      'REPORT' => targetId,
      '' when _isReportRoute => targetId,
      _ => null,
    };
  }

  int? get storyId {
    return switch (normalizedTargetType) {
      'POST' || 'STORY' => targetId,
      _ => destination == NotificationTapDestination.story &&
              normalizedTargetType.isEmpty
          ? targetId
          : null,
    };
  }

  int? get diaryId {
    return normalizedTargetType == 'DIARY' ? targetId : null;
  }

  int? get consultationId {
    return normalizedTargetType == 'CONSULTATION' ? targetId : null;
  }

  bool get hasTargetReference {
    return normalizedTargetType.isNotEmpty || targetId != null;
  }

  NotificationTapDestination get _inferredDestination {
    return _destinationFromRouteKey(
      routeKey ?? '',
      fallbackType: rawType ?? '',
      targetType: targetType,
    );
  }

  bool get _isReportRoute {
    final normalizedRoute = routeKey?.trim().toLowerCase() ?? '';
    final normalizedType = rawType?.trim().toLowerCase() ?? '';
    return normalizedRoute == 'report' ||
        normalizedRoute == 'reports' ||
        normalizedRoute == 'report_status' ||
        normalizedType == 'report_status';
  }
}

NotificationTapDestination _destinationFromRouteKey(
  String routeKey, {
  String fallbackType = '',
  String? targetType,
}) {
  final normalizedRoute = routeKey.trim().toLowerCase();
  final normalizedType = fallbackType.trim().toLowerCase();
  final normalizedTarget = targetType?.trim().toUpperCase() ?? '';
  final routingKey =
      normalizedRoute.isEmpty || normalizedRoute == 'notifications'
          ? normalizedType
          : normalizedRoute;

  final routeDestination = switch (routingKey) {
    'diary' || 'diaries' || 'daily' => NotificationTapDestination.diary,
    'story' || 'stories' || 'post' || 'comment' =>
      NotificationTapDestination.story,
    'letter' ||
    'letters' ||
    'new_letter' ||
    'letter_read' ||
    'writing_status' ||
    'reply_arrival' =>
      NotificationTapDestination.letter,
    'consultation' || 'consultation_reply' =>
      NotificationTapDestination.consultation,
    'operations' || 'operations_action' || 'admin' || 'report' ||
    'reports' ||
    'report_status' =>
      NotificationTapDestination.operations,
    'settings' || 'setting' || 'account' || 'profile' =>
      NotificationTapDestination.settings,
    _ => null,
  };

  if (routeDestination != null) {
    return routeDestination;
  }

  return switch (normalizedTarget) {
    'DIARY' => NotificationTapDestination.diary,
    'POST' || 'STORY' || 'COMMENT' => NotificationTapDestination.story,
    'LETTER' => NotificationTapDestination.letter,
    'CONSULTATION' => NotificationTapDestination.consultation,
    'REPORT' => NotificationTapDestination.operations,
    'SETTINGS' || 'ACCOUNT' || 'PROFILE' => NotificationTapDestination.settings,
    _ => NotificationTapDestination.notifications,
  };
}

class NotificationSubscriptionTicket {
  const NotificationSubscriptionTicket({
    required this.ticket,
    required this.expiresInSeconds,
  });

  factory NotificationSubscriptionTicket.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected notification ticket object.');
    }

    final map = _stringKeyedMap(json);
    return NotificationSubscriptionTicket(
      ticket: map['ticket']?.toString() ?? '',
      expiresInSeconds: _readInt(map, 'expiresInSeconds'),
    );
  }

  final String ticket;
  final int expiresInSeconds;
}

class NotificationStreamEvent {
  const NotificationStreamEvent._({
    required this.type,
    required this.data,
    required this.message,
    this.notificationType,
    this.targetType,
    this.targetId,
    this.routeKey,
    this.letterId,
    this.reportId,
    this.status,
    this.notificationId,
    this.createdAt,
  });

  const NotificationStreamEvent.connect(String data)
      : this._(
          type: NotificationStreamEventType.connect,
          data: data,
          message: data,
        );

  const NotificationStreamEvent.newLetter(String message)
      : this._(
          type: NotificationStreamEventType.newLetter,
          data: message,
          message: message,
        );

  const NotificationStreamEvent.letterRead(String message)
      : this._(
          type: NotificationStreamEventType.letterRead,
          data: message,
          message: message,
        );

  const NotificationStreamEvent.writingStatus(String message)
      : this._(
          type: NotificationStreamEventType.writingStatus,
          data: message,
          message: message,
        );

  const NotificationStreamEvent.replyArrival(String message)
      : this._(
          type: NotificationStreamEventType.replyArrival,
          data: message,
          message: message,
        );

  const NotificationStreamEvent.reportStatus(
    String message, {
    int? reportId,
    String? status,
    int? notificationId,
    String? createdAt,
  }) : this._(
          type: NotificationStreamEventType.reportStatus,
          data: message,
          message: message,
          reportId: reportId,
          status: status,
          notificationId: notificationId,
          createdAt: createdAt,
        );

  const NotificationStreamEvent.consultationReply(
    String message, {
    String? status,
    int? notificationId,
    String? createdAt,
  }) : this._(
          type: NotificationStreamEventType.consultationReply,
          data: message,
          message: message,
          status: status,
          notificationId: notificationId,
          createdAt: createdAt,
        );

  const NotificationStreamEvent.unknown(String data)
      : this._(
          type: NotificationStreamEventType.unknown,
          data: data,
          message: data,
        );

  factory NotificationStreamEvent.fromSse({
    required String event,
    required String data,
  }) {
    final payload = _decodePayload(data);
    final message = payload.message;

    return switch (event) {
      'connect' => NotificationStreamEvent.connect(message),
      'new_letter' => NotificationStreamEvent._(
          type: NotificationStreamEventType.newLetter,
          data: data,
          message: message.isEmpty ? '새로운 랜덤 편지가 도착했습니다!' : message,
          notificationType: payload.notificationType,
          targetType: payload.targetType,
          targetId: payload.targetId,
          routeKey: payload.routeKey,
          letterId: payload.letterId,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      'letter_read' => NotificationStreamEvent._(
          type: NotificationStreamEventType.letterRead,
          data: data,
          message: message.isEmpty ? '상대방이 편지를 읽었습니다.' : message,
          notificationType: payload.notificationType,
          targetType: payload.targetType,
          targetId: payload.targetId,
          routeKey: payload.routeKey,
          letterId: payload.letterId,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      'writing_status' => NotificationStreamEvent._(
          type: NotificationStreamEventType.writingStatus,
          data: data,
          message: message.isEmpty ? '상대방이 답장을 작성 중입니다.' : message,
          notificationType: payload.notificationType,
          targetType: payload.targetType,
          targetId: payload.targetId,
          routeKey: payload.routeKey,
          letterId: payload.letterId,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      'reply_arrival' => NotificationStreamEvent._(
          type: NotificationStreamEventType.replyArrival,
          data: data,
          message: message.isEmpty ? '보낸 편지에 답장이 도착했습니다!' : message,
          notificationType: payload.notificationType,
          targetType: payload.targetType,
          targetId: payload.targetId,
          routeKey: payload.routeKey,
          letterId: payload.letterId,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      'report_status' => NotificationStreamEvent._(
          type: NotificationStreamEventType.reportStatus,
          data: data,
          message: message.isEmpty ? '신고 처리 결과가 등록되었습니다.' : message,
          notificationType: payload.notificationType,
          targetType: payload.targetType,
          targetId: payload.targetId,
          routeKey: payload.routeKey,
          reportId: payload.reportId,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      'consultation_reply' => NotificationStreamEvent._(
          type: NotificationStreamEventType.consultationReply,
          data: data,
          message: message.isEmpty ? '상담 답변이 도착했습니다.' : message,
          notificationType: payload.notificationType,
          targetType: payload.targetType,
          targetId: payload.targetId,
          routeKey: payload.routeKey,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      _ => NotificationStreamEvent.unknown(message),
    };
  }

  final NotificationStreamEventType type;
  final String data;
  final String message;
  final String? notificationType;
  final String? targetType;
  final int? targetId;
  final String? routeKey;
  final int? letterId;
  final int? reportId;
  final String? status;
  final int? notificationId;
  final String? createdAt;

  String get dedupeKey {
    final serverId = notificationId;
    if (serverId != null && serverId > 0) {
      return 'notification:$serverId';
    }

    return [
      type.name,
      letterId,
      reportId,
      status,
      message,
      createdAt,
    ].join('|');
  }

  bool get shouldDisplay {
    return type == NotificationStreamEventType.newLetter ||
        type == NotificationStreamEventType.letterRead ||
        type == NotificationStreamEventType.writingStatus ||
        type == NotificationStreamEventType.replyArrival ||
        type == NotificationStreamEventType.reportStatus ||
        type == NotificationStreamEventType.consultationReply;
  }
}

class NotificationBulkReadResult {
  const NotificationBulkReadResult({required this.updatedCount});

  factory NotificationBulkReadResult.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected notification bulk read object.');
    }

    return NotificationBulkReadResult(
      updatedCount: _readInt(_stringKeyedMap(json), 'updatedCount'),
    );
  }

  final int updatedCount;
}

class NotificationDeviceTokenResult {
  const NotificationDeviceTokenResult({
    required this.platform,
    required this.enabled,
    required this.updatedAt,
  });

  factory NotificationDeviceTokenResult.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected notification device token object.');
    }

    final map = _stringKeyedMap(json);
    return NotificationDeviceTokenResult(
      platform: NotificationDevicePlatform.fromJson(map['platform']),
      enabled: map['enabled'] == true,
      updatedAt: map['updatedAt']?.toString() ?? '',
    );
  }

  final NotificationDevicePlatform platform;
  final bool enabled;
  final String updatedAt;
}

class _NotificationPayload {
  const _NotificationPayload({
    required this.message,
    this.notificationType,
    this.targetType,
    this.targetId,
    this.routeKey,
    this.letterId,
    this.reportId,
    this.status,
    this.notificationId,
    this.createdAt,
  });

  final String message;
  final String? notificationType;
  final String? targetType;
  final int? targetId;
  final String? routeKey;
  final int? letterId;
  final int? reportId;
  final String? status;
  final int? notificationId;
  final String? createdAt;
}

_NotificationPayload _decodePayload(String data) {
  try {
    final decoded = jsonDecode(data);
    if (decoded is Map) {
      final map = _stringKeyedMap(decoded);
      return _NotificationPayload(
        message: (map['message'] ?? map['content'] ?? data).toString(),
        notificationType: _readNullableString(map['type']),
        targetType: _readNullableString(map['targetType']),
        targetId: _readOptionalInt(map, 'targetId'),
        routeKey: _readNullableString(map['routeKey']),
        letterId: _readOptionalInt(map, 'letterId'),
        reportId: _readOptionalInt(map, 'reportId'),
        status: _readNullableString(map['status']),
        notificationId: _readOptionalInt(map, 'notificationId'),
        createdAt: _readNullableString(map['createdAt']),
      );
    }
  } on FormatException {
    // 문자열 이벤트도 정상 포맷이다.
  }

  return _NotificationPayload(message: data);
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

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
  letter,
  consultation,
  operations,
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.content,
    required this.isRead,
    required this.createdAt,
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
  final bool isRead;
  final String createdAt;
  final String? readAt;

  NotificationItem copyWith({
    int? id,
    String? content,
    bool? isRead,
    String? createdAt,
    String? readAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      content: content ?? this.content,
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
    this.letterId,
    this.reportId,
    this.rawType,
  });

  factory NotificationTapPayload.fromJson(Object? json) {
    if (json is! Map) {
      return const NotificationTapPayload(
        destination: NotificationTapDestination.notifications,
      );
    }

    final map = _stringKeyedMap(json);
    final rawType = (map['type'] ??
            map['event'] ??
            map['route'] ??
            map['destination'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final destination = switch (rawType) {
      'letter' ||
      'letters' ||
      'new_letter' ||
      'letter_read' ||
      'writing_status' ||
      'reply_arrival' =>
        NotificationTapDestination.letter,
      'consultation' || 'consultation_reply' =>
        NotificationTapDestination.consultation,
      'operations' || 'admin' => NotificationTapDestination.operations,
      _ => NotificationTapDestination.notifications,
    };

    return NotificationTapPayload(
      destination: destination,
      notificationId: _readOptionalInt(map, 'notificationId'),
      letterId: _readOptionalInt(map, 'letterId'),
      reportId: _readOptionalInt(map, 'reportId'),
      rawType: rawType.isEmpty ? null : rawType,
    );
  }

  final NotificationTapDestination destination;
  final int? notificationId;
  final int? letterId;
  final int? reportId;
  final String? rawType;
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
          letterId: payload.letterId,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      'letter_read' => NotificationStreamEvent._(
          type: NotificationStreamEventType.letterRead,
          data: data,
          message: message.isEmpty ? '상대방이 편지를 읽었습니다.' : message,
          letterId: payload.letterId,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      'writing_status' => NotificationStreamEvent._(
          type: NotificationStreamEventType.writingStatus,
          data: data,
          message: message.isEmpty ? '상대방이 답장을 작성 중입니다.' : message,
          letterId: payload.letterId,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      'reply_arrival' => NotificationStreamEvent._(
          type: NotificationStreamEventType.replyArrival,
          data: data,
          message: message.isEmpty ? '보낸 편지에 답장이 도착했습니다!' : message,
          letterId: payload.letterId,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      'report_status' => NotificationStreamEvent._(
          type: NotificationStreamEventType.reportStatus,
          data: data,
          message: message.isEmpty ? '신고 처리 결과가 등록되었습니다.' : message,
          reportId: payload.reportId,
          status: payload.status,
          notificationId: payload.notificationId,
          createdAt: payload.createdAt,
        ),
      'consultation_reply' => NotificationStreamEvent._(
          type: NotificationStreamEventType.consultationReply,
          data: data,
          message: message.isEmpty ? '상담 답변이 도착했습니다.' : message,
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
    this.letterId,
    this.reportId,
    this.status,
    this.notificationId,
    this.createdAt,
  });

  final String message;
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

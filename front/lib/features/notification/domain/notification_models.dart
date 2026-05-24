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
  unknown,
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.content,
    required this.isRead,
    required this.createdAt,
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
    );
  }

  final int id;
  final String content;
  final bool isRead;
  final String createdAt;
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
    this.status,
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
        ),
      'letter_read' => NotificationStreamEvent._(
          type: NotificationStreamEventType.letterRead,
          data: data,
          message: message.isEmpty ? '상대방이 편지를 읽었습니다.' : message,
          letterId: payload.letterId,
          status: payload.status,
        ),
      'writing_status' => NotificationStreamEvent._(
          type: NotificationStreamEventType.writingStatus,
          data: data,
          message: message.isEmpty ? '상대방이 답장을 작성 중입니다.' : message,
          letterId: payload.letterId,
          status: payload.status,
        ),
      'reply_arrival' => NotificationStreamEvent._(
          type: NotificationStreamEventType.replyArrival,
          data: data,
          message: message.isEmpty ? '보낸 편지에 답장이 도착했습니다!' : message,
          letterId: payload.letterId,
          status: payload.status,
        ),
      _ => NotificationStreamEvent.unknown(message),
    };
  }

  final NotificationStreamEventType type;
  final String data;
  final String message;
  final int? letterId;
  final String? status;

  bool get shouldDisplay {
    return type == NotificationStreamEventType.newLetter ||
        type == NotificationStreamEventType.letterRead ||
        type == NotificationStreamEventType.writingStatus ||
        type == NotificationStreamEventType.replyArrival;
  }
}

class _NotificationPayload {
  const _NotificationPayload({
    required this.message,
    this.letterId,
    this.status,
  });

  final String message;
  final int? letterId;
  final String? status;
}

_NotificationPayload _decodePayload(String data) {
  try {
    final decoded = jsonDecode(data);
    if (decoded is Map) {
      final map = _stringKeyedMap(decoded);
      return _NotificationPayload(
        message: (map['message'] ?? map['content'] ?? data).toString(),
        letterId: _readOptionalInt(map, 'letterId'),
        status: _readNullableString(map['status']),
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

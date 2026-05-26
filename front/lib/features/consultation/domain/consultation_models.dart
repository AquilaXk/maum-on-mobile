import 'dart:convert';

enum ConsultationMessageRole {
  user,
  assistant,
  system,
}

enum ConsultationConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  error,
}

enum ConsultationStreamEventType {
  connect,
  heartbeat,
  chat,
  done,
  error,
  streamError,
  unknown,
}

enum ConsultationRiskCategory {
  none,
  selfHarm,
  violence,
  abuse;

  static ConsultationRiskCategory fromApiValue(String value) {
    return switch (value) {
      'SELF_HARM' => ConsultationRiskCategory.selfHarm,
      'VIOLENCE' => ConsultationRiskCategory.violence,
      'ABUSE' => ConsultationRiskCategory.abuse,
      _ => ConsultationRiskCategory.none,
    };
  }
}

enum ConsultationRiskSeverity {
  low,
  high,
  critical;

  static ConsultationRiskSeverity fromApiValue(String value) {
    return switch (value) {
      'HIGH' => ConsultationRiskSeverity.high,
      'CRITICAL' => ConsultationRiskSeverity.critical,
      _ => ConsultationRiskSeverity.low,
    };
  }
}

enum ConsultationActionPolicy {
  allow,
  safeGuidance,
  blockAndEscalate,
  rateLimited;

  static ConsultationActionPolicy fromApiValue(String value) {
    return switch (value) {
      'SAFE_GUIDANCE' => ConsultationActionPolicy.safeGuidance,
      'BLOCK_AND_ESCALATE' => ConsultationActionPolicy.blockAndEscalate,
      'RATE_LIMITED' => ConsultationActionPolicy.rateLimited,
      _ => ConsultationActionPolicy.allow,
    };
  }
}

class ConsultationMessage {
  const ConsultationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.sensitive = false,
    this.retentionUntil,
  });

  factory ConsultationMessage.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected consultation message object.');
    }

    final map = _stringKeyedMap(json);
    return ConsultationMessage(
      id: map['id']?.toString() ?? '',
      role: _roleFromJson(map['role']),
      content: map['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sensitive: map['sensitive'] == true,
      retentionUntil:
          DateTime.tryParse(map['retentionUntil']?.toString() ?? ''),
    );
  }

  final String id;
  final ConsultationMessageRole role;
  final String content;
  final DateTime createdAt;
  final bool sensitive;
  final DateTime? retentionUntil;

  ConsultationMessage copyWith({
    ConsultationMessageRole? role,
    String? content,
    bool? sensitive,
  }) {
    return ConsultationMessage(
      id: id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt,
      sensitive: sensitive ?? this.sensitive,
      retentionUntil: retentionUntil,
    );
  }
}

class ConsultationSafetyResult {
  const ConsultationSafetyResult({
    required this.category,
    required this.severity,
    required this.actionPolicy,
    required this.message,
  });

  factory ConsultationSafetyResult.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected consultation safety object.');
    }

    final map = _stringKeyedMap(json);
    return ConsultationSafetyResult(
      category: ConsultationRiskCategory.fromApiValue(
        map['category']?.toString() ?? 'NONE',
      ),
      severity: ConsultationRiskSeverity.fromApiValue(
        map['severity']?.toString() ?? 'LOW',
      ),
      actionPolicy: ConsultationActionPolicy.fromApiValue(
        map['actionPolicy']?.toString() ?? 'ALLOW',
      ),
      message: map['message']?.toString() ?? '',
    );
  }

  final ConsultationRiskCategory category;
  final ConsultationRiskSeverity severity;
  final ConsultationActionPolicy actionPolicy;
  final String message;

  bool get blocksConversation => actionPolicy != ConsultationActionPolicy.allow;
}

class ConsultationSendResult {
  const ConsultationSendResult({
    required this.accepted,
    this.safety,
  });

  factory ConsultationSendResult.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected consultation send result object.');
    }

    final map = _stringKeyedMap(json);
    return ConsultationSendResult(
      accepted: map['accepted'] == true,
      safety: map['safety'] == null
          ? null
          : ConsultationSafetyResult.fromJson(map['safety']),
    );
  }

  final bool accepted;
  final ConsultationSafetyResult? safety;
}

class ConsultationStreamEvent {
  const ConsultationStreamEvent._(
    this.type,
    this.data, {
    this.requestId,
    this.sequence,
  });

  const ConsultationStreamEvent.connect(String data)
      : this._(ConsultationStreamEventType.connect, data);

  const ConsultationStreamEvent.heartbeat(String data)
      : this._(ConsultationStreamEventType.heartbeat, data);

  const ConsultationStreamEvent.chat(
    String data, {
    String? requestId,
    int? sequence,
  }) : this._(
          ConsultationStreamEventType.chat,
          data,
          requestId: requestId,
          sequence: sequence,
        );

  const ConsultationStreamEvent.done({
    String? requestId,
    int? sequence,
  }) : this._(
          ConsultationStreamEventType.done,
          'done',
          requestId: requestId,
          sequence: sequence,
        );

  const ConsultationStreamEvent.error(
    String data, {
    String? requestId,
    int? sequence,
  }) : this._(
          ConsultationStreamEventType.error,
          data,
          requestId: requestId,
          sequence: sequence,
        );

  const ConsultationStreamEvent.streamError(String data)
      : this._(ConsultationStreamEventType.streamError, data);

  const ConsultationStreamEvent.unknown(String data)
      : this._(ConsultationStreamEventType.unknown, data);

  factory ConsultationStreamEvent.fromSse({
    required String event,
    required String data,
  }) {
    final payload = _tryJsonDecode(data);
    return switch (event) {
      'connect' => ConsultationStreamEvent.connect(data),
      'heartbeat' => ConsultationStreamEvent.heartbeat(data),
      'chat' => ConsultationStreamEvent.chat(
          _jsonFieldOrRaw(payload, data, 'chunk'),
          requestId: _jsonString(payload, 'requestId'),
          sequence: _jsonInt(payload, 'sequence'),
        ),
      'chat_done' => ConsultationStreamEvent.done(
          requestId: _jsonString(payload, 'requestId'),
          sequence: _jsonInt(payload, 'sequence'),
        ),
      'chat_error' => ConsultationStreamEvent.error(
          _jsonFieldOrRaw(payload, data, 'message'),
          requestId: _jsonString(payload, 'requestId'),
          sequence: _jsonInt(payload, 'sequence'),
        ),
      'stream_error' => ConsultationStreamEvent.streamError(
          _jsonFieldOrRaw(payload, data, 'message'),
        ),
      _ => ConsultationStreamEvent.unknown(data),
    };
  }

  final ConsultationStreamEventType type;
  final String data;
  final String? requestId;
  final int? sequence;
}

ConsultationMessageRole _roleFromJson(Object? value) {
  return switch (value?.toString()) {
    'USER' || 'user' => ConsultationMessageRole.user,
    'ASSISTANT' || 'assistant' => ConsultationMessageRole.assistant,
    _ => ConsultationMessageRole.system,
  };
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

String _jsonFieldOrRaw(Object? decoded, String data, String field) {
  if (decoded is Map) {
    final value = decoded[field];
    if (value != null) {
      return value.toString();
    }
  }
  return data;
}

Object? _tryJsonDecode(String data) {
  try {
    return jsonDecode(data);
  } on FormatException {
    return null;
  }
}

String? _jsonString(Object? decoded, String field) {
  if (decoded is! Map) {
    return null;
  }
  final value = decoded[field];
  return value?.toString();
}

int? _jsonInt(Object? decoded, String field) {
  if (decoded is! Map) {
    return null;
  }
  final value = decoded[field];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

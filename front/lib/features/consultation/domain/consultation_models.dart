enum ConsultationMessageRole {
  user,
  assistant,
  system,
}

enum ConsultationConnectionState {
  idle,
  connecting,
  connected,
  error,
}

enum ConsultationStreamEventType {
  connect,
  chat,
  done,
  error,
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
      retentionUntil: DateTime.tryParse(map['retentionUntil']?.toString() ?? ''),
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
  const ConsultationStreamEvent._(this.type, this.data);

  const ConsultationStreamEvent.connect(String data)
      : this._(ConsultationStreamEventType.connect, data);

  const ConsultationStreamEvent.chat(String data)
      : this._(ConsultationStreamEventType.chat, data);

  const ConsultationStreamEvent.done()
      : this._(ConsultationStreamEventType.done, 'done');

  const ConsultationStreamEvent.error(String data)
      : this._(ConsultationStreamEventType.error, data);

  const ConsultationStreamEvent.unknown(String data)
      : this._(ConsultationStreamEventType.unknown, data);

  factory ConsultationStreamEvent.fromSse({
    required String event,
    required String data,
  }) {
    return switch (event) {
      'connect' => ConsultationStreamEvent.connect(data),
      'chat' => ConsultationStreamEvent.chat(data),
      'chat_done' => const ConsultationStreamEvent.done(),
      'chat_error' => ConsultationStreamEvent.error(data),
      _ => ConsultationStreamEvent.unknown(data),
    };
  }

  final ConsultationStreamEventType type;
  final String data;
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

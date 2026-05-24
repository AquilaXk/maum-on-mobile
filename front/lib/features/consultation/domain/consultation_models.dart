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

class ConsultationMessage {
  const ConsultationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
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
    );
  }

  final String id;
  final ConsultationMessageRole role;
  final String content;
  final DateTime createdAt;

  ConsultationMessage copyWith({
    ConsultationMessageRole? role,
    String? content,
  }) {
    return ConsultationMessage(
      id: id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }
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

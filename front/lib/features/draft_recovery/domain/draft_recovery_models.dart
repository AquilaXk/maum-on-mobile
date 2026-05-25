enum DraftSurface {
  diary,
  story,
  storyComment,
  letter,
  letterReply,
  consultation,
}

enum DraftRecoveryStatus {
  editing,
  failed,
}

enum DraftConnectionStatus {
  online,
  offline,
  reconnecting,
}

class DraftKey {
  const DraftKey({
    required this.memberId,
    required this.surface,
    this.scopeId,
  });

  final int memberId;
  final DraftSurface surface;
  final String? scopeId;

  String get storageKey {
    final normalizedScope = scopeId?.trim().isNotEmpty == true
        ? scopeId!.trim()
        : 'root';
    return 'draft.v1.$memberId.${surface.name}.$normalizedScope';
  }

  bool belongsToMember(int targetMemberId) {
    return memberId == targetMemberId;
  }
}

class DraftEntry {
  const DraftEntry({
    required this.key,
    required this.fields,
    required this.status,
    required this.updatedAt,
    this.failureMessage,
  });

  factory DraftEntry.fromJson(Map<String, Object?> json) {
    final surfaceName = json['surface']?.toString() ?? '';
    return DraftEntry(
      key: DraftKey(
        memberId: _int(json['memberId']),
        surface: DraftSurface.values.firstWhere(
          (surface) => surface.name == surfaceName,
          orElse: () => DraftSurface.diary,
        ),
        scopeId: json['scopeId']?.toString(),
      ),
      fields: _stringMap(json['fields']),
      status: DraftRecoveryStatus.values.firstWhere(
        (status) => status.name == json['status']?.toString(),
        orElse: () => DraftRecoveryStatus.editing,
      ),
      failureMessage: json['failureMessage']?.toString(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final DraftKey key;
  final Map<String, String> fields;
  final DraftRecoveryStatus status;
  final String? failureMessage;
  final DateTime updatedAt;

  bool get isFailed => status == DraftRecoveryStatus.failed;

  Map<String, Object?> toJson() {
    return {
      'memberId': key.memberId,
      'surface': key.surface.name,
      'scopeId': key.scopeId,
      'fields': fields,
      'status': status.name,
      'failureMessage': failureMessage,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class DraftConnectionNotice {
  const DraftConnectionNotice({
    required this.status,
    required this.message,
  });

  const DraftConnectionNotice.online()
      : status = DraftConnectionStatus.online,
        message = '연결됨';

  const DraftConnectionNotice.offline()
      : status = DraftConnectionStatus.offline,
        message = '오프라인입니다. 작성 내용은 임시 저장됩니다.';

  const DraftConnectionNotice.reconnecting()
      : status = DraftConnectionStatus.reconnecting,
        message = '다시 연결하는 중입니다.';

  final DraftConnectionStatus status;
  final String message;
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return value.map((key, value) => MapEntry(key.toString(), value.toString()));
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

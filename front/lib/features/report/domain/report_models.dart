enum ReportTargetType {
  post(label: '게시글', apiValue: 'POST'),
  letter(label: '편지', apiValue: 'LETTER'),
  comment(label: '댓글', apiValue: 'COMMENT');

  const ReportTargetType({
    required this.label,
    required this.apiValue,
  });

  final String label;
  final String apiValue;

  static ReportTargetType fromApiValue(String value) {
    return switch (value) {
      'POST' => ReportTargetType.post,
      'LETTER' => ReportTargetType.letter,
      'COMMENT' => ReportTargetType.comment,
      _ => throw FormatException('Unknown report target type: $value'),
    };
  }
}

enum ReportReasonCode {
  profanity(
    label: '욕설 및 비방',
    apiValue: 'PROFANITY',
    hint: '모욕, 비하, 공격적인 표현이 반복될 때 선택하세요.',
  ),
  spam(
    label: '스팸 및 광고',
    apiValue: 'SPAM',
    hint: '홍보, 도배, 외부 유도성 메시지에 사용하세요.',
  ),
  inappropriate(
    label: '부적절한 내용',
    apiValue: 'INAPPROPRIATE',
    hint: '혐오감, 불쾌감, 성적 표현 등 운영 기준 위반에 사용하세요.',
  ),
  personalInfo(
    label: '개인정보 노출',
    apiValue: 'PERSONAL_INFO',
    hint: '전화번호, 계정 정보, 실명 등 민감정보가 포함된 경우 선택하세요.',
  ),
  other(
    label: '기타',
    apiValue: 'OTHER',
    hint: '선택한 사유에 맞지 않으면 상황을 직접 적어 주세요.',
    requiresDescription: true,
  );

  const ReportReasonCode({
    required this.label,
    required this.apiValue,
    required this.hint,
    this.requiresDescription = false,
  });

  final String label;
  final String apiValue;
  final String hint;
  final bool requiresDescription;
}

enum AdminReportAction {
  resolved(label: '처리 완료', apiValue: 'RESOLVED'),
  rejected(label: '반려', apiValue: 'REJECTED'),
  hidden(label: '숨김', apiValue: 'HIDDEN'),
  deleted(label: '삭제', apiValue: 'DELETED'),
  restricted(label: '제한', apiValue: 'RESTRICTED');

  const AdminReportAction({
    required this.label,
    required this.apiValue,
  });

  final String label;
  final String apiValue;

  static AdminReportAction fromApiValue(String value) {
    return switch (value) {
      'REJECTED' => AdminReportAction.rejected,
      'HIDDEN' => AdminReportAction.hidden,
      'DELETED' => AdminReportAction.deleted,
      'RESTRICTED' => AdminReportAction.restricted,
      _ => AdminReportAction.resolved,
    };
  }
}

class ReportTarget {
  const ReportTarget({
    required this.type,
    required this.id,
    required this.label,
  });

  factory ReportTarget.fromRaw({
    required String targetType,
    required int targetId,
    required String label,
  }) {
    return ReportTarget(
      type: ReportTargetType.fromApiValue(targetType),
      id: targetId,
      label: label,
    );
  }

  final ReportTargetType type;
  final int id;
  final String label;
}

class ReportDraft {
  const ReportDraft({
    required this.target,
    required this.reason,
    required this.content,
  });

  final ReportTarget target;
  final ReportReasonCode reason;
  final String content;

  Map<String, Object?> toJson() {
    return {
      'targetId': target.id,
      'targetType': target.type.apiValue,
      'reason': reason.apiValue,
      if (content.trim().isNotEmpty) 'content': content.trim(),
    };
  }
}

class AdminReportMember {
  const AdminReportMember({
    required this.id,
    required this.email,
    required this.nickname,
    required this.role,
    required this.status,
  });

  factory AdminReportMember.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected admin report member object.');
    }

    final map = _stringKeyedMap(json);
    return AdminReportMember(
      id: _readInt(map, 'id'),
      email: map['email']?.toString() ?? '',
      nickname: map['nickname']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
    );
  }

  final int id;
  final String email;
  final String nickname;
  final String role;
  final String status;
}

class AdminReportTarget {
  const AdminReportTarget({
    required this.id,
    required this.type,
    required this.title,
    required this.preview,
    this.ownerId,
  });

  factory AdminReportTarget.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected admin report target object.');
    }

    final map = _stringKeyedMap(json);
    return AdminReportTarget(
      id: _readInt(map, 'id'),
      type: ReportTargetType.fromApiValue(map['type']?.toString() ?? 'POST'),
      title: map['title']?.toString() ?? '',
      preview: map['preview']?.toString() ?? '',
      ownerId: _readNullableInt(map, 'ownerId'),
    );
  }

  final int id;
  final ReportTargetType type;
  final String title;
  final String preview;
  final int? ownerId;
}

class AdminReportSummary {
  const AdminReportSummary({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.targetTitle,
    required this.targetPreview,
    required this.reporter,
    this.content,
    this.targetOwner,
    this.actionReason,
    this.handledBy,
    this.handledAt,
  });

  factory AdminReportSummary.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected admin report summary object.');
    }

    final map = _stringKeyedMap(json);
    return AdminReportSummary(
      id: _readInt(map, 'id'),
      targetId: _readInt(map, 'targetId'),
      targetType: ReportTargetType.fromApiValue(
        map['targetType']?.toString() ?? 'POST',
      ),
      reason: map['reason']?.toString() ?? '',
      content: _readNullableString(map, 'content'),
      status: map['status']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
      targetTitle: map['targetTitle']?.toString() ?? '',
      targetPreview: map['targetPreview']?.toString() ?? '',
      reporter: AdminReportMember.fromJson(map['reporter']),
      targetOwner: map['targetOwner'] == null
          ? null
          : AdminReportMember.fromJson(map['targetOwner']),
      actionReason: _readNullableString(map, 'actionReason'),
      handledBy: map['handledBy'] == null
          ? null
          : AdminReportMember.fromJson(map['handledBy']),
      handledAt: _readNullableString(map, 'handledAt'),
    );
  }

  final int id;
  final int targetId;
  final ReportTargetType targetType;
  final String reason;
  final String? content;
  final String status;
  final String createdAt;
  final String targetTitle;
  final String targetPreview;
  final AdminReportMember reporter;
  final AdminReportMember? targetOwner;
  final String? actionReason;
  final AdminReportMember? handledBy;
  final String? handledAt;

  bool get isOpen => status == 'RECEIVED';
}

class AdminReportDetail {
  const AdminReportDetail({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.target,
    required this.reporter,
    this.content,
    this.targetOwner,
    this.actionReason,
    this.handledBy,
    this.handledAt,
  });

  factory AdminReportDetail.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected admin report detail object.');
    }

    final map = _stringKeyedMap(json);
    return AdminReportDetail(
      id: _readInt(map, 'id'),
      targetId: _readInt(map, 'targetId'),
      targetType: ReportTargetType.fromApiValue(
        map['targetType']?.toString() ?? 'POST',
      ),
      reason: map['reason']?.toString() ?? '',
      content: _readNullableString(map, 'content'),
      status: map['status']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
      target: AdminReportTarget.fromJson(map['target']),
      reporter: AdminReportMember.fromJson(map['reporter']),
      targetOwner: map['targetOwner'] == null
          ? null
          : AdminReportMember.fromJson(map['targetOwner']),
      actionReason: _readNullableString(map, 'actionReason'),
      handledBy: map['handledBy'] == null
          ? null
          : AdminReportMember.fromJson(map['handledBy']),
      handledAt: _readNullableString(map, 'handledAt'),
    );
  }

  final int id;
  final int targetId;
  final ReportTargetType targetType;
  final String reason;
  final String? content;
  final String status;
  final String createdAt;
  final AdminReportTarget target;
  final AdminReportMember reporter;
  final AdminReportMember? targetOwner;
  final String? actionReason;
  final AdminReportMember? handledBy;
  final String? handledAt;
}

class AdminReportActionDraft {
  const AdminReportActionDraft({
    required this.action,
    required this.reason,
  });

  final AdminReportAction action;
  final String reason;

  Map<String, Object?> toJson() {
    return {
      'status': action.apiValue,
      'reason': reason.trim(),
    };
  }
}

class AdminReportActionResult {
  const AdminReportActionResult({
    required this.id,
    required this.status,
    this.actionReason,
    this.handledBy,
    this.handledAt,
  });

  factory AdminReportActionResult.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected admin report action result object.');
    }

    final map = _stringKeyedMap(json);
    return AdminReportActionResult(
      id: _readInt(map, 'id'),
      status: map['status']?.toString() ?? '',
      actionReason: _readNullableString(map, 'actionReason'),
      handledBy: map['handledBy'] == null
          ? null
          : AdminReportMember.fromJson(map['handledBy']),
      handledAt: _readNullableString(map, 'handledAt'),
    );
  }

  final int id;
  final String status;
  final String? actionReason;
  final AdminReportMember? handledBy;
  final String? handledAt;
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

int? _readNullableInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

String? _readNullableString(Map<String, Object?> map, String key) {
  final value = map[key]?.toString();
  return value == null || value.isEmpty ? null : value;
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

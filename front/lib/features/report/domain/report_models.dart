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

class MemberSettings {
  const MemberSettings({
    required this.id,
    required this.email,
    required this.nickname,
    required this.randomReceiveAllowed,
    required this.socialAccount,
    this.retentionPolicy = const MemberRetentionPolicy(),
    this.latestDataExport,
  });

  factory MemberSettings.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected member settings object.');
    }

    final map = _stringKeyedMap(json);
    return MemberSettings(
      id: _readInt(map, 'id'),
      email: map['email']?.toString() ?? '',
      nickname: map['nickname']?.toString() ?? '',
      randomReceiveAllowed: _readBool(map, 'randomReceiveAllowed'),
      socialAccount: _readBool(map, 'socialAccount'),
      retentionPolicy: MemberRetentionPolicy.fromJson(map['retentionPolicy']),
      latestDataExport: map['latestDataExport'] == null
          ? null
          : MemberDataExportJob.fromJson(map['latestDataExport']),
    );
  }

  final int id;
  final String email;
  final String nickname;
  final bool randomReceiveAllowed;
  final bool socialAccount;
  final MemberRetentionPolicy retentionPolicy;
  final MemberDataExportJob? latestDataExport;

  MemberSettings copyWith({
    String? email,
    String? nickname,
    bool? randomReceiveAllowed,
    bool? socialAccount,
    MemberRetentionPolicy? retentionPolicy,
    MemberDataExportJob? latestDataExport,
    bool clearLatestDataExport = false,
  }) {
    return MemberSettings(
      id: id,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      randomReceiveAllowed:
          randomReceiveAllowed ?? this.randomReceiveAllowed,
      socialAccount: socialAccount ?? this.socialAccount,
      retentionPolicy: retentionPolicy ?? this.retentionPolicy,
      latestDataExport:
          clearLatestDataExport ? null : latestDataExport ?? this.latestDataExport,
    );
  }
}

enum MemberDataExportStatus {
  pending,
  completed,
  failed,
  expired,
}

class MemberDataExportJob {
  const MemberDataExportJob({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    this.expiresAt,
    this.downloadUrl,
    this.failureReason,
  });

  factory MemberDataExportJob.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected data export job object.');
    }

    final map = _stringKeyedMap(json);
    return MemberDataExportJob(
      id: _readInt(map, 'id'),
      status: _readExportStatus(map['status']?.toString()),
      requestedAt: map['requestedAt']?.toString() ?? '',
      completedAt: _readNullableString(map, 'completedAt'),
      expiresAt: _readNullableString(map, 'expiresAt'),
      downloadUrl: _readNullableString(map, 'downloadUrl'),
      failureReason: _readNullableString(map, 'failureReason'),
    );
  }

  final int id;
  final MemberDataExportStatus status;
  final String requestedAt;
  final String? completedAt;
  final String? expiresAt;
  final String? downloadUrl;
  final String? failureReason;

  bool get canDownload => status == MemberDataExportStatus.completed;
}

class MemberDataExportFile {
  const MemberDataExportFile({
    required this.filename,
    required this.contentType,
    required this.content,
    required this.expiresAt,
  });

  factory MemberDataExportFile.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected data export file object.');
    }

    final map = _stringKeyedMap(json);
    return MemberDataExportFile(
      filename: map['filename']?.toString() ?? 'maum-on-data-export.json',
      contentType: map['contentType']?.toString() ?? 'application/json',
      content: map['content']?.toString() ?? '',
      expiresAt: map['expiresAt']?.toString() ?? '',
    );
  }

  final String filename;
  final String contentType;
  final String content;
  final String expiresAt;
}

class MemberRetentionPolicy {
  const MemberRetentionPolicy({
    this.immediateDeletionItems = const [
      '로그인 세션과 기기 알림 토큰은 탈퇴 즉시 폐기됩니다.',
      '민감 상담 메시지는 사용자 화면과 내보내기 대상에서 즉시 제외됩니다.',
    ],
    this.anonymizedRetentionItems = const [
      '계정 이메일과 표시 이름은 탈퇴 회원 식별자로 대체됩니다.',
      '기록, 이야기, 편지의 작성자 표시는 탈퇴한 회원으로 바뀝니다.',
    ],
    this.legalRetentionItems = const [
      '신고, 운영 조치, 서비스 안정성 기록은 분쟁 대응 기간 동안 보존될 수 있습니다.',
      '내보내기 파일은 제한 시간 동안 본인만 접근할 수 있고 만료 뒤 다시 요청해야 합니다.',
    ],
    this.exportExpiryHours = 24,
  });

  factory MemberRetentionPolicy.fromJson(Object? json) {
    if (json is! Map) {
      return const MemberRetentionPolicy();
    }

    final map = _stringKeyedMap(json);
    return MemberRetentionPolicy(
      immediateDeletionItems: _readStringList(map['immediateDeletionItems']),
      anonymizedRetentionItems:
          _readStringList(map['anonymizedRetentionItems']),
      legalRetentionItems: _readStringList(map['legalRetentionItems']),
      exportExpiryHours: _readInt(map, 'exportExpiryHours'),
    );
  }

  final List<String> immediateDeletionItems;
  final List<String> anonymizedRetentionItems;
  final List<String> legalRetentionItems;
  final int exportExpiryHours;
}

class PasswordChangeDraft {
  const PasswordChangeDraft({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  Map<String, Object?> toJson() {
    return {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
  }
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
  if (value is num) {
    return value != 0;
  }

  return value?.toString().toLowerCase() == 'true';
}

String? _readNullableString(Map<String, Object?> map, String key) {
  final value = map[key]?.toString();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

List<String> _readStringList(Object? value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const [];
}

MemberDataExportStatus _readExportStatus(String? value) {
  switch (value?.toUpperCase()) {
    case 'PENDING':
      return MemberDataExportStatus.pending;
    case 'COMPLETED':
      return MemberDataExportStatus.completed;
    case 'FAILED':
      return MemberDataExportStatus.failed;
    case 'EXPIRED':
      return MemberDataExportStatus.expired;
  }
  return MemberDataExportStatus.pending;
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

class AdminDashboard {
  const AdminDashboard({
    required this.todayReportCount,
    required this.openReportCount,
    required this.processedReportCount,
    required this.todayLetterCount,
    required this.todayDiaryCount,
    required this.receivableMemberCount,
    required this.blockedMemberCount,
    required this.adminMemberCount,
    required this.unassignedLetterCount,
    required this.todayAdminActionCount,
  });

  factory AdminDashboard.fromJson(Object? json) {
    final map = _asMap(json);
    return AdminDashboard(
      todayReportCount: _int(map['todayReportCount']),
      openReportCount: _int(map['openReportCount']),
      processedReportCount: _int(map['processedReportCount']),
      todayLetterCount: _int(map['todayLetterCount']),
      todayDiaryCount: _int(map['todayDiaryCount']),
      receivableMemberCount: _int(map['receivableMemberCount']),
      blockedMemberCount: _int(map['blockedMemberCount']),
      adminMemberCount: _int(map['adminMemberCount']),
      unassignedLetterCount: _int(map['unassignedLetterCount']),
      todayAdminActionCount: _int(map['todayAdminActionCount']),
    );
  }

  final int todayReportCount;
  final int openReportCount;
  final int processedReportCount;
  final int todayLetterCount;
  final int todayDiaryCount;
  final int receivableMemberCount;
  final int blockedMemberCount;
  final int adminMemberCount;
  final int unassignedLetterCount;
  final int todayAdminActionCount;
}

class AdminReportMember {
  const AdminReportMember({
    required this.id,
    required this.email,
    required this.nickname,
  });

  factory AdminReportMember.fromJson(Object? json) {
    final map = _asMap(json);
    return AdminReportMember(
      id: _int(map['id']),
      email: _string(map['email']),
      nickname: _string(map['nickname']),
    );
  }

  final int id;
  final String email;
  final String nickname;
}

class AdminReportSummary {
  const AdminReportSummary({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    required this.targetOwner,
    required this.reporter,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.actionCount,
  });

  factory AdminReportSummary.fromJson(Object? json) {
    final map = _asMap(json);
    return AdminReportSummary(
      id: _int(map['id']),
      targetType: _string(map['targetType']),
      targetId: _int(map['targetId']),
      targetTitle: _string(map['targetTitle']),
      targetOwner: map['targetOwner'] == null
          ? null
          : AdminReportMember.fromJson(map['targetOwner']),
      reporter: AdminReportMember.fromJson(map['reporter']),
      reason: _string(map['reason']),
      status: _string(map['status']),
      createdAt: _string(map['createdAt']),
      actionCount: _int(map['actionCount']),
    );
  }

  final int id;
  final String targetType;
  final int targetId;
  final String targetTitle;
  final AdminReportMember? targetOwner;
  final AdminReportMember reporter;
  final String reason;
  final String status;
  final String createdAt;
  final int actionCount;
}

class AdminMemberPage {
  const AdminMemberPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory AdminMemberPage.fromJson(Object? json) {
    final map = _asMap(json);
    return AdminMemberPage(
      content: _asList(map['content'])
          .map(AdminMemberSummary.fromJson)
          .toList(growable: false),
      page: _int(map['page']),
      size: _int(map['size']),
      totalElements: _int(map['totalElements']),
      totalPages: _int(map['totalPages']),
      last: _bool(map['last']),
    );
  }

  final List<AdminMemberSummary> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;
}

class AdminMemberSummary {
  const AdminMemberSummary({
    required this.id,
    required this.email,
    required this.nickname,
    required this.role,
    required this.status,
    required this.socialAccount,
    required this.randomReceiveAllowed,
    required this.reportCount,
    required this.postCount,
    required this.letterCount,
    required this.diaryCount,
  });

  factory AdminMemberSummary.fromJson(Object? json) {
    final map = _asMap(json);
    return AdminMemberSummary(
      id: _int(map['id']),
      email: _string(map['email']),
      nickname: _string(map['nickname']),
      role: _string(map['role']),
      status: _string(map['status']),
      socialAccount: _bool(map['socialAccount']),
      randomReceiveAllowed: _bool(map['randomReceiveAllowed']),
      reportCount: _int(map['reportCount']),
      postCount: _int(map['postCount']),
      letterCount: _int(map['letterCount']),
      diaryCount: _int(map['diaryCount']),
    );
  }

  final int id;
  final String email;
  final String nickname;
  final String role;
  final String status;
  final bool socialAccount;
  final bool randomReceiveAllowed;
  final int reportCount;
  final int postCount;
  final int letterCount;
  final int diaryCount;
}

class AdminLetterPage {
  const AdminLetterPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory AdminLetterPage.fromJson(Object? json) {
    final map = _asMap(json);
    return AdminLetterPage(
      content: _asList(map['content'])
          .map(AdminLetterSummary.fromJson)
          .toList(growable: false),
      page: _int(map['page']),
      size: _int(map['size']),
      totalElements: _int(map['totalElements']),
      totalPages: _int(map['totalPages']),
      last: _bool(map['last']),
    );
  }

  final List<AdminLetterSummary> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;
}

class AdminLetterSummary {
  const AdminLetterSummary({
    required this.id,
    required this.title,
    required this.sender,
    required this.receiver,
    required this.status,
    required this.createdAt,
    required this.originalSummary,
    required this.replySummary,
    required this.availableReceiverCount,
    required this.actionCount,
  });

  factory AdminLetterSummary.fromJson(Object? json) {
    final map = _asMap(json);
    return AdminLetterSummary(
      id: _int(map['id']),
      title: _string(map['title']),
      sender: AdminReportMember.fromJson(map['sender']),
      receiver: map['receiver'] == null
          ? null
          : AdminReportMember.fromJson(map['receiver']),
      status: _string(map['status']),
      createdAt: _string(map['createdAt']),
      originalSummary: _string(map['originalSummary']),
      replySummary:
          map['replySummary'] == null ? null : _string(map['replySummary']),
      availableReceiverCount: _int(map['availableReceiverCount']),
      actionCount: _int(map['actionCount']),
    );
  }

  final int id;
  final String title;
  final AdminReportMember sender;
  final AdminReportMember? receiver;
  final String status;
  final String createdAt;
  final String originalSummary;
  final String? replySummary;
  final int availableReceiverCount;
  final int actionCount;
}

class AdminModerationSummary {
  const AdminModerationSummary({
    required this.totalCount,
    required this.blockedCount,
    required this.modelFailureCount,
    required this.failureRate,
    required this.highRiskCategories,
    required this.modelStatuses,
    required this.targets,
    required this.recentFailures,
  });

  factory AdminModerationSummary.fromJson(Object? json) {
    final map = _asMap(json);
    return AdminModerationSummary(
      totalCount: _int(map['totalCount']),
      blockedCount: _int(map['blockedCount']),
      modelFailureCount: _int(map['modelFailureCount']),
      failureRate: _double(map['failureRate']),
      highRiskCategories: _stringIntMap(map['highRiskCategories']),
      modelStatuses: _stringIntMap(map['modelStatuses']),
      targets: _stringIntMap(map['targets']),
      recentFailures: _asList(map['recentFailures'])
          .map(AdminModerationAudit.fromJson)
          .toList(growable: false),
    );
  }

  final int totalCount;
  final int blockedCount;
  final int modelFailureCount;
  final double failureRate;
  final Map<String, int> highRiskCategories;
  final Map<String, int> modelStatuses;
  final Map<String, int> targets;
  final List<AdminModerationAudit> recentFailures;
}

class AdminModerationAudit {
  const AdminModerationAudit({
    required this.id,
    required this.target,
    required this.riskLevel,
    required this.modelStatus,
    required this.contentSummary,
    required this.createdAt,
  });

  factory AdminModerationAudit.fromJson(Object? json) {
    final map = _asMap(json);
    return AdminModerationAudit(
      id: _int(map['id']),
      target: _string(map['target']),
      riskLevel: _string(map['riskLevel']),
      modelStatus: _string(map['modelStatus']),
      contentSummary: _string(map['contentSummary']),
      createdAt: _string(map['createdAt']),
    );
  }

  final int id;
  final String target;
  final String riskLevel;
  final String modelStatus;
  final String contentSummary;
  final String createdAt;
}

Map<String, Object?> _asMap(Object? json) {
  if (json is Map<String, Object?>) {
    return json;
  }
  if (json is Map) {
    return json.map((key, value) => MapEntry(key.toString(), value));
  }
  throw FormatException('Expected object, got ${json.runtimeType}');
}

List<Object?> _asList(Object? json) {
  if (json == null) {
    return const [];
  }
  if (json is List<Object?>) {
    return json;
  }
  if (json is List) {
    return json.cast<Object?>();
  }
  throw FormatException('Expected list, got ${json.runtimeType}');
}

String _string(Object? value) {
  if (value is String) {
    return value;
  }
  throw FormatException('Expected string, got ${value.runtimeType}');
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Expected int, got ${value.runtimeType}');
}

double _double(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Expected double, got ${value.runtimeType}');
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected bool, got ${value.runtimeType}');
}

Map<String, int> _stringIntMap(Object? json) {
  final map = _asMap(json);
  return map.map((key, value) => MapEntry(key, _int(value)));
}

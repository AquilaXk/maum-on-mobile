import '../../report/domain/report_models.dart';

class OperationsDashboard {
  const OperationsDashboard({
    required this.todayReportCount,
    required this.openReportCount,
    required this.processedReportCount,
    required this.todayLetterCount,
    required this.todayDiaryCount,
    required this.receivableMemberCount,
  });

  factory OperationsDashboard.fromJson(Object? json) {
    final map = _map(json, 'operations dashboard');
    return OperationsDashboard(
      todayReportCount: _int(map['todayReportCount']),
      openReportCount: _int(map['openReportCount']),
      processedReportCount: _int(map['processedReportCount']),
      todayLetterCount: _int(map['todayLetterCount']),
      todayDiaryCount: _int(map['todayDiaryCount']),
      receivableMemberCount: _int(map['receivableMemberCount']),
    );
  }

  final int todayReportCount;
  final int openReportCount;
  final int processedReportCount;
  final int todayLetterCount;
  final int todayDiaryCount;
  final int receivableMemberCount;
}

class MobileApiMetricsSnapshot {
  const MobileApiMetricsSnapshot({
    required this.sampleCount,
    required this.endpoints,
    this.writeRecovery = const MobileWriteRecoveryMetrics(),
    this.notifications = const MobileNotificationMetrics(),
    this.ai = const MobileAiMetrics(),
    this.client = const MobileClientTelemetryMetrics(),
  });

  factory MobileApiMetricsSnapshot.fromJson(Object? json) {
    final map = _map(json, 'mobile api metrics');
    return MobileApiMetricsSnapshot(
      sampleCount: _int(map['sampleCount']),
      endpoints: _list(map['endpoints'])
          .map(MobileApiEndpointMetrics.fromJson)
          .toList(growable: false),
      writeRecovery: MobileWriteRecoveryMetrics.fromJson(
        map['writeRecovery'],
      ),
      notifications: MobileNotificationMetrics.fromJson(map['notifications']),
      ai: MobileAiMetrics.fromJson(map['ai']),
      client: MobileClientTelemetryMetrics.fromJson(map['client']),
    );
  }

  final int sampleCount;
  final List<MobileApiEndpointMetrics> endpoints;
  final MobileWriteRecoveryMetrics writeRecovery;
  final MobileNotificationMetrics notifications;
  final MobileAiMetrics ai;
  final MobileClientTelemetryMetrics client;

  bool get hasData {
    return sampleCount > 0 ||
        endpoints.isNotEmpty ||
        writeRecovery.hasData ||
        notifications.hasData ||
        ai.hasData ||
        client.hasData;
  }

  int get maxP95LatencyMs {
    var maxLatencyMs = 0;
    for (final endpoint in endpoints) {
      if (endpoint.p95LatencyMs > maxLatencyMs) {
        maxLatencyMs = endpoint.p95LatencyMs;
      }
    }
    return maxLatencyMs;
  }

  double get maxErrorRate {
    var maxRate = 0.0;
    for (final endpoint in endpoints) {
      if (endpoint.errorRate > maxRate) {
        maxRate = endpoint.errorRate;
      }
    }
    return maxRate;
  }

  int get appStartCount => client.eventCount('APP_START');

  int get screenViewCount => client.eventCount('SCREEN_VIEW');

  int get apiErrorCount => client.eventCount('API_ERROR');

  int get writeRecoveryEventCount => client.eventCount('WRITE_RECOVERY');
}

class MobileApiEndpointMetrics {
  const MobileApiEndpointMetrics({
    required this.endpoint,
    required this.requestCount,
    required this.successRate,
    required this.p95LatencyMs,
    required this.errorCodes,
  });

  factory MobileApiEndpointMetrics.fromJson(Object? json) {
    final map = _map(json, 'mobile api endpoint metrics');
    return MobileApiEndpointMetrics(
      endpoint: map['endpoint']?.toString() ?? '',
      requestCount: _int(map['requestCount']),
      successRate: _double(map['successRate']),
      p95LatencyMs: _int(map['p95LatencyMs']),
      errorCodes: _countMap(map['errorCodes']),
    );
  }

  final String endpoint;
  final int requestCount;
  final double successRate;
  final int p95LatencyMs;
  final Map<String, int> errorCodes;

  double get errorRate {
    final rate = 1 - successRate;
    if (rate < 0) {
      return 0;
    }
    if (rate > 1) {
      return 1;
    }
    return rate;
  }
}

class MobileWriteRecoveryMetrics {
  const MobileWriteRecoveryMetrics({
    this.duplicatePreventions = const {},
    this.imageLifecycle = const {},
  });

  factory MobileWriteRecoveryMetrics.fromJson(Object? json) {
    if (json == null) {
      return const MobileWriteRecoveryMetrics();
    }
    final map = _map(json, 'mobile write recovery metrics');
    return MobileWriteRecoveryMetrics(
      duplicatePreventions: _countMap(map['duplicatePreventions']),
      imageLifecycle: _countMap(map['imageLifecycle']),
    );
  }

  final Map<String, int> duplicatePreventions;
  final Map<String, int> imageLifecycle;

  bool get hasData {
    return duplicatePreventions.isNotEmpty || imageLifecycle.isNotEmpty;
  }

  int get totalCount {
    return _sumCounts(duplicatePreventions) + _sumCounts(imageLifecycle);
  }
}

class MobileNotificationMetrics {
  const MobileNotificationMetrics({this.pushDelivery = const {}});

  factory MobileNotificationMetrics.fromJson(Object? json) {
    if (json == null) {
      return const MobileNotificationMetrics();
    }
    final map = _map(json, 'mobile notification metrics');
    return MobileNotificationMetrics(
      pushDelivery: _countMap(map['pushDelivery']),
    );
  }

  final Map<String, int> pushDelivery;

  bool get hasData => pushDelivery.isNotEmpty;

  int get totalCount => _sumCounts(pushDelivery);
}

class MobileAiMetrics {
  const MobileAiMetrics({
    this.model = const {},
    this.contentModeration = const {},
    this.consultationSafety = const {},
  });

  factory MobileAiMetrics.fromJson(Object? json) {
    if (json == null) {
      return const MobileAiMetrics();
    }
    final map = _map(json, 'mobile ai metrics');
    return MobileAiMetrics(
      model: _countMap(map['model']),
      contentModeration: _countMap(map['contentModeration']),
      consultationSafety: _countMap(map['consultationSafety']),
    );
  }

  final Map<String, int> model;
  final Map<String, int> contentModeration;
  final Map<String, int> consultationSafety;

  bool get hasData {
    return model.isNotEmpty ||
        contentModeration.isNotEmpty ||
        consultationSafety.isNotEmpty;
  }

  int get totalCount {
    return _sumCounts(model) +
        _sumCounts(contentModeration) +
        _sumCounts(consultationSafety);
  }
}

class MobileClientTelemetryMetrics {
  const MobileClientTelemetryMetrics({
    this.events = const {},
    this.routes = const {},
    this.platforms = const {},
    this.appVersions = const {},
    this.networkStatus = const {},
    this.p95DurationMs = const {},
    this.dropped = const {},
  });

  factory MobileClientTelemetryMetrics.fromJson(Object? json) {
    if (json == null) {
      return const MobileClientTelemetryMetrics();
    }
    final map = _map(json, 'mobile client telemetry metrics');
    return MobileClientTelemetryMetrics(
      events: _countMap(map['events']),
      routes: _countMap(map['routes']),
      platforms: _countMap(map['platforms']),
      appVersions: _countMap(map['appVersions']),
      networkStatus: _countMap(map['networkStatus']),
      p95DurationMs: _countMap(map['p95DurationMs']),
      dropped: _countMap(map['dropped']),
    );
  }

  final Map<String, int> events;
  final Map<String, int> routes;
  final Map<String, int> platforms;
  final Map<String, int> appVersions;
  final Map<String, int> networkStatus;
  final Map<String, int> p95DurationMs;
  final Map<String, int> dropped;

  bool get hasData {
    return events.isNotEmpty ||
        routes.isNotEmpty ||
        platforms.isNotEmpty ||
        appVersions.isNotEmpty ||
        networkStatus.isNotEmpty ||
        p95DurationMs.isNotEmpty ||
        dropped.isNotEmpty;
  }

  int eventCount(String eventType) {
    return events[eventType] ?? 0;
  }

  int get totalEventCount => _sumCounts(events);
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
    final map = _map(json, 'admin member page');
    final content = map['content'];
    if (content is! List) {
      throw const FormatException('Expected admin member content.');
    }

    return AdminMemberPage(
      content: content
          .map(AdminMemberSummary.fromJson)
          .toList(growable: false),
      page: _int(map['page']),
      size: _int(map['size']),
      totalElements: _int(map['totalElements']),
      totalPages: _int(map['totalPages']),
      last: map['last'] == true,
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
    final map = _map(json, 'admin member summary');
    return AdminMemberSummary(
      id: _int(map['id']),
      email: map['email']?.toString() ?? '',
      nickname: map['nickname']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      socialAccount: map['socialAccount'] == true,
      randomReceiveAllowed: map['randomReceiveAllowed'] == true,
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

class AdminMemberDetail {
  const AdminMemberDetail({
    required this.member,
    required this.reports,
    required this.posts,
    required this.letters,
    required this.diaries,
    required this.auditEvents,
  });

  factory AdminMemberDetail.fromJson(Object? json) {
    final map = _map(json, 'admin member detail');
    return AdminMemberDetail(
      member: AdminMemberSummary.fromJson(map['member']),
      reports: _list(map['reports'])
          .map(AdminReportSummary.fromJson)
          .toList(growable: false),
      posts: _list(map['posts'])
          .map(AdminMemberContent.fromJson)
          .toList(growable: false),
      letters: _list(map['letters'])
          .map(AdminMemberContent.fromJson)
          .toList(growable: false),
      diaries: _list(map['diaries'])
          .map(AdminMemberContent.fromJson)
          .toList(growable: false),
      auditEvents: _list(map['auditEvents'])
          .map(AdminAuditEvent.fromJson)
          .toList(growable: false),
    );
  }

  final AdminMemberSummary member;
  final List<AdminReportSummary> reports;
  final List<AdminMemberContent> posts;
  final List<AdminMemberContent> letters;
  final List<AdminMemberContent> diaries;
  final List<AdminAuditEvent> auditEvents;
}

class AdminMemberContent {
  const AdminMemberContent({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  factory AdminMemberContent.fromJson(Object? json) {
    final map = _map(json, 'admin member content');
    return AdminMemberContent(
      id: _int(map['id']),
      title: map['title']?.toString() ?? '',
      status: map['status']?.toString(),
      createdAt: map['createdAt']?.toString() ?? '',
    );
  }

  final int id;
  final String title;
  final String? status;
  final String createdAt;
}

class AdminAuditEvent {
  const AdminAuditEvent({
    required this.id,
    required this.targetMemberId,
    required this.actorMemberId,
    required this.action,
    required this.previousValue,
    required this.newValue,
    required this.reason,
    required this.createdAt,
  });

  factory AdminAuditEvent.fromJson(Object? json) {
    final map = _map(json, 'admin audit event');
    return AdminAuditEvent(
      id: _int(map['id']),
      targetMemberId: _int(map['targetMemberId']),
      actorMemberId: _int(map['actorMemberId']),
      action: map['action']?.toString() ?? '',
      previousValue: map['previousValue']?.toString() ?? '',
      newValue: map['newValue']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
    );
  }

  final int id;
  final int targetMemberId;
  final int actorMemberId;
  final String action;
  final String previousValue;
  final String newValue;
  final String reason;
  final String createdAt;
}

class AdminMemberActionResult {
  const AdminMemberActionResult({
    required this.member,
    required this.status,
    required this.role,
    required this.latestAudit,
  });

  factory AdminMemberActionResult.fromJson(Object? json) {
    final map = _map(json, 'admin member action result');
    return AdminMemberActionResult(
      member: AdminMemberSummary.fromJson(map['member']),
      status: map['status']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      latestAudit: AdminAuditEvent.fromJson(map['latestAudit']),
    );
  }

  final AdminMemberSummary member;
  final String status;
  final String role;
  final AdminAuditEvent latestAudit;
}

class AdminSessionRevokeResult {
  const AdminSessionRevokeResult({
    required this.revokedRefreshTokenCount,
    required this.disabledDeviceTokenCount,
    required this.latestAudit,
  });

  factory AdminSessionRevokeResult.fromJson(Object? json) {
    final map = _map(json, 'admin session revoke result');
    return AdminSessionRevokeResult(
      revokedRefreshTokenCount: _int(map['revokedRefreshTokenCount']),
      disabledDeviceTokenCount: _int(map['disabledDeviceTokenCount']),
      latestAudit: AdminAuditEvent.fromJson(map['latestAudit']),
    );
  }

  final int revokedRefreshTokenCount;
  final int disabledDeviceTokenCount;
  final AdminAuditEvent latestAudit;
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
    final map = _map(json, 'admin letter page');
    return AdminLetterPage(
      content: _list(map['content'])
          .map(AdminLetterSummary.fromJson)
          .toList(growable: false),
      page: _int(map['page']),
      size: _int(map['size']),
      totalElements: _int(map['totalElements']),
      totalPages: _int(map['totalPages']),
      last: map['last'] == true,
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
    final map = _map(json, 'admin letter summary');
    return AdminLetterSummary(
      id: _int(map['id']),
      title: map['title']?.toString() ?? '',
      sender: AdminReportMember.fromJson(map['sender']),
      receiver: map['receiver'] == null
          ? null
          : AdminReportMember.fromJson(map['receiver']),
      status: map['status']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
      originalSummary: map['originalSummary']?.toString() ?? '',
      replySummary: map['replySummary']?.toString(),
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

class AdminLetterDetail {
  const AdminLetterDetail({
    required this.id,
    required this.title,
    required this.sender,
    required this.receiver,
    required this.receivers,
    required this.status,
    required this.createdAt,
    required this.replyCreatedAt,
    required this.originalSummary,
    required this.replySummary,
    required this.auditEvents,
  });

  factory AdminLetterDetail.fromJson(Object? json) {
    final map = _map(json, 'admin letter detail');
    return AdminLetterDetail(
      id: _int(map['id']),
      title: map['title']?.toString() ?? '',
      sender: AdminReportMember.fromJson(map['sender']),
      receiver: map['receiver'] == null
          ? null
          : AdminReportMember.fromJson(map['receiver']),
      receivers: _list(map['receivers'])
          .map(AdminReportMember.fromJson)
          .toList(growable: false),
      status: map['status']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
      replyCreatedAt: map['replyCreatedAt']?.toString(),
      originalSummary: map['originalSummary']?.toString() ?? '',
      replySummary: map['replySummary']?.toString(),
      auditEvents: _list(map['auditEvents'])
          .map(AdminAuditEvent.fromJson)
          .toList(growable: false),
    );
  }

  final int id;
  final String title;
  final AdminReportMember sender;
  final AdminReportMember? receiver;
  final List<AdminReportMember> receivers;
  final String status;
  final String createdAt;
  final String? replyCreatedAt;
  final String originalSummary;
  final String? replySummary;
  final List<AdminAuditEvent> auditEvents;
}

class AdminLetterActionResult {
  const AdminLetterActionResult({
    required this.letter,
    required this.latestAudit,
    required this.revokedRefreshTokenCount,
    required this.disabledDeviceTokenCount,
  });

  factory AdminLetterActionResult.fromJson(Object? json) {
    final map = _map(json, 'admin letter action result');
    return AdminLetterActionResult(
      letter: AdminLetterDetail.fromJson(map['letter']),
      latestAudit: AdminAuditEvent.fromJson(map['latestAudit']),
      revokedRefreshTokenCount: _int(map['revokedRefreshTokenCount']),
      disabledDeviceTokenCount: _int(map['disabledDeviceTokenCount']),
    );
  }

  final AdminLetterDetail letter;
  final AdminAuditEvent latestAudit;
  final int revokedRefreshTokenCount;
  final int disabledDeviceTokenCount;
}

Map<String, Object?> _map(Object? json, String label) {
  if (json is! Map) {
    throw FormatException('Expected $label object.');
  }

  return json.map((key, value) => MapEntry(key.toString(), value));
}

List<Object?> _list(Object? json) {
  if (json == null) {
    return const [];
  }
  if (json is! List) {
    throw const FormatException('Expected list.');
  }
  return json.cast<Object?>();
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

double _double(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, int> _countMap(Object? json) {
  if (json == null) {
    return const {};
  }
  if (json is! Map) {
    throw const FormatException('Expected count map.');
  }

  final entries = json.entries
      .map((entry) => MapEntry(entry.key.toString(), _int(entry.value)))
      .toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return Map.unmodifiable(Map.fromEntries(entries));
}

int _sumCounts(Map<String, int> values) {
  return values.values.fold(0, (total, value) => total + value);
}

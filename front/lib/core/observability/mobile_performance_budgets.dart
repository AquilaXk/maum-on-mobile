enum MobileTelemetryEventType {
  appStart,
  firstInteractive,
  routeChange,
  listScroll,
  mediaAttachment,
  consultationReply,
  networkRecovery,
  duplicatePrevention,
  apiError,
  crash,
}

class MobilePerformanceBudget {
  const MobilePerformanceBudget({
    required this.name,
    required this.owner,
    required this.maxDurationMs,
  });

  final String name;
  final String owner;
  final int maxDurationMs;
}

class MobilePerformanceBudgets {
  const MobilePerformanceBudgets._();

  static const appStart = MobilePerformanceBudget(
    name: 'app_start',
    owner: 'frontend',
    maxDurationMs: 1800,
  );
  static const firstInteractive = MobilePerformanceBudget(
    name: 'first_interactive',
    owner: 'frontend',
    maxDurationMs: 2200,
  );
  static const primaryTabSwitch = MobilePerformanceBudget(
    name: 'primary_tab_switch',
    owner: 'frontend',
    maxDurationMs: 250,
  );
  static const primaryScreenTransition = MobilePerformanceBudget(
    name: 'primary_screen_transition',
    owner: 'frontend',
    maxDurationMs: 350,
  );
  static const listScrollFrame = MobilePerformanceBudget(
    name: 'list_scroll_frame',
    owner: 'frontend',
    maxDurationMs: 16,
  );
  static const feedScrollJank = MobilePerformanceBudget(
    name: 'feed_scroll_jank',
    owner: 'frontend',
    maxDurationMs: 3,
  );
  static const imageAttachmentReady = MobilePerformanceBudget(
    name: 'image_attachment_ready',
    owner: 'frontend',
    maxDurationMs: 1500,
  );
  static const consultationReplyVisible = MobilePerformanceBudget(
    name: 'consultation_reply_visible',
    owner: 'frontend/backend',
    maxDurationMs: 1200,
  );
  static const consultationStreamRecovery = MobilePerformanceBudget(
    name: 'consultation_stream_recovery',
    owner: 'frontend/backend',
    maxDurationMs: 2500,
  );
  static const slowNetworkRecovery = MobilePerformanceBudget(
    name: 'slow_network_recovery',
    owner: 'frontend/backend',
    maxDurationMs: 5000,
  );
  static const duplicateRetryPrevention = MobilePerformanceBudget(
    name: 'duplicate_retry_prevention',
    owner: 'frontend/backend',
    maxDurationMs: 0,
  );

  static const all = [
    appStart,
    firstInteractive,
    primaryTabSwitch,
    primaryScreenTransition,
    listScrollFrame,
    feedScrollJank,
    imageAttachmentReady,
    consultationReplyVisible,
    consultationStreamRecovery,
    slowNetworkRecovery,
    duplicateRetryPrevention,
  ];
}

class MobileTelemetryEvent {
  const MobileTelemetryEvent({
    required this.type,
    required this.name,
    this.durationMs,
    this.attributes = const {},
  });

  final MobileTelemetryEventType type;
  final String name;
  final int? durationMs;
  final Map<String, Object?> attributes;

  Map<String, Object?> toSanitizedPayload() {
    return {
      'type': type.name,
      'name': name,
      if (durationMs != null) 'durationMs': durationMs,
      'attributes': {
        for (final entry in attributes.entries)
          if (!_isSensitiveKey(entry.key) && !_isSensitiveValue(entry.value))
            entry.key: entry.value,
      },
    };
  }

  bool exceeds(MobilePerformanceBudget budget) {
    final duration = durationMs;
    return duration != null && duration > budget.maxDurationMs;
  }
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase();
  return normalized.contains('email') ||
      normalized.contains('authorization') ||
      normalized.contains('auth') ||
      normalized.contains('token') ||
      normalized.contains('password') ||
      normalized.contains('phone') ||
      normalized.contains('content') ||
      normalized.contains('message');
}

bool _isSensitiveValue(Object? value) {
  final text = value?.toString() ?? '';
  return _emailPattern.hasMatch(text) ||
      _phonePattern.hasMatch(text) ||
      _bearerPattern.hasMatch(text);
}

final _emailPattern = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
final _phonePattern = RegExp(r'01[016789][-.\s]?\d{3,4}[-.\s]?\d{4}');
final _bearerPattern = RegExp(
  r'^(bearer|basic)\s+[A-Za-z0-9._~+/=-]+$',
  caseSensitive: false,
);

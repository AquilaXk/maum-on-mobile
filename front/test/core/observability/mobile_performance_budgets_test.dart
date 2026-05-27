import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/observability/mobile_performance_budgets.dart';

void main() {
  test('declares mobile performance budgets for critical flows', () {
    expect(
      MobilePerformanceBudgets.all.map((budget) => budget.name),
      containsAll([
        'app_start',
        'first_interactive',
        'primary_tab_switch',
        'primary_screen_transition',
        'list_scroll_frame',
        'feed_scroll_jank',
        'image_attachment_ready',
        'consultation_reply_visible',
        'consultation_stream_recovery',
        'slow_network_recovery',
        'duplicate_retry_prevention',
      ]),
    );
    expect(MobilePerformanceBudgets.appStart.maxDurationMs, lessThanOrEqualTo(1800));
    expect(
      MobilePerformanceBudgets.firstInteractive.maxDurationMs,
      lessThanOrEqualTo(2200),
    );
    expect(MobilePerformanceBudgets.primaryTabSwitch.maxDurationMs, lessThanOrEqualTo(250));
    expect(
      MobilePerformanceBudgets.primaryScreenTransition.maxDurationMs,
      lessThanOrEqualTo(350),
    );
    expect(MobilePerformanceBudgets.listScrollFrame.maxDurationMs, lessThanOrEqualTo(16));
    expect(
      MobilePerformanceBudgets.feedScrollJank.maxDurationMs,
      lessThanOrEqualTo(3),
    );
    expect(
      MobilePerformanceBudgets.imageAttachmentReady.maxDurationMs,
      lessThanOrEqualTo(1500),
    );
    expect(
      MobilePerformanceBudgets.consultationStreamRecovery.maxDurationMs,
      lessThanOrEqualTo(2500),
    );
    expect(
      MobilePerformanceBudgets.slowNetworkRecovery.maxDurationMs,
      lessThanOrEqualTo(5000),
    );
    expect(
      MobilePerformanceBudgets.duplicateRetryPrevention.maxDurationMs,
      lessThanOrEqualTo(0),
    );
  });

  test('sanitizes telemetry payloads before collection', () {
    const event = MobileTelemetryEvent(
      type: MobileTelemetryEventType.apiError,
      name: 'api_error',
      durationMs: 321,
      attributes: {
        'route': 'GET /api/v1/diaries',
        'email': 'user@example.com',
        'message': '상담 내용 원문',
        'authorization': 'Bearer abc.def.ghi',
        'statusCode': 500,
      },
    );

    final payload = event.toSanitizedPayload();
    final attributes = payload['attributes']! as Map<String, Object?>;

    expect(attributes['route'], 'GET /api/v1/diaries');
    expect(attributes['statusCode'], 500);
    expect(attributes.containsKey('email'), isFalse);
    expect(attributes.containsKey('message'), isFalse);
    expect(attributes.containsKey('authorization'), isFalse);

    for (final authorizationValue in const <String>[
      'bearer abc.def.ghi',
      'Basic Zm9vOmJhcg==',
      'BeArEr mixed.Token',
    ]) {
      final authPayload = MobileTelemetryEvent(
        type: MobileTelemetryEventType.apiError,
        name: 'api_error',
        attributes: {'header': authorizationValue},
      ).toSanitizedPayload();
      final authAttributes =
          authPayload['attributes']! as Map<String, Object?>;

      expect(authAttributes.containsKey('header'), isFalse);
    }
  });

  test('detects budget regressions from measured durations', () {
    const event = MobileTelemetryEvent(
      type: MobileTelemetryEventType.routeChange,
      name: 'primary_tab_switch',
      durationMs: 310,
    );

    expect(event.exceeds(MobilePerformanceBudgets.primaryTabSwitch), isTrue);
  });
}

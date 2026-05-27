import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/legal/domain/legal_disclosures.dart';

void main() {
  test('builds support contact diagnostics without sensitive account data', () {
    const contact = SupportContactInfo(
      supportEmail: 'support@maum-on.app',
      privacyEmail: 'privacy@maum-on.app',
      supportUrl: 'https://maum-on.app/support',
      incidentNoticeUrl: 'https://maum-on.app/status',
      appVersion: '1.2.3',
      buildNumber: '45',
      platform: 'iOS',
    );

    final diagnostics = contact.diagnostics(locale: 'ko-KR');
    final payload = diagnostics.toSafePayload();
    final text = diagnostics.toClipboardText();
    final supportUri = contact.supportMailUri(locale: 'ko-KR');
    final privacyUri = contact.privacyMailUri(locale: 'ko-KR');

    expect(payload, {
      'appVersion': '1.2.3',
      'buildNumber': '45',
      'platform': 'iOS',
      'locale': 'ko-KR',
    });
    expect(text, contains('appVersion=1.2.3'));
    expect(text, contains('buildNumber=45'));
    expect(text, contains('platform=iOS'));
    expect(text, contains('locale=ko-KR'));
    expect(text, isNot(contains('email')));
    expect(text, isNot(contains('memberId')));
    expect(text, isNot(contains('token')));
    expect(text, isNot(contains('password')));
    expect(supportUri.scheme, 'mailto');
    expect(supportUri.path, 'support@maum-on.app');
    expect(supportUri.queryParameters['subject'], contains('고객지원'));
    expect(supportUri.queryParameters['body'], contains('appVersion=1.2.3'));
    expect(privacyUri.path, 'privacy@maum-on.app');
    expect(privacyUri.queryParameters['subject'], contains('개인정보'));
  });
}

class LegalDisclosureLink {
  const LegalDisclosureLink({
    required this.id,
    required this.label,
    required this.uri,
    required this.semanticLabel,
  });

  final String id;
  final String label;
  final String uri;
  final String semanticLabel;

  Uri get parsedUri => Uri.parse(uri);
}

class LegalDisclosures {
  const LegalDisclosures._();

  static const privacyPolicyUrl = 'https://maum-on.app/privacy';
  static const termsUrl = 'https://maum-on.app/terms';
  static const supportEmail = 'support@maum-on.app';
  static const privacyEmail = 'privacy@maum-on.app';
  static const supportUrl = 'https://maum-on.app/support';
  static const incidentNoticeUrl = 'https://maum-on.app/status';

  static const defaultSupportContact = SupportContactInfo(
    supportEmail: supportEmail,
    privacyEmail: privacyEmail,
    supportUrl: supportUrl,
    incidentNoticeUrl: incidentNoticeUrl,
    appVersion: '0.1.0',
    buildNumber: '1',
    platform: 'unknown',
  );

  static const reviewSupportStatus = ReviewSupportStatus(
    owner: 'mobile-release-owner',
    contactEmail: supportEmail,
    privacyEmail: privacyEmail,
    incidentNoticeUrl: incidentNoticeUrl,
    responseSlaHours: 24,
    appStoreReviewStatus: 'ready',
    googlePlayReviewStatus: 'ready',
  );

  static const links = <LegalDisclosureLink>[
    LegalDisclosureLink(
      id: 'privacy-policy',
      label: '개인정보 처리방침',
      uri: privacyPolicyUrl,
      semanticLabel: '개인정보 처리방침 열기',
    ),
    LegalDisclosureLink(
      id: 'terms',
      label: '이용약관',
      uri: termsUrl,
      semanticLabel: '이용약관 열기',
    ),
    LegalDisclosureLink(
      id: 'support',
      label: '지원 문의',
      uri: 'mailto:$supportEmail',
      semanticLabel: '지원 문의 보내기',
    ),
  ];

  static const accountDeletionGuidance = '계정 삭제는 로그인 후 설정의 회원 탈퇴에서 진행할 수 있습니다.';
}

class SupportContactInfo {
  const SupportContactInfo({
    required this.supportEmail,
    required this.privacyEmail,
    required this.supportUrl,
    required this.incidentNoticeUrl,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    this.locale = 'ko-KR',
  });

  final String supportEmail;
  final String privacyEmail;
  final String supportUrl;
  final String incidentNoticeUrl;
  final String appVersion;
  final String buildNumber;
  final String platform;
  final String locale;

  SupportDiagnosticInfo diagnostics({String? locale}) {
    return SupportDiagnosticInfo(
      appVersion: appVersion,
      buildNumber: buildNumber,
      platform: platform,
      locale: locale ?? this.locale,
    );
  }

  Uri supportMailUri({String? locale}) {
    return _mailUri(
      email: supportEmail,
      subject: 'Maum On 고객지원 문의',
      diagnostics: diagnostics(locale: locale),
    );
  }

  Uri privacyMailUri({String? locale}) {
    return _mailUri(
      email: privacyEmail,
      subject: 'Maum On 개인정보 문의',
      diagnostics: diagnostics(locale: locale),
    );
  }

  Uri get incidentNoticeUri => Uri.parse(incidentNoticeUrl);

  Uri _mailUri({
    required String email,
    required String subject,
    required SupportDiagnosticInfo diagnostics,
  }) {
    return Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': '문의 내용을 입력해 주세요.\n\n진단 정보\n${diagnostics.toClipboardText()}',
      },
    );
  }
}

class SupportDiagnosticInfo {
  const SupportDiagnosticInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.locale,
  });

  final String appVersion;
  final String buildNumber;
  final String platform;
  final String locale;

  Map<String, String> toSafePayload() {
    return {
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'platform': platform,
      'locale': locale,
    };
  }

  String toClipboardText() {
    return toSafePayload()
        .entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('\n');
  }
}

class ReviewSupportStatus {
  const ReviewSupportStatus({
    required this.owner,
    required this.contactEmail,
    required this.privacyEmail,
    required this.incidentNoticeUrl,
    required this.responseSlaHours,
    required this.appStoreReviewStatus,
    required this.googlePlayReviewStatus,
  });

  final String owner;
  final String contactEmail;
  final String privacyEmail;
  final String incidentNoticeUrl;
  final int responseSlaHours;
  final String appStoreReviewStatus;
  final String googlePlayReviewStatus;

  String get responseSlaLabel => '$responseSlaHours시간 이내';
}

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
  static const dataExportGuidance = '내 데이터 내보내기와 탈퇴 보존 정책은 설정에서 확인할 수 있습니다.';
}

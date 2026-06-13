import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/settings/application/settings_controller.dart';
import 'package:maum_on_mobile_front/features/settings/data/settings_repository.dart';
import 'package:maum_on_mobile_front/features/settings/domain/settings_models.dart';
import 'package:maum_on_mobile_front/features/settings/presentation/settings_screen.dart';
import 'package:maum_on_mobile_front/features/legal/domain/legal_disclosures.dart';
import 'package:maum_on_mobile_front/shared/ui/app_design_system.dart';

void main() {
  testWidgets('shows compact account status on a phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeSettingsRepository();
    final controller = SettingsController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-account-toolbar')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-flow-panel')), findsNothing);
    expect(find.text('계정 점검 흐름'), findsNothing);
    expect(find.text('계정 정보, 보안 항목, 지원 채널을 순서대로 확인합니다.'), findsNothing);
    expect(find.text('이메일 계정'), findsOneWidget);
    expect(find.text('랜덤 편지 수신 중'), findsOneWidget);
    expect(find.text('내보내기 요청 가능'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-profile-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-routine-group-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-security-group-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-support-group-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-danger-group-header')),
      findsOneWidget,
    );

    final routineTop = tester
        .getRect(find.byKey(const ValueKey('settings-routine-group-header')))
        .top;
    final profileTop = tester
        .getRect(find.byKey(const ValueKey('settings-profile-section')))
        .top;
    final securityTop = tester
        .getRect(find.byKey(const ValueKey('settings-security-group-header')))
        .top;
    final dangerTop = tester
        .getRect(find.byKey(const ValueKey('settings-danger-group-header')))
        .top;

    expect(profileTop, greaterThan(routineTop));
    expect(securityTop, greaterThan(profileTop));
    expect(dangerTop, greaterThan(securityTop));

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('settings-scroll')),
    );
    final padding = scrollView.padding! as EdgeInsets;
    expect(
      padding.bottom,
      greaterThanOrEqualTo(AppSpacing.persistentNavigationReserve),
    );
  });

  testWidgets('renders settings and submits account changes', (tester) async {
    final repository = _FakeSettingsRepository();
    final controller = SettingsController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsNothing);
    expect(
      find.byKey(const ValueKey('settings-account-toolbar')),
      findsOneWidget,
    );
    expect(find.text('랜덤 편지 수신 중'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('settings-account-section')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('settings-profile-section')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-account-toolbar')),
        matching: find.text('me@example.com'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('settings-nickname-field')),
      '새 닉네임',
    );
    await tester.tap(find.byKey(const ValueKey('settings-save-nickname')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('settings-email-field')),
      'new@example.com',
    );
    await tester
        .ensureVisible(find.byKey(const ValueKey('settings-save-email')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-save-email')));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-random-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-random-toggle')));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-request-data-export')),
    );
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('settings-request-data-export')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('settings-download-data-export')));
    await tester.pump();

    expect(repository.nicknameUpdates, ['새 닉네임']);
    expect(repository.emailUpdates, ['new@example.com']);
    expect(repository.randomToggleCount, 1);
    expect(repository.exportRequestCount, 1);
    expect(repository.downloadedExportIds, [1]);
    expect(find.textContaining('maum-on-data-export-1.json'), findsWidgets);
  });

  testWidgets('설정 화면 계정 영역에서 로그아웃을 실행한다', (tester) async {
    var logoutCount = 0;
    final repository = _FakeSettingsRepository();
    final controller = SettingsController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          onBack: () {},
          onLogout: () => logoutCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('로그아웃'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-account-toolbar')),
        matching: find.byKey(const ValueKey('settings-logout-button')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('settings-logout-button')));
    await tester.pumpAndSettle();

    expect(logoutCount, 1);
  });

  testWidgets('설정 저장 중에는 로그아웃을 비활성화한다', (tester) async {
    var logoutCount = 0;
    final nicknameUpdateDelay = Completer<void>();
    final repository = _FakeSettingsRepository(
      nicknameUpdateDelay: nicknameUpdateDelay,
    );
    final controller = SettingsController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          onBack: () {},
          onLogout: () => logoutCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('settings-nickname-field')),
      '저장 중 닉네임',
    );
    await tester.tap(find.byKey(const ValueKey('settings-save-nickname')));
    await tester.pump();

    final logoutButton = find.byKey(const ValueKey('settings-logout-button'));
    expect(tester.widget<OutlinedButton>(logoutButton).onPressed, isNull);

    await tester.tap(logoutButton);
    await tester.pump();
    expect(logoutCount, 0);

    nicknameUpdateDelay.complete();
    await tester.pumpAndSettle();

    expect(tester.widget<OutlinedButton>(logoutButton).onPressed, isNotNull);
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(logoutCount, 1);
  });

  testWidgets('confirms withdrawal and clears session', (tester) async {
    var cleaned = false;
    final repository = _FakeSettingsRepository();
    final controller = SettingsController(
      repository: repository,
      onWithdrawn: () async {
        cleaned = true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-request-withdraw')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-request-withdraw')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-withdraw-password')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('settings-withdraw-password')),
      'old-password',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-confirm-withdraw')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-confirm-withdraw')));
    await tester.pump();

    expect(repository.withdrawPasswords, ['old-password']);
    expect(cleaned, isTrue);
  });

  testWidgets('exposes privacy disclosures and withdrawal action',
      (tester) async {
    final repository = _FakeSettingsRepository();
    final controller = SettingsController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-privacy-policy-link')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-privacy-policy-link')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('settings-terms-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-support-link')), findsOneWidget);
    expect(find.textContaining('내 데이터'), findsWidgets);
    expect(find.byKey(const ValueKey('settings-request-withdraw')),
        findsOneWidget);
  });

  testWidgets('keeps settings sections free of helper explanation copy',
      (tester) async {
    final repository = _FakeSettingsRepository()
      ..settings = const MemberSettings(
        id: 7,
        email: 'me@example.com',
        nickname: '마음이',
        randomReceiveAllowed: true,
        socialAccount: true,
      );
    final controller = SettingsController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('계정 삭제는 아래 회원 탈퇴에서 처리하며, 보존 정책을 먼저 확인해 주세요.'),
      findsNothing,
    );
    expect(
      find.text('탈퇴 전 데이터 내보내기와 보존 정책을 확인해 주세요.'),
      findsNothing,
    );
    expect(
      find.text('내 데이터 내보내기와 탈퇴 보존 정책은 설정에서 확인할 수 있습니다.'),
      findsNothing,
    );
    expect(
      find.text('문의에는 앱 버전, 빌드 번호, 플랫폼, locale 진단 정보만 포함됩니다.'),
      findsNothing,
    );

    final emailField = tester.widget<TextField>(
      find.byKey(const ValueKey('settings-email-field')),
    );
    final currentPasswordField = tester.widget<TextField>(
      find.byKey(const ValueKey('settings-current-password-field')),
    );

    expect(emailField.decoration?.helperText, isNull);
    expect(currentPasswordField.decoration?.helperText, isNull);
    expect(emailField.enabled, isFalse);
    expect(currentPasswordField.enabled, isFalse);
  });

  testWidgets('opens support contacts and copies sanitized diagnostics',
      (tester) async {
    final repository = _FakeSettingsRepository();
    final controller = SettingsController(repository: repository);
    final openedUris = <Uri>[];
    final copiedDiagnostics = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          onBack: () {},
          supportContactInfo: const SupportContactInfo(
            supportEmail: 'support@maum-on.app',
            privacyEmail: 'privacy@maum-on.app',
            supportUrl: 'https://maum-on.app/support',
            incidentNoticeUrl: 'https://maum-on.app/status',
            appVersion: '1.2.3',
            buildNumber: '45',
            platform: 'Android',
          ),
          onOpenExternalUri: (uri) async {
            openedUris.add(uri);
            return true;
          },
          onCopyDiagnostics: (value) async {
            copiedDiagnostics.add(value);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-support-contact-button')),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('settings-support-section')), findsOneWidget);
    expect(find.text('고객지원'), findsWidgets);
    expect(find.text('개인정보 문의'), findsOneWidget);
    expect(find.text('장애 공지'), findsOneWidget);
    expect(find.text('앱 버전'), findsOneWidget);
    expect(find.bySemanticsLabel('앱 버전, 1.2.3'), findsOneWidget);
    expect(find.text('빌드 번호'), findsOneWidget);
    expect(find.bySemanticsLabel('빌드 번호, 45'), findsOneWidget);
    expect(find.text('플랫폼'), findsOneWidget);
    expect(find.bySemanticsLabel('플랫폼, Android'), findsOneWidget);
    expect(find.text('locale'), findsOneWidget);
    expect(find.bySemanticsLabel('locale, ko-KR'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('settings-support-contact-button')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('settings-privacy-contact-button')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('settings-incident-notice-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-copy-diagnostics')));
    await tester.pumpAndSettle();

    expect(openedUris[0].scheme, 'mailto');
    expect(openedUris[0].path, 'support@maum-on.app');
    expect(openedUris[0].queryParameters['body'], contains('appVersion=1.2.3'));
    expect(openedUris[0].queryParameters['body'], contains('buildNumber=45'));
    expect(openedUris[0].queryParameters['body'], contains('platform=Android'));
    expect(openedUris[0].queryParameters['body'], contains('locale=ko-KR'));
    expect(openedUris[0].queryParameters['body'],
        isNot(contains('me@example.com')));
    expect(openedUris[1].path, 'privacy@maum-on.app');
    expect(openedUris[2].toString(), 'https://maum-on.app/status');
    expect(copiedDiagnostics.single, contains('appVersion=1.2.3'));
    expect(copiedDiagnostics.single, contains('buildNumber=45'));
    expect(copiedDiagnostics.single, contains('platform=Android'));
    expect(copiedDiagnostics.single, contains('locale=ko-KR'));
    expect(copiedDiagnostics.single, isNot(contains('me@example.com')));
    expect(copiedDiagnostics.single, isNot(contains('memberId')));
    expect(copiedDiagnostics.single, isNot(contains('token')));
  });

  testWidgets('stacks support actions on a narrow phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeSettingsRepository();
    final controller = SettingsController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          onBack: () {},
          supportContactInfo: const SupportContactInfo(
            supportEmail: 'support@maum-on.app',
            privacyEmail: 'privacy@maum-on.app',
            supportUrl: 'https://maum-on.app/support',
            incidentNoticeUrl: 'https://maum-on.app/status',
            appVersion: '1.2.3',
            buildNumber: '45',
            platform: 'Android',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-copy-diagnostics')),
    );
    await tester.pumpAndSettle();

    final supportRect = tester.getRect(
      find.byKey(const ValueKey('settings-support-contact-button')),
    );
    final privacyRect = tester.getRect(
      find.byKey(const ValueKey('settings-privacy-contact-button')),
    );
    final incidentRect = tester.getRect(
      find.byKey(const ValueKey('settings-incident-notice-button')),
    );
    final copyRect = tester.getRect(
      find.byKey(const ValueKey('settings-copy-diagnostics')),
    );

    for (final rect in [supportRect, privacyRect, incidentRect, copyRect]) {
      expect(rect.width, greaterThanOrEqualTo(240));
    }
    expect(privacyRect.top, greaterThan(supportRect.bottom));
    expect(incidentRect.top, greaterThan(privacyRect.bottom));
    expect(copyRect.top, greaterThan(incidentRect.bottom));
  });
}

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({this.nicknameUpdateDelay});

  final Completer<void>? nicknameUpdateDelay;
  final List<String> nicknameUpdates = [];
  final List<String> emailUpdates = [];
  final List<String?> withdrawPasswords = [];
  final List<int> downloadedExportIds = [];
  int randomToggleCount = 0;
  int exportRequestCount = 0;
  MemberSettings settings = const MemberSettings(
    id: 7,
    email: 'me@example.com',
    nickname: '마음이',
    randomReceiveAllowed: true,
    socialAccount: false,
  );

  @override
  Future<MemberSettings> fetchSettings() async => settings;

  @override
  Future<MemberSettings> updateNickname(String nickname) async {
    nicknameUpdates.add(nickname);
    await nicknameUpdateDelay?.future;
    settings = settings.copyWith(nickname: nickname);
    return settings;
  }

  @override
  Future<MemberSettings> updateEmail(String email) async {
    emailUpdates.add(email);
    settings = settings.copyWith(email: email);
    return settings;
  }

  @override
  Future<MemberSettings> updatePassword(PasswordChangeDraft draft) async {
    return settings;
  }

  @override
  Future<MemberSettings> toggleRandomSetting() async {
    randomToggleCount += 1;
    settings = settings.copyWith(
      randomReceiveAllowed: !settings.randomReceiveAllowed,
    );
    return settings;
  }

  @override
  Future<MemberDataExportJob> requestDataExport() async {
    exportRequestCount += 1;
    return const MemberDataExportJob(
      id: 1,
      status: MemberDataExportStatus.completed,
      requestedAt: '2026-05-26T00:00:00Z',
      completedAt: '2026-05-26T00:00:00Z',
      expiresAt: '2999-05-27T00:00:00Z',
      downloadUrl: '/api/v1/members/me/data-exports/1/download',
    );
  }

  @override
  Future<MemberDataExportJob> fetchDataExportStatus(int exportId) async {
    return MemberDataExportJob(
      id: exportId,
      status: MemberDataExportStatus.completed,
      requestedAt: '2026-05-26T00:00:00Z',
      completedAt: '2026-05-26T00:00:00Z',
      expiresAt: '2999-05-27T00:00:00Z',
      downloadUrl: '/api/v1/members/me/data-exports/$exportId/download',
    );
  }

  @override
  Future<MemberDataExportFile> downloadDataExport(int exportId) async {
    downloadedExportIds.add(exportId);
    return MemberDataExportFile(
      filename: 'maum-on-data-export-$exportId.json',
      contentType: 'application/json',
      content: '{"account":{}}',
      expiresAt: '2999-05-27T00:00:00Z',
    );
  }

  @override
  Future<void> withdraw({String? currentPassword}) async {
    withdrawPasswords.add(currentPassword);
  }
}

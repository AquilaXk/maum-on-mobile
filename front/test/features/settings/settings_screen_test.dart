import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/settings/application/settings_controller.dart';
import 'package:maum_on_mobile_front/features/settings/data/settings_repository.dart';
import 'package:maum_on_mobile_front/features/settings/domain/settings_models.dart';
import 'package:maum_on_mobile_front/features/settings/presentation/settings_screen.dart';

void main() {
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

    expect(find.text('설정'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);

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
    await tester.tap(find.byKey(const ValueKey('settings-save-email')));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-random-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-random-toggle')));
    await tester.pump();

    expect(repository.nicknameUpdates, ['새 닉네임']);
    expect(repository.emailUpdates, ['new@example.com']);
    expect(repository.randomToggleCount, 1);
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
}

class _FakeSettingsRepository implements SettingsRepository {
  final List<String> nicknameUpdates = [];
  final List<String> emailUpdates = [];
  final List<String?> withdrawPasswords = [];
  int randomToggleCount = 0;
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
  Future<void> withdraw({String? currentPassword}) async {
    withdrawPasswords.add(currentPassword);
  }
}

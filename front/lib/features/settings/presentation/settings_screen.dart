import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../application/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.controller,
    required this.onBack,
    super.key,
  });

  final SettingsController controller;
  final VoidCallback onBack;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _emailController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _withdrawPasswordController;

  @override
  void initState() {
    super.initState();
    final state = widget.controller.state;
    _nicknameController = TextEditingController(text: state.nicknameDraft);
    _emailController = TextEditingController(text: state.emailDraft);
    _currentPasswordController =
        TextEditingController(text: state.currentPasswordDraft);
    _newPasswordController =
        TextEditingController(text: state.newPasswordDraft);
    _withdrawPasswordController =
        TextEditingController(text: state.withdrawPasswordDraft);
    unawaited(widget.controller.load());
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller &&
        !widget.controller.state.hasLoaded) {
      unawaited(widget.controller.load());
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _withdrawPasswordController.dispose();
    super.dispose();
  }

  void _syncFields(SettingsState state) {
    _syncText(_nicknameController, state.nicknameDraft);
    _syncText(_emailController, state.emailDraft);
    _syncText(_currentPasswordController, state.currentPasswordDraft);
    _syncText(_newPasswordController, state.newPasswordDraft);
    _syncText(_withdrawPasswordController, state.withdrawPasswordDraft);
  }

  void _syncText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        _syncFields(state);

        if (state.isLoading && !state.hasLoaded) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _SettingsHeader(onBack: widget.onBack),
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: AppStateView.loading(
                          title: '설정을 불러오는 중입니다.',
                          semanticLabel: '계정 설정을 불러오는 중',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final settings = state.settings;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _SettingsHeader(onBack: widget.onBack),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('settings-scroll'),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (state.errorMessage != null) ...[
                              _InlineNotice(
                                message: state.errorMessage!,
                                isError: true,
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (state.noticeMessage != null) ...[
                              _InlineNotice(message: state.noticeMessage!),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (settings == null)
                              state.hasLoaded
                                  ? const AppStateView.error(
                                      title: '설정을 불러오지 못했습니다.',
                                      message: '네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
                                      semanticLabel: '계정 설정 로드 실패',
                                    )
                                  : const AppStateView.loading(
                                      title: '설정을 불러오는 중입니다.',
                                      semanticLabel: '계정 설정을 불러오는 중',
                                    )
                            else ...[
                              _AccountSummary(
                                email: settings.email,
                                nickname: settings.nickname,
                                isSocialAccount: settings.socialAccount,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _ProfileSection(
                                nicknameController: _nicknameController,
                                isSubmitting: state.isSubmitting,
                                onChanged:
                                    widget.controller.updateNicknameDraft,
                                onSave: widget.controller.saveNickname,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _EmailSection(
                                emailController: _emailController,
                                isSocialAccount: settings.socialAccount,
                                isSubmitting: state.isSubmitting,
                                onChanged: widget.controller.updateEmailDraft,
                                onSave: widget.controller.saveEmail,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _PasswordSection(
                                currentPasswordController:
                                    _currentPasswordController,
                                newPasswordController: _newPasswordController,
                                isSocialAccount: settings.socialAccount,
                                isSubmitting: state.isSubmitting,
                                onCurrentPasswordChanged: widget
                                    .controller.updateCurrentPasswordDraft,
                                onNewPasswordChanged:
                                    widget.controller.updateNewPasswordDraft,
                                onSave: widget.controller.savePassword,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _RandomReceiveSection(
                                value: settings.randomReceiveAllowed,
                                isSubmitting: state.isSubmitting,
                                onChanged: (_) =>
                                    widget.controller.toggleRandomSetting(),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _WithdrawalSection(
                                state: state,
                                withdrawPasswordController:
                                    _withdrawPasswordController,
                                onRequest:
                                    widget.controller.requestWithdrawal,
                                onCancel: widget.controller.cancelWithdrawal,
                                onPasswordChanged: widget
                                    .controller.updateWithdrawPasswordDraft,
                                onConfirm:
                                    widget.controller.confirmWithdrawal,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: AppScreenHeader(
        eyebrow: '설정',
        title: '계정 설정',
        onBack: onBack,
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({
    required this.email,
    required this.nickname,
    required this.isSocialAccount,
  });

  final String email;
  final String nickname;
  final bool isSocialAccount;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nickname,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text('$email · ${isSocialAccount ? '소셜 계정' : '이메일 계정'}'),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.nicknameController,
    required this.isSubmitting,
    required this.onChanged,
    required this.onSave,
  });

  final TextEditingController nicknameController;
  final bool isSubmitting;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '프로필',
      children: [
        TextField(
          key: const ValueKey('settings-nickname-field'),
          controller: nicknameController,
          decoration: const InputDecoration(labelText: '닉네임'),
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const ValueKey('settings-save-nickname'),
            onPressed: isSubmitting ? null : () => onSave(),
            child: const Text('닉네임 저장'),
          ),
        ),
      ],
    );
  }
}

class _EmailSection extends StatelessWidget {
  const _EmailSection({
    required this.emailController,
    required this.isSocialAccount,
    required this.isSubmitting,
    required this.onChanged,
    required this.onSave,
  });

  final TextEditingController emailController;
  final bool isSocialAccount;
  final bool isSubmitting;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '이메일',
      children: [
        TextField(
          key: const ValueKey('settings-email-field'),
          controller: emailController,
          decoration: InputDecoration(
            labelText: '이메일',
            helperText: isSocialAccount ? '소셜 계정은 이메일을 변경할 수 없습니다.' : null,
          ),
          enabled: !isSocialAccount,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const ValueKey('settings-save-email'),
            onPressed: isSubmitting || isSocialAccount ? null : () => onSave(),
            child: const Text('이메일 저장'),
          ),
        ),
      ],
    );
  }
}

class _PasswordSection extends StatelessWidget {
  const _PasswordSection({
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.isSocialAccount,
    required this.isSubmitting,
    required this.onCurrentPasswordChanged,
    required this.onNewPasswordChanged,
    required this.onSave,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final bool isSocialAccount;
  final bool isSubmitting;
  final ValueChanged<String> onCurrentPasswordChanged;
  final ValueChanged<String> onNewPasswordChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '비밀번호',
      children: [
        TextField(
          key: const ValueKey('settings-current-password-field'),
          controller: currentPasswordController,
          decoration: InputDecoration(
            labelText: '현재 비밀번호',
            helperText: isSocialAccount ? '소셜 계정은 비밀번호를 변경할 수 없습니다.' : null,
          ),
          enabled: !isSocialAccount,
          obscureText: true,
          textInputAction: TextInputAction.next,
          onChanged: onCurrentPasswordChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('settings-new-password-field'),
          controller: newPasswordController,
          decoration: const InputDecoration(labelText: '새 비밀번호'),
          enabled: !isSocialAccount,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onChanged: onNewPasswordChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const ValueKey('settings-save-password'),
            onPressed:
                isSubmitting || isSocialAccount ? null : () => onSave(),
            child: const Text('비밀번호 저장'),
          ),
        ),
      ],
    );
  }
}

class _RandomReceiveSection extends StatelessWidget {
  const _RandomReceiveSection({
    required this.value,
    required this.isSubmitting,
    required this.onChanged,
  });

  final bool value;
  final bool isSubmitting;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '랜덤 편지',
      children: [
        Row(
          children: [
            const Expanded(child: Text('랜덤 편지 수신')),
            Switch(
              key: const ValueKey('settings-random-toggle'),
              value: value,
              onChanged: isSubmitting ? null : onChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _WithdrawalSection extends StatelessWidget {
  const _WithdrawalSection({
    required this.state,
    required this.withdrawPasswordController,
    required this.onRequest,
    required this.onCancel,
    required this.onPasswordChanged,
    required this.onConfirm,
  });

  final SettingsState state;
  final TextEditingController withdrawPasswordController;
  final VoidCallback onRequest;
  final VoidCallback onCancel;
  final ValueChanged<String> onPasswordChanged;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '회원 탈퇴',
      children: [
        if (!state.isWithdrawConfirmVisible)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const ValueKey('settings-request-withdraw'),
              onPressed: state.isSubmitting ? null : onRequest,
              child: const Text('회원 탈퇴'),
            ),
          )
        else ...[
          const Text('탈퇴하면 계정과 세션이 정리됩니다.'),
          if (!state.isSocialAccount) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('settings-withdraw-password'),
              controller: withdrawPasswordController,
              decoration: const InputDecoration(labelText: '현재 비밀번호'),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onChanged: onPasswordChanged,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                onPressed: state.isSubmitting ? null : onCancel,
                child: const Text('취소'),
              ),
              FilledButton(
                key: const ValueKey('settings-confirm-withdraw'),
                onPressed: state.isSubmitting ? null : () => onConfirm(),
                child: const Text('탈퇴 확인'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return AppNotice(
      message: message,
      tone: isError ? AppNoticeTone.error : AppNoticeTone.success,
    );
  }
}

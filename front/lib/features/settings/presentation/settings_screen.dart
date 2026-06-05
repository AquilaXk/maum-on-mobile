import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/ui/app_design_system.dart';
import '../../legal/domain/legal_disclosures.dart';
import '../../legal/presentation/legal_disclosure_links.dart';
import '../application/settings_controller.dart';
import '../domain/settings_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.controller,
    required this.onBack,
    this.supportContactInfo = LegalDisclosures.defaultSupportContact,
    this.onOpenExternalUri,
    this.onCopyDiagnostics,
    super.key,
  });

  final SettingsController controller;
  final VoidCallback onBack;
  final SupportContactInfo supportContactInfo;
  final Future<bool> Function(Uri uri)? onOpenExternalUri;
  final Future<void> Function(String value)? onCopyDiagnostics;

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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.persistentNavigationReserve,
                    ),
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
                                randomReceiveAllowed:
                                    settings.randomReceiveAllowed,
                                dataExport: state.dataExport,
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
                              _DataExportSection(
                                state: state,
                                onRequest: widget.controller.requestDataExport,
                                onRefresh: widget.controller.refreshDataExport,
                                onDownload:
                                    widget.controller.downloadDataExport,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _RetentionPolicySection(
                                policy: settings.retentionPolicy,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _PrivacyDisclosureSection(
                                onOpenExternalUri: widget.onOpenExternalUri,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _SupportContactSection(
                                contactInfo: widget.supportContactInfo,
                                onOpenExternalUri: widget.onOpenExternalUri,
                                onCopyDiagnostics: widget.onCopyDiagnostics,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _WithdrawalSection(
                                state: state,
                                withdrawPasswordController:
                                    _withdrawPasswordController,
                                onRequest: widget.controller.requestWithdrawal,
                                onCancel: widget.controller.cancelWithdrawal,
                                onPasswordChanged: widget
                                    .controller.updateWithdrawPasswordDraft,
                                onConfirm: widget.controller.confirmWithdrawal,
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

class _PrivacyDisclosureSection extends StatelessWidget {
  const _PrivacyDisclosureSection({this.onOpenExternalUri});

  final Future<bool> Function(Uri uri)? onOpenExternalUri;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '개인정보와 지원',
      children: [
        const Text(LegalDisclosures.dataExportGuidance),
        const SizedBox(height: AppSpacing.xs),
        const Text('계정 삭제는 아래 회원 탈퇴에서 처리하며, 보존 정책을 먼저 확인해 주세요.'),
        const SizedBox(height: AppSpacing.md),
        LegalDisclosureLinks(
          keyPrefix: 'settings',
          onOpenExternalUri: onOpenExternalUri,
          showAccountDeletionGuidance: false,
        ),
      ],
    );
  }
}

class _SupportContactSection extends StatelessWidget {
  const _SupportContactSection({
    required this.contactInfo,
    this.onOpenExternalUri,
    this.onCopyDiagnostics,
  });

  final SupportContactInfo contactInfo;
  final Future<bool> Function(Uri uri)? onOpenExternalUri;
  final Future<void> Function(String value)? onCopyDiagnostics;

  @override
  Widget build(BuildContext context) {
    final diagnostics = contactInfo.diagnostics();

    return _SettingsSection(
      key: const ValueKey('settings-support-section'),
      title: '고객지원',
      children: [
        const Text('문의에는 앱 버전, 빌드 번호, 플랫폼, locale 진단 정보만 포함됩니다.'),
        const SizedBox(height: AppSpacing.md),
        AppDetailRow(label: '앱 버전', value: diagnostics.appVersion),
        AppDetailRow(label: '빌드 번호', value: diagnostics.buildNumber),
        AppDetailRow(label: '플랫폼', value: diagnostics.platform),
        AppDetailRow(label: 'locale', value: diagnostics.locale),
        const SizedBox(height: AppSpacing.md),
        _SupportActionButtons(
          contactInfo: contactInfo,
          diagnostics: diagnostics,
          onOpenExternalUri: onOpenExternalUri,
          onCopyDiagnostics: onCopyDiagnostics,
        ),
      ],
    );
  }
}

class _SupportActionButtons extends StatelessWidget {
  const _SupportActionButtons({
    required this.contactInfo,
    required this.diagnostics,
    this.onOpenExternalUri,
    this.onCopyDiagnostics,
  });

  final SupportContactInfo contactInfo;
  final SupportDiagnosticInfo diagnostics;
  final Future<bool> Function(Uri uri)? onOpenExternalUri;
  final Future<void> Function(String value)? onCopyDiagnostics;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveActionWrap(
      alignment: WrapAlignment.end,
      children: [
        FilledButton.icon(
          key: const ValueKey('settings-support-contact-button'),
          onPressed: () => _open(contactInfo.supportMailUri()),
          icon: const Icon(Icons.support_agent_outlined),
          label: const Text('고객지원'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('settings-privacy-contact-button'),
          onPressed: () => _open(contactInfo.privacyMailUri()),
          icon: const Icon(Icons.privacy_tip_outlined),
          label: const Text('개인정보 문의'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('settings-incident-notice-button'),
          onPressed: () => _open(contactInfo.incidentNoticeUri),
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('장애 공지'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('settings-copy-diagnostics'),
          onPressed: () => _copyDiagnostics(context),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('진단 정보 복사'),
        ),
      ],
    );
  }

  Future<void> _open(Uri uri) async {
    final opener = onOpenExternalUri ??
        (Uri target) => launchUrl(
              target,
              mode: LaunchMode.externalApplication,
            );
    await opener(uri);
  }

  Future<void> _copyDiagnostics(BuildContext context) async {
    final text = diagnostics.toClipboardText();
    final copier = onCopyDiagnostics ??
        (String value) => Clipboard.setData(ClipboardData(text: value));
    await copier(text);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('진단 정보를 복사했습니다.')),
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
    required this.randomReceiveAllowed,
    required this.dataExport,
  });

  final String email;
  final String nickname;
  final bool isSocialAccount;
  final bool randomReceiveAllowed;
  final MemberDataExportJob? dataExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accountType = isSocialAccount ? '소셜 계정' : '이메일 계정';
    final randomStatus = randomReceiveAllowed ? '랜덤 편지 수신 중' : '랜덤 편지 중지';
    final exportStatus = dataExport == null
        ? '내보내기 요청 가능'
        : '내보내기 ${_exportStatusLabel(dataExport!.status)}';

    return KeyedSubtree(
      key: const ValueKey('settings-account-section'),
      child: Card(
        key: const ValueKey('settings-account-toolbar'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.manage_accounts_outlined,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppStatusPill(
                    label: accountType,
                    tone: isSocialAccount
                        ? AppStatusTone.warning
                        : AppStatusTone.success,
                  ),
                  AppStatusPill(
                    label: randomStatus,
                    tone: randomReceiveAllowed
                        ? AppStatusTone.success
                        : AppStatusTone.neutral,
                  ),
                  AppStatusPill(
                    label: exportStatus,
                    tone: dataExport?.canDownload == true
                        ? AppStatusTone.success
                        : AppStatusTone.neutral,
                  ),
                ],
              ),
            ],
          ),
        ),
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
      key: const ValueKey('settings-profile-section'),
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
            onPressed: isSubmitting || isSocialAccount ? null : () => onSave(),
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
        const Text('탈퇴 전 데이터 내보내기와 보존 정책을 확인해 주세요.'),
        const SizedBox(height: AppSpacing.md),
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
          const Text('탈퇴하면 계정과 세션이 정리되고 일부 운영 기록은 보존될 수 있습니다.'),
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
          AppResponsiveActionWrap(
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

class _DataExportSection extends StatelessWidget {
  const _DataExportSection({
    required this.state,
    required this.onRequest,
    required this.onRefresh,
    required this.onDownload,
  });

  final SettingsState state;
  final Future<void> Function() onRequest;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    final export = state.dataExport;
    final downloadedExport = state.downloadedExport;
    return _SettingsSection(
      title: '내 데이터',
      children: [
        if (export == null)
          const Text('기록, 이야기, 편지, 상담 요약, 계정 정보를 JSON 파일로 받을 수 있습니다.')
        else ...[
          Text('상태: ${_exportStatusLabel(export.status)}'),
          if (export.expiresAt != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text('만료: ${export.expiresAt}'),
          ],
          if (export.failureReason != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(export.failureReason!),
          ],
        ],
        if (downloadedExport != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppNotice(
            message:
                '${downloadedExport.filename} · ${downloadedExport.content.length}자',
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppResponsiveActionWrap(
          alignment: WrapAlignment.end,
          children: [
            if (export == null ||
                export.status == MemberDataExportStatus.failed ||
                export.status == MemberDataExportStatus.expired)
              FilledButton(
                key: const ValueKey('settings-request-data-export'),
                onPressed:
                    state.canRequestDataExport ? () => onRequest() : null,
                child: Text(
                  export == null ? '내보내기 요청' : '다시 요청',
                ),
              )
            else ...[
              OutlinedButton(
                key: const ValueKey('settings-refresh-data-export'),
                onPressed: state.isExporting ? null : () => onRefresh(),
                child: const Text('상태 갱신'),
              ),
              FilledButton(
                key: const ValueKey('settings-download-data-export'),
                onPressed:
                    state.canDownloadDataExport ? () => onDownload() : null,
                child: const Text('파일 받기'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _RetentionPolicySection extends StatelessWidget {
  const _RetentionPolicySection({required this.policy});

  final MemberRetentionPolicy policy;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: '탈퇴 보존 정책',
      children: [
        _PolicyList(title: '즉시 처리', items: policy.immediateDeletionItems),
        const SizedBox(height: AppSpacing.md),
        _PolicyList(title: '비식별 보존', items: policy.anonymizedRetentionItems),
        const SizedBox(height: AppSpacing.md),
        _PolicyList(title: '운영 보존', items: policy.legalRetentionItems),
      ],
    );
  }
}

class _PolicyList extends StatelessWidget {
  const _PolicyList({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xxs),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Text('- $item'),
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    super.key,
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

String _exportStatusLabel(MemberDataExportStatus status) {
  switch (status) {
    case MemberDataExportStatus.pending:
      return '준비 중';
    case MemberDataExportStatus.completed:
      return '준비 완료';
    case MemberDataExportStatus.failed:
      return '실패';
    case MemberDataExportStatus.expired:
      return '만료';
  }
}

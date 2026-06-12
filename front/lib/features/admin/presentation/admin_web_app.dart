import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/api_transport.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/network/dio_api_transport.dart';
import '../../../core/network/secure_auth_token_store.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_models.dart';
import '../../../theme/app_theme.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

class MaumOnAdminWebApp extends StatelessWidget {
  const MaumOnAdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = buildAdminWebDependencies(
      apiConfig: adminWebApiConfigFromEnvironment(),
    );

    return MaterialApp(
      title: 'Maum On Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: ThemeMode.light,
      home: AdminWebAuthShell(
        authRepository: dependencies.authRepository,
        adminRepository: dependencies.adminRepository,
      ),
    );
  }
}

ApiConfig adminWebApiConfigFromEnvironment({
  String baseUrl = const String.fromEnvironment('API_BASE_URL'),
  TargetPlatform? targetPlatform,
  bool isWeb = kIsWeb,
  bool isReleaseMode = kReleaseMode,
}) {
  if (isWeb && isReleaseMode && baseUrl.trim().isEmpty) {
    throw StateError(
      'API_BASE_URL must be provided with --dart-define for admin web release builds.',
    );
  }

  return ApiConfig.fromEnvironment(
    baseUrl: baseUrl,
    targetPlatform: targetPlatform,
    isWeb: isWeb,
    isReleaseMode: isReleaseMode,
  );
}

class AdminWebDependencies {
  const AdminWebDependencies({
    required this.authRepository,
    required this.adminRepository,
  });

  final AuthRepository authRepository;
  final AdminRepository adminRepository;
}

AdminWebDependencies buildAdminWebDependencies({
  required ApiConfig apiConfig,
  AuthTokenStore tokenStore = const SecureAuthTokenStore(),
  ApiTransport? rawTransport,
  ApiTransport? sessionTransport,
}) {
  final rawApiClient = ApiClient(
    transport: rawTransport ?? DioApiTransport.fromConfig(apiConfig),
    tokenStore: tokenStore,
  );
  final rawAuthRepository = ApiAuthRepository(
    apiClient: rawApiClient,
    tokenStore: tokenStore,
  );
  final tokenRefresher = AuthSessionTokenRefresher(
    authRepository: rawAuthRepository,
  );
  final sessionApiClient = ApiClient(
    transport: sessionTransport ?? DioApiTransport.fromConfig(apiConfig),
    tokenStore: tokenStore,
    tokenRefresher: tokenRefresher,
  );

  return AdminWebDependencies(
    authRepository: ApiAuthRepository(
      apiClient: sessionApiClient,
      tokenStore: tokenStore,
    ),
    adminRepository: ApiAdminRepository(apiClient: sessionApiClient),
  );
}

class AdminWebAuthShell extends StatefulWidget {
  const AdminWebAuthShell({
    required this.authRepository,
    required this.adminRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final AdminRepository adminRepository;

  @override
  State<AdminWebAuthShell> createState() => _AdminWebAuthShellState();
}

class _AdminWebAuthShellState extends State<AdminWebAuthShell> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRestoring = true;
  bool _isSubmitting = false;
  AuthMember? _adminMember;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _restoreAdminSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreAdminSession() async {
    try {
      final session = await widget.authRepository.restoreSession();
      if (!_isAdmin(session.member)) {
        await widget.authRepository.clearLocalSession();
        if (!mounted) {
          return;
        }
        setState(() {
          _isRestoring = false;
          _errorMessage = '관리자 권한이 필요합니다.';
        });
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isRestoring = false;
        _adminMember = session.member;
        _errorMessage = null;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRestoring = false;
      });
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '이메일과 비밀번호를 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final session = await widget.authRepository.login(
        LoginRequest(email: email, password: password),
      );
      if (!_isAdmin(session.member)) {
        await widget.authRepository.clearLocalSession();
        if (!mounted) {
          return;
        }
        setState(() {
          _isSubmitting = false;
          _adminMember = null;
          _errorMessage = '관리자 권한이 필요합니다.';
        });
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _adminMember = session.member;
        _errorMessage = null;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = '관리자 계정 정보를 확인해 주세요.';
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.logout();
    } on Object {
      await widget.authRepository.clearLocalSession();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _adminMember = null;
        });
      }
    }
  }

  bool _isAdmin(AuthMember member) {
    return member.role.toUpperCase() == 'ADMIN';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestoring) {
      return const Scaffold(
        body: Center(
          child: _AdminStatePanel(
            title: '관리자 콘솔',
            message: '관리자 세션을 확인하는 중입니다.',
            progress: true,
          ),
        ),
      );
    }

    if (_adminMember == null) {
      return _AdminLoginView(
        emailController: _emailController,
        passwordController: _passwordController,
        isSubmitting: _isSubmitting,
        errorMessage: _errorMessage,
        onSubmit: _login,
      );
    }

    return AdminWebApp(
      repository: widget.adminRepository,
      onLogout: _logout,
    );
  }
}

class AdminWebApp extends StatefulWidget {
  const AdminWebApp({
    required this.repository,
    this.onLogout,
    super.key,
  });

  final AdminRepository repository;
  final VoidCallback? onLogout;

  @override
  State<AdminWebApp> createState() => _AdminWebAppState();
}

class _AdminWebAppState extends State<AdminWebApp> {
  late Future<_AdminOverviewData> _overview;

  @override
  void initState() {
    super.initState();
    _overview = _loadOverview();
  }

  @override
  void didUpdateWidget(covariant AdminWebApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _overview = _loadOverview();
    }
  }

  Future<_AdminOverviewData> _loadOverview() async {
    final results = await Future.wait<Object>([
      widget.repository.fetchDashboard(),
      widget.repository.fetchReports(status: 'OPEN', sort: 'OPEN_FIRST'),
      widget.repository.fetchMembers(status: 'ACTIVE'),
      widget.repository.fetchLetters(status: 'UNASSIGNED'),
      widget.repository.fetchModerationSummary(),
    ]);

    return _AdminOverviewData(
      dashboard: results[0] as AdminDashboard,
      reports: results[1] as List<AdminReportSummary>,
      members: results[2] as AdminMemberPage,
      letters: results[3] as AdminLetterPage,
      moderation: results[4] as AdminModerationSummary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: FutureBuilder<_AdminOverviewData>(
          future: _overview,
          builder: (context, snapshot) {
            final data = snapshot.data;

            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: _AdminStatePanel(
                  title: '관리자 콘솔',
                  message: '운영 데이터를 불러오는 중입니다.',
                  progress: true,
                ),
              );
            }

            if (snapshot.hasError || data == null) {
              return Center(
                child: _AdminStatePanel(
                  title: '관리자 로그인이 필요합니다.',
                  message: '관리자 권한 세션으로 다시 접속해 주세요.',
                  progress: false,
                  onRetry: () {
                    setState(() {
                      _overview = _loadOverview();
                    });
                  },
                  secondaryActionLabel:
                      widget.onLogout == null ? null : '로그인으로 돌아가기',
                  onSecondaryAction: widget.onLogout,
                ),
              );
            }

            return _AdminDashboardView(
              data: data,
              onLogout: widget.onLogout,
              onRefresh: () {
                setState(() {
                  _overview = _loadOverview();
                });
              },
            );
          },
        ),
      ),
    );
  }
}

class _AdminDashboardView extends StatelessWidget {
  const _AdminDashboardView({
    required this.data,
    required this.onRefresh,
    this.onLogout,
  });

  final _AdminOverviewData data;
  final VoidCallback onRefresh;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '관리자 콘솔',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '모바일 앱과 분리된 운영 공간',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (onLogout != null)
                        OutlinedButton.icon(
                          onPressed: onLogout,
                          icon: const Icon(Icons.logout),
                          label: const Text('로그아웃'),
                        ),
                      FilledButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('새로고침'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionSurface(
                title: '운영 대시보드',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricTile(
                      label: '오늘 신고',
                      value: '${data.dashboard.todayReportCount}',
                    ),
                    _MetricTile(
                      label: '열린 신고',
                      value: '${data.dashboard.openReportCount}',
                      caption: '열린 신고 ${data.dashboard.openReportCount}건',
                    ),
                    _MetricTile(
                      label: '처리 완료',
                      value: '${data.dashboard.processedReportCount}',
                    ),
                    _MetricTile(
                      label: '미배정 편지',
                      value: '${data.dashboard.unassignedLetterCount}',
                      caption:
                          '미배정 편지 ${data.dashboard.unassignedLetterCount}건',
                    ),
                    _MetricTile(
                      label: '차단 회원',
                      value: '${data.dashboard.blockedMemberCount}',
                    ),
                    _MetricTile(
                      label: '오늘 조치',
                      value: '${data.dashboard.todayAdminActionCount}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 840;
                  final children = [
                    _SectionSurface(
                      title: '신고 관리',
                      child: _ReportQueue(reports: data.reports),
                    ),
                    _SectionSurface(
                      title: '회원 관리',
                      child: _MemberQueue(members: data.members.content),
                    ),
                    _SectionSurface(
                      title: '편지 관리',
                      child: _LetterQueue(letters: data.letters.content),
                    ),
                    _SectionSurface(
                      title: 'AI 필터 상태',
                      child: _ModerationSummary(summary: data.moderation),
                    ),
                  ];

                  if (!twoColumns) {
                    return Column(
                      children: [
                        for (final child in children) ...[
                          child,
                          const SizedBox(height: 16),
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            children[0],
                            const SizedBox(height: 16),
                            children[2],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            children[1],
                            const SizedBox(height: 16),
                            children[3],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              Text(
                '관리자 API: /api/v1/admin',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 168,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (caption != null) ...[
                const SizedBox(height: 6),
                Text(caption!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportQueue extends StatelessWidget {
  const _ReportQueue({required this.reports});

  final List<AdminReportSummary> reports;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyQueue(label: '확인할 신고가 없습니다.');
    }

    return Column(
      children: [
        for (final report in reports.take(4))
          _QueueRow(
            icon: Icons.flag_outlined,
            title: report.targetTitle,
            meta: '${report.targetType} · ${report.status}',
            trailing: '${report.actionCount}회',
          ),
      ],
    );
  }
}

class _MemberQueue extends StatelessWidget {
  const _MemberQueue({required this.members});

  final List<AdminMemberSummary> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const _EmptyQueue(label: '표시할 회원이 없습니다.');
    }

    return Column(
      children: [
        for (final member in members.take(4))
          _QueueRow(
            icon: Icons.person_outline,
            title: member.nickname,
            meta: '${member.email} · ${member.status}',
            trailing: member.role,
          ),
      ],
    );
  }
}

class _LetterQueue extends StatelessWidget {
  const _LetterQueue({required this.letters});

  final List<AdminLetterSummary> letters;

  @override
  Widget build(BuildContext context) {
    if (letters.isEmpty) {
      return const _EmptyQueue(label: '확인할 편지가 없습니다.');
    }

    return Column(
      children: [
        for (final letter in letters.take(4))
          _QueueRow(
            icon: Icons.mail_outline,
            title: letter.title,
            meta: '${letter.sender.nickname} · ${letter.status}',
            trailing: '${letter.actionCount}회',
          ),
      ],
    );
  }
}

class _ModerationSummary extends StatelessWidget {
  const _ModerationSummary({required this.summary});

  final AdminModerationSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(label: '전체 ${summary.totalCount}건'),
        _StatusChip(label: '차단 ${summary.blockedCount}건'),
        _StatusChip(label: '모델 실패 ${summary.modelFailureCount}건'),
        _StatusChip(label: '실패율 ${(summary.failureRate * 100).round()}%'),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.icon,
    required this.title,
    required this.meta,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String meta;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(trailing, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _AdminLoginView extends StatelessWidget {
  const _AdminLoginView({
    required this.emailController,
    required this.passwordController,
    required this.isSubmitting,
    required this.onSubmit,
    this.errorMessage,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 40,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '관리자 로그인',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '운영 계정으로 접속해 주세요.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 18),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onErrorContainer),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      TextField(
                        key: const ValueKey('admin-login-email-field'),
                        controller: emailController,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('admin-login-password-field'),
                        controller: passwordController,
                        enabled: !isSubmitting,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => isSubmitting ? null : onSubmit(),
                        decoration: const InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const ValueKey('admin-login-submit-button'),
                        onPressed: isSubmitting ? null : onSubmit,
                        icon: isSubmitting
                            ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onPrimary,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(isSubmitting ? '확인 중' : '관리자 로그인'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminStatePanel extends StatelessWidget {
  const _AdminStatePanel({
    required this.title,
    required this.message,
    required this.progress,
    this.onRetry,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String message;
  final bool progress;
  final VoidCallback? onRetry;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress) const CircularProgressIndicator(),
            if (progress) const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
            if (onSecondaryAction != null && secondaryActionLabel != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminOverviewData {
  const _AdminOverviewData({
    required this.dashboard,
    required this.reports,
    required this.members,
    required this.letters,
    required this.moderation,
  });

  final AdminDashboard dashboard;
  final List<AdminReportSummary> reports;
  final AdminMemberPage members;
  final AdminLetterPage letters;
  final AdminModerationSummary moderation;
}

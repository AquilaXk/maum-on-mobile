import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import '../deeplink/external_login.dart';
import '../domain/login_provider_policy.dart';
import '../../legal/presentation/legal_disclosure_links.dart';
import '../../../shared/ui/app_design_system.dart';
import '../../../shared/ui/brand_identity.dart';

enum AuthFormMode {
  login,
  signup,
  passwordResetRequest,
  passwordResetConfirm,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.controller,
    this.externalLoginController,
    this.loginProviders,
    this.onOpenExternalUri,
    super.key,
  });

  final AuthController controller;
  final ExternalLoginController? externalLoginController;
  final List<LoginProvider>? loginProviders;
  final Future<bool> Function(Uri uri)? onOpenExternalUri;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _resetTokenController = TextEditingController();
  final _signupEmailVerificationCodeController = TextEditingController();
  AuthFormMode _mode = AuthFormMode.login;
  bool _acceptedRequiredTerms = false;
  bool _signupEmailVerificationRequested = false;
  Map<String, String> _fieldErrors = {};
  String? _passwordResetEmail;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    _resetTokenController.dispose();
    _signupEmailVerificationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.controller.state;
    final externalLoginState = widget.externalLoginController?.state;
    final platform = theme.platform;
    final isAuthBusy =
        state.isSubmitting || (externalLoginState?.isStarting ?? false);
    final secondaryActions = _secondaryActions(platform, isAuthBusy);

    return Scaffold(
      body: DecoratedBox(
        key: const ValueKey('auth-blue-shell'),
        decoration: const BoxDecoration(
          color: AppBrandColors.backgroundBlue,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE7F2FF),
              Color(0xFFF7FBFF),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - AppSpacing.xxl * 2,
                      maxWidth: 440,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AuthHeader(subtitle: _subtitle),
                        const SizedBox(height: AppSpacing.lg),
                        _AuthTrustStrip(
                          items: _trustStripItems,
                          semanticLabel: _trustStripSemanticLabel,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _AuthFormPanel(
                          title: _modeTitle,
                          icon: _submitIcon,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (state.errorMessage != null) ...[
                                _MessagePanel(
                                  message: state.errorMessage!,
                                  color: theme.colorScheme.errorContainer,
                                  textColor: theme.colorScheme.onErrorContainer,
                                  isError: true,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              if (externalLoginState?.errorMessage != null) ...[
                                _MessagePanel(
                                  message: externalLoginState!.errorMessage!,
                                  color: theme.colorScheme.errorContainer,
                                  textColor: theme.colorScheme.onErrorContainer,
                                  isError: true,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              if (state.infoMessage != null) ...[
                                _MessagePanel(
                                  message: state.infoMessage!,
                                  color: theme.colorScheme.primaryContainer,
                                  textColor:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              ..._fieldsForMode(theme, isAuthBusy),
                              const SizedBox(height: AppSpacing.xl),
                              FilledButton.icon(
                                key: ValueKey(_submitButtonKey),
                                onPressed: isAuthBusy ? null : _submit,
                                icon: state.isSubmitting
                                    ? SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                      )
                                    : Icon(_submitIcon),
                                label: Text(
                                  state.isSubmitting ? '처리 중' : _submitLabel,
                                ),
                              ),
                              if (secondaryActions.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                ...secondaryActions,
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        LegalDisclosureLinks(
                          keyPrefix: 'auth',
                          onOpenExternalUri: widget.onOpenExternalUri,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    return switch (_mode) {
      AuthFormMode.login => '계정으로 마음 기록을 이어가세요.',
      AuthFormMode.signup => '새 계정을 만들고 시작하세요.',
      AuthFormMode.passwordResetRequest => '비밀번호 재설정',
      AuthFormMode.passwordResetConfirm => '비밀번호 재설정',
    };
  }

  String get _modeTitle {
    return switch (_mode) {
      AuthFormMode.login => '로그인',
      AuthFormMode.signup =>
        _signupEmailVerificationRequested ? '회원가입' : '이메일 인증',
      AuthFormMode.passwordResetRequest => '계정 이메일 확인',
      AuthFormMode.passwordResetConfirm => '새 비밀번호 설정',
    };
  }

  String get _submitButtonKey {
    return switch (_mode) {
      AuthFormMode.login => 'login-submit-button',
      AuthFormMode.signup => _signupEmailVerificationRequested
          ? 'signup-submit-button'
          : 'signup-email-verification-request-button',
      AuthFormMode.passwordResetRequest => 'password-reset-request-button',
      AuthFormMode.passwordResetConfirm => 'password-reset-confirm-button',
    };
  }

  String get _submitLabel {
    return switch (_mode) {
      AuthFormMode.login => '로그인',
      AuthFormMode.signup =>
        _signupEmailVerificationRequested ? '회원가입' : '인증번호 받기',
      AuthFormMode.passwordResetRequest => '재설정 안내 받기',
      AuthFormMode.passwordResetConfirm => '비밀번호 변경',
    };
  }

  IconData get _submitIcon {
    return switch (_mode) {
      AuthFormMode.login => Icons.login,
      AuthFormMode.signup => _signupEmailVerificationRequested
          ? Icons.person_add_alt_1
          : Icons.mark_email_unread_outlined,
      AuthFormMode.passwordResetRequest => Icons.outgoing_mail,
      AuthFormMode.passwordResetConfirm => Icons.lock_reset,
    };
  }

  List<_AuthTrustItemData> get _trustStripItems {
    return switch (_mode) {
      AuthFormMode.login => const [
          _AuthTrustItemData(Icons.alternate_email, '이메일 로그인'),
          _AuthTrustItemData(Icons.verified_user_outlined, '자동 로그인'),
          _AuthTrustItemData(Icons.lock_outline, '안전한 기록'),
        ],
      AuthFormMode.signup => _signupEmailVerificationRequested
          ? const [
              _AuthTrustItemData(Icons.mark_email_read_outlined, '인증번호 확인'),
              _AuthTrustItemData(Icons.lock_outline, '비밀번호 설정'),
              _AuthTrustItemData(Icons.person_outline, '프로필 설정'),
            ]
          : const [
              _AuthTrustItemData(Icons.mark_email_unread_outlined, '이메일 인증'),
              _AuthTrustItemData(Icons.pin_outlined, '6자리 코드'),
              _AuthTrustItemData(Icons.person_outline, '프로필 설정'),
            ],
      AuthFormMode.passwordResetRequest => const [
          _AuthTrustItemData(Icons.alternate_email, '이메일 확인'),
          _AuthTrustItemData(Icons.outgoing_mail, '안내 발송'),
          _AuthTrustItemData(Icons.lock_reset, '재설정'),
        ],
      AuthFormMode.passwordResetConfirm => const [
          _AuthTrustItemData(Icons.password, '토큰 입력'),
          _AuthTrustItemData(Icons.lock_reset, '새 비밀번호'),
          _AuthTrustItemData(Icons.login, '다시 로그인'),
        ],
    };
  }

  String get _trustStripSemanticLabel {
    final prefix = switch (_mode) {
      AuthFormMode.login => '보안 기능',
      AuthFormMode.signup => '가입 절차',
      AuthFormMode.passwordResetRequest ||
      AuthFormMode.passwordResetConfirm =>
        '재설정 단계',
    };
    final labels = _trustStripItems.map((item) => item.label).join(', ');
    return '$prefix: $labels';
  }

  List<Widget> _fieldsForMode(ThemeData theme, bool isAuthBusy) {
    return switch (_mode) {
      AuthFormMode.login => _loginFields(),
      AuthFormMode.signup => _signupFields(theme, isAuthBusy),
      AuthFormMode.passwordResetRequest => _passwordResetRequestFields(),
      AuthFormMode.passwordResetConfirm => _passwordResetConfirmFields(),
    };
  }

  List<Widget> _loginFields() {
    return [
      _emailField(
        key: const ValueKey('login-email-field'),
        controller: _emailController,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      _passwordField(
        key: const ValueKey('login-password-field'),
        controller: _passwordController,
        labelText: '비밀번호',
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
      ),
    ];
  }

  List<Widget> _signupFields(ThemeData theme, bool isAuthBusy) {
    final fields = <Widget>[
      _emailField(
        key: const ValueKey('login-email-field'),
        controller: _emailController,
        textInputAction: TextInputAction.next,
        readOnly: _signupEmailVerificationRequested,
      ),
    ];

    if (!_signupEmailVerificationRequested) {
      return fields;
    }

    fields.addAll([
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey('signup-email-change-button'),
          onPressed: isAuthBusy ? null : _resetSignupEmailVerification,
          child: const Text('다른 이메일 사용'),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('signup-email-verification-code-field'),
        controller: _signupEmailVerificationCodeController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        autofillHints: const [AutofillHints.oneTimeCode],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: '이메일 인증번호',
          counterText: '',
          errorText: _fieldErrors['emailVerificationCode'],
        ),
      ),
      const SizedBox(height: 12),
      _passwordField(
        key: const ValueKey('login-password-field'),
        controller: _passwordController,
        labelText: '비밀번호',
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      _passwordField(
        key: const ValueKey('signup-password-confirm-field'),
        controller: _passwordConfirmController,
        labelText: '비밀번호 확인',
        errorText: _fieldErrors['passwordConfirm'],
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('signup-nickname-field'),
        controller: _nicknameController,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: '닉네임',
          errorText: _fieldErrors['nickname'],
        ),
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        key: const ValueKey('signup-required-terms-checkbox'),
        value: _acceptedRequiredTerms,
        onChanged: (value) {
          setState(() {
            _acceptedRequiredTerms = value ?? false;
            _fieldErrors = Map<String, String>.from(_fieldErrors)
              ..remove('requiredTerms');
          });
        },
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('필수 약관 및 개인정보 처리에 동의합니다.'),
        subtitle: _fieldErrors['requiredTerms'] == null
            ? null
            : Text(
                _fieldErrors['requiredTerms']!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    ]);

    return fields;
  }

  List<Widget> _passwordResetRequestFields() {
    return [
      _emailField(
        key: const ValueKey('password-reset-email-field'),
        controller: _emailController,
        textInputAction: TextInputAction.done,
      ),
    ];
  }

  List<Widget> _passwordResetConfirmFields() {
    return [
      if (_passwordResetEmail != null) ...[
        Text('재설정 안내를 ${_passwordResetEmail!}로 보냈습니다.'),
        const SizedBox(height: 12),
      ],
      TextField(
        key: const ValueKey('password-reset-token-field'),
        controller: _resetTokenController,
        autofillHints: const [AutofillHints.oneTimeCode],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: '재설정 토큰',
          errorText: _fieldErrors['token'],
        ),
      ),
      const SizedBox(height: 12),
      _passwordField(
        key: const ValueKey('password-reset-new-password-field'),
        controller: _passwordController,
        labelText: '새 비밀번호',
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      _passwordField(
        key: const ValueKey('password-reset-confirm-password-field'),
        controller: _passwordConfirmController,
        labelText: '새 비밀번호 확인',
        errorText: _fieldErrors['passwordConfirm'],
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.done,
      ),
    ];
  }

  Widget _emailField({
    required Key key,
    required TextEditingController controller,
    required TextInputAction textInputAction,
    bool readOnly = false,
  }) {
    return TextField(
      key: key,
      controller: controller,
      readOnly: readOnly,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: '이메일',
        errorText: _fieldErrors['email'],
      ),
    );
  }

  Widget _passwordField({
    required Key key,
    required TextEditingController controller,
    required String labelText,
    required Iterable<String> autofillHints,
    required TextInputAction textInputAction,
    String? errorText,
  }) {
    return TextField(
      key: key,
      controller: controller,
      obscureText: true,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: labelText,
        errorText: errorText ?? _fieldErrors['password'],
      ),
    );
  }

  List<Widget> _secondaryActions(TargetPlatform platform, bool isAuthBusy) {
    final actions = <Widget>[];

    switch (_mode) {
      case AuthFormMode.login:
        actions.add(
          TextButton(
            key: const ValueKey('password-reset-open-button'),
            onPressed: isAuthBusy
                ? null
                : () => _changeMode(AuthFormMode.passwordResetRequest),
            child: const Text('비밀번호를 잊으셨나요?'),
          ),
        );
        actions.add(
          TextButton(
            onPressed:
                isAuthBusy ? null : () => _changeMode(AuthFormMode.signup),
            child: const Text('새 계정 만들기'),
          ),
        );
        if (LoginProviderPolicy.showsReviewEmailGuidance(platform)) {
          actions.add(const SizedBox(height: 8));
          actions.add(
            const _IosReviewEmailLoginGuidance(),
          );
        }
        final providers =
            widget.loginProviders ?? LoginProviderPolicy.providersFor(platform);
        if (widget.externalLoginController != null && providers.isNotEmpty) {
          actions.add(const SizedBox(height: 8));
          actions.add(
            _QuickLoginProviderRow(
              providers: providers,
              isStarting: isAuthBusy,
              onStart: (provider) => widget.externalLoginController!.start(
                provider: provider.providerId,
              ),
            ),
          );
        }
        break;
      case AuthFormMode.signup:
        actions.add(
          TextButton(
            onPressed:
                isAuthBusy ? null : () => _changeMode(AuthFormMode.login),
            child: const Text('이미 계정이 있어요'),
          ),
        );
        break;
      case AuthFormMode.passwordResetRequest:
      case AuthFormMode.passwordResetConfirm:
        actions.add(
          TextButton(
            onPressed:
                isAuthBusy ? null : () => _changeMode(AuthFormMode.login),
            child: const Text('로그인으로 돌아가기'),
          ),
        );
        break;
    }

    return actions;
  }

  Future<void> _submit() async {
    switch (_mode) {
      case AuthFormMode.signup:
        if (!_signupEmailVerificationRequested) {
          if (!_validateSignupEmailVerificationRequest()) {
            return;
          }
          final email = _emailController.text.trim();
          final requested =
              await widget.controller.requestSignupEmailVerification(
            email: email,
          );
          if (mounted && requested) {
            setState(() {
              _emailController.text = email;
              _signupEmailVerificationRequested = true;
              _signupEmailVerificationCodeController.clear();
              _passwordController.clear();
              _passwordConfirmController.clear();
              _nicknameController.clear();
              _acceptedRequiredTerms = false;
              _fieldErrors = {};
            });
          }
          return;
        }
        if (!_validateSignup()) {
          return;
        }
        await widget.controller.signup(
          email: _emailController.text,
          password: _passwordController.text,
          nickname: _nicknameController.text,
          emailVerificationCode: _signupEmailVerificationCodeController.text,
        );
        if (mounted && widget.controller.state.errorMessage == null) {
          _changeMode(AuthFormMode.login);
        }
        return;
      case AuthFormMode.login:
        await widget.controller.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
        return;
      case AuthFormMode.passwordResetRequest:
        if (!_validatePasswordResetRequest()) {
          return;
        }
        final email = _emailController.text.trim();
        final requested = await widget.controller.requestPasswordReset(
          email: email,
        );
        if (mounted && requested) {
          setState(() {
            _passwordResetEmail = email;
            _passwordController.clear();
            _passwordConfirmController.clear();
            _resetTokenController.clear();
            _fieldErrors = {};
            _mode = AuthFormMode.passwordResetConfirm;
          });
        }
        return;
      case AuthFormMode.passwordResetConfirm:
        if (!_validatePasswordResetConfirm()) {
          return;
        }
        final confirmed = await widget.controller.confirmPasswordReset(
          token: _resetTokenController.text,
          newPassword: _passwordController.text,
        );
        if (mounted && confirmed) {
          _passwordController.clear();
          _passwordConfirmController.clear();
          _resetTokenController.clear();
          _changeMode(AuthFormMode.login);
        }
        return;
    }
  }

  bool _validateSignup() {
    final errors = <String, String>{};
    _validateEmail(errors, _emailController.text);
    _validateEmailVerificationCode(errors);
    _validatePassword(errors, _passwordController.text);
    _validatePasswordConfirm(errors);

    final nicknameLength = _nicknameController.text.trim().length;
    if (nicknameLength < 2 || nicknameLength > 20) {
      errors['nickname'] = '닉네임은 2자 이상 20자 이하로 입력해 주세요.';
    }

    if (!_acceptedRequiredTerms) {
      errors['requiredTerms'] = '필수 동의 항목을 확인해 주세요.';
    }

    return _commitFieldErrors(errors);
  }

  bool _validateSignupEmailVerificationRequest() {
    final errors = <String, String>{};
    _validateEmail(errors, _emailController.text);
    return _commitFieldErrors(errors);
  }

  bool _validatePasswordResetRequest() {
    final errors = <String, String>{};
    _validateEmail(errors, _emailController.text);
    return _commitFieldErrors(errors);
  }

  bool _validatePasswordResetConfirm() {
    final errors = <String, String>{};
    if (_resetTokenController.text.trim().isEmpty) {
      errors['token'] = '재설정 토큰을 입력해 주세요.';
    }
    _validatePassword(errors, _passwordController.text);
    _validatePasswordConfirm(errors);
    return _commitFieldErrors(errors);
  }

  void _validateEmail(Map<String, String> errors, String email) {
    final trimmed = email.trim();
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(trimmed)) {
      errors['email'] = '올바른 이메일 주소를 입력해 주세요.';
    }
  }

  void _validatePassword(Map<String, String> errors, String password) {
    if (password.length < 8) {
      errors['password'] = '비밀번호는 8자 이상이어야 합니다.';
    }
  }

  void _validatePasswordConfirm(Map<String, String> errors) {
    if (_passwordConfirmController.text != _passwordController.text) {
      errors['passwordConfirm'] = '비밀번호가 서로 일치하지 않습니다.';
    }
  }

  void _validateEmailVerificationCode(Map<String, String> errors) {
    final codePattern = RegExp(r'^\d{6}$');
    if (!codePattern
        .hasMatch(_signupEmailVerificationCodeController.text.trim())) {
      errors['emailVerificationCode'] = '인증번호 6자리를 입력해 주세요.';
    }
  }

  bool _commitFieldErrors(Map<String, String> errors) {
    setState(() {
      _fieldErrors = errors;
    });
    return errors.isEmpty;
  }

  void _changeMode(AuthFormMode mode) {
    setState(() {
      _mode = mode;
      _fieldErrors = {};
      if (mode == AuthFormMode.signup) {
        _signupEmailVerificationRequested = false;
        _signupEmailVerificationCodeController.clear();
        _acceptedRequiredTerms = false;
      }
      if (mode != AuthFormMode.signup) {
        _signupEmailVerificationRequested = false;
        _signupEmailVerificationCodeController.clear();
        _acceptedRequiredTerms = false;
      }
      if (mode != AuthFormMode.login) {
        _passwordController.clear();
        _passwordConfirmController.clear();
        _resetTokenController.clear();
      }
      if (mode == AuthFormMode.login) {
        _passwordController.clear();
        _passwordConfirmController.clear();
        _resetTokenController.clear();
        _passwordResetEmail = null;
      }
    });
  }

  void _resetSignupEmailVerification() {
    setState(() {
      _signupEmailVerificationRequested = false;
      _signupEmailVerificationCodeController.clear();
      _passwordController.clear();
      _passwordConfirmController.clear();
      _nicknameController.clear();
      _acceptedRequiredTerms = false;
      _fieldErrors = {};
    });
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const MaumOnBrandWordmark(
          height: 44,
          foregroundColor: AppBrandColors.foreground,
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthTrustStrip extends StatelessWidget {
  const _AuthTrustStrip({
    required this.items,
    required this.semanticLabel,
  });

  final List<_AuthTrustItemData> items;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const ValueKey('auth-trust-strip'),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.56),
            borderRadius: AppRadii.card,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  Expanded(child: _AuthTrustItem(item: items[index])),
                  if (index != items.length - 1)
                    Container(
                      width: 1,
                      height: 24,
                      color: colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTrustItem extends StatelessWidget {
  const _AuthTrustItem({required this.item});

  final _AuthTrustItemData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTrustItemData {
  const _AuthTrustItemData(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const ValueKey('auth-form-panel'),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.card,
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              key: const ValueKey('auth-form-title-row'),
              children: [
                DecoratedBox(
                  key: const ValueKey('auth-form-title-icon'),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: AppRadii.chip,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.message,
    required this.color,
    required this.textColor,
    this.isError = false,
  });

  final String message;
  final Color color;
  final Color textColor;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: textColor,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLoginProviderRow extends StatelessWidget {
  const _QuickLoginProviderRow({
    required this.providers,
    required this.isStarting,
    required this.onStart,
  });

  final List<LoginProvider> providers;
  final bool isStarting;
  final ValueChanged<LoginProvider> onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('quick-login-provider-row'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                '간편 로그인',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final provider in providers)
              _QuickLoginProviderButton(
                provider: provider,
                isStarting: isStarting,
                onPressed: () => onStart(provider),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickLoginProviderButton extends StatelessWidget {
  const _QuickLoginProviderButton({
    required this.provider,
    required this.isStarting,
    required this.onPressed,
  });

  final LoginProvider provider;
  final bool isStarting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = !isStarting;
    final opacity = enabled ? 1.0 : 0.55;
    final label = provider.label;

    return Semantics(
      key: ValueKey(provider.buttonKey),
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        child: Opacity(
          opacity: opacity,
          child: Material(
            color: _providerBackground(provider),
            shape: CircleBorder(side: _providerBorder(provider)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onPressed : null,
              child: SizedBox.square(
                dimension: 58,
                child: Center(
                  child: _QuickLoginProviderMark(provider: provider),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _providerBackground(LoginProvider provider) {
    return switch (provider) {
      LoginProvider.naver => const Color(0xFF03C75A),
      LoginProvider.kakao => const Color(0xFFFEE500),
      LoginProvider.facebook => const Color(0xFF4267B2),
      LoginProvider.google => Colors.white,
      LoginProvider.apple => Colors.black,
    };
  }

  BorderSide _providerBorder(LoginProvider provider) {
    return switch (provider) {
      LoginProvider.google => const BorderSide(
          color: Color(0xFF4285F4),
          width: 1.4,
        ),
      _ => BorderSide.none,
    };
  }
}

class _QuickLoginProviderMark extends StatelessWidget {
  const _QuickLoginProviderMark({
    required this.provider,
  });

  final LoginProvider provider;

  @override
  Widget build(BuildContext context) {
    return switch (provider) {
      LoginProvider.naver => const Text(
          'N',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      LoginProvider.kakao => const Icon(
          Icons.chat_bubble,
          color: Color(0xFF3C1E1E),
          size: 25,
        ),
      LoginProvider.facebook => const Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w800,
            height: 0.95,
          ),
        ),
      LoginProvider.google => const Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      LoginProvider.apple => const Icon(
          Icons.apple,
          color: Colors.white,
          size: 30,
        ),
    };
  }
}

class _IosReviewEmailLoginGuidance extends StatelessWidget {
  const _IosReviewEmailLoginGuidance();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'iOS에서는 이메일과 비밀번호로 로그인할 수 있으며, 계정 삭제는 로그인 후 설정의 회원 탈퇴에서 진행할 수 있습니다.',
      key: const ValueKey('ios-review-email-login-guidance'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

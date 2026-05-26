import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import '../deeplink/external_login.dart';
import '../domain/login_provider_policy.dart';
import '../../legal/presentation/legal_disclosure_links.dart';

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
    this.onOpenExternalUri,
    super.key,
  });

  final AuthController controller;
  final ExternalLoginController? externalLoginController;
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
  AuthFormMode _mode = AuthFormMode.login;
  bool _acceptedRequiredTerms = false;
  Map<String, String> _fieldErrors = {};
  String? _passwordResetEmail;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    _resetTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.controller.state;
    final externalLoginState = widget.externalLoginController?.state;
    final platform = theme.platform;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Maum On',
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  if (state.errorMessage != null) ...[
                    _MessagePanel(
                      message: state.errorMessage!,
                      color: theme.colorScheme.errorContainer,
                      textColor: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (externalLoginState?.errorMessage != null) ...[
                    _MessagePanel(
                      message: externalLoginState!.errorMessage!,
                      color: theme.colorScheme.errorContainer,
                      textColor: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.infoMessage != null) ...[
                    _MessagePanel(
                      message: state.infoMessage!,
                      color: theme.colorScheme.primaryContainer,
                      textColor: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 16),
                  ],
                  ..._fieldsForMode(theme),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: ValueKey(_submitButtonKey),
                    onPressed: state.isSubmitting ? null : _submit,
                    child: Text(
                      state.isSubmitting ? '처리 중' : _submitLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._secondaryActions(state, externalLoginState, platform),
                  const SizedBox(height: 16),
                  LegalDisclosureLinks(
                    keyPrefix: 'auth',
                    onOpenExternalUri: widget.onOpenExternalUri,
                  ),
                ],
              ),
            ),
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

  String get _submitButtonKey {
    return switch (_mode) {
      AuthFormMode.login => 'login-submit-button',
      AuthFormMode.signup => 'signup-submit-button',
      AuthFormMode.passwordResetRequest => 'password-reset-request-button',
      AuthFormMode.passwordResetConfirm => 'password-reset-confirm-button',
    };
  }

  String get _submitLabel {
    return switch (_mode) {
      AuthFormMode.login => '로그인',
      AuthFormMode.signup => '회원가입',
      AuthFormMode.passwordResetRequest => '재설정 안내 받기',
      AuthFormMode.passwordResetConfirm => '비밀번호 변경',
    };
  }

  List<Widget> _fieldsForMode(ThemeData theme) {
    return switch (_mode) {
      AuthFormMode.login => _loginFields(),
      AuthFormMode.signup => _signupFields(theme),
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

  List<Widget> _signupFields(ThemeData theme) {
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
    ];
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
  }) {
    return TextField(
      key: key,
      controller: controller,
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

  List<Widget> _secondaryActions(
    AuthState state,
    ExternalLoginState? externalLoginState,
    TargetPlatform platform,
  ) {
    final actions = <Widget>[];

    switch (_mode) {
      case AuthFormMode.login:
        actions.add(
          TextButton(
            key: const ValueKey('password-reset-open-button'),
            onPressed: state.isSubmitting
                ? null
                : () => _changeMode(AuthFormMode.passwordResetRequest),
            child: const Text('비밀번호를 잊으셨나요?'),
          ),
        );
        actions.add(
          TextButton(
            onPressed: state.isSubmitting
                ? null
                : () => _changeMode(AuthFormMode.signup),
            child: const Text('새 계정 만들기'),
          ),
        );
        if (LoginProviderPolicy.showsReviewEmailGuidance(platform)) {
          actions.add(const SizedBox(height: 8));
          actions.add(
            const _IosReviewEmailLoginGuidance(),
          );
        }
        final providers = LoginProviderPolicy.providersFor(platform);
        if (widget.externalLoginController != null && providers.isNotEmpty) {
          actions.add(const SizedBox(height: 8));
          for (final provider in providers) {
            actions.add(
              OutlinedButton(
                key: ValueKey(provider.buttonKey),
                onPressed: externalLoginState?.isStarting == true
                    ? null
                    : () => widget.externalLoginController!.start(
                          provider: provider.providerId,
                        ),
                child: Text(
                  externalLoginState?.isStarting == true
                      ? '외부 로그인 준비 중'
                      : provider.label,
                ),
              ),
            );
          }
        }
        break;
      case AuthFormMode.signup:
        actions.add(
          TextButton(
            onPressed: state.isSubmitting
                ? null
                : () => _changeMode(AuthFormMode.login),
            child: const Text('이미 계정이 있어요'),
          ),
        );
        break;
      case AuthFormMode.passwordResetRequest:
      case AuthFormMode.passwordResetConfirm:
        actions.add(
          TextButton(
            onPressed: state.isSubmitting
                ? null
                : () => _changeMode(AuthFormMode.login),
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
        if (!_validateSignup()) {
          return;
        }
        await widget.controller.signup(
          email: _emailController.text,
          password: _passwordController.text,
          nickname: _nicknameController.text,
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
      if (mode != AuthFormMode.signup) {
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
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.message,
    required this.color,
    required this.textColor,
  });

  final String message;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
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

import 'package:flutter/material.dart';

import '../application/auth_controller.dart';

enum AuthFormMode {
  login,
  signup,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.controller,
    super.key,
  });

  final AuthController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  AuthFormMode _mode = AuthFormMode.login;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.controller.state;
    final isSignup = _mode == AuthFormMode.signup;

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
                    isSignup ? '새 계정을 만들고 시작하세요.' : '계정으로 마음 기록을 이어가세요.',
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
                  if (state.infoMessage != null) ...[
                    _MessagePanel(
                      message: state.infoMessage!,
                      color: theme.colorScheme.primaryContainer,
                      textColor: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    key: const ValueKey('login-email-field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('login-password-field'),
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction:
                        isSignup ? TextInputAction.next : TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                    ),
                  ),
                  if (isSignup) ...[
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('signup-nickname-field'),
                      controller: _nicknameController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: '닉네임',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: ValueKey(
                      isSignup ? 'signup-submit-button' : 'login-submit-button',
                    ),
                    onPressed: state.isSubmitting ? null : _submit,
                    child: Text(state.isSubmitting
                        ? '처리 중'
                        : isSignup
                            ? '회원가입'
                            : '로그인'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: state.isSubmitting ? null : _toggleMode,
                    child: Text(isSignup ? '이미 계정이 있어요' : '새 계정 만들기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_mode == AuthFormMode.signup) {
      await widget.controller.signup(
        email: _emailController.text,
        password: _passwordController.text,
        nickname: _nicknameController.text,
      );
      if (mounted && widget.controller.state.errorMessage == null) {
        setState(() {
          _mode = AuthFormMode.login;
        });
      }
      return;
    }

    await widget.controller.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _toggleMode() {
    setState(() {
      _mode =
          _mode == AuthFormMode.login ? AuthFormMode.signup : AuthFormMode.login;
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

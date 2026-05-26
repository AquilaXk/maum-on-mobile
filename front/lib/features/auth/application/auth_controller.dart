import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

enum AuthStatus {
  restoring,
  unauthenticated,
  authenticated,
}

class AuthState {
  const AuthState({
    required this.status,
    this.member,
    this.isSubmitting = false,
    this.hasRestored = false,
    this.errorMessage,
    this.infoMessage,
    this.sessionRevision = 0,
  });

  const AuthState.initial()
      : status = AuthStatus.restoring,
        member = null,
        isSubmitting = false,
        hasRestored = false,
        errorMessage = null,
        infoMessage = null,
        sessionRevision = 0;

  final AuthStatus status;
  final AuthMember? member;
  final bool isSubmitting;
  final bool hasRestored;
  final String? errorMessage;
  final String? infoMessage;
  final int sessionRevision;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  bool get isRestoring => status == AuthStatus.restoring;

  AuthState copyWith({
    AuthStatus? status,
    AuthMember? member,
    bool clearMember = false,
    bool? isSubmitting,
    bool? hasRestored,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? infoMessage,
    bool clearInfoMessage = false,
    int? sessionRevision,
  }) {
    return AuthState(
      status: status ?? this.status,
      member: clearMember ? null : member ?? this.member,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hasRestored: hasRestored ?? this.hasRestored,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      infoMessage: clearInfoMessage ? null : infoMessage ?? this.infoMessage,
      sessionRevision: sessionRevision ?? this.sessionRevision,
    );
  }
}

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
  }) : _authRepository = authRepository;

  final AuthRepository _authRepository;

  AuthState _state = const AuthState.initial();
  Future<void>? _sessionInvalidationFuture;

  AuthState get state => _state;

  Future<void> restoreSession() async {
    _setState(
      _state.copyWith(
        status: AuthStatus.restoring,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    try {
      final session = await _authRepository.restoreSession();
      _setAuthenticated(session.member, hasRestored: true);
    } on Object catch (error) {
      final infoMessage =
          error is ApiClientException && error.sessionInvalidated
              ? error.message
              : null;
      _setState(
        AuthState(
          status: AuthStatus.unauthenticated,
          hasRestored: true,
          infoMessage: infoMessage,
          sessionRevision: _state.sessionRevision + 1,
        ),
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    try {
      final session = await _authRepository.login(
        LoginRequest(email: email.trim(), password: password),
      );
      _setAuthenticated(session.member, hasRestored: true);
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          status: AuthStatus.unauthenticated,
          clearMember: true,
          isSubmitting: false,
          hasRestored: true,
          errorMessage: _messageFromError(error),
          sessionRevision: _state.sessionRevision + 1,
        ),
      );
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String nickname,
  }) async {
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    try {
      await _authRepository.signup(
        SignupRequest(
          email: email.trim(),
          password: password,
          nickname: nickname.trim(),
        ),
      );
      _setState(
        _state.copyWith(
          status: AuthStatus.unauthenticated,
          clearMember: true,
          isSubmitting: false,
          hasRestored: true,
          infoMessage: '가입이 완료되었습니다. 로그인해 주세요.',
        ),
      );
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          status: AuthStatus.unauthenticated,
          clearMember: true,
          isSubmitting: false,
          hasRestored: true,
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  Future<bool> requestPasswordReset({
    required String email,
  }) async {
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    try {
      await _authRepository.requestPasswordReset(
        PasswordResetRequest(email: email.trim()),
      );
      _setState(
        _state.copyWith(
          status: AuthStatus.unauthenticated,
          clearMember: true,
          isSubmitting: false,
          hasRestored: true,
          infoMessage: '계정이 있으면 재설정 안내가 전송됩니다.',
        ),
      );
      return true;
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          status: AuthStatus.unauthenticated,
          clearMember: true,
          isSubmitting: false,
          hasRestored: true,
          errorMessage: _messageFromError(error),
        ),
      );
      return false;
    }
  }

  Future<bool> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    try {
      await _authRepository.confirmPasswordReset(
        PasswordResetConfirmRequest(
          token: token.trim(),
          newPassword: newPassword,
        ),
      );
      _setState(
        _state.copyWith(
          status: AuthStatus.unauthenticated,
          clearMember: true,
          isSubmitting: false,
          hasRestored: true,
          infoMessage: '비밀번호가 변경되었습니다. 다시 로그인해 주세요.',
        ),
      );
      return true;
    } on Object catch (error) {
      _setState(
        _state.copyWith(
          status: AuthStatus.unauthenticated,
          clearMember: true,
          isSubmitting: false,
          hasRestored: true,
          errorMessage: _messageFromError(error),
        ),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _setUnauthenticated();
  }

  Future<void> completeExternalLogin(AuthSession session) async {
    await _authRepository.saveSession(session);
    _setAuthenticated(session.member, hasRestored: true);
  }

  Future<void> clearSession() async {
    try {
      await _authRepository.logout();
    } on Object {
      // 회원 탈퇴 후에는 서버 로그아웃 실패와 관계없이 로컬 세션을 정리한다.
    }

    _setUnauthenticated(infoMessage: '회원 탈퇴가 완료되었습니다.');
  }

  Future<void> invalidateSession({required String message}) {
    final currentInvalidation = _sessionInvalidationFuture;
    if (currentInvalidation != null) {
      return currentInvalidation;
    }

    final nextInvalidation = _invalidateSession(message);
    _sessionInvalidationFuture = nextInvalidation;
    return nextInvalidation.whenComplete(() {
      if (identical(_sessionInvalidationFuture, nextInvalidation)) {
        _sessionInvalidationFuture = null;
      }
    });
  }

  Future<void> _invalidateSession(String message) async {
    await _authRepository.clearLocalSession();
    if (_state.status == AuthStatus.unauthenticated && _state.hasRestored) {
      return;
    }
    _setUnauthenticated(infoMessage: message);
  }

  void _setAuthenticated(AuthMember member, {required bool hasRestored}) {
    _setState(
      AuthState(
        status: AuthStatus.authenticated,
        member: member,
        hasRestored: hasRestored,
        sessionRevision: _state.sessionRevision + 1,
      ),
    );
  }

  void _setUnauthenticated({String? infoMessage}) {
    _setState(
      AuthState(
        status: AuthStatus.unauthenticated,
        hasRestored: true,
        infoMessage: infoMessage,
        sessionRevision: _state.sessionRevision + 1,
      ),
    );
  }

  void _setState(AuthState nextState) {
    _state = nextState;
    notifyListeners();
  }

  String _messageFromError(Object error) {
    if (error is ApiClientException) {
      return error.message;
    }

    return '요청을 처리하지 못했습니다.';
  }
}

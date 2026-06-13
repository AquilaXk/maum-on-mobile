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
    this.externalLoginProviderIds,
    this.sessionRevision = 0,
  });

  const AuthState.initial()
      : status = AuthStatus.restoring,
        member = null,
        isSubmitting = false,
        hasRestored = false,
        errorMessage = null,
        infoMessage = null,
        externalLoginProviderIds = null,
        sessionRevision = 0;

  final AuthStatus status;
  final AuthMember? member;
  final bool isSubmitting;
  final bool hasRestored;
  final String? errorMessage;
  final String? infoMessage;
  final List<String>? externalLoginProviderIds;
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
    List<String>? externalLoginProviderIds,
    bool clearExternalLoginProviderIds = false,
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
      externalLoginProviderIds: clearExternalLoginProviderIds
          ? null
          : externalLoginProviderIds ?? this.externalLoginProviderIds,
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

  Future<void> loadExternalLoginProviders() async {
    try {
      final providerIds = await _authRepository.fetchOidcProviderIds();
      _setState(
        _state.copyWith(
          externalLoginProviderIds: _knownExternalLoginProviderIds(providerIds),
        ),
      );
    } on Object {
      // 서버 목록 조회가 실패하면 Provider 상태를 비워 호출 화면의 fallback 정책을 사용한다.
      _setState(_state.copyWith(clearExternalLoginProviderIds: true));
    }
  }

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
      final infoMessage = error is ApiClientException &&
              _shouldShowRestoreFailureMessage(error.kind)
          ? error.message
          : null;
      _setState(
        AuthState(
          status: AuthStatus.unauthenticated,
          hasRestored: true,
          infoMessage: infoMessage,
          externalLoginProviderIds: _state.externalLoginProviderIds,
          sessionRevision: _state.sessionRevision + 1,
        ),
      );
    }
  }

  bool _shouldShowRestoreFailureMessage(ApiErrorKind kind) {
    return switch (kind) {
      ApiErrorKind.sessionExpired ||
      ApiErrorKind.permissionChanged ||
      ApiErrorKind.accountBlocked ||
      ApiErrorKind.accountWithdrawn =>
        true,
      _ => false,
    };
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
    required String emailVerificationCode,
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
          emailVerificationCode: emailVerificationCode.trim(),
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

  Future<bool> requestSignupEmailVerification({
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
      await _authRepository.requestSignupEmailVerification(
        SignupEmailVerificationRequest(email: email.trim()),
      );
      _setState(
        _state.copyWith(
          status: AuthStatus.unauthenticated,
          clearMember: true,
          isSubmitting: false,
          hasRestored: true,
          infoMessage: '인증번호를 이메일로 보냈습니다.',
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

  Future<void> completeExternalLoginCallback({
    required String provider,
    required String code,
    required String state,
  }) async {
    final session = await _authRepository.exchangeOidcSession(
      OidcSessionRequest(
        provider: provider.trim(),
        code: code.trim(),
        state: state.trim(),
      ),
    );
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
        externalLoginProviderIds: _state.externalLoginProviderIds,
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
        externalLoginProviderIds: _state.externalLoginProviderIds,
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

  List<String> _knownExternalLoginProviderIds(List<String> providerIds) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final providerId in providerIds) {
      final id = providerId.trim().toLowerCase();
      if (!_knownProviderIds.contains(id) || !seen.add(id)) {
        continue;
      }
      normalized.add(id);
    }
    return List.unmodifiable(normalized);
  }

  static const _knownProviderIds = {
    'naver',
    'kakao',
    'facebook',
    'google',
    'apple',
  };
}

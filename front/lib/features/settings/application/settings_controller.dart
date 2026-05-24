import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../data/settings_repository.dart';
import '../domain/settings_models.dart';

class SettingsState {
  const SettingsState({
    this.settings,
    this.nicknameDraft = '',
    this.emailDraft = '',
    this.currentPasswordDraft = '',
    this.newPasswordDraft = '',
    this.withdrawPasswordDraft = '',
    this.isLoading = false,
    this.hasLoaded = false,
    this.isSubmitting = false,
    this.isWithdrawConfirmVisible = false,
    this.isWithdrawn = false,
    this.errorMessage,
    this.noticeMessage,
  });

  final MemberSettings? settings;
  final String nicknameDraft;
  final String emailDraft;
  final String currentPasswordDraft;
  final String newPasswordDraft;
  final String withdrawPasswordDraft;
  final bool isLoading;
  final bool hasLoaded;
  final bool isSubmitting;
  final bool isWithdrawConfirmVisible;
  final bool isWithdrawn;
  final String? errorMessage;
  final String? noticeMessage;

  bool get isSocialAccount => settings?.socialAccount ?? false;

  bool get canSaveNickname {
    final currentSettings = settings;
    return currentSettings != null &&
        !isSubmitting &&
        nicknameDraft.trim().isNotEmpty &&
        nicknameDraft.trim() != currentSettings.nickname;
  }

  bool get canSaveEmail {
    final currentSettings = settings;
    return currentSettings != null &&
        !isSubmitting &&
        !currentSettings.socialAccount &&
        _looksLikeEmail(emailDraft.trim()) &&
        emailDraft.trim() != currentSettings.email;
  }

  bool get canSavePassword {
    return settings != null &&
        !isSubmitting &&
        !isSocialAccount &&
        currentPasswordDraft.isNotEmpty &&
        newPasswordDraft.length >= 8;
  }

  bool get canConfirmWithdrawal {
    return settings != null &&
        !isSubmitting &&
        (isSocialAccount || withdrawPasswordDraft.trim().isNotEmpty);
  }

  SettingsState copyWith({
    MemberSettings? settings,
    String? nicknameDraft,
    String? emailDraft,
    String? currentPasswordDraft,
    String? newPasswordDraft,
    String? withdrawPasswordDraft,
    bool? isLoading,
    bool? hasLoaded,
    bool? isSubmitting,
    bool? isWithdrawConfirmVisible,
    bool? isWithdrawn,
    String? errorMessage,
    String? noticeMessage,
    bool clearErrorMessage = false,
    bool clearNoticeMessage = false,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      nicknameDraft: nicknameDraft ?? this.nicknameDraft,
      emailDraft: emailDraft ?? this.emailDraft,
      currentPasswordDraft:
          currentPasswordDraft ?? this.currentPasswordDraft,
      newPasswordDraft: newPasswordDraft ?? this.newPasswordDraft,
      withdrawPasswordDraft:
          withdrawPasswordDraft ?? this.withdrawPasswordDraft,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isWithdrawConfirmVisible:
          isWithdrawConfirmVisible ?? this.isWithdrawConfirmVisible,
      isWithdrawn: isWithdrawn ?? this.isWithdrawn,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      noticeMessage:
          clearNoticeMessage ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsRepository repository,
    VoidCallback? onUnauthorized,
    Future<void> Function()? onWithdrawn,
  })  : _repository = repository,
        _onUnauthorized = onUnauthorized,
        _onWithdrawn = onWithdrawn;

  final SettingsRepository _repository;
  final VoidCallback? _onUnauthorized;
  final Future<void> Function()? _onWithdrawn;

  SettingsState _state = const SettingsState();
  bool _isDisposed = false;

  SettingsState get state => _state;

  Future<void> load() async {
    _setState(
      _state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final settings = await _repository.fetchSettings();
      _setState(
        _state.copyWith(
          settings: settings,
          nicknameDraft: settings.nickname,
          emailDraft: settings.email,
          currentPasswordDraft: '',
          newPasswordDraft: '',
          withdrawPasswordDraft: '',
          isLoading: false,
          hasLoaded: true,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(
        _state.copyWith(
          isLoading: false,
          hasLoaded: true,
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  void updateNicknameDraft(String value) {
    _setState(
      _state.copyWith(
        nicknameDraft: value,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void updateEmailDraft(String value) {
    _setState(
      _state.copyWith(
        emailDraft: value,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void updateCurrentPasswordDraft(String value) {
    _setState(
      _state.copyWith(
        currentPasswordDraft: value,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void updateNewPasswordDraft(String value) {
    _setState(
      _state.copyWith(
        newPasswordDraft: value,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void updateWithdrawPasswordDraft(String value) {
    _setState(
      _state.copyWith(
        withdrawPasswordDraft: value,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> saveNickname() {
    if (!_state.canSaveNickname) {
      return _failValidation('닉네임을 입력해 주세요.');
    }

    return _submitSettingsChange(
      () => _repository.updateNickname(_state.nicknameDraft.trim()),
      noticeMessage: '닉네임이 저장되었습니다.',
    );
  }

  Future<void> saveEmail() {
    if (_state.isSocialAccount) {
      return _failValidation('소셜 계정은 이 항목을 변경할 수 없습니다.');
    }
    if (!_state.canSaveEmail) {
      return _failValidation('이메일 형식을 확인해 주세요.');
    }

    return _submitSettingsChange(
      () => _repository.updateEmail(_state.emailDraft.trim()),
      noticeMessage: '이메일이 저장되었습니다.',
    );
  }

  Future<void> savePassword() async {
    if (_state.isSocialAccount) {
      await _failValidation('소셜 계정은 이 항목을 변경할 수 없습니다.');
      return;
    }
    if (!_state.canSavePassword) {
      await _failValidation('현재 비밀번호와 새 비밀번호를 확인해 주세요.');
      return;
    }

    await _submitSettingsChange(
      () => _repository.updatePassword(
        PasswordChangeDraft(
          currentPassword: _state.currentPasswordDraft,
          newPassword: _state.newPasswordDraft,
        ),
      ),
      noticeMessage: '비밀번호가 저장되었습니다.',
    );
    _setState(
      _state.copyWith(
        currentPasswordDraft: '',
        newPasswordDraft: '',
      ),
    );
  }

  Future<void> toggleRandomSetting() {
    return _submitSettingsChange(
      _repository.toggleRandomSetting,
      noticeMessage: '랜덤 편지 수신 설정이 저장되었습니다.',
    );
  }

  void requestWithdrawal() {
    _setState(
      _state.copyWith(
        isWithdrawConfirmVisible: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void cancelWithdrawal() {
    _setState(
      _state.copyWith(
        isWithdrawConfirmVisible: false,
        withdrawPasswordDraft: '',
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> confirmWithdrawal() async {
    if (!_state.canConfirmWithdrawal) {
      await _failValidation('회원 탈퇴를 위해 비밀번호를 입력해 주세요.');
      return;
    }

    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      await _repository.withdraw(
        currentPassword:
            _state.isSocialAccount ? null : _state.withdrawPasswordDraft,
      );
      _setState(
        _state.copyWith(
          isSubmitting: false,
          isWithdrawn: true,
          noticeMessage: '회원 탈퇴가 완료되었습니다.',
        ),
      );
      await _onWithdrawn?.call();
    } on Object catch (error) {
      _handleError(error);
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  Future<void> _submitSettingsChange(
    Future<MemberSettings> Function() submit, {
    required String noticeMessage,
  }) async {
    if (_state.isSubmitting) {
      return;
    }

    _setState(
      _state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final settings = await submit();
      _setState(
        _state.copyWith(
          settings: settings,
          nicknameDraft: settings.nickname,
          emailDraft: settings.email,
          isSubmitting: false,
          noticeMessage: noticeMessage,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  Future<void> _failValidation(String message) {
    _setState(
      _state.copyWith(
        errorMessage: message,
        clearNoticeMessage: true,
      ),
    );
    return Future<void>.value();
  }

  void _handleError(Object error) {
    if (error is ApiClientException &&
        error.kind == ApiErrorKind.unauthorized) {
      _onUnauthorized?.call();
    }
  }

  String _messageFromError(Object error) {
    if (error is ApiClientException) {
      return error.message;
    }

    return '설정을 처리하지 못했습니다.';
  }

  void _setState(SettingsState state) {
    if (_isDisposed) {
      return;
    }

    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

bool _looksLikeEmail(String value) {
  final atIndex = value.indexOf('@');
  final dotIndex = value.lastIndexOf('.');
  return atIndex > 0 && dotIndex > atIndex + 1 && dotIndex < value.length - 1;
}

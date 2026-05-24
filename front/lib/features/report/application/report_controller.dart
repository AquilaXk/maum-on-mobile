import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../../moderation/data/content_moderation_repository.dart';
import '../../moderation/domain/content_moderation_models.dart';
import '../data/report_repository.dart';
import '../domain/report_models.dart';

class ReportState {
  const ReportState({
    this.target,
    this.reason = ReportReasonCode.profanity,
    this.content = '',
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.submittedReportId,
    this.errorMessage,
    this.noticeMessage,
  });

  final ReportTarget? target;
  final ReportReasonCode reason;
  final String content;
  final bool isSubmitting;
  final bool isSubmitted;
  final int? submittedReportId;
  final String? errorMessage;
  final String? noticeMessage;

  static const int contentMaxLength = 300;
  static const int otherReasonMinLength = 5;

  String? get validationMessage {
    final currentTarget = target;
    if (currentTarget == null) {
      return '신고 대상을 선택해 주세요.';
    }

    if (currentTarget.id <= 0) {
      return '신고 대상 번호를 확인해 주세요.';
    }

    if (content.length > contentMaxLength) {
      return '추가 설명은 $contentMaxLength자 이하로 작성해 주세요.';
    }

    if (reason.requiresDescription &&
        content.trim().length < otherReasonMinLength) {
      return '기타 사유는 $otherReasonMinLength자 이상 입력해 주세요.';
    }

    return null;
  }

  bool get canSubmit {
    return !isSubmitting && !isSubmitted && validationMessage == null;
  }

  ReportState copyWith({
    ReportTarget? target,
    ReportReasonCode? reason,
    String? content,
    bool? isSubmitting,
    bool? isSubmitted,
    int? submittedReportId,
    String? errorMessage,
    String? noticeMessage,
    bool clearTarget = false,
    bool clearErrorMessage = false,
    bool clearNoticeMessage = false,
    bool clearSubmittedReportId = false,
  }) {
    return ReportState(
      target: clearTarget ? null : target ?? this.target,
      reason: reason ?? this.reason,
      content: content ?? this.content,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      submittedReportId: clearSubmittedReportId
          ? null
          : submittedReportId ?? this.submittedReportId,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      noticeMessage:
          clearNoticeMessage ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

class ReportController extends ChangeNotifier {
  ReportController({
    required ReportRepository repository,
    ContentModerationRepository? moderationRepository,
    VoidCallback? onUnauthorized,
  })  : _repository = repository,
        _moderationRepository = moderationRepository,
        _onUnauthorized = onUnauthorized;

  final ReportRepository _repository;
  final ContentModerationRepository? _moderationRepository;
  final VoidCallback? _onUnauthorized;

  ReportState _state = const ReportState();
  bool _isDisposed = false;

  ReportState get state => _state;

  void selectTarget(ReportTarget target) {
    _setState(
      _state.copyWith(
        target: target,
        isSubmitted: false,
        clearSubmittedReportId: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void clearTarget() {
    _setState(
      _state.copyWith(
        clearTarget: true,
        isSubmitted: false,
        clearSubmittedReportId: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void selectReason(ReportReasonCode reason) {
    _setState(
      _state.copyWith(
        reason: reason,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void updateContent(String content) {
    _setState(
      _state.copyWith(
        content: content.length > ReportState.contentMaxLength
            ? content.substring(0, ReportState.contentMaxLength)
            : content,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> submit() async {
    if (_state.isSubmitted || _state.isSubmitting) {
      return;
    }

    final validationMessage = _state.validationMessage;
    if (validationMessage != null) {
      _setState(
        _state.copyWith(
          errorMessage: validationMessage,
          clearNoticeMessage: true,
        ),
      );
      return;
    }

    final target = _state.target;
    if (target == null) {
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
      if (!await _ensureModerationAllowed(_state.content.trim())) {
        return;
      }

      final reportId = await _repository.createReport(
        ReportDraft(
          target: target,
          reason: _state.reason,
          content: _state.content.trim(),
        ),
      );
      _setState(
        _state.copyWith(
          isSubmitting: false,
          isSubmitted: true,
          submittedReportId: reportId,
          noticeMessage: '신고가 접수되었습니다.',
        ),
      );
    } on Object catch (error) {
      if (error is ApiClientException &&
          error.kind == ApiErrorKind.unauthorized) {
        _onUnauthorized?.call();
      }
      _setState(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: _messageFromError(error),
        ),
      );
    }
  }

  String _messageFromError(Object error) {
    if (error is ApiClientException) {
      return error.message;
    }

    return '신고를 접수하지 못했습니다.';
  }

  Future<bool> _ensureModerationAllowed(String text) async {
    if (text.isEmpty) {
      return true;
    }
    final repository = _moderationRepository;
    if (repository == null) {
      return true;
    }

    final result = await repository.reviewText(
      targetType: ContentModerationTarget.report,
      text: text,
    );
    if (result.allowed) {
      if (result.riskLevel != ContentModerationRiskLevel.low) {
        _setState(_state.copyWith(noticeMessage: result.message));
      }
      return true;
    }

    _setState(
      _state.copyWith(
        isSubmitting: false,
        errorMessage: result.message,
        clearNoticeMessage: true,
      ),
    );
    return false;
  }

  void _setState(ReportState state) {
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

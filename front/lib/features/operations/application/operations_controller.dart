import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../report/data/report_repository.dart';
import '../../report/domain/report_models.dart';

class OperationsState {
  const OperationsState({
    this.reports = const [],
    this.selectedReport,
    this.selectedAction = AdminReportAction.resolved,
    this.actionReason = '',
    this.isLoading = false,
    this.isDetailLoading = false,
    this.isSubmitting = false,
    this.hasLoaded = false,
    this.errorMessage,
    this.noticeMessage,
  });

  final List<AdminReportSummary> reports;
  final AdminReportDetail? selectedReport;
  final AdminReportAction selectedAction;
  final String actionReason;
  final bool isLoading;
  final bool isDetailLoading;
  final bool isSubmitting;
  final bool hasLoaded;
  final String? errorMessage;
  final String? noticeMessage;

  bool get isEmpty => hasLoaded && reports.isEmpty && errorMessage == null;

  bool get canSubmitAction {
    return selectedReport != null &&
        actionReason.trim().length >= actionReasonMinLength &&
        !isSubmitting;
  }

  static const int actionReasonMinLength = 4;

  OperationsState copyWith({
    List<AdminReportSummary>? reports,
    AdminReportDetail? selectedReport,
    bool clearSelectedReport = false,
    AdminReportAction? selectedAction,
    String? actionReason,
    bool? isLoading,
    bool? isDetailLoading,
    bool? isSubmitting,
    bool? hasLoaded,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? noticeMessage,
    bool clearNoticeMessage = false,
  }) {
    return OperationsState(
      reports: reports ?? this.reports,
      selectedReport:
          clearSelectedReport ? null : selectedReport ?? this.selectedReport,
      selectedAction: selectedAction ?? this.selectedAction,
      actionReason: actionReason ?? this.actionReason,
      isLoading: isLoading ?? this.isLoading,
      isDetailLoading: isDetailLoading ?? this.isDetailLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      noticeMessage:
          clearNoticeMessage ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

class OperationsController extends ChangeNotifier {
  OperationsController({
    required ReportRepository repository,
    VoidCallback? onUnauthorized,
  })  : _repository = repository,
        _onUnauthorized = onUnauthorized;

  final ReportRepository _repository;
  final VoidCallback? _onUnauthorized;

  OperationsState _state = const OperationsState();
  bool _isDisposed = false;

  OperationsState get state => _state;

  Future<void> load() async {
    _setState(
      _state.copyWith(
        isLoading: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final reports = await _repository.fetchAdminReports();
      _setState(
        _state.copyWith(
          reports: reports,
          isLoading: false,
          hasLoaded: true,
          clearErrorMessage: true,
        ),
      );
      if (reports.isNotEmpty && _state.selectedReport == null) {
        await openReport(reports.first);
      }
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isLoading: false, hasLoaded: true));
    }
  }

  Future<void> openReport(AdminReportSummary report) async {
    _setState(
      _state.copyWith(
        isDetailLoading: true,
        selectedAction: AdminReportAction.fromApiValue(report.status),
        actionReason: report.actionReason ?? '',
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final detail = await _repository.fetchAdminReport(report.id);
      _setState(
        _state.copyWith(
          selectedReport: detail,
          selectedAction: AdminReportAction.fromApiValue(detail.status),
          actionReason: detail.actionReason ?? '',
          isDetailLoading: false,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isDetailLoading: false));
    }
  }

  void selectAction(AdminReportAction action) {
    _setState(
      _state.copyWith(
        selectedAction: action,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void updateActionReason(String reason) {
    _setState(
      _state.copyWith(
        actionReason: reason,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> submitAction() async {
    final report = _state.selectedReport;
    if (report == null || _state.isSubmitting) {
      return;
    }

    if (_state.actionReason.trim().length <
        OperationsState.actionReasonMinLength) {
      _setState(
        _state.copyWith(
          errorMessage:
              '조치 사유를 ${OperationsState.actionReasonMinLength}자 이상 입력해 주세요.',
          clearNoticeMessage: true,
        ),
      );
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
      final result = await _repository.updateAdminReportStatus(
        report.id,
        AdminReportActionDraft(
          action: _state.selectedAction,
          reason: _state.actionReason,
        ),
      );
      final reports = await _repository.fetchAdminReports();
      final detail = await _repository.fetchAdminReport(result.id);
      _setState(
        _state.copyWith(
          reports: reports,
          selectedReport: detail,
          selectedAction: AdminReportAction.fromApiValue(detail.status),
          actionReason: detail.actionReason ?? '',
          isSubmitting: false,
          noticeMessage: '운영 조치가 저장되었습니다.',
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isSubmitting: false));
    }
  }

  void _handleError(Object error) {
    if (error is ApiClientException &&
        error.kind == ApiErrorKind.unauthorized) {
      _onUnauthorized?.call();
    }

    _setState(
      _state.copyWith(
        errorMessage: error is ApiClientException
            ? error.message
            : '운영 요청을 처리하지 못했습니다.',
        clearNoticeMessage: true,
      ),
    );
  }

  void _setState(OperationsState state) {
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

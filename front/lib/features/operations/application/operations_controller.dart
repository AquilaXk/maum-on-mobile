import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../data/operations_repository.dart';
import '../domain/operations_models.dart';
import '../../report/data/report_repository.dart';
import '../../report/domain/report_models.dart';

enum OperationsView { dashboard, observability, system, members, letters, reports }

class OperationsState {
  const OperationsState({
    this.view = OperationsView.dashboard,
    this.dashboard,
    this.apiMetrics,
    this.systemStatus,
    this.reports = const [],
    this.selectedReport,
    this.reportStatusFilter,
    this.reportTargetTypeFilter,
    this.members = const [],
    this.memberPage,
    this.selectedMember,
    this.letters = const [],
    this.letterPage,
    this.selectedLetter,
    this.memberQuery = '',
    this.memberStatusFilter,
    this.memberRoleFilter,
    this.memberSocialAccountFilter,
    this.memberActionReason = '',
    this.letterQuery = '',
    this.letterStatusFilter,
    this.letterActionReason = '',
    this.letterNote = '',
    this.letterReceiverQuery = '',
    this.letterReceiverCandidates = const [],
    this.selectedLetterReceiverId,
    this.selectedAction = AdminReportAction.resolved,
    this.actionReason = '',
    this.isLoading = false,
    this.isMemberLoading = false,
    this.isMemberDetailLoading = false,
    this.isMemberActionSubmitting = false,
    this.isLetterLoading = false,
    this.isLetterDetailLoading = false,
    this.isLetterActionSubmitting = false,
    this.isLetterReceiverLoading = false,
    this.isDetailLoading = false,
    this.isMetricsLoading = false,
    this.isSystemStatusLoading = false,
    this.isSubmitting = false,
    this.hasLoaded = false,
    this.hasMetricsLoaded = false,
    this.hasSystemStatusLoaded = false,
    this.isMetricsPermissionError = false,
    this.isSystemStatusPermissionError = false,
    this.errorMessage,
    this.metricsErrorMessage,
    this.systemStatusErrorMessage,
    this.noticeMessage,
  });

  final OperationsView view;
  final OperationsDashboard? dashboard;
  final MobileApiMetricsSnapshot? apiMetrics;
  final OperationsSystemStatus? systemStatus;
  final List<AdminReportSummary> reports;
  final AdminReportDetail? selectedReport;
  final String? reportStatusFilter;
  final ReportTargetType? reportTargetTypeFilter;
  final List<AdminMemberSummary> members;
  final AdminMemberPage? memberPage;
  final AdminMemberDetail? selectedMember;
  final List<AdminLetterSummary> letters;
  final AdminLetterPage? letterPage;
  final AdminLetterDetail? selectedLetter;
  final String memberQuery;
  final String? memberStatusFilter;
  final String? memberRoleFilter;
  final bool? memberSocialAccountFilter;
  final String memberActionReason;
  final String letterQuery;
  final String? letterStatusFilter;
  final String letterActionReason;
  final String letterNote;
  final String letterReceiverQuery;
  final List<AdminMemberSummary> letterReceiverCandidates;
  final int? selectedLetterReceiverId;
  final AdminReportAction selectedAction;
  final String actionReason;
  final bool isLoading;
  final bool isMemberLoading;
  final bool isMemberDetailLoading;
  final bool isMemberActionSubmitting;
  final bool isLetterLoading;
  final bool isLetterDetailLoading;
  final bool isLetterActionSubmitting;
  final bool isLetterReceiverLoading;
  final bool isDetailLoading;
  final bool isMetricsLoading;
  final bool isSystemStatusLoading;
  final bool isSubmitting;
  final bool hasLoaded;
  final bool hasMetricsLoaded;
  final bool hasSystemStatusLoaded;
  final bool isMetricsPermissionError;
  final bool isSystemStatusPermissionError;
  final String? errorMessage;
  final String? metricsErrorMessage;
  final String? systemStatusErrorMessage;
  final String? noticeMessage;

  List<AdminReportSummary> get visibleReports {
    final filtered = reports.where((report) {
      final statusMatches =
          reportStatusFilter == null || report.status == reportStatusFilter;
      final targetMatches = reportTargetTypeFilter == null ||
          report.targetType == reportTargetTypeFilter;
      return statusMatches && targetMatches;
    }).toList(growable: false);
    return [...filtered]..sort((a, b) {
        final openComparison =
            (b.isOpen ? 1 : 0).compareTo(a.isOpen ? 1 : 0);
        if (openComparison != 0) {
          return openComparison;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  bool get isEmpty => hasLoaded && visibleReports.isEmpty && errorMessage == null;

  bool get isMemberEmpty {
    return hasLoaded && members.isEmpty && errorMessage == null;
  }

  bool get canLoadMoreMembers {
    return memberPage != null && !memberPage!.last && !isMemberLoading;
  }

  bool get isLetterEmpty {
    return hasLoaded && letters.isEmpty && errorMessage == null;
  }

  bool get isMetricsEmpty {
    return hasMetricsLoaded &&
        apiMetrics != null &&
        !apiMetrics!.hasData &&
        metricsErrorMessage == null;
  }

  bool get canLoadMoreLetters {
    return letterPage != null && !letterPage!.last && !isLetterLoading;
  }

  bool get canSubmitAction {
    return selectedReport != null &&
        actionReason.trim().length >= actionReasonMinLength &&
        !isSubmitting;
  }

  bool get canSubmitMemberAction {
    return selectedMember != null &&
        memberActionReason.trim().length >= actionReasonMinLength &&
        !isMemberActionSubmitting;
  }

  bool get canSubmitLetterAction {
    return selectedLetter != null &&
        letterActionReason.trim().length >= actionReasonMinLength &&
        !isLetterActionSubmitting;
  }

  bool get canSubmitLetterNote {
    return canSubmitLetterAction &&
        letterNote.trim().length >= letterNoteMinLength;
  }

  bool get canSubmitLetterReassign {
    return canSubmitLetterAction && selectedLetterReceiverId != null;
  }

  static const int actionReasonMinLength = 4;
  static const int letterNoteMinLength = 2;

  OperationsState copyWith({
    OperationsView? view,
    OperationsDashboard? dashboard,
    MobileApiMetricsSnapshot? apiMetrics,
    OperationsSystemStatus? systemStatus,
    List<AdminReportSummary>? reports,
    AdminReportDetail? selectedReport,
    bool clearSelectedReport = false,
    String? reportStatusFilter,
    bool clearReportStatusFilter = false,
    ReportTargetType? reportTargetTypeFilter,
    bool clearReportTargetTypeFilter = false,
    List<AdminMemberSummary>? members,
    AdminMemberPage? memberPage,
    AdminMemberDetail? selectedMember,
    bool clearSelectedMember = false,
    List<AdminLetterSummary>? letters,
    AdminLetterPage? letterPage,
    AdminLetterDetail? selectedLetter,
    bool clearSelectedLetter = false,
    String? memberQuery,
    String? memberStatusFilter,
    bool clearMemberStatusFilter = false,
    String? memberRoleFilter,
    bool clearMemberRoleFilter = false,
    bool? memberSocialAccountFilter,
    bool clearMemberSocialAccountFilter = false,
    String? memberActionReason,
    String? letterQuery,
    String? letterStatusFilter,
    bool clearLetterStatusFilter = false,
    String? letterActionReason,
    String? letterNote,
    String? letterReceiverQuery,
    List<AdminMemberSummary>? letterReceiverCandidates,
    int? selectedLetterReceiverId,
    bool clearSelectedLetterReceiver = false,
    AdminReportAction? selectedAction,
    String? actionReason,
    bool? isLoading,
    bool? isMemberLoading,
    bool? isMemberDetailLoading,
    bool? isMemberActionSubmitting,
    bool? isLetterLoading,
    bool? isLetterDetailLoading,
    bool? isLetterActionSubmitting,
    bool? isLetterReceiverLoading,
    bool? isDetailLoading,
    bool? isMetricsLoading,
    bool? isSystemStatusLoading,
    bool? isSubmitting,
    bool? hasLoaded,
    bool? hasMetricsLoaded,
    bool? hasSystemStatusLoaded,
    bool? isMetricsPermissionError,
    bool? isSystemStatusPermissionError,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? metricsErrorMessage,
    bool clearMetricsErrorMessage = false,
    String? systemStatusErrorMessage,
    bool clearSystemStatusErrorMessage = false,
    String? noticeMessage,
    bool clearNoticeMessage = false,
  }) {
    return OperationsState(
      view: view ?? this.view,
      dashboard: dashboard ?? this.dashboard,
      apiMetrics: apiMetrics ?? this.apiMetrics,
      systemStatus: systemStatus ?? this.systemStatus,
      reports: reports ?? this.reports,
      selectedReport:
          clearSelectedReport ? null : selectedReport ?? this.selectedReport,
      reportStatusFilter: clearReportStatusFilter
          ? null
          : reportStatusFilter ?? this.reportStatusFilter,
      reportTargetTypeFilter: clearReportTargetTypeFilter
          ? null
          : reportTargetTypeFilter ?? this.reportTargetTypeFilter,
      members: members ?? this.members,
      memberPage: memberPage ?? this.memberPage,
      selectedMember:
          clearSelectedMember ? null : selectedMember ?? this.selectedMember,
      letters: letters ?? this.letters,
      letterPage: letterPage ?? this.letterPage,
      selectedLetter:
          clearSelectedLetter ? null : selectedLetter ?? this.selectedLetter,
      memberQuery: memberQuery ?? this.memberQuery,
      memberStatusFilter: clearMemberStatusFilter
          ? null
          : memberStatusFilter ?? this.memberStatusFilter,
      memberRoleFilter: clearMemberRoleFilter
          ? null
          : memberRoleFilter ?? this.memberRoleFilter,
      memberSocialAccountFilter: clearMemberSocialAccountFilter
          ? null
          : memberSocialAccountFilter ?? this.memberSocialAccountFilter,
      memberActionReason: memberActionReason ?? this.memberActionReason,
      letterQuery: letterQuery ?? this.letterQuery,
      letterStatusFilter: clearLetterStatusFilter
          ? null
          : letterStatusFilter ?? this.letterStatusFilter,
      letterActionReason: letterActionReason ?? this.letterActionReason,
      letterNote: letterNote ?? this.letterNote,
      letterReceiverQuery: letterReceiverQuery ?? this.letterReceiverQuery,
      letterReceiverCandidates:
          letterReceiverCandidates ?? this.letterReceiverCandidates,
      selectedLetterReceiverId: clearSelectedLetterReceiver
          ? null
          : selectedLetterReceiverId ?? this.selectedLetterReceiverId,
      selectedAction: selectedAction ?? this.selectedAction,
      actionReason: actionReason ?? this.actionReason,
      isLoading: isLoading ?? this.isLoading,
      isMemberLoading: isMemberLoading ?? this.isMemberLoading,
      isMemberDetailLoading: isMemberDetailLoading ?? this.isMemberDetailLoading,
      isMemberActionSubmitting:
          isMemberActionSubmitting ?? this.isMemberActionSubmitting,
      isLetterLoading: isLetterLoading ?? this.isLetterLoading,
      isLetterDetailLoading:
          isLetterDetailLoading ?? this.isLetterDetailLoading,
      isLetterActionSubmitting:
          isLetterActionSubmitting ?? this.isLetterActionSubmitting,
      isLetterReceiverLoading:
          isLetterReceiverLoading ?? this.isLetterReceiverLoading,
      isDetailLoading: isDetailLoading ?? this.isDetailLoading,
      isMetricsLoading: isMetricsLoading ?? this.isMetricsLoading,
      isSystemStatusLoading:
          isSystemStatusLoading ?? this.isSystemStatusLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      hasMetricsLoaded: hasMetricsLoaded ?? this.hasMetricsLoaded,
      hasSystemStatusLoaded:
          hasSystemStatusLoaded ?? this.hasSystemStatusLoaded,
      isMetricsPermissionError:
          isMetricsPermissionError ?? this.isMetricsPermissionError,
      isSystemStatusPermissionError:
          isSystemStatusPermissionError ?? this.isSystemStatusPermissionError,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      metricsErrorMessage: clearMetricsErrorMessage
          ? null
          : metricsErrorMessage ?? this.metricsErrorMessage,
      systemStatusErrorMessage: clearSystemStatusErrorMessage
          ? null
          : systemStatusErrorMessage ?? this.systemStatusErrorMessage,
      noticeMessage:
          clearNoticeMessage ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}

class OperationsController extends ChangeNotifier {
  OperationsController({
    required ReportRepository reportRepository,
    required OperationsRepository operationsRepository,
    OperationsSystemEnvironment systemEnvironment =
        const OperationsSystemEnvironment(),
    ValueChanged<String>? onUnauthorized,
  })  : _reportRepository = reportRepository,
        _operationsRepository = operationsRepository,
        _systemEnvironment = systemEnvironment,
        _onUnauthorized = onUnauthorized;

  final ReportRepository _reportRepository;
  final OperationsRepository _operationsRepository;
  final OperationsSystemEnvironment _systemEnvironment;
  final ValueChanged<String>? _onUnauthorized;

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
      final dashboard = await _operationsRepository.fetchDashboard();
      final reports = await _reportRepository.fetchAdminReports();
      final memberPage = await _operationsRepository.fetchMembers(
        query: _state.memberQuery,
        status: _state.memberStatusFilter,
        role: _state.memberRoleFilter,
        socialAccount: _state.memberSocialAccountFilter,
      );
      final letterPage = await _operationsRepository.fetchLetters(
        query: _state.letterQuery,
        status: _state.letterStatusFilter,
      );
      _setState(
        _state.copyWith(
          dashboard: dashboard,
          reports: reports,
          members: memberPage.content,
          memberPage: memberPage,
          letters: letterPage.content,
          letterPage: letterPage,
          isLoading: false,
          hasLoaded: true,
          clearErrorMessage: true,
        ),
      );
      await _loadObservability(showLoading: false);
      if (_state.visibleReports.isNotEmpty && _state.selectedReport == null) {
        await openReport(_state.visibleReports.first);
      }
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isLoading: false, hasLoaded: true));
    }
  }

  void selectView(OperationsView view) {
    _setState(_state.copyWith(view: view, clearNoticeMessage: true));
    if (view == OperationsView.observability &&
        !_state.hasMetricsLoaded &&
        !_state.isMetricsLoading) {
      unawaited(refreshObservability());
    }
    if (view == OperationsView.system &&
        !_state.hasSystemStatusLoaded &&
        !_state.isSystemStatusLoading) {
      unawaited(refreshSystemStatus());
    }
  }

  Future<void> refreshObservability() {
    return _loadObservability(showLoading: true);
  }

  Future<void> refreshSystemStatus() {
    return _loadSystemStatus(showLoading: true);
  }

  Future<void> _loadObservability({required bool showLoading}) async {
    if (_state.isMetricsLoading) {
      return;
    }

    _setState(
      _state.copyWith(
        isMetricsLoading: showLoading,
        isMetricsPermissionError: false,
        clearMetricsErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final metrics = await _operationsRepository.fetchApiMetrics();
      _setState(
        _state.copyWith(
          apiMetrics: metrics,
          isMetricsLoading: false,
          hasMetricsLoaded: true,
          isMetricsPermissionError: false,
          clearMetricsErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleMetricsError(error);
      _setState(
        _state.copyWith(
          isMetricsLoading: false,
          hasMetricsLoaded: true,
        ),
      );
    }
  }

  Future<void> _loadSystemStatus({required bool showLoading}) async {
    if (_state.isSystemStatusLoading) {
      return;
    }

    _setState(
      _state.copyWith(
        isSystemStatusLoading: showLoading,
        isSystemStatusPermissionError: false,
        clearSystemStatusErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final status = await _operationsRepository.fetchSystemStatus(
        _systemEnvironment,
      );
      _setState(
        _state.copyWith(
          systemStatus: status,
          isSystemStatusLoading: false,
          hasSystemStatusLoaded: true,
          isSystemStatusPermissionError:
              status.kind == OperationsSystemStatusKind.permissionDenied,
          systemStatusErrorMessage:
              status.kind == OperationsSystemStatusKind.connected
                  ? null
                  : status.message,
          clearSystemStatusErrorMessage:
              status.kind == OperationsSystemStatusKind.connected,
        ),
      );
    } on Object catch (error) {
      _handleSystemStatusError(error);
      _setState(
        _state.copyWith(
          isSystemStatusLoading: false,
          hasSystemStatusLoaded: true,
        ),
      );
    }
  }

  void selectReportStatusFilter(String? status) {
    _setState(
      _state.copyWith(
        reportStatusFilter: status,
        clearReportStatusFilter: status == null,
        clearNoticeMessage: true,
      ),
    );
  }

  void selectReportTargetTypeFilter(ReportTargetType? targetType) {
    _setState(
      _state.copyWith(
        reportTargetTypeFilter: targetType,
        clearReportTargetTypeFilter: targetType == null,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> updateMemberQuery(String query) async {
    _setState(_state.copyWith(memberQuery: query));
    await loadMembers(reset: true);
  }

  Future<void> selectMemberStatusFilter(String? status) async {
    _setState(
      _state.copyWith(
        memberStatusFilter: status,
        clearMemberStatusFilter: status == null,
      ),
    );
    await loadMembers(reset: true);
  }

  Future<void> selectMemberRoleFilter(String? role) async {
    _setState(
      _state.copyWith(
        memberRoleFilter: role,
        clearMemberRoleFilter: role == null,
      ),
    );
    await loadMembers(reset: true);
  }

  Future<void> selectMemberSocialAccountFilter(bool? socialAccount) async {
    _setState(
      _state.copyWith(
        memberSocialAccountFilter: socialAccount,
        clearMemberSocialAccountFilter: socialAccount == null,
      ),
    );
    await loadMembers(reset: true);
  }

  Future<void> loadMembers({bool reset = false}) async {
    if (_state.isMemberLoading) {
      return;
    }

    final nextPage = reset ? 0 : (_state.memberPage?.page ?? -1) + 1;
    _setState(
      _state.copyWith(
        isMemberLoading: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final page = await _operationsRepository.fetchMembers(
        query: _state.memberQuery,
        status: _state.memberStatusFilter,
        role: _state.memberRoleFilter,
        socialAccount: _state.memberSocialAccountFilter,
        page: nextPage,
      );
      _setState(
        _state.copyWith(
          members: reset ? page.content : [..._state.members, ...page.content],
          memberPage: page,
          isMemberLoading: false,
          hasLoaded: true,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isMemberLoading: false, hasLoaded: true));
    }
  }

  Future<void> openMember(AdminMemberSummary member) async {
    _setState(
      _state.copyWith(
        isMemberDetailLoading: true,
        memberActionReason: '',
        clearSelectedMember: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final detail = await _operationsRepository.fetchMemberDetail(member.id);
      _setState(
        _state.copyWith(
          selectedMember: detail,
          isMemberDetailLoading: false,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isMemberDetailLoading: false));
    }
  }

  void updateMemberActionReason(String reason) {
    _setState(
      _state.copyWith(
        memberActionReason: reason,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> blockSelectedMember() {
    return _submitMemberStatus('BLOCKED');
  }

  Future<void> unblockSelectedMember() {
    return _submitMemberStatus('ACTIVE');
  }

  Future<void> promoteSelectedMember() {
    return _submitMemberRole('ADMIN');
  }

  Future<void> demoteSelectedMember() {
    return _submitMemberRole('USER');
  }

  Future<void> revokeSelectedMemberSessions() {
    return _submitMemberSessionRevoke();
  }

  Future<void> updateLetterQuery(String query) async {
    _setState(_state.copyWith(letterQuery: query));
    await loadLetters(reset: true);
  }

  Future<void> selectLetterStatusFilter(String? status) async {
    _setState(
      _state.copyWith(
        letterStatusFilter: status,
        clearLetterStatusFilter: status == null,
      ),
    );
    await loadLetters(reset: true);
  }

  Future<void> loadLetters({bool reset = false}) async {
    if (_state.isLetterLoading) {
      return;
    }

    final nextPage = reset ? 0 : (_state.letterPage?.page ?? -1) + 1;
    _setState(
      _state.copyWith(
        isLetterLoading: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final page = await _operationsRepository.fetchLetters(
        status: _state.letterStatusFilter,
        query: _state.letterQuery,
        page: nextPage,
      );
      _setState(
        _state.copyWith(
          letters: reset ? page.content : [..._state.letters, ...page.content],
          letterPage: page,
          isLetterLoading: false,
          hasLoaded: true,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isLetterLoading: false, hasLoaded: true));
    }
  }

  Future<void> openLetter(AdminLetterSummary letter) async {
    _setState(
      _state.copyWith(
        isLetterDetailLoading: true,
        letterActionReason: '',
        letterNote: '',
        letterReceiverQuery: '',
        letterReceiverCandidates: const [],
        clearSelectedLetter: true,
        clearSelectedLetterReceiver: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final detail = await _operationsRepository.fetchLetterDetail(letter.id);
      _setState(
        _state.copyWith(
          selectedLetter: detail,
          isLetterDetailLoading: false,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isLetterDetailLoading: false));
    }
  }

  void updateLetterActionReason(String reason) {
    _setState(
      _state.copyWith(
        letterActionReason: reason,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  void updateLetterNote(String note) {
    _setState(
      _state.copyWith(
        letterNote: note,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> searchLetterReceivers(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      _setState(
        _state.copyWith(
          letterReceiverQuery: '',
          letterReceiverCandidates: const [],
          isLetterReceiverLoading: false,
          clearSelectedLetterReceiver: true,
          clearErrorMessage: true,
          clearNoticeMessage: true,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        letterReceiverQuery: trimmedQuery,
        isLetterReceiverLoading: true,
        clearSelectedLetterReceiver: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final page = await _operationsRepository.fetchMembers(
        query: trimmedQuery,
        status: 'ACTIVE',
        page: 0,
        size: 10,
      );
      _setState(
        _state.copyWith(
          letterReceiverCandidates: page.content,
          isLetterReceiverLoading: false,
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isLetterReceiverLoading: false));
    }
  }

  void selectLetterReceiver(int memberId) {
    _setState(
      _state.copyWith(
        selectedLetterReceiverId: memberId,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );
  }

  Future<void> addSelectedLetterNote() {
    return _submitLetterNote();
  }

  Future<void> reassignSelectedLetter() {
    return _submitLetterReassign();
  }

  Future<void> blockSelectedLetterSender() {
    return _submitLetterSenderBlock();
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
      final detail = await _reportRepository.fetchAdminReport(report.id);
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

  Future<void> openReportById(int reportId) async {
    selectView(OperationsView.reports);
    final summary = _findReportSummary(reportId);
    if (summary != null) {
      await openReport(summary);
      return;
    }

    _setState(
      _state.copyWith(
        isDetailLoading: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      final detail = await _reportRepository.fetchAdminReport(reportId);
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

  AdminReportSummary? _findReportSummary(int reportId) {
    for (final report in _state.reports) {
      if (report.id == reportId) {
        return report;
      }
    }

    return null;
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
      final result = await _reportRepository.updateAdminReportStatus(
        report.id,
        AdminReportActionDraft(
          action: _state.selectedAction,
          reason: _state.actionReason,
        ),
      );
      final reports = await _reportRepository.fetchAdminReports();
      final detail = await _reportRepository.fetchAdminReport(result.id);
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

  Future<void> _submitMemberStatus(String status) async {
    final member = _state.selectedMember?.member;
    if (member == null || _state.isMemberActionSubmitting) {
      return;
    }

    final reason = _validMemberReasonOrSetError() ?? '';
    if (reason.isEmpty) {
      return;
    }

    _setState(
      _state.copyWith(
        isMemberActionSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      await _operationsRepository.updateMemberStatus(
        memberId: member.id,
        status: status,
        reason: reason,
      );
      await _refreshSelectedMember(member.id);
      await loadMembers(reset: true);
      _setState(
        _state.copyWith(
          isMemberActionSubmitting: false,
          memberActionReason: '',
          noticeMessage: '회원 조치가 저장되었습니다.',
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isMemberActionSubmitting: false));
    }
  }

  Future<void> _submitMemberRole(String role) async {
    final member = _state.selectedMember?.member;
    if (member == null || _state.isMemberActionSubmitting) {
      return;
    }

    final reason = _validMemberReasonOrSetError() ?? '';
    if (reason.isEmpty) {
      return;
    }

    _setState(
      _state.copyWith(
        isMemberActionSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      await _operationsRepository.updateMemberRole(
        memberId: member.id,
        role: role,
        reason: reason,
      );
      await _refreshSelectedMember(member.id);
      await loadMembers(reset: true);
      _setState(
        _state.copyWith(
          isMemberActionSubmitting: false,
          memberActionReason: '',
          noticeMessage: '회원 조치가 저장되었습니다.',
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isMemberActionSubmitting: false));
    }
  }

  Future<void> _submitMemberSessionRevoke() async {
    final member = _state.selectedMember?.member;
    if (member == null || _state.isMemberActionSubmitting) {
      return;
    }

    final reason = _validMemberReasonOrSetError() ?? '';
    if (reason.isEmpty) {
      return;
    }

    _setState(
      _state.copyWith(
        isMemberActionSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      await _operationsRepository.revokeMemberSessions(
        memberId: member.id,
        reason: reason,
      );
      await _refreshSelectedMember(member.id);
      _setState(
        _state.copyWith(
          isMemberActionSubmitting: false,
          memberActionReason: '',
          noticeMessage: '회원 조치가 저장되었습니다.',
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isMemberActionSubmitting: false));
    }
  }

  Future<void> _submitLetterNote() async {
    final letter = _state.selectedLetter;
    if (letter == null || _state.isLetterActionSubmitting) {
      return;
    }

    final reason = _validLetterReasonOrSetError() ?? '';
    if (reason.isEmpty) {
      return;
    }

    if (_state.letterNote.trim().length < OperationsState.letterNoteMinLength) {
      _setState(
        _state.copyWith(
          errorMessage:
              '편지 운영 메모를 ${OperationsState.letterNoteMinLength}자 이상 입력해 주세요.',
          clearNoticeMessage: true,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        isLetterActionSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      await _operationsRepository.addLetterNote(
        letterId: letter.id,
        note: _state.letterNote.trim(),
        reason: reason,
      );
      await _refreshSelectedLetter(letter.id);
      await loadLetters(reset: true);
      _setState(
        _state.copyWith(
          isLetterActionSubmitting: false,
          letterActionReason: '',
          letterNote: '',
          letterReceiverQuery: '',
          letterReceiverCandidates: const [],
          clearSelectedLetterReceiver: true,
          noticeMessage: '편지 조치가 저장되었습니다.',
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isLetterActionSubmitting: false));
    }
  }

  Future<void> _submitLetterReassign() async {
    final letter = _state.selectedLetter;
    final receiverId = _state.selectedLetterReceiverId;
    if (letter == null || _state.isLetterActionSubmitting) {
      return;
    }

    if (receiverId == null) {
      _setState(
        _state.copyWith(
          errorMessage: '재배정할 수신자를 선택해 주세요.',
          clearNoticeMessage: true,
        ),
      );
      return;
    }

    final reason = _validLetterReasonOrSetError() ?? '';
    if (reason.isEmpty) {
      return;
    }

    _setState(
      _state.copyWith(
        isLetterActionSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      await _operationsRepository.reassignLetterReceiver(
        letterId: letter.id,
        receiverMemberId: receiverId,
        reason: reason,
      );
      await _refreshSelectedLetter(letter.id);
      await loadLetters(reset: true);
      _setState(
        _state.copyWith(
          isLetterActionSubmitting: false,
          letterActionReason: '',
          letterReceiverQuery: '',
          letterReceiverCandidates: const [],
          clearSelectedLetterReceiver: true,
          noticeMessage: '편지 조치가 저장되었습니다.',
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isLetterActionSubmitting: false));
    }
  }

  Future<void> _submitLetterSenderBlock() async {
    final letter = _state.selectedLetter;
    if (letter == null || _state.isLetterActionSubmitting) {
      return;
    }

    final reason = _validLetterReasonOrSetError() ?? '';
    if (reason.isEmpty) {
      return;
    }

    _setState(
      _state.copyWith(
        isLetterActionSubmitting: true,
        clearErrorMessage: true,
        clearNoticeMessage: true,
      ),
    );

    try {
      await _operationsRepository.blockLetterSender(
        letterId: letter.id,
        reason: reason,
      );
      await _refreshSelectedLetter(letter.id);
      await loadLetters(reset: true);
      _setState(
        _state.copyWith(
          isLetterActionSubmitting: false,
          letterActionReason: '',
          letterReceiverQuery: '',
          letterReceiverCandidates: const [],
          clearSelectedLetterReceiver: true,
          noticeMessage: '편지 조치가 저장되었습니다.',
          clearErrorMessage: true,
        ),
      );
    } on Object catch (error) {
      _handleError(error);
      _setState(_state.copyWith(isLetterActionSubmitting: false));
    }
  }

  Future<void> _refreshSelectedMember(int memberId) async {
    final detail = await _operationsRepository.fetchMemberDetail(memberId);
    _setState(_state.copyWith(selectedMember: detail));
  }

  Future<void> _refreshSelectedLetter(int letterId) async {
    final detail = await _operationsRepository.fetchLetterDetail(letterId);
    _setState(_state.copyWith(selectedLetter: detail));
  }

  String? _validMemberReasonOrSetError() {
    final reason = _state.memberActionReason.trim();
    if (reason.length < OperationsState.actionReasonMinLength) {
      _setState(
        _state.copyWith(
          errorMessage:
              '관리자 조치 사유를 ${OperationsState.actionReasonMinLength}자 이상 입력해 주세요.',
          clearNoticeMessage: true,
        ),
      );
      return null;
    }
    return reason;
  }

  String? _validLetterReasonOrSetError() {
    final reason = _state.letterActionReason.trim();
    if (reason.length < OperationsState.actionReasonMinLength) {
      _setState(
        _state.copyWith(
          errorMessage:
              '편지 조치 사유를 ${OperationsState.actionReasonMinLength}자 이상 입력해 주세요.',
          clearNoticeMessage: true,
        ),
      );
      return null;
    }
    return reason;
  }

  void _handleError(Object error) {
    if (error is ApiClientException && error.sessionInvalidated) {
      _onUnauthorized?.call(error.message);
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

  void _handleMetricsError(Object error) {
    final isPermissionError = error is ApiClientException &&
        (error.kind == ApiErrorKind.unauthorized ||
            error.kind == ApiErrorKind.forbidden ||
            error.kind == ApiErrorKind.permissionChanged);
    if (error is ApiClientException && error.sessionInvalidated) {
      _onUnauthorized?.call(error.message);
    }

    _setState(
      _state.copyWith(
        metricsErrorMessage: error is ApiClientException
            ? error.message
            : '관측 지표를 불러오지 못했습니다.',
        isMetricsPermissionError: isPermissionError,
        clearNoticeMessage: true,
      ),
    );
  }

  void _handleSystemStatusError(Object error) {
    final isPermissionError = error is ApiClientException &&
        (error.kind == ApiErrorKind.unauthorized ||
            error.kind == ApiErrorKind.forbidden ||
            error.kind == ApiErrorKind.permissionChanged);
    if (error is ApiClientException && error.sessionInvalidated) {
      _onUnauthorized?.call(error.message);
    }

    _setState(
      _state.copyWith(
        systemStatusErrorMessage: error is ApiClientException
            ? error.message
            : '관측 도구 상태를 확인하지 못했습니다.',
        isSystemStatusPermissionError: isPermissionError,
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

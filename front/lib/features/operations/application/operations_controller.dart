import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../data/operations_repository.dart';
import '../domain/operations_models.dart';
import '../../report/data/report_repository.dart';
import '../../report/domain/report_models.dart';

enum OperationsView { dashboard, members, reports }

class OperationsState {
  const OperationsState({
    this.view = OperationsView.dashboard,
    this.dashboard,
    this.reports = const [],
    this.selectedReport,
    this.members = const [],
    this.memberPage,
    this.selectedMember,
    this.memberQuery = '',
    this.memberStatusFilter,
    this.memberRoleFilter,
    this.memberSocialAccountFilter,
    this.memberActionReason = '',
    this.selectedAction = AdminReportAction.resolved,
    this.actionReason = '',
    this.isLoading = false,
    this.isMemberLoading = false,
    this.isMemberDetailLoading = false,
    this.isMemberActionSubmitting = false,
    this.isDetailLoading = false,
    this.isSubmitting = false,
    this.hasLoaded = false,
    this.errorMessage,
    this.noticeMessage,
  });

  final OperationsView view;
  final OperationsDashboard? dashboard;
  final List<AdminReportSummary> reports;
  final AdminReportDetail? selectedReport;
  final List<AdminMemberSummary> members;
  final AdminMemberPage? memberPage;
  final AdminMemberDetail? selectedMember;
  final String memberQuery;
  final String? memberStatusFilter;
  final String? memberRoleFilter;
  final bool? memberSocialAccountFilter;
  final String memberActionReason;
  final AdminReportAction selectedAction;
  final String actionReason;
  final bool isLoading;
  final bool isMemberLoading;
  final bool isMemberDetailLoading;
  final bool isMemberActionSubmitting;
  final bool isDetailLoading;
  final bool isSubmitting;
  final bool hasLoaded;
  final String? errorMessage;
  final String? noticeMessage;

  bool get isEmpty => hasLoaded && reports.isEmpty && errorMessage == null;

  bool get isMemberEmpty {
    return hasLoaded && members.isEmpty && errorMessage == null;
  }

  bool get canLoadMoreMembers {
    return memberPage != null && !memberPage!.last && !isMemberLoading;
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

  static const int actionReasonMinLength = 4;

  OperationsState copyWith({
    OperationsView? view,
    OperationsDashboard? dashboard,
    List<AdminReportSummary>? reports,
    AdminReportDetail? selectedReport,
    bool clearSelectedReport = false,
    List<AdminMemberSummary>? members,
    AdminMemberPage? memberPage,
    AdminMemberDetail? selectedMember,
    bool clearSelectedMember = false,
    String? memberQuery,
    String? memberStatusFilter,
    bool clearMemberStatusFilter = false,
    String? memberRoleFilter,
    bool clearMemberRoleFilter = false,
    bool? memberSocialAccountFilter,
    bool clearMemberSocialAccountFilter = false,
    String? memberActionReason,
    AdminReportAction? selectedAction,
    String? actionReason,
    bool? isLoading,
    bool? isMemberLoading,
    bool? isMemberDetailLoading,
    bool? isMemberActionSubmitting,
    bool? isDetailLoading,
    bool? isSubmitting,
    bool? hasLoaded,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? noticeMessage,
    bool clearNoticeMessage = false,
  }) {
    return OperationsState(
      view: view ?? this.view,
      dashboard: dashboard ?? this.dashboard,
      reports: reports ?? this.reports,
      selectedReport:
          clearSelectedReport ? null : selectedReport ?? this.selectedReport,
      members: members ?? this.members,
      memberPage: memberPage ?? this.memberPage,
      selectedMember:
          clearSelectedMember ? null : selectedMember ?? this.selectedMember,
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
      selectedAction: selectedAction ?? this.selectedAction,
      actionReason: actionReason ?? this.actionReason,
      isLoading: isLoading ?? this.isLoading,
      isMemberLoading: isMemberLoading ?? this.isMemberLoading,
      isMemberDetailLoading: isMemberDetailLoading ?? this.isMemberDetailLoading,
      isMemberActionSubmitting:
          isMemberActionSubmitting ?? this.isMemberActionSubmitting,
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
    required ReportRepository reportRepository,
    required OperationsRepository operationsRepository,
    VoidCallback? onUnauthorized,
  })  : _reportRepository = reportRepository,
        _operationsRepository = operationsRepository,
        _onUnauthorized = onUnauthorized;

  final ReportRepository _reportRepository;
  final OperationsRepository _operationsRepository;
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
      final dashboard = await _operationsRepository.fetchDashboard();
      final reports = await _reportRepository.fetchAdminReports();
      final memberPage = await _operationsRepository.fetchMembers(
        query: _state.memberQuery,
        status: _state.memberStatusFilter,
        role: _state.memberRoleFilter,
        socialAccount: _state.memberSocialAccountFilter,
      );
      _setState(
        _state.copyWith(
          dashboard: dashboard,
          reports: reports,
          members: memberPage.content,
          memberPage: memberPage,
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

  void selectView(OperationsView view) {
    _setState(_state.copyWith(view: view, clearNoticeMessage: true));
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

  Future<void> _refreshSelectedMember(int memberId) async {
    final detail = await _operationsRepository.fetchMemberDetail(memberId);
    _setState(_state.copyWith(selectedMember: detail));
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

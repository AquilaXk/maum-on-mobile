import 'package:flutter/material.dart';

import '../../../shared/ui/app_design_system.dart';
import '../../report/domain/report_models.dart';
import '../application/operations_controller.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({
    required this.controller,
    required this.onBack,
    super.key,
  });

  final OperationsController controller;
  final VoidCallback onBack;

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(
      text: widget.controller.state.actionReason,
    );
    widget.controller.addListener(_syncReason);
    _loadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant OperationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncReason);
      widget.controller.addListener(_syncReason);
      _loadIfNeeded();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncReason);
    _reasonController.dispose();
    super.dispose();
  }

  void _loadIfNeeded() {
    if (!widget.controller.state.hasLoaded) {
      Future<void>.microtask(widget.controller.load);
    }
  }

  void _syncReason() {
    final reason = widget.controller.state.actionReason;
    if (_reasonController.text == reason) {
      return;
    }

    _reasonController.value = TextEditingValue(
      text: reason,
      selection: TextSelection.collapsed(offset: reason.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;

        return AppScreen(
          title: '운영 검수',
          subtitle: '신고와 대상 정보를 확인하고 조치를 남깁니다.',
          onBack: widget.onBack,
          onRefresh: widget.controller.load,
          children: [
            if (state.errorMessage != null) ...[
              AppNotice(
                message: state.errorMessage!,
                tone: AppNoticeTone.error,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.noticeMessage != null) ...[
              AppNotice(message: state.noticeMessage!),
              const SizedBox(height: AppSpacing.md),
            ],
            _ReportQueue(state: state, controller: widget.controller),
            const SizedBox(height: AppSpacing.lg),
            _ReportDetail(
              state: state,
              reasonController: _reasonController,
              onActionSelected: widget.controller.selectAction,
              onReasonChanged: widget.controller.updateActionReason,
              onSubmit: widget.controller.submitAction,
            ),
          ],
        );
      },
    );
  }
}

class _ReportQueue extends StatelessWidget {
  const _ReportQueue({
    required this.state,
    required this.controller,
  });

  final OperationsState state;
  final OperationsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && !state.hasLoaded) {
      return const AppNotice(message: '신고 목록을 불러오는 중입니다.');
    }

    if (state.isEmpty) {
      return const AppNotice(message: '처리할 신고가 없습니다.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('신고 대기열', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final report in state.reports) ...[
          _ReportQueueTile(
            report: report,
            selected: state.selectedReport?.id == report.id,
            onTap: () => controller.openReport(report),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _ReportQueueTile extends StatelessWidget {
  const _ReportQueueTile({
    required this.report,
    required this.selected,
    required this.onTap,
  });

  final AdminReportSummary report;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = report.targetTitle.isEmpty ? '대상 없음' : report.targetTitle;
    final statusLabel = _reportStatusLabel(report.status);

    return AppListRow(
      rowKey: ValueKey('operations-report-${report.id}'),
      title: title,
      subtitle:
          '${report.targetType.label} · 신고자 ${report.reporter.nickname} · ${report.createdAt}',
      statusLabel: statusLabel,
      statusTone: _reportStatusTone(report.status),
      leadingIcon: report.isOpen ? Icons.inbox_outlined : Icons.task_alt,
      selected: selected,
      onTap: onTap,
      semanticLabel:
          '신고 항목: ${report.targetType.label}, $title, 신고자 ${report.reporter.nickname}, 상태 $statusLabel',
    );
  }
}

class _ReportDetail extends StatelessWidget {
  const _ReportDetail({
    required this.state,
    required this.reasonController,
    required this.onActionSelected,
    required this.onReasonChanged,
    required this.onSubmit,
  });

  final OperationsState state;
  final TextEditingController reasonController;
  final ValueChanged<AdminReportAction> onActionSelected;
  final ValueChanged<String> onReasonChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final report = state.selectedReport;
    if (state.isDetailLoading) {
      return const AppNotice(message: '신고 상세를 불러오는 중입니다.');
    }

    if (report == null) {
      return const AppNotice(message: '검수할 신고를 선택해 주세요.');
    }

    return AppSectionCard(
      title: '신고 상세',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppStatusPill(
                label: _reportStatusLabel(report.status),
                tone: _reportStatusTone(report.status),
              ),
              AppStatusPill(label: report.target.type.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppDetailRow(
            label: '신고자',
            value: _memberLabel(report.reporter),
          ),
          AppDetailRow(
            label: '대상 회원',
            value: report.targetOwner == null
                ? '-'
                : _memberLabel(report.targetOwner!),
          ),
          AppDetailRow(label: '대상', value: report.target.title),
          if (report.target.preview.isNotEmpty)
            AppDetailRow(label: '내용', value: report.target.preview),
          if (report.content != null)
            AppDetailRow(label: '신고 설명', value: report.content!),
          const SizedBox(height: AppSpacing.md),
          KeyedSubtree(
            key: const ValueKey('operations-action-field'),
            child: DropdownButtonFormField<AdminReportAction>(
              key: ValueKey(
                'operations-action-value-${report.id}-${state.selectedAction.apiValue}',
              ),
              initialValue: state.selectedAction,
              decoration: const InputDecoration(
                labelText: '조치',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final action in AdminReportAction.values)
                  DropdownMenuItem(
                    value: action,
                    child: Text(action.label),
                  ),
              ],
              onChanged: state.isSubmitting
                  ? null
                  : (action) {
                      if (action != null) {
                        onActionSelected(action);
                      }
                    },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('operations-reason-field'),
            controller: reasonController,
            minLines: 2,
            maxLines: 4,
            onChanged: onReasonChanged,
            decoration: const InputDecoration(
              labelText: '조치 사유',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppConfirmActionButton(
            buttonKey: const ValueKey('operations-submit-button'),
            confirmButtonKey:
                const ValueKey('operations-confirm-submit-button'),
            enabled: state.canSubmitAction,
            icon: const Icon(Icons.gavel_outlined),
            label: state.isSubmitting ? '저장 중' : '조치 저장',
            confirmTitle: '조치 저장 확인',
            confirmMessage:
                '${state.selectedAction.label} 조치를 저장합니다. 사유와 상태가 운영 기록에 남습니다.',
            confirmButtonLabel: '저장',
            semanticLabel: '운영 조치 저장',
            onConfirmed: onSubmit,
          ),
          if (report.handledBy != null || report.actionReason != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppNotice(
              message:
                  '${report.handledBy?.nickname ?? '운영자'} · ${report.handledAt ?? '-'} · ${report.actionReason ?? '-'}',
              tone: AppNoticeTone.success,
            ),
          ],
        ],
      ),
    );
  }

  String _memberLabel(AdminReportMember member) {
    return '${member.nickname} · ${member.email} · ${member.status}';
  }
}

String _reportStatusLabel(String status) {
  return switch (status) {
    'RECEIVED' => '접수',
    'RESOLVED' => '처리 완료',
    'REJECTED' => '반려',
    'HIDDEN' => '숨김',
    'DELETED' => '삭제',
    'RESTRICTED' => '제한',
    _ => status.isEmpty ? '-' : status,
  };
}

AppStatusTone _reportStatusTone(String status) {
  switch (status) {
    case 'RESOLVED':
      return AppStatusTone.success;
    case 'RECEIVED':
      return AppStatusTone.warning;
    case 'HIDDEN':
    case 'DELETED':
    case 'RESTRICTED':
      return AppStatusTone.danger;
    default:
      return AppStatusTone.neutral;
  }
}

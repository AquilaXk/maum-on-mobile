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
        Text('신고 queue', style: Theme.of(context).textTheme.titleMedium),
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
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        key: ValueKey('operations-report-${report.id}'),
        selected: selected,
        onTap: onTap,
        leading: Icon(report.isOpen ? Icons.inbox_outlined : Icons.task_alt),
        title: Text(report.targetTitle.isEmpty ? '대상 없음' : report.targetTitle),
        subtitle: Text(
          '${report.targetType.label} · ${report.reporter.nickname} · ${report.status}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
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
          _DetailLine(label: '상태', value: report.status),
          _DetailLine(label: '신고자', value: _memberLabel(report.reporter)),
          _DetailLine(
            label: '대상 회원',
            value: report.targetOwner == null
                ? '-'
                : _memberLabel(report.targetOwner!),
          ),
          _DetailLine(label: '대상', value: report.target.title),
          if (report.target.preview.isNotEmpty)
            _DetailLine(label: '내용', value: report.target.preview),
          if (report.content != null)
            _DetailLine(label: '신고 설명', value: report.content!),
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
          FilledButton.icon(
            key: const ValueKey('operations-submit-button'),
            onPressed: state.canSubmitAction ? onSubmit : null,
            icon: const Icon(Icons.gavel_outlined),
            label: Text(state.isSubmitting ? '저장 중' : '조치 저장'),
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

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(value.isEmpty ? '-' : value),
        ],
      ),
    );
  }
}

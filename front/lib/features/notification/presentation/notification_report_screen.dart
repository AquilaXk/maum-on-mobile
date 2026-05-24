import 'dart:async';

import 'package:flutter/material.dart';

import '../../report/application/report_controller.dart';
import '../../report/domain/report_models.dart';
import '../application/notification_controller.dart';
import '../domain/notification_models.dart';

class NotificationReportScreen extends StatefulWidget {
  const NotificationReportScreen({
    required this.notificationController,
    required this.reportController,
    required this.onBack,
    super.key,
  });

  final NotificationController notificationController;
  final ReportController reportController;
  final VoidCallback onBack;

  @override
  State<NotificationReportScreen> createState() =>
      _NotificationReportScreenState();
}

class _NotificationReportScreenState extends State<NotificationReportScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _reportContentController;
  late final TextEditingController _targetIdController;
  ReportTargetType _manualTargetType = ReportTargetType.post;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reportContentController =
        TextEditingController(text: widget.reportController.state.content);
    _targetIdController = TextEditingController(
      text: widget.reportController.state.target?.id.toString() ?? '',
    );
    unawaited(widget.notificationController.load());
    unawaited(widget.notificationController.connect());
  }

  @override
  void didUpdateWidget(covariant NotificationReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notificationController != widget.notificationController) {
      unawaited(widget.notificationController.load());
      unawaited(widget.notificationController.connect());
    }
    _syncReportFields();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.notificationController.handleLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.notificationController.close();
    _reportContentController.dispose();
    _targetIdController.dispose();
    super.dispose();
  }

  void _syncReportFields() {
    final reportState = widget.reportController.state;
    if (_reportContentController.text != reportState.content) {
      _reportContentController.value = TextEditingValue(
        text: reportState.content,
        selection: TextSelection.collapsed(offset: reportState.content.length),
      );
    }

    final target = reportState.target;
    if (target != null) {
      _manualTargetType = target.type;
      final nextId = target.id.toString();
      if (_targetIdController.text != nextId) {
        _targetIdController.value = TextEditingValue(
          text: nextId,
          selection: TextSelection.collapsed(offset: nextId.length),
        );
      }
    }
  }

  void _updateManualTarget() {
    final targetId = int.tryParse(_targetIdController.text.trim());
    if (targetId == null || targetId <= 0) {
      widget.reportController.clearTarget();
      return;
    }

    widget.reportController.selectTarget(
      ReportTarget(
        type: _manualTargetType,
        id: targetId,
        label: '${_manualTargetType.label} #$targetId',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.notificationController,
        widget.reportController,
      ]),
      builder: (context, _) {
        _syncReportFields();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _Header(
                    connectionState:
                        widget.notificationController.state.connectionState,
                    onBack: widget.onBack,
                    onReconnect: widget.notificationController.reconnect,
                  ),
                  const TabBar(
                    tabs: [
                      Tab(text: '알림'),
                      Tab(text: '신고'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _NotificationCenter(
                          state: widget.notificationController.state,
                          onRefresh: widget.notificationController.load,
                        ),
                        _ReportForm(
                          state: widget.reportController.state,
                          contentController: _reportContentController,
                          targetIdController: _targetIdController,
                          selectedTargetType: _manualTargetType,
                          onTargetTypeChanged: (targetType) {
                            if (targetType == null) {
                              return;
                            }
                            _manualTargetType = targetType;
                            _updateManualTarget();
                          },
                          onTargetIdChanged: (_) => _updateManualTarget(),
                          onReasonSelected:
                              widget.reportController.selectReason,
                          onContentChanged:
                              widget.reportController.updateContent,
                          onSubmit: widget.reportController.submit,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.connectionState,
    required this.onBack,
    required this.onReconnect,
  });

  final NotificationConnectionState connectionState;
  final VoidCallback onBack;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (connectionState) {
      NotificationConnectionState.idle => '연결 대기',
      NotificationConnectionState.connecting => '연결 중',
      NotificationConnectionState.connected => '연결됨',
      NotificationConnectionState.error => '연결 불안정',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('notification-back-button'),
            tooltip: '홈으로',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '알림/신고',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(statusText),
              ],
            ),
          ),
          if (connectionState == NotificationConnectionState.error)
            IconButton.filledTonal(
              key: const ValueKey('notification-reconnect-button'),
              tooltip: '다시 연결',
              onPressed: () => onReconnect(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }
}

class _NotificationCenter extends StatelessWidget {
  const _NotificationCenter({
    required this.state,
    required this.onRefresh,
  });

  final NotificationState state;
  final Future<void> Function({bool silent}) onRefresh;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && !state.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => onRefresh(silent: false),
      child: ListView(
        key: const ValueKey('notification-list'),
        padding: const EdgeInsets.all(16),
        children: [
          if (state.errorMessage != null) ...[
            _InlineNotice(message: state.errorMessage!, isError: true),
            const SizedBox(height: 12),
          ],
          if (state.noticeMessage != null) ...[
            _InlineNotice(message: state.noticeMessage!),
            const SizedBox(height: 12),
          ],
          if (state.isEmpty)
            const _InlineNotice(message: '아직 도착한 알림이 없습니다.'),
          for (final notification in state.notifications) ...[
            _NotificationTile(notification: notification),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: notification.isRead
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              notification.isRead
                  ? Icons.notifications_none
                  : Icons.notifications_active_outlined,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.content,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (notification.createdAt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.createdAt,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportForm extends StatelessWidget {
  const _ReportForm({
    required this.state,
    required this.contentController,
    required this.targetIdController,
    required this.selectedTargetType,
    required this.onTargetTypeChanged,
    required this.onTargetIdChanged,
    required this.onReasonSelected,
    required this.onContentChanged,
    required this.onSubmit,
  });

  final ReportState state;
  final TextEditingController contentController;
  final TextEditingController targetIdController;
  final ReportTargetType selectedTargetType;
  final ValueChanged<ReportTargetType?> onTargetTypeChanged;
  final ValueChanged<String> onTargetIdChanged;
  final ValueChanged<ReportReasonCode> onReasonSelected;
  final ValueChanged<String> onContentChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final validationMessage = state.validationMessage;

    return ListView(
      key: const ValueKey('report-form'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '신고 대상',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 132,
              child: DropdownButtonFormField<ReportTargetType>(
                key: const ValueKey('report-target-type-field'),
                value: selectedTargetType,
                decoration: const InputDecoration(
                  labelText: '유형',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in ReportTargetType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: state.isSubmitted ? null : onTargetTypeChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('report-target-id-field'),
                controller: targetIdController,
                enabled: !state.isSubmitted,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '대상 번호',
                  border: OutlineInputBorder(),
                ),
                onChanged: onTargetIdChanged,
              ),
            ),
          ],
        ),
        if (state.target != null) ...[
          const SizedBox(height: 8),
          _InlineNotice(
            message:
                '${state.target!.type.label} #${state.target!.id} · ${state.target!.label}',
          ),
        ],
        const SizedBox(height: 20),
        Text(
          '신고 사유',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final reason in ReportReasonCode.values)
              ChoiceChip(
                key: ValueKey('report-reason-${reason.name}'),
                label: Text(reason.label),
                selected: state.reason == reason,
                onSelected:
                    state.isSubmitted ? null : (_) => onReasonSelected(reason),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _InlineNotice(message: state.reason.hint),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('report-content-field'),
          controller: contentController,
          enabled: !state.isSubmitted,
          minLines: 4,
          maxLines: 6,
          maxLength: ReportState.contentMaxLength,
          decoration: InputDecoration(
            labelText: state.reason.requiresDescription ? '상세 사유' : '추가 설명',
            helperText: state.reason.requiresDescription
                ? '기타 사유는 5자 이상 입력해 주세요.'
                : '필요한 경우에만 입력해 주세요.',
            border: const OutlineInputBorder(),
          ),
          onChanged: onContentChanged,
        ),
        if (validationMessage != null) ...[
          const SizedBox(height: 8),
          _InlineNotice(message: validationMessage, isError: true),
        ],
        if (state.errorMessage != null) ...[
          const SizedBox(height: 8),
          _InlineNotice(message: state.errorMessage!, isError: true),
        ],
        if (state.noticeMessage != null) ...[
          const SizedBox(height: 8),
          _InlineNotice(message: state.noticeMessage!),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('report-submit-button'),
          onPressed: state.canSubmit ? () => onSubmit() : null,
          icon: state.isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.shield_outlined),
          label: Text(
            state.isSubmitted ? '이미 접수된 신고입니다.' : '신고 접수',
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: isError ? colorScheme.onErrorContainer : null,
          ),
        ),
      ),
    );
  }
}

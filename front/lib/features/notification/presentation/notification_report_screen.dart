import 'dart:async';

import 'package:flutter/material.dart';

import '../../moderation/presentation/content_moderation_feedback_panel.dart';
import '../../report/application/report_controller.dart';
import '../../report/domain/report_models.dart';
import '../../../shared/ui/app_design_system.dart';
import '../application/notification_controller.dart';
import '../domain/notification_models.dart';

class NotificationReportScreen extends StatefulWidget {
  const NotificationReportScreen({
    required this.notificationController,
    required this.reportController,
    required this.onBack,
    this.onOpenNotification,
    this.closeNotificationStreamOnDispose = true,
    super.key,
  });

  final NotificationController notificationController;
  final ReportController reportController;
  final VoidCallback onBack;
  final ValueChanged<NotificationItem>? onOpenNotification;
  final bool closeNotificationStreamOnDispose;

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
    if (widget.closeNotificationStreamOnDispose) {
      widget.notificationController.close();
    }
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

  Future<void> _openNotification(NotificationItem notification) async {
    final opened =
        await widget.notificationController.openNotification(notification);
    if (!mounted || opened == null) {
      return;
    }

    widget.onOpenNotification?.call(opened);
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
                    pushNotificationState: widget
                        .notificationController.state.pushNotificationState,
                    canOpenPushSettings:
                        widget.notificationController.state.canOpenPushSettings,
                    unreadCount:
                        widget.notificationController.state.unreadCount,
                    directCount:
                        widget.notificationController.state.notifications
                            .where(
                              (notification) =>
                                  notification.destination !=
                                  NotificationTapDestination.notifications,
                            )
                            .length,
                    lastReceivedAt:
                        widget.notificationController.state.lastReceivedAt,
                    onBack: widget.onBack,
                    onReconnect: widget.notificationController.reconnect,
                    onRequestPush:
                        widget.notificationController.requestPushPermission,
                    onOpenPushSettings: widget
                        .notificationController.openPushNotificationSettings,
                    onMarkAllRead: widget.notificationController.markAllRead,
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
                          onOpenNotification: _openNotification,
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
                          onDismissFeedback:
                              widget.reportController.clearModerationFeedback,
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
    required this.pushNotificationState,
    required this.canOpenPushSettings,
    required this.unreadCount,
    required this.directCount,
    required this.lastReceivedAt,
    required this.onBack,
    required this.onReconnect,
    required this.onRequestPush,
    required this.onOpenPushSettings,
    required this.onMarkAllRead,
  });

  final NotificationConnectionState connectionState;
  final PushNotificationState pushNotificationState;
  final bool canOpenPushSettings;
  final int unreadCount;
  final int directCount;
  final String? lastReceivedAt;
  final VoidCallback onBack;
  final Future<void> Function() onReconnect;
  final Future<void> Function() onRequestPush;
  final Future<void> Function() onOpenPushSettings;
  final Future<void> Function() onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (connectionState) {
      NotificationConnectionState.idle => '연결 대기',
      NotificationConnectionState.connecting => '연결 중',
      NotificationConnectionState.connected => '연결됨',
      NotificationConnectionState.error => '연결 불안정',
    };
    final summary = lastReceivedAt == null
        ? '$statusText · 읽지 않음 $unreadCount'
        : '$statusText · 읽지 않음 $unreadCount · $lastReceivedAt';
    final pushAction = pushNotificationState == PushNotificationState.denied &&
            canOpenPushSettings
        ? onOpenPushSettings
        : onRequestPush;
    final permissionState = switch (pushNotificationState) {
      PushNotificationState.idle => AppStateView.permission(
          title: '푸시 알림 권한을 확인해 주세요.',
          message: '새 알림을 바로 받으려면 권한 요청을 진행합니다.',
          actionLabel: '권한 요청',
          onAction: () => unawaited(onRequestPush()),
          semanticLabel: '푸시 알림 권한 요청 가능',
        ),
      PushNotificationState.requesting => const AppStateView.loading(
          title: '푸시 알림 권한을 확인하는 중입니다.',
          semanticLabel: '푸시 알림 권한 확인 중',
        ),
      PushNotificationState.denied => AppStateView.permission(
          title: '푸시 알림 권한이 꺼져 있습니다.',
          message: '기기 설정에서 알림 권한을 허용한 뒤 다시 시도해 주세요.',
          actionLabel: canOpenPushSettings ? '설정 열기' : '다시 시도',
          onAction: () => unawaited(
            canOpenPushSettings ? onOpenPushSettings() : onRequestPush(),
          ),
          semanticLabel: '푸시 알림 권한 거부됨',
        ),
      PushNotificationState.error => AppStateView.error(
          title: '푸시 알림을 설정하지 못했습니다.',
          message: '네트워크 또는 기기 설정을 확인한 뒤 다시 시도해 주세요.',
          actionLabel: '다시 시도',
          onAction: () => unawaited(onRequestPush()),
          semanticLabel: '푸시 알림 설정 오류',
        ),
      PushNotificationState.registered => null,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppScreenHeader(
            title: '알림/신고',
            subtitle: summary,
            onBack: onBack,
          ),
          const SizedBox(height: AppSpacing.sm),
          _NotificationStatusToolbar(
            connectionState: connectionState,
            pushNotificationState: pushNotificationState,
            unreadCount: unreadCount,
            directCount: directCount,
            canOpenPushSettings: canOpenPushSettings,
            onReconnect: onReconnect,
            onPushAction: pushAction,
            onMarkAllRead: onMarkAllRead,
            permissionState: permissionState,
          ),
        ],
      ),
    );
  }
}

class _NotificationStatusToolbar extends StatelessWidget {
  const _NotificationStatusToolbar({
    required this.connectionState,
    required this.pushNotificationState,
    required this.unreadCount,
    required this.directCount,
    required this.canOpenPushSettings,
    required this.onReconnect,
    required this.onPushAction,
    required this.onMarkAllRead,
    required this.permissionState,
  });

  final NotificationConnectionState connectionState;
  final PushNotificationState pushNotificationState;
  final int unreadCount;
  final int directCount;
  final bool canOpenPushSettings;
  final Future<void> Function() onReconnect;
  final Future<void> Function() onPushAction;
  final Future<void> Function() onMarkAllRead;
  final AppStateView? permissionState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pushLabel = _pushStatusLabel(pushNotificationState);

    return Card(
      key: const ValueKey('notification-status-toolbar'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '알림 상태',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  IconButton(
                    key: const ValueKey('notification-mark-all-read-button'),
                    tooltip: '모두 읽음',
                    onPressed: () => onMarkAllRead(),
                    icon: const Icon(Icons.done_all),
                  ),
                IconButton(
                  key: const ValueKey('notification-push-button'),
                  tooltip: '푸시 알림',
                  onPressed:
                      pushNotificationState == PushNotificationState.requesting
                          ? null
                          : () => unawaited(onPushAction()),
                  icon: Icon(_pushStatusIcon(pushNotificationState)),
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
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppStatusPill(
                  label: '읽지 않음 $unreadCount개',
                  tone: unreadCount > 0
                      ? AppStatusTone.warning
                      : AppStatusTone.success,
                ),
                AppStatusPill(
                  label: '바로 이동 $directCount개',
                  tone: directCount > 0
                      ? AppStatusTone.success
                      : AppStatusTone.neutral,
                ),
                AppStatusPill(
                  label: _connectionStatusLabel(connectionState),
                  tone: _connectionStatusTone(connectionState),
                ),
                AppStatusPill(
                  label: pushLabel,
                  tone: _pushStatusTone(pushNotificationState),
                ),
              ],
            ),
            if (permissionState != null &&
                pushNotificationState != PushNotificationState.idle) ...[
              const SizedBox(height: AppSpacing.sm),
              permissionState!,
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationCenter extends StatelessWidget {
  const _NotificationCenter({
    required this.state,
    required this.onRefresh,
    required this.onOpenNotification,
  });

  final NotificationState state;
  final Future<void> Function({bool silent}) onRefresh;
  final Future<void> Function(NotificationItem notification) onOpenNotification;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && !state.hasLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppStateView.loading(
            title: '알림을 불러오는 중입니다.',
            semanticLabel: '알림 목록을 불러오는 중',
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: const ValueKey('notification-result-section'),
      child: RefreshIndicator(
        onRefresh: () => onRefresh(silent: false),
        child: ListView(
          key: const ValueKey('notification-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.persistentNavigationReserve,
          ),
          children: [
            if (state.errorMessage != null) ...[
              AppStateView.error(
                title: '알림을 불러오지 못했습니다.',
                message: state.errorMessage!,
                semanticLabel: '알림 목록 오류',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.noticeMessage != null) ...[
              _InlineNotice(message: state.noticeMessage!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.isEmpty)
              const AppStateView.empty(
                title: '아직 도착한 알림이 없습니다.',
                semanticLabel: '알림 목록 비어 있음',
              ),
            for (final notification in state.notifications) ...[
              _NotificationTile(
                notification: notification,
                onOpenNotification: onOpenNotification,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onOpenNotification,
  });

  final NotificationItem notification;
  final Future<void> Function(NotificationItem notification) onOpenNotification;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: notification.accessibilityLabel,
      button: true,
      child: Material(
        color: notification.isRead
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer,
        borderRadius: AppRadii.card,
        child: InkWell(
          key: ValueKey('notification-card-${notification.id}'),
          borderRadius: AppRadii.card,
          onTap: () => onOpenNotification(notification),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _notificationIcon(notification),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xxs,
                        children: [
                          AppStatusPill(
                            label: notification.isRead ? '읽음' : '새 알림',
                            tone: notification.isRead
                                ? AppStatusTone.neutral
                                : AppStatusTone.warning,
                          ),
                          AppStatusPill(
                            label: notification.destinationLabel,
                            tone: _notificationDestinationTone(notification),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        notification.content,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (notification.createdAt.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          notification.createdAt,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _connectionStatusLabel(NotificationConnectionState state) {
  return switch (state) {
    NotificationConnectionState.idle => '대기',
    NotificationConnectionState.connecting => '연결 중',
    NotificationConnectionState.connected => '연결됨',
    NotificationConnectionState.error => '불안정',
  };
}

AppStatusTone _connectionStatusTone(NotificationConnectionState state) {
  return switch (state) {
    NotificationConnectionState.connected => AppStatusTone.success,
    NotificationConnectionState.connecting => AppStatusTone.warning,
    NotificationConnectionState.error => AppStatusTone.danger,
    NotificationConnectionState.idle => AppStatusTone.neutral,
  };
}

String _pushStatusLabel(PushNotificationState state) {
  return switch (state) {
    PushNotificationState.idle => '푸시 권한 확인',
    PushNotificationState.requesting => '푸시 확인 중',
    PushNotificationState.registered => '푸시 수신 중',
    PushNotificationState.denied => '권한 꺼짐',
    PushNotificationState.error => '권한 오류',
  };
}

IconData _pushStatusIcon(PushNotificationState state) {
  return switch (state) {
    PushNotificationState.registered => Icons.notifications_active,
    PushNotificationState.requesting => Icons.hourglass_top,
    PushNotificationState.denied => Icons.notifications_off_outlined,
    PushNotificationState.error => Icons.notification_important_outlined,
    PushNotificationState.idle => Icons.notifications_outlined,
  };
}

AppStatusTone _pushStatusTone(PushNotificationState state) {
  return switch (state) {
    PushNotificationState.registered => AppStatusTone.success,
    PushNotificationState.requesting => AppStatusTone.warning,
    PushNotificationState.denied ||
    PushNotificationState.error =>
      AppStatusTone.danger,
    PushNotificationState.idle => AppStatusTone.neutral,
  };
}

IconData _notificationIcon(NotificationItem notification) {
  if (!notification.isRead) {
    return Icons.notifications_active_outlined;
  }

  return switch (notification.destination) {
    NotificationTapDestination.diary => Icons.edit_note,
    NotificationTapDestination.story => Icons.forum_outlined,
    NotificationTapDestination.letter => Icons.mail_outline,
    NotificationTapDestination.consultation => Icons.chat_bubble_outline,
    NotificationTapDestination.settings => Icons.settings_outlined,
    NotificationTapDestination.notifications => Icons.notifications_none,
  };
}

AppStatusTone _notificationDestinationTone(NotificationItem notification) {
  return switch (notification.destination) {
    NotificationTapDestination.notifications => AppStatusTone.neutral,
    _ => AppStatusTone.success,
  };
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
    required this.onDismissFeedback,
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
  final VoidCallback onDismissFeedback;

  @override
  Widget build(BuildContext context) {
    final validationMessage = state.validationMessage;

    return SingleChildScrollView(
      key: const ValueKey('report-form'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.persistentNavigationReserve,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '신고 대상',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final typeField = DropdownButtonFormField<ReportTargetType>(
                key: ValueKey(
                  'report-target-type-field-${selectedTargetType.name}',
                ),
                initialValue: selectedTargetType,
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
              );
              final idField = TextField(
                key: const ValueKey('report-target-id-field'),
                controller: targetIdController,
                enabled: !state.isSubmitted,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '대상 번호',
                  border: OutlineInputBorder(),
                ),
                onChanged: onTargetIdChanged,
              );

              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    typeField,
                    const SizedBox(height: AppSpacing.sm),
                    idField,
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(width: 132, child: typeField),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: idField),
                ],
              );
            },
          ),
          if (state.target != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _InlineNotice(
              message:
                  '${state.target!.type.label} #${state.target!.id} · ${state.target!.label}',
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            '신고 사유',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final reason in ReportReasonCode.values)
                ChoiceChip(
                  key: ValueKey('report-reason-${reason.name}'),
                  label: Text(reason.label),
                  selected: state.reason == reason,
                  onSelected: state.isSubmitted
                      ? null
                      : (_) => onReasonSelected(reason),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppStateView.risk(
            title: '신고 전 확인',
            message: state.reason.hint,
            semanticLabel: '신고 사유 안내',
          ),
          const SizedBox(height: AppSpacing.md),
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
            const SizedBox(height: AppSpacing.xs),
            _InlineNotice(message: validationMessage, isError: true),
          ],
          if (state.moderationFeedback != null) ...[
            const SizedBox(height: AppSpacing.xs),
            ContentModerationFeedbackPanel(
              feedback: state.moderationFeedback!,
              onRetry: onSubmit,
              onDismiss: onDismissFeedback,
            ),
          ] else if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _InlineNotice(message: state.errorMessage!, isError: true),
          ],
          if (state.noticeMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _InlineNotice(message: state.noticeMessage!),
          ],
          const SizedBox(height: AppSpacing.md),
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
      ),
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
    return AppNotice(
      message: message,
      tone: isError ? AppNoticeTone.error : AppNoticeTone.neutral,
    );
  }
}

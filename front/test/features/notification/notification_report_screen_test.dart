import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/notification/application/notification_controller.dart';
import 'package:maum_on_mobile_front/features/notification/data/notification_repository.dart';
import 'package:maum_on_mobile_front/features/notification/domain/notification_models.dart';
import 'package:maum_on_mobile_front/features/notification/presentation/notification_report_screen.dart';
import 'package:maum_on_mobile_front/features/report/application/report_controller.dart';
import 'package:maum_on_mobile_front/features/report/data/report_repository.dart';
import 'package:maum_on_mobile_front/features/report/domain/report_models.dart';
import 'package:maum_on_mobile_front/shared/ui/app_design_system.dart';

void main() {
  testWidgets('shows compact notification status on a phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notificationRepository = _FakeNotificationRepository();
    final reportRepository = _FakeReportRepository();
    final notificationController = NotificationController(
      repository: notificationRepository,
    );
    final reportController = ReportController(repository: reportRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationReportScreen(
          notificationController: notificationController,
          reportController: reportController,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    notificationRepository.emit(
      const NotificationStreamEvent.replyArrival('AI 상담 답변이 도착했습니다.'),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notification-status-toolbar')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('notification-flow-panel')), findsNothing);
    expect(find.byKey(const ValueKey('notification-list-summary-card')),
        findsNothing);
    expect(find.text('알림 확인 흐름'), findsNothing);
    expect(find.text('읽지 않음 2개'), findsOneWidget);
    expect(find.text('바로 이동 2개'), findsOneWidget);
    expect(find.text('푸시 권한 확인'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-list')), findsOneWidget);

    final notificationList = tester.widget<ListView>(
      find.byKey(const ValueKey('notification-list')),
    );
    final notificationPadding = notificationList.padding! as EdgeInsets;
    expect(
      notificationPadding.bottom,
      greaterThanOrEqualTo(AppSpacing.persistentNavigationReserve),
    );
  });

  testWidgets('알림 카드는 ISO 원문 대신 읽기 쉬운 시간을 보여준다', (tester) async {
    final notificationRepository = _FakeNotificationRepository();
    final reportRepository = _FakeReportRepository();
    final notificationController = NotificationController(
      repository: notificationRepository,
    );
    final reportController = ReportController(repository: reportRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationReportScreen(
          notificationController: notificationController,
          reportController: reportController,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026.05.24 09:00'), findsOneWidget);
    expect(find.text('2026-05-24T09:00:00'), findsNothing);
  });

  testWidgets('renders notifications and submits a report', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final notificationRepository = _FakeNotificationRepository();
      final reportRepository = _FakeReportRepository();
      final openedNotifications = <NotificationItem>[];
      final notificationController = NotificationController(
        repository: notificationRepository,
      );
      final reportController = ReportController(repository: reportRepository)
        ..selectTarget(
          const ReportTarget(
            type: ReportTargetType.letter,
            id: 12,
            label: '도착한 편지',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationReportScreen(
            notificationController: notificationController,
            reportController: reportController,
            onBack: () {},
            onOpenNotification: openedNotifications.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      notificationRepository.emit(
        const NotificationStreamEvent.replyArrival('보낸 편지에 답장이 도착했습니다!'),
      );
      await tester.pumpAndSettle();

      expect(find.text('알림/신고'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notification-status-toolbar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notification-result-section')),
        findsOneWidget,
      );
      expect(find.text('읽지 않음 2개'), findsOneWidget);
      expect(find.text('바로 이동 2개'), findsOneWidget);
      expect(find.text('상대방이 편지를 읽었습니다.'), findsOneWidget);
      expect(find.text('보낸 편지에 답장이 도착했습니다!'), findsWidgets);
      expect(find.text('새 알림'), findsWidgets);
      expect(find.text('편지'), findsWidgets);

      await tester.ensureVisible(
        find.byKey(const ValueKey('notification-card-1')),
      );
      await tester.drag(
        find.byKey(const ValueKey('notification-list')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notification-card-1')));
      await tester.pumpAndSettle();

      expect(notificationRepository.markReadIds, [1]);
      expect(openedNotifications.single.isRead, isTrue);
      expect(find.bySemanticsLabel(RegExp('읽은 알림.*편지')), findsOneWidget);
      expect(find.text('읽음'), findsWidgets);

      await tester.tap(find.text('신고'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-flow-panel')), findsNothing);
      expect(find.text('신고 접수 흐름'), findsNothing);
      final reportForm = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('report-form')),
      );
      final reportPadding = reportForm.padding! as EdgeInsets;
      expect(
        reportPadding.bottom,
        greaterThanOrEqualTo(AppSpacing.persistentNavigationReserve),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('report-reason-spam')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-reason-spam')));
      await tester.enterText(
        find.byKey(const ValueKey('report-content-field')),
        '반복 광고입니다.',
      );
      final submitButton = find.byKey(const ValueKey('report-submit-button'));
      await tester.dragUntilVisible(
        submitButton,
        find.byKey(const ValueKey('report-form')),
        const Offset(0, -120),
      );
      await tester.drag(
        find.byKey(const ValueKey('report-form')),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pump();

      expect(reportRepository.drafts, hasLength(1));
      expect(find.text('신고가 접수되었습니다.'), findsOneWidget);
      expect(find.text('이미 접수된 신고입니다.'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('separates unread and read notifications in the list',
      (tester) async {
    final notificationRepository = _MixedNotificationRepository();
    final reportRepository = _FakeReportRepository();
    final notificationController = NotificationController(
      repository: notificationRepository,
    );
    final reportController = ReportController(repository: reportRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationReportScreen(
          notificationController: notificationController,
          reportController: reportController,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notification-unread-section-header')),
        findsOneWidget);
    expect(find.text('새 알림 1개'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-read-section-header')),
        findsOneWidget);
    expect(find.text('읽은 알림 1개'), findsOneWidget);

    final unreadRect = tester.getRect(
      find.byKey(const ValueKey('notification-card-11')),
    );
    final readRect = tester.getRect(
      find.byKey(const ValueKey('notification-card-12')),
    );

    expect(readRect.top, greaterThan(unreadRect.bottom));
  });

  testWidgets('stacks report target fields on a narrow phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final notificationRepository = _FakeNotificationRepository();
    final reportRepository = _FakeReportRepository();
    final notificationController = NotificationController(
      repository: notificationRepository,
    );
    final reportController = ReportController(repository: reportRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationReportScreen(
          notificationController: notificationController,
          reportController: reportController,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('신고'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('report-target-id-field')),
    );
    await tester.pumpAndSettle();

    final typeRect = tester.getRect(
      find.byKey(const ValueKey('report-target-type-field-post')),
    );
    final idRect = tester.getRect(
      find.byKey(const ValueKey('report-target-id-field')),
    );

    expect(typeRect.width, greaterThanOrEqualTo(240));
    expect(idRect.width, greaterThanOrEqualTo(240));
    expect(idRect.top, greaterThan(typeRect.bottom));
  });

  testWidgets('keeps notification empty state free of helper explanation copy',
      (tester) async {
    final notificationRepository = _EmptyNotificationRepository();
    final reportRepository = _FakeReportRepository();
    final notificationController = NotificationController(
      repository: notificationRepository,
    );
    final reportController = ReportController(repository: reportRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationReportScreen(
          notificationController: notificationController,
          reportController: reportController,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('아직 도착한 알림이 없습니다.'), findsOneWidget);
    expect(find.text('새 알림이 오면 이곳에 표시됩니다.'), findsNothing);
  });
}

class _FakeNotificationRepository implements NotificationRepository {
  int ticketRequestCount = 0;
  final List<int> markReadIds = [];
  StreamController<NotificationStreamEvent>? _controller;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    return const [
      NotificationItem(
        id: 1,
        content: '상대방이 편지를 읽었습니다.',
        type: 'letter_read',
        targetType: 'LETTER',
        targetId: 12,
        routeKey: 'letter',
        isRead: false,
        createdAt: '2026-05-24T09:00:00',
      ),
    ];
  }

  @override
  Future<NotificationItem> markRead(int notificationId) async {
    markReadIds.add(notificationId);
    return NotificationItem(
      id: notificationId,
      content: '상대방이 편지를 읽었습니다.',
      type: 'letter_read',
      targetType: 'LETTER',
      targetId: 12,
      routeKey: 'letter',
      isRead: true,
      createdAt: '2026-05-24T09:00:00',
      readAt: '2026-05-24T09:01:00',
    );
  }

  @override
  Future<NotificationBulkReadResult> markAllRead() async {
    return const NotificationBulkReadResult(updatedCount: 1);
  }

  @override
  Future<NotificationDeviceTokenResult> registerDeviceToken({
    required NotificationDevicePlatform platform,
    required String token,
  }) async {
    return NotificationDeviceTokenResult(
      platform: platform,
      enabled: true,
      updatedAt: '2026-05-24T09:02:00',
    );
  }

  @override
  Future<bool> unregisterDeviceToken(String token) async {
    return true;
  }

  @override
  Future<NotificationSubscriptionTicket> requestSubscriptionTicket() async {
    ticketRequestCount += 1;
    return const NotificationSubscriptionTicket(
      ticket: 'ticket-1',
      expiresInSeconds: 60,
    );
  }

  @override
  Stream<NotificationStreamEvent> connect(String ticket) {
    _controller = StreamController<NotificationStreamEvent>(sync: true);
    return _controller!.stream;
  }

  void emit(NotificationStreamEvent event) {
    _controller?.add(event);
  }
}

class _EmptyNotificationRepository extends _FakeNotificationRepository {
  @override
  Future<List<NotificationItem>> fetchNotifications() async => const [];

  @override
  Future<NotificationBulkReadResult> markAllRead() async {
    return const NotificationBulkReadResult(updatedCount: 0);
  }
}

class _MixedNotificationRepository extends _FakeNotificationRepository {
  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    return const [
      NotificationItem(
        id: 11,
        content: '새 댓글이 도착했습니다.',
        type: 'story_comment',
        targetType: 'POST',
        targetId: 21,
        routeKey: 'story',
        isRead: false,
        createdAt: '2026-05-24T09:00:00',
      ),
      NotificationItem(
        id: 12,
        content: '이전 알림입니다.',
        type: 'letter_read',
        targetType: 'LETTER',
        targetId: 12,
        routeKey: 'letter',
        isRead: true,
        createdAt: '2026-05-24T08:00:00',
        readAt: '2026-05-24T08:10:00',
      ),
    ];
  }
}

class _FakeReportRepository implements ReportRepository {
  final List<ReportDraft> drafts = [];

  @override
  Future<int> createReport(ReportDraft draft) async {
    drafts.add(draft);
    return drafts.length;
  }
}

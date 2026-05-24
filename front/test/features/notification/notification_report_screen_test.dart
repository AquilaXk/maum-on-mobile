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

void main() {
  testWidgets('renders notifications and submits a report', (tester) async {
    final notificationRepository = _FakeNotificationRepository();
    final reportRepository = _FakeReportRepository();
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
        ),
      ),
    );
    await tester.pump();
    notificationRepository.emit(
      const NotificationStreamEvent.replyArrival('보낸 편지에 답장이 도착했습니다!'),
    );
    await tester.pump();

    expect(find.text('알림/신고'), findsOneWidget);
    expect(find.text('상대방이 편지를 읽었습니다.'), findsOneWidget);
    expect(find.text('보낸 편지에 답장이 도착했습니다!'), findsWidgets);

    await tester.tap(find.text('신고'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-reason-spam')));
    await tester.enterText(
      find.byKey(const ValueKey('report-content-field')),
      '반복 광고입니다.',
    );
    final submitButton = find.byKey(const ValueKey('report-submit-button'));
    await tester.scrollUntilVisible(
      submitButton,
      500,
      scrollable: find.byKey(const ValueKey('report-form')),
    );
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pump();

    expect(reportRepository.drafts, hasLength(1));
    expect(find.text('신고가 접수되었습니다.'), findsOneWidget);
    expect(find.text('이미 접수된 신고입니다.'), findsOneWidget);
  });
}

class _FakeNotificationRepository implements NotificationRepository {
  int ticketRequestCount = 0;
  StreamController<NotificationStreamEvent>? _controller;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    return const [
      NotificationItem(
        id: 1,
        content: '상대방이 편지를 읽었습니다.',
        isRead: false,
        createdAt: '2026-05-24T09:00:00',
      ),
    ];
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

class _FakeReportRepository implements ReportRepository {
  final List<ReportDraft> drafts = [];

  @override
  Future<int> createReport(ReportDraft draft) async {
    drafts.add(draft);
    return drafts.length;
  }
}

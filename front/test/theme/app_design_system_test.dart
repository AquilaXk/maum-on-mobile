import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/shared/ui/app_design_system.dart';
import 'package:maum_on_mobile_front/theme/app_theme.dart';

void main() {
  testWidgets('keeps the mobile design shell stable with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          );
        },
        home: AppScreen(
          title: '마음 기록',
          subtitle: '오늘의 감정과 대화를 한 화면에서 확인합니다.',
          onBack: () {},
          actions: [
            IconButton(
              tooltip: '새로고침',
              onPressed: () {},
              icon: const Icon(Icons.refresh),
            ),
          ],
          children: const [
            AppNotice(
              message: '네트워크가 불안정해도 화면 상태가 유지됩니다.',
            ),
            SizedBox(height: AppSpacing.md),
            AppMetricTile(
              label: '최근 받은 편지',
              value: '마음이 전한 긴 제목의 편지',
            ),
            SizedBox(height: AppSpacing.md),
            AppSectionCard(
              title: '오늘의 입력',
              child: TextField(
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(labelText: '내용'),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            AppStatusPill(
              label: '상담 연결됨',
              tone: AppStatusTone.success,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('마음 기록'), findsOneWidget);
    expect(find.text('상담 연결됨'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notice variants expose consistent state icons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Column(
            children: [
              AppNotice(message: '정보'),
              AppNotice(
                message: '성공',
                tone: AppNoticeTone.success,
              ),
              AppNotice(
                message: '오류',
                tone: AppNoticeTone.error,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('screen exposes pull refresh when a reload callback is provided',
      (tester) async {
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppScreen(
          title: '목록',
          onRefresh: () async {
            refreshCount += 1;
          },
          children: const [
            SizedBox(height: 1200, child: Text('스크롤 목록')),
          ],
        ),
      ),
    );

    expect(find.byType(RefreshIndicator), findsOneWidget);

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await indicator.onRefresh();
    await tester.pump();

    expect(refreshCount, 1);
  });

  testWidgets('list and detail rows expose stable mobile accessibility',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ListView(
            children: [
              AppListRow(
                rowKey: const ValueKey('design-list-row'),
                title: '작은 화면에서 두 줄까지 보이는 긴 운영 대상 제목',
                subtitle: '신고자 · very.long.email.address@example-service.test',
                statusLabel: '접수',
                statusTone: AppStatusTone.warning,
                leadingIcon: Icons.inbox_outlined,
                semanticLabel: '운영 목록 행, 게시글, 접수 상태',
                onTap: () {},
              ),
              const AppDetailRow(
                label: '신고자',
                value: '신고자 · very.long.email.address@example-service.test',
                semanticLabel:
                    '신고자, 신고자, very.long.email.address@example-service.test',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('운영 목록 행, 게시글, 접수 상태'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '신고자, 신고자, very.long.email.address@example-service.test',
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('design-list-row'))).height,
      greaterThanOrEqualTo(64),
    );
    expect(tester.takeException(), isNull);
  });
}

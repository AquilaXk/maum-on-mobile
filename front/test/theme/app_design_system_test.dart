import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/shared/ui/app_design_system.dart';
import 'package:maum_on_mobile_front/theme/app_theme.dart';

double _contrastRatio(Color foreground, Color background) {
  double linear(double channel) {
    return channel <= 0.03928
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  double luminance(Color c) {
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
  }

  final l1 = luminance(foreground);
  final l2 = luminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('uses the product blue brand colors without changing component scale',
      () {
    final theme = buildAppTheme();

    expect(theme.colorScheme.primary, const Color(0xFF2563EB));
    expect(theme.colorScheme.secondary, const Color(0xFF18A9ED));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFEDF5FF));
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.colorScheme.outlineVariant, const Color(0xFFDBE7FB));
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve({}),
      const Size(48, 52),
    );
  });

  test('앱 테마는 하늘색 라이트 토큰만 제공한다', () {
    final theme = buildAppTheme();

    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFEDF5FF));
    expect(theme.colorScheme.surface, Colors.white);
    expect(theme.colorScheme.surfaceContainerHighest, const Color(0xFFFBFDFF));
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.colorScheme.outlineVariant, const Color(0xFFDBE7FB));
  });

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
              label: 'AI 상담 연결됨',
              tone: AppStatusTone.success,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('마음 기록'), findsOneWidget);
    expect(find.text('AI 상담 연결됨'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses clamping refresh physics to avoid stretch overscroll',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppScreen(
          title: '홈',
          onRefresh: () async {},
          children: const [
            Text('새로고침 가능한 화면'),
          ],
        ),
      ),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );

    expect(scrollView.physics, isA<ClampingScrollPhysics>());
    expect(
      (scrollView.physics! as ClampingScrollPhysics).parent,
      isA<AlwaysScrollableScrollPhysics>(),
    );
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

  testWidgets('state views expose journey semantics and retry actions',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const AppStateView.loading(
                title: '상태를 불러오는 중입니다.',
                semanticLabel: '공통 로딩 상태',
              ),
              const SizedBox(height: AppSpacing.md),
              AppStateView.empty(
                title: '표시할 항목이 없습니다.',
                message: '조건을 바꿔 다시 확인해 주세요.',
                actionLabel: '다시 시도',
                onAction: () {
                  retryCount += 1;
                },
                semanticLabel: '공통 빈 상태',
              ),
              const SizedBox(height: AppSpacing.md),
              const AppStateView.permission(
                title: '권한이 필요합니다.',
                message: '기기 설정에서 권한을 허용해 주세요.',
                semanticLabel: '공통 권한 상태',
              ),
              const SizedBox(height: AppSpacing.md),
              const AppStateView.risk(
                title: '즉시 도움 요청',
                message: '위험 상황이면 주변 도움을 먼저 요청해 주세요.',
                semanticLabel: '공통 위험 안내 상태',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.health_and_safety_outlined), findsOneWidget);
    expect(find.bySemanticsLabel('공통 로딩 상태'), findsOneWidget);
    expect(find.bySemanticsLabel('공통 빈 상태'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, '다시 시도')).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.text('다시 시도'));
    expect(retryCount, 1);
    expect(tester.takeException(), isNull);
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

  testWidgets('screen reserves scroll space above persistent navigation',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const AppScreen(
          title: '상세',
          children: [
            SizedBox(height: 900, child: Text('마지막 액션')),
          ],
        ),
      ),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final padding = scrollView.padding!.resolve(TextDirection.ltr);

    expect(padding.bottom, greaterThanOrEqualTo(96));
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

  testWidgets(
      'content cards keep metadata and actions stable on compact phones',
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
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppContentCard(
                key: const ValueKey('design-content-card'),
                leadingIcon: Icons.article_outlined,
                title: '좁은 화면에서도 깨지지 않아야 하는 긴 콘텐츠 제목',
                subtitle: '작성자 · 조회 1234 · 오늘',
                badges: const [
                  AppStatusPill(
                    label: '일상',
                    tone: AppStatusTone.success,
                  ),
                  AppStatusPill(label: '공개'),
                ],
                content: const Text(
                  '본문 미리보기는 여러 줄이어도 카드 내부에서 안정적으로 줄바꿈됩니다.',
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('수정'),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('삭제'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('design-content-card')), findsOneWidget);
    expect(find.text('수정'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'content card keeps actions accessible outside ExcludeSemantics when semanticLabel is set',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      var cardTapped = 0;
      var editTapped = 0;
      var reportTapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: AppContentCard(
              key: const ValueKey('semantic-action-card'),
              title: 'very.long.email@example-service.test/path_name',
              subtitle: '일반 한국어 부제목',
              badges: const [AppStatusPill(label: '공개')],
              content: const Text('본문 내용'),
              semanticLabel: '콘텐츠 카드 요약',
              onTap: () => cardTapped += 1,
              actions: [
                OutlinedButton(
                  key: const ValueKey('card-edit-action'),
                  onPressed: () => editTapped += 1,
                  child: const Text('수정'),
                ),
                OutlinedButton(
                  key: const ValueKey('card-report-action'),
                  onPressed: () => reportTapped += 1,
                  child: const Text('신고'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('콘텐츠 카드 요약'), findsOneWidget);

      final editSemantics = tester.getSemantics(
        find.byKey(const ValueKey('card-edit-action')),
      );
      expect(editSemantics.label, contains('수정'));
      expect(
        editSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      final reportSemantics = tester.getSemantics(
        find.byKey(const ValueKey('card-report-action')),
      );
      expect(reportSemantics.label, contains('신고'));
      expect(
        reportSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('card-edit-action')));
      await tester.tap(find.byKey(const ValueKey('card-report-action')));
      await tester.tap(find.bySemanticsLabel('콘텐츠 카드 요약'));
      await tester.pump();

      expect(editTapped, 1);
      expect(reportTapped, 1);
      expect(cardTapped, 1);

      final titleWidget = tester.widget<Text>(
        find.text(
          'very.\u200Blong.\u200Bemail@\u200Bexample-\u200Bservice.\u200Btest/\u200Bpath_\u200Bname',
        ),
      );
      expect(titleWidget.data, contains('\u200B'));
    } finally {
      semanticsHandle.dispose();
    }
  });

  test('라이트 및 다크 테마 주요 전경/배경 조합은 WCAG AA(4.5:1 이상) 대비를 충족한다', () {
    for (final theme in [buildAppTheme(), buildDarkAppTheme()]) {
      final scheme = theme.colorScheme;
      expect(
        _contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(scheme.primary, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(scheme.onSecondaryContainer, scheme.secondaryContainer),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}

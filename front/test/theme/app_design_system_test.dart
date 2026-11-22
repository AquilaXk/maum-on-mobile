import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/consultation/presentation/widgets/breathing_grounding_sheet.dart';
import 'package:maum_on_mobile_front/features/diary/domain/mood_year_bitmap.dart';
import 'package:maum_on_mobile_front/features/diary/presentation/mood_heatmap_strip.dart';
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
    expect(theme.colorScheme.surfaceContainerHighest, const Color(0xFFF8FBFF));
    expect(theme.colorScheme.onSurface, const Color(0xFF1E293B));
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
    expect(find.byType(ShadCard), findsNWidgets(2));
    expect(find.byType(ShadBadge), findsOneWidget);
    expect(find.text('마음 기록'), findsOneWidget);
    expect(find.text('AI 상담 연결됨'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('buildMaumShadThemeData maps Light Sky-Blue and Dark Slate-Periwinkle tokens',
      () {
    final lightShad = buildMaumShadThemeData(Brightness.light);
    final darkShad = buildMaumShadThemeData(Brightness.dark);

    expect(lightShad.brightness, Brightness.light);
    expect(lightShad.radius, BorderRadius.circular(16));
    expect(lightShad.colorScheme.background, const Color(0xFFEDF5FF));
    expect(lightShad.colorScheme.card, const Color(0xFFFFFFFF));
    expect(lightShad.colorScheme.primary, const Color(0xFF2563EB));
    expect(lightShad.colorScheme.border, const Color(0xFFDBE7FB));

    expect(darkShad.brightness, Brightness.dark);
    expect(darkShad.radius, BorderRadius.circular(16));
    expect(darkShad.colorScheme.background, const Color(0xFF18191D));
    expect(darkShad.colorScheme.card, const Color(0xFF212529));
    expect(darkShad.colorScheme.primary, const Color(0xFF8E9CE6));
    expect(darkShad.colorScheme.border, const Color(0xFF343A40));
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

  test('MaumTokens는 라이트 및 다크 테마에 등록되고 5단계 감정 팔레트와 WCAG AA 대비를 충족한다', () {
    final lightTheme = buildAppTheme();
    final darkTheme = buildDarkAppTheme();

    expect(lightTheme.extension<MaumTokens>(), MaumTokens.light);
    expect(darkTheme.extension<MaumTokens>(), MaumTokens.dark);

    expect(lightTheme.textTheme.bodyLarge?.fontSize, 16);
    expect(lightTheme.textTheme.bodyLarge?.height, 1.58);
    expect(lightTheme.textTheme.bodyMedium?.fontSize, 14);
    expect(lightTheme.textTheme.bodyMedium?.height, 1.52);

    expect(darkTheme.textTheme.bodyLarge?.fontSize, 16);
    expect(darkTheme.textTheme.bodyLarge?.height, 1.58);
    expect(darkTheme.textTheme.bodyMedium?.fontSize, 14);
    expect(darkTheme.textTheme.bodyMedium?.height, 1.52);

    for (final tokens in [MaumTokens.light, MaumTokens.dark]) {
      expect(
        _contrastRatio(tokens.foreground, tokens.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.foreground, tokens.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.foreground, tokens.surfaceStrong),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.foreground, tokens.elevatedSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.foreground, tokens.codeBlockBackground),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.mutedForeground, tokens.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.mutedForeground, tokens.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.mutedForeground, tokens.surfaceStrong),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.mutedForeground, tokens.elevatedSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.primary, tokens.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.primary, tokens.softTint),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.onPrimary, tokens.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.statusSuccessFg, tokens.statusSuccessBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.statusWarningFg, tokens.statusWarningBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.statusDangerFg, tokens.statusDangerBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.statusInfoFg, tokens.statusInfoBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.statusNeutralFg, tokens.statusNeutralBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.statusSuccessDot, tokens.surface),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(tokens.statusWarningDot, tokens.surface),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(tokens.statusDangerDot, tokens.surface),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(tokens.statusNeutralDot, tokens.surface),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrastRatio(tokens.quickActionSkyFg, tokens.quickActionSkyBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.quickActionBlueFg, tokens.quickActionBlueBg),
        greaterThanOrEqualTo(4.5),
      );
    }

    for (var score = 1; score <= 5; score += 1) {
      final bg = MaumTokens.moodBackground(score);
      final fg = MaumTokens.moodForeground(score);
      expect(MaumTokens.moodColor(score), bg);
      expect(_contrastRatio(fg, bg), greaterThanOrEqualTo(4.5));
    }
    expect(MaumTokens.moodLabel(1), '매우 힘듦');
    expect(MaumTokens.moodLabel(2), '지침');
    expect(MaumTokens.moodLabel(3), '보통');
    expect(MaumTokens.moodLabel(4), '좋음');
    expect(MaumTokens.moodLabel(5), '매우 좋음');
  });

  test('MaumTokens.lerp는 라이트와 다크 토큰 사이의 중간 색상을 생성한다', () {
    final lerped = MaumTokens.light.lerp(MaumTokens.dark, 0.5);

    expect(
      lerped.background,
      Color.lerp(MaumTokens.light.background, MaumTokens.dark.background, 0.5),
    );
    expect(lerped.background, isNot(MaumTokens.light.background));
    expect(lerped.background, isNot(MaumTokens.dark.background));
    expect(
      lerped.surface,
      Color.lerp(MaumTokens.light.surface, MaumTokens.dark.surface, 0.5),
    );
    expect(
      lerped.primary,
      Color.lerp(MaumTokens.light.primary, MaumTokens.dark.primary, 0.5),
    );
    expect(
      lerped.quickActionBlueBg,
      Color.lerp(
        MaumTokens.light.quickActionBlueBg,
        MaumTokens.dark.quickActionBlueBg,
        0.5,
      ),
    );
    expect(MaumTokens.light.lerp(null, 0.5), MaumTokens.light);
    expect(
      MaumTokens.light.copyWith(primary: MaumTokens.dark.primary).primary,
      MaumTokens.dark.primary,
    );
  });

  test('허용된 토큰 파일 외 lib/**/*.dart에는 인라인 Color(0x...) 리터럴이 없다', () {
    final frontRoot = Directory('lib').existsSync()
        ? Directory.current
        : Directory('front');
    final libDir = Directory('${frontRoot.path}/lib');
    expect(libDir.existsSync(), isTrue);

    final colorLiteralPattern = RegExp(r'Color\s*\(\s*0[xX][0-9a-fA-F]+\s*\)');
    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final normalized = entity.path.replaceAll('\\', '/');
      final libIndex = normalized.lastIndexOf('/lib/');
      final relative =
          libIndex >= 0 ? normalized.substring(libIndex + 1) : normalized;

      final isAllowed = relative.startsWith('lib/theme/') ||
          relative == 'lib/shared/ui/brand_identity.dart' ||
          relative == 'lib/features/auth/presentation/oauth_brand_palette.dart';
      if (isAllowed) {
        continue;
      }

      final contents = entity.readAsStringSync();
      if (colorLiteralPattern.hasMatch(contents)) {
        violations.add(relative);
      }
    }

    expect(violations, isEmpty, reason: 'Found inline Color(0x...) in: $violations');
  });

  testWidgets('BuildContext.maumTokens는 등록된 확장과 미등록 폴백을 반환하고 tabularFigures가 숫자 위젯에 적용된다',
      (tester) async {
    late MaumTokens fallbackLight;
    late MaumTokens fallbackDark;
    late MaumTokens registeredLight;
    late MaumTokens registeredDark;

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('fallback-light'),
        theme: ThemeData.light(),
        home: Builder(
          builder: (context) {
            fallbackLight = context.maumTokens;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(fallbackLight, MaumTokens.light);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('fallback-dark'),
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            fallbackDark = context.maumTokens;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(fallbackDark, MaumTokens.dark);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('registered-dark'),
        theme: buildDarkAppTheme(),
        home: Builder(
          builder: (context) {
            registeredDark = context.maumTokens;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(registeredDark, MaumTokens.dark);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('registered-light-widgets'),
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    registeredLight = context.maumTokens;
                    return const AppMetricTile(
                      label: '연속 기록',
                      value: '12일',
                    );
                  },
                ),
                MoodHeatmapStrip(
                  bitmapsByYear: const <int, MoodYearBitmap>{},
                  anchorDate: DateTime(2026, 5, 20),
                ),
                const BreathingGroundingSheet(),
              ],
            ),
          ),
        ),
      ),
    );

    expect(registeredLight, MaumTokens.light);

    final metricText = tester.widget<Text>(find.text('12일'));
    expect(metricText.style?.fontFeatures, AppTypography.tabularFigures);

    final streakText = tester.widget<Text>(find.textContaining('연속 0일'));
    expect(streakText.style?.fontFeatures, AppTypography.tabularFigures);

    final secondsText = tester.widget<Text>(
      find.byKey(const ValueKey('breathing-seconds-label')),
    );
    expect(secondsText.style?.fontFeatures, AppTypography.tabularFigures);
  });
}

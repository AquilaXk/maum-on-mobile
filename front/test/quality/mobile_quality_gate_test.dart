import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/shared/ui/app_design_system.dart';
import 'package:maum_on_mobile_front/theme/app_theme.dart';

void main() {
  testWidgets('quality gate variants keep text and controls stable',
      (tester) async {
    final semantics = tester.ensureSemantics();

    try {
      const variants = [
        _QualityVariant(
          name: 'small-screen-large-text',
          size: Size(320, 640),
          textScale: 1.35,
          themeMode: ThemeMode.light,
        ),
        _QualityVariant(
          name: 'dark-mode',
          size: Size(390, 844),
          textScale: 1,
          themeMode: ThemeMode.dark,
        ),
        _QualityVariant(
          name: 'rotated-landscape',
          size: Size(844, 390),
          textScale: 1.15,
          themeMode: ThemeMode.light,
        ),
      ];

      for (final variant in variants) {
        await _pumpQualitySurface(tester, variant);

        expect(find.byKey(ValueKey('quality-${variant.name}')), findsOneWidget);
        expect(find.bySemanticsLabel('품질 게이트 작성 버튼'), findsOneWidget);
        final actionSize = tester.getSize(
          find.byKey(const ValueKey('quality-primary-action')),
        );
        expect(actionSize.width, greaterThanOrEqualTo(48));
        expect(actionSize.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _pumpQualitySurface(
  WidgetTester tester,
  _QualityVariant variant,
) async {
  tester.view.physicalSize = variant.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: variant.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(variant.textScale),
          ),
          child: child!,
        );
      },
      home: AppScreen(
        title: '모바일 품질 점검',
        subtitle: '작은 화면과 큰 글자에서도 주요 액션이 안정적으로 보입니다.',
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: () {},
            icon: const Icon(Icons.refresh),
          ),
        ],
        children: [
          const AppNotice(
            message: '백그라운드 복귀 후 실시간 연결을 다시 확인합니다.',
            tone: AppNoticeTone.success,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title: '작성 흐름',
            subtitle: '로그인, 탭 이동, 작성, 전송까지 이어지는 핵심 시나리오',
            child: Semantics(
              container: true,
              button: true,
              label: '품질 게이트 작성 버튼',
              child: ExcludeSemantics(
                child: FilledButton.icon(
                  key: const ValueKey('quality-primary-action'),
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined),
                  label: Text('작성하기 - ${variant.name}'),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppListRow(
            rowKey: ValueKey('quality-${variant.name}'),
            title: '푸시와 실시간 연결 상태가 중복 없이 표시되는 항목',
            subtitle: '화면 회전, 큰 글자, 다크 모드에서도 줄바꿈과 터치 영역을 유지합니다.',
            statusLabel: '연결됨',
            statusTone: AppStatusTone.success,
            leadingIcon: Icons.notifications_active_outlined,
            semanticLabel: '품질 게이트 실시간 연결 항목',
            onTap: () {},
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _QualityVariant {
  const _QualityVariant({
    required this.name,
    required this.size,
    required this.textScale,
    required this.themeMode,
  });

  final String name;
  final Size size;
  final double textScale;
  final ThemeMode themeMode;
}

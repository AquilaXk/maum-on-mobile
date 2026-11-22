import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/theme/app_theme.dart';

void main() {
  testWidgets('ShadTheme.maybeOf returns null when absent and ShadTheme.of throws',
      (tester) async {
    ShadThemeData? missing;
    Object? ofError;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            missing = ShadTheme.maybeOf(context);
            try {
              ShadTheme.of(context);
            } catch (error) {
              ofError = error;
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(missing, isNull);
    expect(ofError, isA<FlutterError>());
  });

  testWidgets('ShadTheme.of returns nearest Light and Dark ShadThemeData',
      (tester) async {
    late ShadThemeData resolvedLight;
    late ShadThemeData resolvedDark;

    await tester.pumpWidget(
      MaterialApp(
        home: ShadTheme(
          data: buildMaumShadThemeData(Brightness.light),
          child: Builder(
            builder: (context) {
              resolvedLight = ShadTheme.of(context);
              return ShadTheme(
                data: buildMaumShadThemeData(Brightness.dark),
                child: Builder(
                  builder: (darkContext) {
                    resolvedDark = ShadTheme.of(darkContext);
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(resolvedLight.brightness, Brightness.light);
    expect(resolvedLight.colorScheme.card, const Color(0xFFFFFFFF));
    expect(resolvedLight.colorScheme.primary, const Color(0xFF2563EB));
    expect(resolvedDark.brightness, Brightness.dark);
    expect(resolvedDark.colorScheme.card, const Color(0xFF212529));
    expect(resolvedDark.colorScheme.primary, const Color(0xFF8E9CE6));
  });

  testWidgets('ShadCard applies theme defaults and explicit overrides',
      (tester) async {
    final lightTheme = buildMaumShadThemeData(Brightness.light);
    final customBorderColor = const Color(0xFF1D4ED8);
    final customBg = const Color(0xFFE0F2FE);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShadTheme(
            data: lightTheme,
            child: Column(
              children: [
                const ShadCard(
                  key: ValueKey('default-card'),
                  child: Text('기본 카드'),
                ),
                ShadCard(
                  key: const ValueKey('override-card'),
                  width: 220,
                  height: 88,
                  padding: const EdgeInsets.all(8),
                  backgroundColor: customBg,
                  radius: BorderRadius.circular(24),
                  border: ShadBorder.all(color: customBorderColor, width: 2),
                  shadows: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                  rowMainAxisSize: MainAxisSize.max,
                  rowMainAxisAlignment: MainAxisAlignment.center,
                  columnCrossAxisAlignment: CrossAxisAlignment.center,
                  child: const Text('오버라이드 카드'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final defaultDecorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('default-card')),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final defaultBox = defaultDecorated.decoration as BoxDecoration;
    expect(defaultBox.color, lightTheme.cardTheme!.backgroundColor);
    expect(defaultBox.borderRadius, lightTheme.cardTheme!.radius);
    expect(defaultBox.boxShadow, isNotEmpty);

    final overrideCardSize =
        tester.getSize(find.byKey(const ValueKey('override-card')));
    expect(overrideCardSize, const Size(220, 88));

    final overrideDecorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('override-card')),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final overrideBox = overrideDecorated.decoration as BoxDecoration;
    expect(overrideBox.color, customBg);
    expect(overrideBox.borderRadius, BorderRadius.circular(24));
    expect(
      overrideBox.border,
      Border.all(color: customBorderColor, width: 2),
    );
  });

  testWidgets('ShadCard works inside IntrinsicHeight and unbounded Row',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkAppTheme(),
        home: const Scaffold(
          body: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ShadCard(
                        rowMainAxisSize: MainAxisSize.max,
                        columnCrossAxisAlignment: CrossAxisAlignment.stretch,
                        child: Text('짧음'),
                      ),
                    ),
                    Expanded(
                      child: ShadCard(
                        rowMainAxisSize: MainAxisSize.max,
                        columnCrossAxisAlignment: CrossAxisAlignment.stretch,
                        child: Text('두 줄로\n높아지는 카드'),
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ShadCard(child: Text('비제한 폭')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('짧음'), findsOneWidget);
    expect(find.text('두 줄로\n높아지는 카드'), findsOneWidget);
    expect(find.text('비제한 폭'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShadBadge renders all variants with theme and custom overrides',
      (tester) async {
    final lightTheme = buildMaumShadThemeData(Brightness.light);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShadTheme(
            data: lightTheme,
            child: const Column(
              children: [
                ShadBadge(
                  key: ValueKey('badge-primary'),
                  child: Text('Primary'),
                ),
                ShadBadge.secondary(
                  key: ValueKey('badge-secondary'),
                  child: Text('Secondary'),
                ),
                ShadBadge.outline(
                  key: ValueKey('badge-outline'),
                  child: Text('Outline'),
                ),
                ShadBadge.destructive(
                  key: ValueKey('badge-destructive'),
                  child: Text('Destructive'),
                ),
                ShadBadge.raw(
                  key: ValueKey('badge-raw'),
                  variant: ShadBadgeVariant.outline,
                  backgroundColor: Color(0xFFDCFCE7),
                  hoverBackgroundColor: Color(0xFFBBF7D0),
                  foregroundColor: Color(0xFF166534),
                  shape: StadiumBorder(
                    side: BorderSide(color: Color(0xFF86EFAC)),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Text('Custom'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Secondary'), findsOneWidget);
    expect(find.text('Outline'), findsOneWidget);
    expect(find.text('Destructive'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    final rawBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('badge-raw')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final rawShape = rawBox.decoration as ShapeDecoration;
    expect(rawShape.color, const Color(0xFFDCFCE7));

    final primaryBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('badge-primary')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final primaryShape = primaryBox.decoration as ShapeDecoration;
    expect(primaryShape.color, lightTheme.colorScheme.primary);
    expect(tester.takeException(), isNull);
  });
}

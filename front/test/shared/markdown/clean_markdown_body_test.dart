import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/shared/markdown/clean_markdown_body.dart';

void main() {
  testWidgets('renders headings, soft line breaks, formatting, and rules',
      (tester) async {
    const sample = '''
# 큰 제목
## 중간 제목
### 작은 제목

첫 줄
둘째 줄 **굵게** *기울임* ~~취소선~~ `코드`

---
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CleanMarkdownBody(
              data: sample,
              softLineBreak: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('큰 제목'), findsOneWidget);
    expect(find.text('중간 제목'), findsOneWidget);
    expect(find.text('작은 제목'), findsOneWidget);
    expect(find.textContaining('첫 줄\n둘째 줄'), findsOneWidget);
    expect(find.textContaining('굵게'), findsOneWidget);
    expect(find.textContaining('기울임'), findsOneWidget);
    expect(find.textContaining('취소선'), findsOneWidget);
    expect(find.textContaining('코드'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders list markers as sibling Text widgets and handles lists',
      (tester) async {
    const sample = '''
**목록 제목**
- 첫 번째 항목
* 두 번째 항목
1. 순서 첫째
2. 순서 둘째
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CleanMarkdownBody(data: sample),
          ),
        ),
      ),
    );

    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('첫 번째 항목'), findsOneWidget);
    expect(find.text('두 번째 항목'), findsOneWidget);
    expect(find.text('순서 첫째'), findsOneWidget);
    expect(find.text('순서 둘째'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders blockquotes, fenced code blocks, and GFM tables',
      (tester) async {
    const sample = '''
> 마음이 힘들 때는 잠시 숨을 고르세요.

```dart
void breathe() {
  // <b>not html</b>
}
```

| 단계 | 시간 |
| :--- | ---: |
| 들숨 | 4초 |
| 날숨 | 4초 |
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CleanMarkdownBody(data: sample),
          ),
        ),
      ),
    );

    expect(find.text('마음이 힘들 때는 잠시 숨을 고르세요.'), findsOneWidget);
    expect(find.textContaining('void breathe()'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('단계'), findsOneWidget);
    expect(find.text('시간'), findsOneWidget);
    expect(find.text('들숨'), findsOneWidget);
    expect(find.text('4초'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks javascript:/data: links and triggers callback for https:',
      (tester) async {
    final tapped = <(String, String?, String)>[];
    const sample = '''
- [안전 안내](https://maum-on.app/help)
- [차단 JS](javascript:alert(1))
- [차단 Data](data:text/html,<script>alert(1)</script>)
''';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CleanMarkdownBody(
            data: sample,
            onTapLink: (text, href, title) {
              tapped.add((text, href, title));
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('차단 JS'));
    await tester.tap(find.text('차단 Data'));
    await tester.pump();
    expect(tapped, isEmpty);

    await tester.tap(find.text('안전 안내'));
    await tester.pump();
    expect(tapped, [('안전 안내', 'https://maum-on.app/help', '')]);
  });

  testWidgets('suppresses markdown images and escapes raw html/script literals',
      (tester) async {
    const sample = '''
![숨겨진 이미지](https://evil.example/tracker.png)

<script>alert("xss")</script>

<b>굵지 않은 태그</b>
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CleanMarkdownBody(data: sample),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('tracker.png'), findsNothing);
    expect(find.text('<script>alert("xss")</script>'), findsOneWidget);
    expect(find.text('<b>굵지 않은 태그</b>'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('enforces fail-closed parser caps on characters, blocks, spans, nesting',
      () {
    final overCharInput =
        '${'가' * (CleanMarkdownBody.maxCharacters - 1)}😊OVERFLOW_SENTINEL';
    final charDoc = CleanMarkdownParser.parse(overCharInput);
    expect(charDoc.truncated, isTrue);
    final flattenedChars = charDoc.plainTextLength;
    expect(flattenedChars, lessThanOrEqualTo(CleanMarkdownBody.maxCharacters));
    expect(overCharInput.substring(0, flattenedChars).contains('OVERFLOW'),
        isFalse);

    final manyBlocks =
        List<String>.generate(300, (index) => '- 항목 $index').join('\n');
    final blockDoc = CleanMarkdownParser.parse(manyBlocks);
    expect(blockDoc.truncated, isTrue);
    expect(blockDoc.blocks.length, lessThanOrEqualTo(CleanMarkdownBody.maxBlocks));

    final manySpans = List<String>.generate(300, (i) => '**s$i**').join(' ');
    final spanDoc = CleanMarkdownParser.parse(manySpans);
    final paragraph = spanDoc.blocks.single as CleanMarkdownParagraphBlock;
    expect(
      paragraph.spans.length,
      lessThanOrEqualTo(CleanMarkdownBody.maxInlineSpans),
    );

    final deepQuote = '${'> ' * 15}깊은 인용';
    final quoteDoc = CleanMarkdownParser.parse(deepQuote);
    expect(quoteDoc.maxObservedNesting, lessThanOrEqualTo(CleanMarkdownBody.maxNesting));
  });

  testWidgets('enforces max character cap in widget rendering and disposes links cleanly',
      (tester) async {
    final overflowPayload =
        '${'a' * CleanMarkdownBody.maxCharacters}\n\n# OVERFLOW_HEADING';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CleanMarkdownBody(
              data: overflowPayload,
              onTapLink: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('OVERFLOW_HEADING'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CleanMarkdownBody(
            data: '[첫 링크](https://maum-on.app/1)',
            onTapLink: (_, __, ___) {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CleanMarkdownBody(
            data: '[둘째 링크](https://maum-on.app/2)',
            onTapLink: (_, __, ___) {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

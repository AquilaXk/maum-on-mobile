import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/consultation/application/consultation_controller.dart';
import 'package:maum_on_mobile_front/features/consultation/data/consultation_repository.dart';
import 'package:maum_on_mobile_front/features/consultation/domain/consultation_models.dart';
import 'package:maum_on_mobile_front/features/consultation/presentation/consultation_screen.dart';
import 'package:maum_on_mobile_front/features/consultation/presentation/widgets/breathing_grounding_sheet.dart';
import 'package:maum_on_mobile_front/features/consultation/presentation/widgets/counselor_markdown_message.dart';
import 'package:maum_on_mobile_front/features/consultation/presentation/widgets/jumping_dots_indicator.dart';
import 'package:maum_on_mobile_front/theme/app_theme.dart';

void main() {
  testWidgets('shows compact consultation status on a phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeConsultationRepository();
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('consultation-status-toolbar')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('consultation-flow-panel')), findsNothing);
    expect(find.text('상담'), findsNothing);
    expect(find.text('상담 흐름'), findsNothing);
    expect(find.text('AI 상담'), findsOneWidget);
    expect(find.text('연결'), findsNothing);
    expect(find.text('입력'), findsNothing);
    expect(find.text('응답'), findsNothing);
    expect(find.text('AI 상담 연결됨'), findsNothing);
    expect(find.text('대화 0개'), findsNothing);
    expect(find.text('입력 가능'), findsNothing);
    expect(find.text('상담 대기 중'), findsNothing);
    expect(find.text('연결됨'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('consultation-breathing-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('consultation-new-session-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('consultation-empty-state')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('consultation-empty-state')),
        matching: find.byType(ShadCard),
      ),
      findsOneWidget,
    );
    expect(find.text('오늘 마음을 나눠 볼까요'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('consultation-composer-section')),
      findsOneWidget,
    );

    await tester.tap(find.text('마음이 지쳐서 쉬고 싶어요'));
    await tester.pump();
    expect(controller.state.draft, '마음이 지쳐서 쉬고 싶어요');
  });

  testWidgets('상담 상태 영역은 첫 화면 대화를 밀어내지 않는 얇은 스트립이다', (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeConsultationRepository();
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pump();

    expect(find.text('AI 상담 상태'), findsNothing);

    final toolbarSize = tester.getSize(
      find.byKey(const ValueKey('consultation-status-toolbar')),
    );
    expect(toolbarSize.height, lessThanOrEqualTo(72));
  });

  testWidgets('renders chat stream and sends a message', (tester) async {
    final repository = _FakeConsultationRepository();
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pump();

    expect(repository.connectCount, 1);
    expect(find.text('연결됨'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('consultation-status-toolbar')),
      findsOneWidget,
    );
    expect(find.text('대화 0개'), findsNothing);
    expect(find.byKey(const ValueKey('consultation-chat-section')),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('consultation-composer-section')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '잠이 잘 오지 않아요',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pump();

    expect(find.text('답변 작성 중'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('consultation-typing-indicator')),
      findsOneWidget,
    );

    repository
      ..emit(const ConsultationStreamEvent.chat('오늘은 '))
      ..emit(const ConsultationStreamEvent.chat('천천히 쉬어도 괜찮아요.'))
      ..emit(const ConsultationStreamEvent.done());
    await tester.pump();

    expect(repository.sentMessages, ['잠이 잘 오지 않아요']);
    expect(find.text('오늘은 천천히 쉬어도 괜찮아요.'), findsOneWidget);
  });

  testWidgets('hides composer count and aligns send action with input',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeConsultationRepository();
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pump();

    expect(
      find.text('0/${ConsultationController.maxMessageLength}'),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '안녕',
    );
    await tester.pump();

    expect(
      find.text('2/${ConsultationController.maxMessageLength}'),
      findsNothing,
    );

    final messageField = tester.widget<TextField>(
      find.byKey(const ValueKey('consultation-message-field')),
    );
    expect(messageField.maxLength, ConsultationController.maxMessageLength);
    expect(messageField.inputFormatters, isNull);
    expect(messageField.buildCounter, isNotNull);
    expect(messageField.decoration?.helperText, isNull);
    expect(messageField.decoration?.counterText, isNull);
    expect(messageField.decoration?.semanticCounterText, isNull);
    expect(messageField.decoration?.counter, isNull);
    expect(messageField.decoration?.constraints?.minHeight, 56);

    final fieldSemantics = _findSemanticsWithLengthLimit(
      tester,
      ConsultationController.maxMessageLength,
      where: (data) =>
          data.flagsCollection.isTextField &&
          data.currentValueLength == 2 &&
          data.value == '안녕',
    );
    expect(fieldSemantics, isNotNull);
    expect(fieldSemantics!.currentValueLength, 2);
    semanticsHandle.dispose();

    final fieldRect = tester.getRect(
      find.byKey(const ValueKey('consultation-message-field')),
    );
    final sendButtonRect = tester.getRect(
      find.byKey(const ValueKey('consultation-send-button')),
    );

    expect(
      sendButtonRect.width,
      52,
    );
    expect(
      sendButtonRect.height,
      52,
    );
    expect(
      fieldRect.height,
      greaterThanOrEqualTo(sendButtonRect.height),
    );
    expect(
      (sendButtonRect.center.dy - fieldRect.center.dy).abs(),
      lessThanOrEqualTo(1),
    );

    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pump();

    expect(find.text('답변을 작성 중입니다.'), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('consultation-message-field')),
          )
          .decoration
          ?.helperText,
      isNull,
    );
    final streamingFieldRect = tester.getRect(
      find.byKey(const ValueKey('consultation-message-field')),
    );
    final streamingStopButtonRect = tester.getRect(
      find.byKey(const ValueKey('consultation-stop-button')),
    );
    expect(
      (streamingStopButtonRect.center.dy - streamingFieldRect.center.dy).abs(),
      lessThanOrEqualTo(1),
    );

    repository.emit(const ConsultationStreamEvent.done());
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '첫 줄\n둘째 줄\n셋째 줄',
    );
    await tester.pump();

    expect(
      find.textContaining('/${ConsultationController.maxMessageLength}'),
      findsNothing,
    );

    final expandedFieldRect = tester.getRect(
      find.byKey(const ValueKey('consultation-message-field')),
    );
    final fixedSendButtonRect = tester.getRect(
      find.byKey(const ValueKey('consultation-send-button')),
    );

    expect(fixedSendButtonRect.width, 52);
    expect(fixedSendButtonRect.height, 52);
    expect(
      (fixedSendButtonRect.center.dy - expandedFieldRect.center.dy).abs(),
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('keeps composer above the keyboard inset on a phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeConsultationRepository();
    final controller = ConsultationController(repository: repository);
    const keyboardInset = 260.0;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: keyboardInset),
            ),
            child: child!,
          );
        },
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pumpAndSettle();

    final composerRect = tester.getRect(
      find.byKey(const ValueKey('consultation-composer-section')),
    );

    expect(
      composerRect.bottom,
      lessThanOrEqualTo(640 - keyboardInset),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows reconnect action after a stream error', (tester) async {
    final repository = _FakeConsultationRepository();
    final controller = ConsultationController(
      repository: repository,
      reconnectBackoffDelays: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emitError(Exception('closed'));
    await tester.pump();

    expect(find.text('재연결 필요'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('consultation-reconnect-button')));
    await tester.pump();

    expect(repository.connectCount, 2);
  });

  testWidgets('상담 재연결 버튼은 모바일 터치 영역을 유지한다', (tester) async {
    final repository = _FakeConsultationRepository();
    final controller = ConsultationController(
      repository: repository,
      reconnectBackoffDelays: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emitError(Exception('closed'));
    await tester.pump();

    final reconnectButtonSize = tester.getSize(
      find.byKey(const ValueKey('consultation-reconnect-button')),
    );

    expect(reconnectButtonSize.width, greaterThanOrEqualTo(48));
    expect(reconnectButtonSize.height, greaterThanOrEqualTo(48));
  });

  testWidgets('shows retry and delete actions for a failed send',
      (tester) async {
    final repository = _FakeConsultationRepository()
      ..sendErrors.add(Exception('network down'));
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '전송에 실패할 메시지',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('consultation-failed-message-notice')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('consultation-retry-failed-message-button')),
    );
    await tester.pump();
    repository
      ..emit(const ConsultationStreamEvent.chat('다시 보냈어요.'))
      ..emit(const ConsultationStreamEvent.done());
    await tester.pump();

    expect(repository.sentMessages, ['전송에 실패할 메시지', '전송에 실패할 메시지']);
    expect(find.text('다시 보냈어요.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('consultation-failed-message-notice')),
      findsNothing,
    );

    repository.sendErrors.add(Exception('network down'));
    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '삭제할 실패 메시지',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('consultation-delete-failed-message-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('삭제할 실패 메시지'), findsNothing);
  });

  testWidgets('stacks failed send actions on a narrow phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeConsultationRepository()
      ..sendErrors.add(Exception('network down'));
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '전송 실패 확인',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pumpAndSettle();

    final retryRect = tester.getRect(
      find.byKey(const ValueKey('consultation-retry-failed-message-button')),
    );
    final deleteRect = tester.getRect(
      find.byKey(const ValueKey('consultation-delete-failed-message-button')),
    );

    expect(retryRect.width, greaterThanOrEqualTo(240));
    expect(deleteRect.width, greaterThanOrEqualTo(240));
    expect(deleteRect.top, greaterThan(retryRect.bottom));
  });

  testWidgets('shows safety guidance and deletes sensitive history',
      (tester) async {
    final repository = _FakeConsultationRepository(
      sendResult: const ConsultationSendResult(
        accepted: false,
        safety: ConsultationSafetyResult(
          category: ConsultationRiskCategory.selfHarm,
          severity: ConsultationRiskSeverity.critical,
          actionPolicy: ConsultationActionPolicy.blockAndEscalate,
          message: '지금 안전이 가장 중요합니다. 119에 도움을 요청해 주세요.',
        ),
      ),
    );
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '죽고 싶어요',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('consultation-safety-notice')),
      findsOneWidget,
    );
    expect(find.text('즉시 도움 요청'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('consultation-emergency-109-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('consultation-emergency-119-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('consultation-emergency-1577-0199-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('consultation-emergency-112-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('consultation-emergency-1388-button')),
      findsOneWidget,
    );

    final messageField = tester.widget<TextField>(
      find.byKey(const ValueKey('consultation-message-field')),
    );
    expect(messageField.enabled, isFalse);
    expect(messageField.decoration?.helperText, isNull);
    expect(find.text('안전 안내 확인 후 다시 이용할 수 있습니다.'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('consultation-emergency-119-button')),
    );
    await tester.pump();

    expect(find.text('기기 전화 앱에서 119에 연락해 주세요.'), findsOneWidget);

    repository.recentMessagesAfterDelete = const [];
    await tester.tap(
      find.byKey(const ValueKey('consultation-delete-sensitive-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteSensitiveCount, 1);
    expect(
        find.byKey(const ValueKey('consultation-safety-notice')), findsNothing);
  });

  testWidgets('invokes crisis emergency dialer callback alongside notice',
      (tester) async {
    final dialedNumbers = <String>[];
    final repository = _FakeConsultationRepository(
      sendResult: const ConsultationSendResult(
        accepted: false,
        safety: ConsultationSafetyResult(
          category: ConsultationRiskCategory.selfHarm,
          severity: ConsultationRiskSeverity.critical,
          actionPolicy: ConsultationActionPolicy.blockAndEscalate,
          message: '즉시 1577-0199에 도움을 요청해 주세요.',
        ),
      ),
    );
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
          emergencyDialer: (number) async {
            dialedNumbers.add(number);
          },
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '위기 지원이 필요해요',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('consultation-emergency-1577-0199-button')),
    );
    await tester.pump();

    expect(dialedNumbers, ['1577-0199']);
    expect(find.text('기기 전화 앱에서 1577-0199에 연락해 주세요.'), findsOneWidget);
  });

  testWidgets('does not force-scroll when user scrolled up and offers jump pill',
      (tester) async {
    tester.view.physicalSize = const Size(390, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recent = List<ConsultationMessage>.generate(
      24,
      (index) => ConsultationMessage(
        id: 'm-$index',
        role: index.isEven
            ? ConsultationMessageRole.user
            : ConsultationMessageRole.assistant,
        content: '이전 대화 메시지 $index — 스크롤 테스트를 위해 충분한 높이의 문장을 적습니다.',
        createdAt: DateTime(2026, 5, 1, 10, index),
      ),
    );
    final repository = _FakeConsultationRepository()
      ..recentMessagesAfterDelete = recent;
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pumpAndSettle();

    final listFinder = find.byKey(const ValueKey('consultation-message-list'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: listFinder, matching: find.byType(Scrollable)),
    );
    final scrollPosition = scrollable.position;
    expect(scrollPosition.maxScrollExtent, greaterThan(0));

    // Scroll far up away from the bottom.
    scrollPosition.jumpTo(0);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('consultation-jump-to-bottom-button')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '새 질문',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.chat('답변 중입니다.'));
    await tester.pump();

    // Scroll must remain where the user left it.
    expect(scrollPosition.pixels, lessThan(scrollPosition.maxScrollExtent - 64));

    await tester.tap(
      find.byKey(const ValueKey('consultation-jump-to-bottom-button')),
    );
    await tester.pump();

    expect(scrollPosition.extentAfter, lessThanOrEqualTo(1));
  });

  testWidgets('supports stop generation, new session, and topic reopening',
      (tester) async {
    final stalledCompleter = Completer<ConsultationSendResult>();
    final repository = _FakeConsultationRepository()
      ..stallSendCompleter = stalledCompleter;
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ConsultationScreen(
          controller: controller,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '숨 고르기가 필요해요',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('consultation-stop-button')),
      findsOneWidget,
    );
    repository.emit(const ConsultationStreamEvent.chat('천천히 숨을 고르세요.'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('consultation-stop-button')));
    stalledCompleter.complete(const ConsultationSendResult(accepted: true));
    await tester.pump();

    expect(repository.stopGeneratingCount, 1);
    expect(
      find.byKey(const ValueKey('consultation-send-button')),
      findsOneWidget,
    );
    expect(find.text('천천히 숨을 고르세요.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('consultation-topics-button')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('consultation-topics-tray')),
      findsOneWidget,
    );

    await tester.tap(find.text('머릿속이 복잡해요'));
    await tester.pump();
    expect(controller.state.draft, '머릿속이 복잡해요');
    expect(
      find.byKey(const ValueKey('consultation-topics-tray')),
      findsNothing,
    );

    await tester
        .tap(find.byKey(const ValueKey('consultation-new-session-button')));
    await tester.pump();

    expect(repository.startNewSessionCount, 1);
    expect(find.byKey(const ValueKey('consultation-empty-state')),
        findsOneWidget);
    expect(find.text('오늘 마음을 나눠 볼까요'), findsOneWidget);
  });

  testWidgets('renders markdown bubble with >=48dp copy button and safe links',
      (tester) async {
    String? copiedText;
    final openedLinks = <Uri>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    const sampleMarkdown =
        '**핵심 정리**\n- [안전 안내](https://maum-on.app/help)\n- [차단 링크](javascript:alert(1))';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: CounselorMarkdownMessage(
                data: sampleMarkdown,
                copyButtonKey: const ValueKey('test-markdown-copy'),
                onLinkTap: (uri) async => openedLinks.add(uri),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copySize =
        tester.getSize(find.byKey(const ValueKey('test-markdown-copy')));
    expect(copySize.width, greaterThanOrEqualTo(48));
    expect(copySize.height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('차단 링크'));
    await tester.pump();
    expect(openedLinks, isEmpty);

    await tester.tap(find.text('안전 안내'));
    await tester.pump();
    expect(openedLinks, [Uri.parse('https://maum-on.app/help')]);

    await tester.tap(find.byKey(const ValueKey('test-markdown-copy')));
    await tester.pump();
    expect(copiedText, sampleMarkdown);
    expect(find.text('복사됨'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('jumping dots falls back cleanly when animations are disabled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: JumpingDotsIndicator(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(JumpingDotsIndicator), findsOneWidget);
  });

  testWidgets('breathing and sensory grounding sheet operates interactively',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeConsultationRepository();
    final controller = ConsultationController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2.0),
          ),
          child: ConsultationScreen(
            controller: controller,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    repository.emit(const ConsultationStreamEvent.connect('connected'));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('consultation-breathing-button')));
    await tester.pumpAndSettle();

    expect(find.byType(BreathingGroundingSheet), findsOneWidget);
    expect(find.text('4-4-4-4 박스 호흡'), findsOneWidget);
    expect(find.text('들숨'), findsOneWidget);
    expect(find.text('4초'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('breathing-toggle-button')));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('멈춤'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('breathing-reset-button')));
    await tester.pump();
    expect(find.text('들숨'), findsOneWidget);
    expect(find.text('4초'), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const ValueKey('grounding-step-5')));
    await tester.tap(find.byKey(const ValueKey('grounding-step-5')));
    await tester.pump();
    expect(find.text('1/5 확인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

SemanticsData? _findSemanticsWithLengthLimit(
  WidgetTester tester,
  int maxValueLength, {
  bool Function(SemanticsData data)? where,
}) {
  final roots = <SemanticsNode>[];
  void collectSemanticsRoots(PipelineOwner owner) {
    final root = owner.semanticsOwner?.rootSemanticsNode;
    if (root != null) {
      roots.add(root);
    }
    owner.visitChildren(collectSemanticsRoots);
  }

  collectSemanticsRoots(tester.binding.rootPipelineOwner);
  for (final root in roots) {
    final data = _findSemanticsData(root, maxValueLength, where: where);
    if (data != null) {
      return data;
    }
  }
  return null;
}

SemanticsData? _findSemanticsData(
  SemanticsNode node,
  int maxValueLength, {
  bool Function(SemanticsData data)? where,
}) {
  final data = node.getSemanticsData();
  if (data.maxValueLength == maxValueLength && (where?.call(data) ?? true)) {
    return data;
  }

  SemanticsData? result;
  node.visitChildren((child) {
    result ??= _findSemanticsData(child, maxValueLength, where: where);
    return result == null;
  });
  return result;
}

class _FakeConsultationRepository implements ConsultationRepository {
  _FakeConsultationRepository({
    this.sendResult = const ConsultationSendResult(accepted: true),
  });

  final ConsultationSendResult sendResult;
  final List<String> sentMessages = [];
  final List<Object> sendErrors = [];
  int connectCount = 0;
  int startNewSessionCount = 0;
  int stopGeneratingCount = 0;
  int deleteSensitiveCount = 0;
  Completer<ConsultationSendResult>? stallSendCompleter;
  List<ConsultationMessage>? recentMessagesAfterDelete;
  StreamController<ConsultationStreamEvent>? _controller;

  @override
  Stream<ConsultationStreamEvent> connect() {
    connectCount += 1;
    _controller = StreamController<ConsultationStreamEvent>(sync: true);
    return _controller!.stream;
  }

  @override
  Future<ConsultationSendResult> sendMessage(String message) async {
    sentMessages.add(message);
    if (sendErrors.isNotEmpty) {
      throw sendErrors.removeAt(0);
    }
    final stalledSend = stallSendCompleter;
    if (stalledSend != null) {
      return stalledSend.future;
    }
    return sendResult;
  }

  @override
  Future<List<ConsultationMessage>> loadRecentMessages() async {
    return recentMessagesAfterDelete ?? const [];
  }

  @override
  Future<int> startNewSession() async {
    startNewSessionCount += 1;
    return startNewSessionCount + 1;
  }

  @override
  Future<bool> stopGenerating() async {
    stopGeneratingCount += 1;
    emit(const ConsultationStreamEvent.done());
    return true;
  }

  @override
  Future<int> deleteSensitiveMessages() async {
    deleteSensitiveCount += 1;
    return 2;
  }

  void emit(ConsultationStreamEvent event) {
    _controller?.add(event);
  }

  void emitError(Object error) {
    _controller?.addError(error);
  }
}

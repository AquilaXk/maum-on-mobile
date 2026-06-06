import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/consultation/application/consultation_controller.dart';
import 'package:maum_on_mobile_front/features/consultation/data/consultation_repository.dart';
import 'package:maum_on_mobile_front/features/consultation/domain/consultation_models.dart';
import 'package:maum_on_mobile_front/features/consultation/presentation/consultation_screen.dart';

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
    expect(find.text('연결'), findsNothing);
    expect(find.text('입력'), findsNothing);
    expect(find.text('응답'), findsNothing);
    expect(find.text('상담 연결됨'), findsOneWidget);
    expect(find.text('메시지 1개'), findsOneWidget);
    expect(find.text('입력 가능'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('consultation-composer-section')),
      findsOneWidget,
    );
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
    expect(find.text('상담 연결됨'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('consultation-status-toolbar')),
      findsOneWidget,
    );
    expect(find.text('메시지 1개'), findsOneWidget);
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
    final streamingSendButtonRect = tester.getRect(
      find.byKey(const ValueKey('consultation-send-button')),
    );
    expect(
      (streamingSendButtonRect.center.dy - streamingFieldRect.center.dy).abs(),
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
      find.byKey(const ValueKey('consultation-emergency-119-button')),
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
  int deleteSensitiveCount = 0;
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
    return sendResult;
  }

  @override
  Future<List<ConsultationMessage>> loadRecentMessages() async {
    return recentMessagesAfterDelete ?? const [];
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

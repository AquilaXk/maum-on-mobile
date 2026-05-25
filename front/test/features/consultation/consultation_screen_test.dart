import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/consultation/application/consultation_controller.dart';
import 'package:maum_on_mobile_front/features/consultation/data/consultation_repository.dart';
import 'package:maum_on_mobile_front/features/consultation/domain/consultation_models.dart';
import 'package:maum_on_mobile_front/features/consultation/presentation/consultation_screen.dart';

void main() {
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

    await tester.enterText(
      find.byKey(const ValueKey('consultation-message-field')),
      '잠이 잘 오지 않아요',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consultation-send-button')));
    await tester.pump();
    repository
      ..emit(const ConsultationStreamEvent.chat('오늘은 '))
      ..emit(const ConsultationStreamEvent.chat('천천히 쉬어도 괜찮아요.'))
      ..emit(const ConsultationStreamEvent.done());
    await tester.pump();

    expect(repository.sentMessages, ['잠이 잘 오지 않아요']);
    expect(find.text('오늘은 천천히 쉬어도 괜찮아요.'), findsOneWidget);
  });

  testWidgets('shows reconnect action after a stream error', (tester) async {
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
    repository.emitError(Exception('closed'));
    await tester.pump();

    expect(find.text('연결 불안정'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('consultation-reconnect-button')));
    await tester.pump();

    expect(repository.connectCount, 2);
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

    expect(find.byKey(const ValueKey('consultation-safety-notice')), findsOneWidget);
    expect(find.text('즉시 도움 요청'), findsOneWidget);
    expect(find.text('119'), findsOneWidget);

    repository.recentMessagesAfterDelete = const [];
    await tester.tap(
      find.byKey(const ValueKey('consultation-delete-sensitive-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.deleteSensitiveCount, 1);
    expect(find.byKey(const ValueKey('consultation-safety-notice')), findsNothing);
  });
}

class _FakeConsultationRepository implements ConsultationRepository {
  _FakeConsultationRepository({
    this.sendResult = const ConsultationSendResult(accepted: true),
  });

  final ConsultationSendResult sendResult;
  final List<String> sentMessages = [];
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

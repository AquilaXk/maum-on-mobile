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
}

class _FakeConsultationRepository implements ConsultationRepository {
  final List<String> sentMessages = [];
  int connectCount = 0;
  StreamController<ConsultationStreamEvent>? _controller;

  @override
  Stream<ConsultationStreamEvent> connect() {
    connectCount += 1;
    _controller = StreamController<ConsultationStreamEvent>(sync: true);
    return _controller!.stream;
  }

  @override
  Future<void> sendMessage(String message) async {
    sentMessages.add(message);
  }

  @override
  Future<List<ConsultationMessage>> loadRecentMessages() async => const [];

  void emit(ConsultationStreamEvent event) {
    _controller?.add(event);
  }

  void emitError(Object error) {
    _controller?.addError(error);
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/features/consultation/application/consultation_controller.dart';
import 'package:maum_on_mobile_front/features/consultation/data/consultation_repository.dart';
import 'package:maum_on_mobile_front/features/consultation/domain/consultation_models.dart';

void main() {
  group('ConsultationController', () {
    test('sends a message and appends streamed assistant chunks', () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(repository: repository);

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('요즘 마음이 불안해요');
      await controller.submitMessage();
      repository
        ..emit(const ConsultationStreamEvent.chat('천천히 '))
        ..emit(const ConsultationStreamEvent.chat('호흡해 볼까요?'))
        ..emit(const ConsultationStreamEvent.done());

      expect(repository.sentMessages, ['요즘 마음이 불안해요']);
      expect(controller.state.connectionState,
          ConsultationConnectionState.connected);
      expect(controller.state.isStreaming, isFalse);
      expect(
        controller.state.messages.map((message) => message.role),
        containsAllInOrder([
          ConsultationMessageRole.user,
          ConsultationMessageRole.assistant,
        ]),
      );
      expect(controller.state.messages.last.content, '천천히 호흡해 볼까요?');
    });

    test('does not create duplicate stream connections', () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(repository: repository);

      await controller.connect();
      await controller.connect();

      expect(repository.connectCount, 1);
      expect(controller.state.connectionState,
          ConsultationConnectionState.connecting);
    });

    test('surfaces stream errors and reconnects on demand', () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(repository: repository);

      await controller.connect();
      repository.emitError(Exception('closed'));
      await Future<void>.delayed(Duration.zero);

      expect(
          controller.state.connectionState, ConsultationConnectionState.error);
      expect(
          controller.state.messages.last.role, ConsultationMessageRole.system);

      await controller.reconnect();

      expect(repository.connectCount, 2);
      expect(controller.state.connectionState,
          ConsultationConnectionState.connecting);
    });

    test('cleans up and restores stream around app lifecycle changes',
        () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(repository: repository);

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.handleLifecycleState(AppLifecycleState.paused);

      expect(repository.cancelCount, 1);
      expect(
          controller.state.connectionState, ConsultationConnectionState.idle);

      controller.handleLifecycleState(AppLifecycleState.resumed);

      expect(repository.connectCount, 2);
      expect(controller.state.connectionState,
          ConsultationConnectionState.connecting);
    });

    test('closes the active stream on demand', () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(repository: repository);

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.close();

      expect(repository.cancelCount, 1);
      expect(
          controller.state.connectionState, ConsultationConnectionState.idle);
      expect(controller.state.isStreaming, isFalse);
    });
  });
}

class _FakeConsultationRepository implements ConsultationRepository {
  final List<String> sentMessages = [];
  int connectCount = 0;
  int cancelCount = 0;
  StreamController<ConsultationStreamEvent>? _controller;

  @override
  Stream<ConsultationStreamEvent> connect() {
    connectCount += 1;
    _controller = StreamController<ConsultationStreamEvent>(
      sync: true,
      onCancel: () {
        cancelCount += 1;
      },
    );
    return _controller!.stream;
  }

  @override
  Future<void> sendMessage(String message) async {
    sentMessages.add(message);
  }

  void emit(ConsultationStreamEvent event) {
    _controller?.add(event);
  }

  void emitError(Object error) {
    _controller?.addError(error);
  }
}

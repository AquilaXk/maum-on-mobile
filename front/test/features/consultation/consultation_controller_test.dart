import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
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

    test('loads recent messages before opening a stream', () async {
      final repository = _FakeConsultationRepository(
        recentMessages: [
          ConsultationMessage(
            id: 'remote-1',
            role: ConsultationMessageRole.user,
            content: '어제 불안했어요',
            createdAt: DateTime.parse('2026-05-25T00:00:00Z'),
          ),
          ConsultationMessage(
            id: 'remote-2',
            role: ConsultationMessageRole.assistant,
            content: '그 마음을 같이 정리해 볼게요.',
            createdAt: DateTime.parse('2026-05-25T00:00:01Z'),
          ),
        ],
      );
      final controller = ConsultationController(repository: repository);

      await controller.connect();

      expect(repository.loadRecentCount, 1);
      expect(repository.connectCount, 1);
      expect(controller.state.messages.first.id, 'remote-1');
      expect(controller.state.messages.last.content, '그 마음을 같이 정리해 볼게요.');
    });

    test('chat error replaces the pending assistant message', () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(repository: repository);

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('응답 실패를 보여 주세요');
      await controller.submitMessage();
      repository.emit(
        const ConsultationStreamEvent.error(
          '지금은 답변을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.',
        ),
      );

      expect(controller.state.isStreaming, isFalse);
      expect(
        controller.state.messages.where(
          (message) =>
              message.role == ConsultationMessageRole.assistant &&
              message.content.isEmpty,
        ),
        isEmpty,
      );
      expect(controller.state.messages.last.role, ConsultationMessageRole.system);
      expect(
        controller.state.messages.last.content,
        '지금은 답변을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
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

    test('clears expired sessions when the stream rejects authorization',
        () async {
      final repository = _FakeConsultationRepository();
      var unauthorizedCount = 0;
      final controller = ConsultationController(
        repository: repository,
        onUnauthorized: () {
          unauthorizedCount += 1;
        },
      );

      await controller.connect();
      repository.emitError(
        const ApiClientException(
          kind: ApiErrorKind.unauthorized,
          message: '다시 로그인해 주세요.',
          statusCode: 401,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(unauthorizedCount, 1);
      expect(
          controller.state.connectionState, ConsultationConnectionState.error);
      expect(controller.state.errorMessage, '다시 로그인해 주세요.');
      expect(
          controller.state.messages.last.role, ConsultationMessageRole.system);
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
  _FakeConsultationRepository({
    this.recentMessages = const [],
  });

  final List<ConsultationMessage> recentMessages;
  final List<String> sentMessages = [];
  int connectCount = 0;
  int cancelCount = 0;
  int loadRecentCount = 0;
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

  @override
  Future<List<ConsultationMessage>> loadRecentMessages() async {
    loadRecentCount += 1;
    return recentMessages;
  }

  void emit(ConsultationStreamEvent event) {
    _controller?.add(event);
  }

  void emitError(Object error) {
    _controller?.addError(error);
  }
}

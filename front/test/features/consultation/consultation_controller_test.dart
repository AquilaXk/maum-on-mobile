import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/api_error.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/data/draft_recovery_repository.dart';
import 'package:maum_on_mobile_front/features/draft_recovery/domain/draft_recovery_models.dart';
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

    test('keeps streamed sentence chunks readable when they omit spacing',
        () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(repository: repository);

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('문장 사이 공백을 확인해 주세요');
      await controller.submitMessage();
      repository
        ..emit(
          const ConsultationStreamEvent.chat(
            '마음이 불안하다고 이야기해주셨네요.',
            requestId: 'reply-spacing',
            sequence: 0,
          ),
        )
        ..emit(
          const ConsultationStreamEvent.chat(
            '지금은 발바닥 감각을 천천히 느껴보면 좋아요.',
            requestId: 'reply-spacing',
            sequence: 1,
          ),
        )
        ..emit(
          const ConsultationStreamEvent.done(
            requestId: 'reply-spacing',
            sequence: 2,
          ),
        );

      expect(
        controller.state.messages.last.content,
        '마음이 불안하다고 이야기해주셨네요. 지금은 발바닥 감각을 천천히 느껴보면 좋아요.',
      );
    });

    test('keeps mid-word streamed chunks attached', () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(repository: repository);

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('단어 중간 조각을 확인해 주세요');
      await controller.submitMessage();
      repository
        ..emit(
          const ConsultationStreamEvent.chat(
            '불',
            requestId: 'reply-word',
            sequence: 0,
          ),
        )
        ..emit(
          const ConsultationStreamEvent.chat(
            '안한 마음',
            requestId: 'reply-word',
            sequence: 1,
          ),
        )
        ..emit(
          const ConsultationStreamEvent.done(
            requestId: 'reply-word',
            sequence: 2,
          ),
        );

      expect(controller.state.messages.last.content, '불안한 마음');
    });

    test('ignores duplicated streamed chunks with the same request sequence',
        () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(repository: repository);

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('중복 응답을 막아 주세요');
      await controller.submitMessage();
      repository
        ..emit(
          const ConsultationStreamEvent.chat(
            '천천히 ',
            requestId: 'reply-1',
            sequence: 0,
          ),
        )
        ..emit(
          const ConsultationStreamEvent.chat(
            '천천히 ',
            requestId: 'reply-1',
            sequence: 0,
          ),
        )
        ..emit(
          const ConsultationStreamEvent.chat(
            '호흡해 볼까요?',
            requestId: 'reply-1',
            sequence: 1,
          ),
        )
        ..emit(
          const ConsultationStreamEvent.done(
            requestId: 'reply-1',
            sequence: 2,
          ),
        )
        ..emit(
          const ConsultationStreamEvent.chat(
            '호흡해 볼까요?',
            requestId: 'reply-1',
            sequence: 1,
          ),
        );

      expect(controller.state.messages.last.content, '천천히 호흡해 볼까요?');
      expect(controller.state.isStreaming, isFalse);
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
      expect(
          controller.state.messages.last.role, ConsultationMessageRole.system);
      expect(
        controller.state.messages.last.content,
        '지금은 답변을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    });

    test('safety result replaces pending reply and can clear sensitive history',
        () async {
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

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('죽고 싶어요');
      await controller.submitMessage();

      expect(controller.state.isStreaming, isFalse);
      expect(controller.state.safetyNotice?.actionPolicy,
          ConsultationActionPolicy.blockAndEscalate);
      expect(
          controller.state.messages.last.role, ConsultationMessageRole.system);
      expect(controller.state.messages.last.content, contains('119'));

      repository.latestRecentMessages = [
        ConsultationMessage(
          id: 'remote-safe',
          role: ConsultationMessageRole.assistant,
          content: '다시 대화를 시작할 수 있어요.',
          createdAt: DateTime.parse('2026-05-25T00:00:02Z'),
        ),
      ];
      await controller.deleteSensitiveMessages();

      expect(repository.deleteSensitiveCount, 1);
      expect(controller.state.safetyNotice, isNull);
      expect(controller.state.messages.single.id, 'remote-safe');
    });

    test('blocks new input until sensitive safety history is cleared',
        () async {
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

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('죽고 싶어요');
      await controller.submitMessage();

      expect(controller.state.inputBlockedBySafety, isTrue);
      expect(controller.state.canSubmit, isFalse);

      controller.updateDraft('다시 보낼게요');
      await controller.submitMessage();

      expect(controller.state.draft, isEmpty);
      expect(controller.state.safetyNotice, isNotNull);
      expect(repository.sentMessages, ['죽고 싶어요']);
    });

    test('keeps reconnect errors behind an active safety notice', () async {
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
      final controller = ConsultationController(
        repository: repository,
        reconnectBackoffDelays: const [Duration.zero],
      );

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('죽고 싶어요');
      await controller.submitMessage();

      repository.emitError(Exception('closed'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.safetyNotice, isNotNull);
      expect(controller.state.errorMessage, isNull);
      expect(
        controller.state.messages
            .where((message) => message.content.contains('자동으로 다시 연결')),
        isEmpty,
      );
    });

    test('restores normal draft but clears blocked sensitive draft', () async {
      final draftRepository = StorageDraftRecoveryRepository(
        storage: MemoryDraftRecoveryStorage(),
      );
      final controller = ConsultationController(
        repository: _FakeConsultationRepository(),
        currentMemberId: 7,
        draftRepository: draftRepository,
      );

      controller.updateDraft('내일 상담에서 이어 말할 내용');
      await Future<void>.delayed(Duration.zero);

      final restoredController = ConsultationController(
        repository: _FakeConsultationRepository(),
        currentMemberId: 7,
        draftRepository: draftRepository,
      );
      await restoredController.restoreDraft();

      expect(restoredController.state.draft, '내일 상담에서 이어 말할 내용');

      final blockedRepository = _FakeConsultationRepository(
        sendResult: const ConsultationSendResult(
          accepted: false,
          safety: ConsultationSafetyResult(
            category: ConsultationRiskCategory.selfHarm,
            severity: ConsultationRiskSeverity.critical,
            actionPolicy: ConsultationActionPolicy.blockAndEscalate,
            message: '긴급 도움을 요청해 주세요.',
          ),
        ),
      );
      final blockedController = ConsultationController(
        repository: blockedRepository,
        currentMemberId: 7,
        draftRepository: draftRepository,
      );
      await blockedController.connect();
      blockedRepository
          .emit(const ConsultationStreamEvent.connect('connected'));
      blockedController.updateDraft('죽고 싶어요');
      await blockedController.submitMessage();

      expect(
        await draftRepository.read(
          const DraftKey(memberId: 7, surface: DraftSurface.consultation),
        ),
        isNull,
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
      final controller = ConsultationController(
        repository: repository,
        reconnectBackoffDelays: const [],
      );

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

    test('automatically reconnects with bounded backoff after stream errors',
        () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(
        repository: repository,
        reconnectBackoffDelays: const [Duration.zero, Duration.zero],
      );

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      repository.emitError(Exception('first close'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.connectCount, 2);
      expect(controller.state.connectionState,
          ConsultationConnectionState.connecting);
      expect(
        controller.state.messages
            .where((message) => message.content.contains('자동으로 다시 연결'))
            .length,
        1,
      );

      repository.emitError(Exception('second close'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.connectCount, 3);

      repository.emitError(Exception('third close'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.connectCount, 3);
      expect(
          controller.state.connectionState, ConsultationConnectionState.error);
      expect(
        controller.state.messages
            .where((message) => message.content.contains('자동으로 다시 연결'))
            .length,
        1,
      );
    });

    test('keeps heartbeat quiet and reconnects stream error events', () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(
        repository: repository,
        reconnectBackoffDelays: const [Duration.zero],
      );

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      repository.emit(const ConsultationStreamEvent.heartbeat('ping'));

      expect(
        controller.state.messages.where(
          (message) => message.content.contains('ping'),
        ),
        isEmpty,
      );

      repository.emit(
        const ConsultationStreamEvent.streamError('연결이 지연되고 있습니다.'),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.connectCount, 2);
      expect(controller.state.connectionState,
          ConsultationConnectionState.connecting);
    });

    test('stores failed sends for retry and deletion', () async {
      final repository = _FakeConsultationRepository()
        ..sendErrors.add(Exception('network down'));
      final draftRepository = StorageDraftRecoveryRepository(
        storage: MemoryDraftRecoveryStorage(),
      );
      final controller = ConsultationController(
        repository: repository,
        currentMemberId: 7,
        draftRepository: draftRepository,
      );

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('다시 보내고 싶은 말');
      await controller.submitMessage();

      expect(controller.state.failedMessage?.content, '다시 보내고 싶은 말');
      final failedDraft = await draftRepository.read(
        const DraftKey(memberId: 7, surface: DraftSurface.consultation),
      );
      expect(failedDraft?.isFailed, isTrue);

      await controller.retryFailedMessage();

      expect(repository.sentMessages, ['다시 보내고 싶은 말', '다시 보내고 싶은 말']);
      expect(controller.state.failedMessage, isNull);
      expect(
        await draftRepository.read(
          const DraftKey(memberId: 7, surface: DraftSurface.consultation),
        ),
        isNull,
      );

      repository.sendErrors.add(Exception('network down'));
      controller.updateDraft('삭제할 실패 메시지');
      await controller.submitMessage();

      await controller.deleteFailedMessage();

      expect(controller.state.failedMessage, isNull);
      expect(
        controller.state.messages
            .where((message) => message.content.contains('삭제할 실패 메시지')),
        isEmpty,
      );
    });

    test('times out stalled sends and restores input availability', () async {
      final repository = _FakeConsultationRepository()
        ..stallSendCompleter = Completer<ConsultationSendResult>();
      final controller = ConsultationController(
        repository: repository,
        sendTimeout: Duration.zero,
      );

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('응답 완료 처리가 멈추면 안 돼요');
      await controller.submitMessage();

      expect(controller.state.isSending, isFalse);
      expect(controller.state.isStreaming, isFalse);
      expect(controller.state.failedMessage?.content, '응답 완료 처리가 멈추면 안 돼요');
      expect(controller.state.canSubmit, isFalse);
      expect(
        controller.state.messages.last.content,
        contains('전송 실패'),
      );
    });

    test('stops waiting when send result is not accepted', () async {
      final repository = _FakeConsultationRepository(
        sendResult: const ConsultationSendResult(accepted: false),
      );
      final controller = ConsultationController(repository: repository);

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('서버가 수락하지 않은 메시지');
      await controller.submitMessage();

      expect(repository.sentMessages, ['서버가 수락하지 않은 메시지']);
      expect(controller.state.isSending, isFalse);
      expect(controller.state.isStreaming, isFalse);
      expect(controller.state.failedMessage?.content, '서버가 수락하지 않은 메시지');
      expect(
        controller.state.messages.last.content,
        contains('전송 실패'),
      );
    });

    test('times out stalled response streams after send succeeds', () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(
        repository: repository,
        responseTimeout: Duration.zero,
        reconnectBackoffDelays: const [],
      );

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('응답 스트림이 멈추면 복구해 주세요');
      await controller.submitMessage();

      expect(repository.sentMessages, ['응답 스트림이 멈추면 복구해 주세요']);
      expect(controller.state.isSending, isFalse);
      expect(controller.state.isStreaming, isFalse);
      expect(controller.state.failedMessage, isNull);
      expect(controller.state.canSubmit, isFalse);
      expect(repository.cancelCount, 1);
      expect(
        controller.state.messages.last.content,
        contains('AI 상담 응답이 지연되고 있습니다'),
      );
    });

    test('응답 지연 후 재연결하면 서버 상담 답변을 다시 불러온다', () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(
        repository: repository,
        responseTimeout: Duration.zero,
        reconnectBackoffDelays: const [Duration.zero],
      );

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('서버 답변이 늦게 저장될 수 있어요');
      await controller.submitMessage();
      repository.latestRecentMessages = [
        ConsultationMessage(
          id: 'remote-user-late',
          role: ConsultationMessageRole.user,
          content: '서버 답변이 늦게 저장될 수 있어요',
          createdAt: DateTime.parse('2026-05-25T00:00:00Z'),
        ),
        ConsultationMessage(
          id: 'remote-assistant-late',
          role: ConsultationMessageRole.assistant,
          content: '늦게 저장된 답변을 다시 보여드릴게요.',
          createdAt: DateTime.parse('2026-05-25T00:00:01Z'),
        ),
      ];

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.connectCount, 2);
      expect(repository.loadRecentCount, 2);
      expect(controller.state.messages.last.id, 'remote-assistant-late');
      expect(controller.state.messages.last.content, '늦게 저장된 답변을 다시 보여드릴게요.');
      expect(controller.state.isStreaming, isFalse);
      expect(controller.state.connectionState,
          ConsultationConnectionState.connecting);
    });

    test('응답 타임아웃 뒤 늦은 스트림 조각은 새 답변으로 붙이지 않는다', () async {
      final repository = _FakeConsultationRepository();
      final controller = ConsultationController(
        repository: repository,
        responseTimeout: Duration.zero,
        reconnectBackoffDelays: const [Duration.zero],
      );

      await controller.connect();
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('늦은 응답은 새 답변으로 붙으면 안 돼요');
      await controller.submitMessage();

      repository
        ..emitAt(0, const ConsultationStreamEvent.chat('늦게 도착한 답변'))
        ..emitAt(0, const ConsultationStreamEvent.done());

      await Future<void>.delayed(Duration.zero);
      repository.emit(const ConsultationStreamEvent.connect('connected'));
      controller.updateDraft('다음 메시지');

      expect(
        controller.state.messages
            .where((message) => message.content.contains('늦게 도착한 답변')),
        isEmpty,
      );
      expect(repository.cancelCount, 1);
      expect(repository.connectCount, 2);
      expect(repository.loadRecentCount, 2);
      expect(controller.state.isStreaming, isFalse);
      expect(controller.state.canSubmit, isTrue);
    });

    test('clears expired sessions when the stream rejects authorization',
        () async {
      final repository = _FakeConsultationRepository();
      var unauthorizedCount = 0;
      final controller = ConsultationController(
        repository: repository,
        reconnectBackoffDelays: const [Duration.zero],
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
      expect(repository.connectCount, 1);
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
    this.sendResult = const ConsultationSendResult(accepted: true),
  });

  final List<ConsultationMessage> recentMessages;
  final ConsultationSendResult sendResult;
  final List<String> sentMessages = [];
  final List<Object> sendErrors = [];
  Completer<ConsultationSendResult>? stallSendCompleter;
  int connectCount = 0;
  int cancelCount = 0;
  int loadRecentCount = 0;
  int deleteSensitiveCount = 0;
  List<ConsultationMessage>? latestRecentMessages;
  final List<StreamController<ConsultationStreamEvent>> streamControllers = [];
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
    streamControllers.add(_controller!);
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
    loadRecentCount += 1;
    return latestRecentMessages ?? recentMessages;
  }

  @override
  Future<int> deleteSensitiveMessages() async {
    deleteSensitiveCount += 1;
    return 2;
  }

  void emit(ConsultationStreamEvent event) {
    _controller?.add(event);
  }

  void emitAt(int index, ConsultationStreamEvent event) {
    streamControllers[index].add(event);
  }

  void emitError(Object error) {
    _controller?.addError(error);
  }
}

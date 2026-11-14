import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/network/sse_event_parser.dart';
import 'package:maum_on_mobile_front/features/consultation/domain/consultation_models.dart';

void main() {
  group('SseEventParser', () {
    test('parses split stream chunks and multiline data', () async {
      final events = await const SseEventParser()
          .parse(
            Stream<List<int>>.fromIterable([
              utf8.encode('event: chat\ndata: 천천히\n'),
              utf8.encode('data: 쉬어도 괜찮아요.\n\n'),
            ]),
          )
          .toList();

      expect(events, hasLength(1));
      expect(events.single.event, 'chat');
      expect(events.single.data, '천천히\n쉬어도 괜찮아요.');
    });

    test('ignores comments and flushes a trailing event', () async {
      final events = await const SseEventParser()
          .parse(
            Stream<List<int>>.value(
              utf8.encode(': ping\nevent: chat_error\ndata: 연결이 끊겼습니다.'),
            ),
          )
          .toList();

      expect(events, hasLength(1));
      expect(events.single.event, 'chat_error');
      expect(events.single.data, '연결이 끊겼습니다.');
    });

    test('maps consultation heartbeat and stream error events', () async {
      final events = await const SseEventParser()
          .parse(
            Stream<List<int>>.value(
              utf8.encode(
                'event: heartbeat\ndata: ping\n\n'
                'event: stream_error\ndata: 연결이 지연되고 있습니다.\n\n',
              ),
            ),
          )
          .map(
            (event) => ConsultationStreamEvent.fromSse(
              event: event.event,
              data: event.data,
            ),
          )
          .toList();

      expect(events.first.type, ConsultationStreamEventType.heartbeat);
      expect(events.last.type, ConsultationStreamEventType.streamError);
      expect(events.last.data, '연결이 지연되고 있습니다.');
    });

    test('unwraps consultation JSON stream payloads for display', () async {
      final events = await const SseEventParser()
          .parse(
            Stream<List<int>>.value(
              utf8.encode(
                'event: chat\n'
                'data: {"requestId":"r1","sequence":0,"chunk":"함께 "}\n\n'
                'event: chat_done\n'
                'data: {"requestId":"r1","sequence":1,"done":true}\n\n'
                'event: chat_error\n'
                'data: {"requestId":"r2","sequence":0,"message":"다시 시도해 주세요."}\n\n'
                'event: stream_error\n'
                'data: {"retryable":true,"message":"재연결 중입니다."}\n\n',
              ),
            ),
          )
          .map(
            (event) => ConsultationStreamEvent.fromSse(
              event: event.event,
              data: event.data,
            ),
          )
          .toList();

      expect(events[0].type, ConsultationStreamEventType.chat);
      expect(events[0].data, '함께 ');
      expect(events[0].requestId, 'r1');
      expect(events[0].sequence, 0);
      expect(events[1].type, ConsultationStreamEventType.done);
      expect(events[1].requestId, 'r1');
      expect(events[1].sequence, 1);
      expect(events[2].type, ConsultationStreamEventType.error);
      expect(events[2].data, '다시 시도해 주세요.');
      expect(events[2].requestId, 'r2');
      expect(events[2].sequence, 0);
      expect(events[3].type, ConsultationStreamEventType.streamError);
      expect(events[3].data, '재연결 중입니다.');
    });

    test('parses split CRLF and multibyte UTF-8 characters across chunk slices',
        () async {
      final events = await const SseEventParser()
          .parse(
            Stream<List<int>>.fromIterable([
              utf8.encode('event: chat\r'),
              utf8.encode('\ndata: 안녕'),
              utf8.encode('하세요\r\n\r\n'),
            ]),
          )
          .toList();

      expect(events, hasLength(1));
      expect(events.single.event, 'chat');
      expect(events.single.data, '안녕하세요');
    });

    test('fails closed with FormatException when unterminated line exceeds cap',
        () async {
      const parser = SseEventParser(maxBufferBytes: 64);
      final oversized = Stream<List<int>>.value(
        List<int>.filled(65, 0x61), // 65 bytes of 'a' without newline
      );

      await expectLater(
        parser.parse(oversized).toList(),
        throwsFormatException,
      );
    });

    test('fails closed when cumulative event lines exceed maxBufferBytes',
        () async {
      const parser = SseEventParser(maxBufferBytes: 64);
      final multiLineNoBoundary = Stream<List<int>>.fromIterable([
        utf8.encode('data: ${'a' * 30}\n'),
        utf8.encode('data: ${'b' * 40}\n'),
      ]);

      await expectLater(
        parser.parse(multiLineNoBoundary).toList(),
        throwsFormatException,
      );
    });

    test('strips trailing CR at EOF when stream ends without final newline',
        () async {
      const parser = SseEventParser();
      final crWithoutLf = Stream<List<int>>.fromIterable([
        utf8.encode('data: hello\r'),
      ]);

      final events = await parser.parse(crWithoutLf).toList();
      expect(events, hasLength(1));
      expect(events.single.data, 'hello');
    });
  });
}

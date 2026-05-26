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
  });
}

import 'dart:async';
import 'dart:convert';

class SseEvent {
  const SseEvent({
    required this.event,
    required this.data,
  });

  final String event;
  final String data;
}

class SseEventParser {
  const SseEventParser();

  Stream<SseEvent> parse(Stream<List<int>> byteStream) async* {
    final builder = _SseEventBuilder();
    var pending = '';

    await for (final chunk in byteStream.transform(utf8.decoder)) {
      pending += chunk;

      while (true) {
        final lineBreakIndex = pending.indexOf('\n');
        if (lineBreakIndex == -1) {
          break;
        }

        var line = pending.substring(0, lineBreakIndex);
        pending = pending.substring(lineBreakIndex + 1);
        if (line.endsWith('\r')) {
          line = line.substring(0, line.length - 1);
        }

        final event = builder.consume(line);
        if (event != null) {
          yield event;
        }
      }
    }

    if (pending.isNotEmpty) {
      final event = builder.consume(pending);
      if (event != null) {
        yield event;
      }
    }

    final event = builder.flush();
    if (event != null) {
      yield event;
    }
  }
}

class _SseEventBuilder {
  String _eventName = 'message';
  final List<String> _dataLines = [];

  SseEvent? consume(String line) {
    if (line.isEmpty) {
      return flush();
    }

    if (line.startsWith(':')) {
      return null;
    }

    final separatorIndex = line.indexOf(':');
    final field =
        separatorIndex == -1 ? line : line.substring(0, separatorIndex);
    var value = separatorIndex == -1 ? '' : line.substring(separatorIndex + 1);
    if (value.startsWith(' ')) {
      value = value.substring(1);
    }

    if (field == 'event') {
      _eventName = value;
    } else if (field == 'data') {
      _dataLines.add(value);
    }

    return null;
  }

  SseEvent? flush() {
    if (_dataLines.isEmpty) {
      _eventName = 'message';
      return null;
    }

    final event = SseEvent(
      event: _eventName,
      data: _dataLines.join('\n'),
    );
    _eventName = 'message';
    _dataLines.clear();
    return event;
  }
}

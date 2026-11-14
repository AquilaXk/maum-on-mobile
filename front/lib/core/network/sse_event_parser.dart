import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

class SseEvent {
  const SseEvent({
    required this.event,
    required this.data,
  });

  final String event;
  final String data;
}

class SseEventParser {
  const SseEventParser({
    this.maxBufferBytes = defaultMaxBufferBytes,
  }) : assert(maxBufferBytes > 0);

  static const int defaultMaxBufferBytes = 256 * 1024;

  final int maxBufferBytes;

  Stream<SseEvent> parse(Stream<List<int>> byteStream) async* {
    final builder = _SseEventBuilder(maxBufferBytes: maxBufferBytes);
    final pendingBytes = BytesBuilder(copy: false);

    await for (final chunk in byteStream) {
      if (chunk.isEmpty) {
        continue;
      }

      var cursor = 0;
      while (cursor < chunk.length) {
        final nlIndex = _indexOfByte(chunk, 0x0A, cursor);
        if (nlIndex == -1) {
          final tailLength = chunk.length - cursor;
          final nextLineBytes = pendingBytes.length + tailLength;
          _checkBufferLimit(nextLineBytes, builder.bufferedBytes);
          pendingBytes.add(
            cursor == 0 ? chunk : Uint8List.sublistView(
              chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
              cursor,
            ),
          );
          break;
        }

        if (pendingBytes.isNotEmpty) {
          final segmentLength = nlIndex - cursor;
          _checkBufferLimit(
            pendingBytes.length + segmentLength,
            builder.bufferedBytes,
          );
          if (segmentLength > 0) {
            pendingBytes.add(
              cursor == 0 && nlIndex == chunk.length
                  ? chunk
                  : _sliceBytes(chunk, cursor, nlIndex),
            );
          }
          final combined = pendingBytes.takeBytes();
          var lineEnd = combined.length;
          if (lineEnd > 0 && combined[lineEnd - 1] == 0x0D) {
            lineEnd -= 1;
          }
          final line = lineEnd == 0
              ? ''
              : utf8.decoder.convert(combined, 0, lineEnd);
          final event = builder.consume(line, combined.length);
          if (event != null) {
            yield event;
          }
        } else {
          var lineEnd = nlIndex;
          if (lineEnd > cursor && chunk[lineEnd - 1] == 0x0D) {
            lineEnd -= 1;
          }
          final rawLineLength = nlIndex - cursor;
          _checkBufferLimit(rawLineLength, builder.bufferedBytes);
          final line = lineEnd <= cursor
              ? ''
              : utf8.decoder.convert(chunk, cursor, lineEnd);
          final event = builder.consume(line, rawLineLength);
          if (event != null) {
            yield event;
          }
        }

        cursor = nlIndex + 1;
      }
    }

    if (pendingBytes.isNotEmpty) {
      final combined = pendingBytes.takeBytes();
      _checkBufferLimit(combined.length, builder.bufferedBytes);
      var lineEnd = combined.length;
      if (lineEnd > 0 && combined[lineEnd - 1] == 0x0D) {
        lineEnd -= 1;
      }
      final line = lineEnd == 0 ? '' : utf8.decoder.convert(combined, 0, lineEnd);
      final event = builder.consume(line, combined.length);
      if (event != null) {
        yield event;
      }
    }

    final event = builder.flush();
    if (event != null) {
      yield event;
    }
  }

  void _checkBufferLimit(int pendingLineBytes, int eventBufferedBytes) {
    if (pendingLineBytes > maxBufferBytes ||
        eventBufferedBytes + pendingLineBytes > maxBufferBytes) {
      throw FormatException(
        'SSE buffer limit exceeded: max $maxBufferBytes bytes.',
      );
    }
  }
}

int _indexOfByte(List<int> bytes, int target, int start) {
  for (var index = start; index < bytes.length; index += 1) {
    if (bytes[index] == target) {
      return index;
    }
  }
  return -1;
}

List<int> _sliceBytes(List<int> bytes, int start, int end) {
  if (bytes is Uint8List) {
    return Uint8List.sublistView(bytes, start, end);
  }
  return bytes.sublist(start, end);
}

class _SseEventBuilder {
  _SseEventBuilder({required this.maxBufferBytes});

  final int maxBufferBytes;
  String _eventName = 'message';
  final List<String> _dataLines = [];
  int _bufferedBytes = 0;

  int get bufferedBytes => _bufferedBytes;

  SseEvent? consume(String line, int rawLineBytes) {
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
      _trackBytes(rawLineBytes + 1);
    } else if (field == 'data') {
      _trackBytes(rawLineBytes + 1);
      _dataLines.add(value);
    }

    return null;
  }

  void _trackBytes(int delta) {
    _bufferedBytes += delta;
    if (_bufferedBytes > maxBufferBytes) {
      throw FormatException(
        'SSE event buffer limit exceeded: max $maxBufferBytes bytes.',
      );
    }
  }

  SseEvent? flush() {
    _bufferedBytes = 0;
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

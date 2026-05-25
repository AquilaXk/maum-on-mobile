import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../domain/diary_models.dart';

enum DiaryImagePickStatus {
  picked,
  cancelled,
  permissionDenied,
  tooLarge,
  unsupportedFormat,
  unavailable,
  error,
}

class DiaryImagePickResult {
  const DiaryImagePickResult._({
    required this.status,
    this.attachment,
    this.message,
    this.canOpenSettings = false,
  });

  const DiaryImagePickResult.picked(DiaryImageAttachment? attachment)
      : this._(
          status: DiaryImagePickStatus.picked,
          attachment: attachment,
        );

  const DiaryImagePickResult.cancelled()
      : this._(status: DiaryImagePickStatus.cancelled);

  const DiaryImagePickResult.permissionDenied({
    required String message,
    bool canOpenSettings = false,
  }) : this._(
          status: DiaryImagePickStatus.permissionDenied,
          message: message,
          canOpenSettings: canOpenSettings,
        );

  const DiaryImagePickResult.tooLarge(String message)
      : this._(status: DiaryImagePickStatus.tooLarge, message: message);

  const DiaryImagePickResult.unsupportedFormat(String message)
      : this._(
          status: DiaryImagePickStatus.unsupportedFormat,
          message: message,
        );

  const DiaryImagePickResult.unavailable(String message)
      : this._(status: DiaryImagePickStatus.unavailable, message: message);

  const DiaryImagePickResult.error(String message)
      : this._(status: DiaryImagePickStatus.error, message: message);

  final DiaryImagePickStatus status;
  final DiaryImageAttachment? attachment;
  final String? message;
  final bool canOpenSettings;
}

abstract interface class DiaryImagePicker {
  Future<DiaryImagePickResult> pickImage(DiaryImageSource source);

  Future<bool> openSettings();
}

class PlatformDiaryImagePicker implements DiaryImagePicker {
  const PlatformDiaryImagePicker({
    MethodChannel channel = _channel,
    DiaryImageProcessor processor = const DiaryImageProcessor(),
  })  : _channel = channel,
        _processor = processor;

  static const MethodChannel _channel =
      MethodChannel('maum_on_mobile/diary_images');

  final MethodChannel _channel;
  final DiaryImageProcessor _processor;

  @override
  Future<DiaryImagePickResult> pickImage(DiaryImageSource source) async {
    final payload = await _channel.invokeMapMethod<String, Object?>(
      'pickDiaryImage',
      {'source': source.name},
    );
    if (payload == null) {
      return const DiaryImagePickResult.cancelled();
    }

    final status = payload['status']?.toString();
    final message = payload['message']?.toString();
    switch (status) {
      case 'picked':
        final bytes = payload['bytes'];
        if (bytes is! Uint8List || bytes.isEmpty) {
          return const DiaryImagePickResult.error('이미지를 읽지 못했습니다.');
        }
        return _processor.process(
          source: source,
          filename: payload['filename']?.toString() ?? _fallbackFilename(source),
          bytes: bytes,
          contentType: payload['contentType']?.toString(),
        );
      case 'cancelled':
        return const DiaryImagePickResult.cancelled();
      case 'permissionDenied':
        return DiaryImagePickResult.permissionDenied(
          message: message ?? '${source.label} 권한이 허용되지 않았습니다.',
          canOpenSettings: payload['canOpenSettings'] == true,
        );
      case 'unsupported':
        return DiaryImagePickResult.unavailable(
          message ?? '${source.label}을 사용할 수 없습니다.',
        );
      default:
        return DiaryImagePickResult.error(
          message ?? '이미지를 선택하지 못했습니다.',
        );
    }
  }

  @override
  Future<bool> openSettings() async {
    return await _channel.invokeMethod<bool>('openSettings') ?? false;
  }
}

class DiaryImageProcessor {
  const DiaryImageProcessor({
    this.maxOriginalBytes = 12 * 1024 * 1024,
    this.maxUploadBytes = 4 * 1024 * 1024,
    this.maxEdgePixels = 1600,
  });

  final int maxOriginalBytes;
  final int maxUploadBytes;
  final int maxEdgePixels;

  Future<DiaryImagePickResult> process({
    required DiaryImageSource source,
    required String filename,
    required List<int> bytes,
    String? contentType,
  }) async {
    final normalizedFilename = filename.trim().isEmpty
        ? _fallbackFilename(source)
        : filename.trim();
    final normalizedType = _contentTypeFrom(
      filename: normalizedFilename,
      contentType: contentType,
    );
    if (normalizedType == null) {
      return const DiaryImagePickResult.unsupportedFormat(
        '지원하지 않는 이미지 형식입니다. JPG, PNG, WEBP 이미지만 첨부할 수 있습니다.',
      );
    }

    if (bytes.length > maxOriginalBytes) {
      return DiaryImagePickResult.tooLarge(
        '이미지 용량이 너무 큽니다. ${_formatBytes(maxOriginalBytes)} 이하 이미지를 선택해 주세요.',
      );
    }

    if (bytes.length <= maxUploadBytes) {
      return DiaryImagePickResult.picked(
        DiaryImageAttachment(
          filename: normalizedFilename,
          bytes: List<int>.unmodifiable(bytes),
          source: source,
          contentType: normalizedType,
          originalByteSize: bytes.length,
        ),
      );
    }

    final compressed = await _resizeAsPng(bytes);
    if (compressed == null || compressed.bytes.length > maxUploadBytes) {
      return DiaryImagePickResult.tooLarge(
        '이미지 용량을 줄이지 못했습니다. ${_formatBytes(maxUploadBytes)} 이하 이미지를 선택해 주세요.',
      );
    }

    return DiaryImagePickResult.picked(
      DiaryImageAttachment(
        filename: _replaceExtension(normalizedFilename, 'png'),
        bytes: compressed.bytes,
        source: source,
        contentType: 'image/png',
        originalByteSize: bytes.length,
        width: compressed.width,
        height: compressed.height,
        wasCompressed: true,
      ),
    );
  }

  Future<_ProcessedImage?> _resizeAsPng(List<int> bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final longestEdge = image.width > image.height ? image.width : image.height;
      final scale = longestEdge > maxEdgePixels ? maxEdgePixels / longestEdge : 1.0;
      final targetWidth =
          (image.width * scale).round().clamp(1, image.width).toInt();
      final targetHeight =
          (image.height * scale).round().clamp(1, image.height).toInt();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final resized = await picture.toImage(targetWidth, targetHeight);
      final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      resized.dispose();
      if (byteData == null) {
        return null;
      }
      return _ProcessedImage(
        bytes: byteData.buffer.asUint8List().toList(growable: false),
        width: targetWidth,
        height: targetHeight,
      );
    } on Object {
      return null;
    }
  }
}

class _ProcessedImage {
  const _ProcessedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final List<int> bytes;
  final int width;
  final int height;
}

String? _contentTypeFrom({required String filename, String? contentType}) {
  final normalized = contentType?.trim().toLowerCase();
  if (_allowedContentTypes.contains(normalized)) {
    return normalized;
  }

  final extension = filename.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => null,
  };
}

String _fallbackFilename(DiaryImageSource source) {
  return 'diary-${source.name}-${DateTime.now().millisecondsSinceEpoch}.jpg';
}

String _replaceExtension(String filename, String extension) {
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex <= 0) {
    return '$filename.$extension';
  }
  return '${filename.substring(0, dotIndex)}.$extension';
}

String _formatBytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)}MB';
}

const Set<String> _allowedContentTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
};

import 'dart:async';

import 'package:flutter/services.dart';

import '../../features/auth/deeplink/external_login.dart';

const String deepLinksChannelName = 'maum_on_mobile/deep_links';

class MethodChannelDeepLinkSource implements ExternalLoginDeepLinkSource {
  MethodChannelDeepLinkSource({
    MethodChannel channel = defaultChannel,
  }) : _channel = channel {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const MethodChannel defaultChannel =
      MethodChannel(deepLinksChannelName);

  final MethodChannel _channel;
  final StreamController<Uri> _uriController =
      StreamController<Uri>.broadcast();
  bool _disposed = false;

  @override
  Future<Uri?> getInitialUri() async {
    try {
      final raw = await _channel.invokeMethod<String>('getInitialLink');
      if (raw == null) {
        return null;
      }
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return Uri.tryParse(trimmed);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Stream<Uri> get uriStream => _uriController.stream;

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onDeepLink' || _disposed) {
      return;
    }

    final raw = call.arguments?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(raw);
    if (uri != null && !_uriController.isClosed) {
      _uriController.add(uri);
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _channel.setMethodCallHandler(null);
    unawaited(_uriController.close());
  }
}

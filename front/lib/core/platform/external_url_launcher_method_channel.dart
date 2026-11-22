import 'package:flutter/services.dart';

import 'external_url_launcher_policy.dart';

const String urlLauncherChannelName = 'maum_on_mobile/external_url';

class MethodChannelExternalUrlLauncher {
  const MethodChannelExternalUrlLauncher({
    MethodChannel channel = defaultChannel,
  }) : _channel = channel;

  static const MethodChannel defaultChannel =
      MethodChannel(urlLauncherChannelName);

  final MethodChannel _channel;

  Future<bool> launch(Uri uri) async {
    if (!isAllowedExternalUri(uri)) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>(
            'launchUrl',
            <String, Object?>{'url': uri.toString()},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

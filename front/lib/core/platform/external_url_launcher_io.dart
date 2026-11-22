import 'external_url_launcher_method_channel.dart';

const MethodChannelExternalUrlLauncher _defaultLauncher =
    MethodChannelExternalUrlLauncher();

Future<bool> launchPlatformExternalUri(Uri uri) {
  return _defaultLauncher.launch(uri);
}

import 'external_url_launcher_stub.dart'
    if (dart.library.io) 'external_url_launcher_io.dart'
    if (dart.library.js_interop) 'external_url_launcher_web.dart' as impl;

export 'external_url_launcher_method_channel.dart'
    show MethodChannelExternalUrlLauncher, urlLauncherChannelName;
export 'external_url_launcher_policy.dart' show isAllowedExternalUri;

Future<bool> launchExternalUri(Uri uri) {
  return impl.launchPlatformExternalUri(uri);
}

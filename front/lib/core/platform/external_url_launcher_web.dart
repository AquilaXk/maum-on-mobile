import 'dart:js_interop';

import 'external_url_launcher_policy.dart';

Future<bool> launchPlatformExternalUri(Uri uri) async {
  if (!isAllowedExternalUri(uri)) {
    return false;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'tel' || scheme == 'mailto') {
    _windowOpen(uri.toString().toJS, '_self'.toJS);
    return true;
  }

  _windowOpen(
    uri.toString().toJS,
    '_blank'.toJS,
    'noopener,noreferrer'.toJS,
  );
  return true;
}

@JS('window.open')
external JSObject? _windowOpen(
  JSString url,
  JSString target, [
  JSString? features,
]);

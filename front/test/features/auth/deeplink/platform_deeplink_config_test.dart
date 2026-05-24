import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest registers the external login callback scheme', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('flutter_deeplinking_enabled'));
    expect(manifest, contains('android:scheme="maumon"'));
    expect(manifest, contains('android:host="auth"'));
    expect(manifest, contains('android:path="/callback"'));
  });

  test('iOS Info.plist registers the external login callback scheme', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<key>FlutterDeepLinkingEnabled</key>'));
    expect(plist, contains('<false/>'));
    expect(plist, contains('<key>CFBundleURLSchemes</key>'));
    expect(plist, contains('<string>maumon</string>'));
  });
}

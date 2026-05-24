import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest registers the external login callback scheme', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final debugManifest = File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('flutter_deeplinking_enabled'));
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.READ_MEDIA_IMAGES'));
    expect(manifest, contains('android.permission.READ_EXTERNAL_STORAGE'));
    expect(manifest, isNot(contains('android:usesCleartextTraffic="true"')));
    expect(debugManifest, contains('android:usesCleartextTraffic="true"'));
    expect(manifest, contains('android:scheme="maumon"'));
    expect(manifest, contains('android:host="auth"'));
    expect(manifest, contains('android:path="/callback"'));
    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:scheme="http"'));
  });

  test('iOS Info.plist registers the external login callback scheme', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<key>FlutterDeepLinkingEnabled</key>'));
    expect(plist, contains('<false/>'));
    expect(plist, contains('<key>CFBundleURLSchemes</key>'));
    expect(plist, contains('<string>maumon</string>'));
    expect(plist, contains('<key>LSApplicationQueriesSchemes</key>'));
    expect(plist, contains('<string>https</string>'));
    expect(plist, contains('<string>http</string>'));
    expect(plist, contains('<key>NSAppTransportSecurity</key>'));
    expect(
      plist,
      matches(RegExp(r'<key>NSAllowsLocalNetworking</key>\s*<true/>')),
    );
    expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
  });
}

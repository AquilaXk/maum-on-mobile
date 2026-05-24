import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

const root = process.cwd();

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function firstExisting(relativePaths) {
  const existingPath = relativePaths.find((relativePath) => existsSync(path.join(root, relativePath)));

  assert.ok(existingPath, `Expected one of these files to exist: ${relativePaths.join(", ")}`);

  return existingPath;
}

test("front uses a Flutter Android/iOS app scaffold", () => {
  const requiredFiles = [
    "front/pubspec.yaml",
    "front/pubspec.lock",
    "front/.gitignore",
    "front/.metadata",
    "front/analysis_options.yaml",
    "front/lib/main.dart",
    "front/lib/app/maum_on_mobile_app.dart",
    "front/lib/app/supported_platforms.dart",
    "front/lib/features/home/home_screen.dart",
    "front/test/widget_test.dart",
    "front/android/app/src/main/AndroidManifest.xml",
    "front/android/app/src/main/kotlin/com/aquilaxk/maumonmobile/MainActivity.kt",
    "front/android/gradle/wrapper/gradle-wrapper.properties",
    "front/ios/Flutter/Debug.xcconfig",
    "front/ios/Flutter/Release.xcconfig",
    "front/ios/Runner/AppDelegate.swift",
    "front/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json",
    "front/ios/Runner/Info.plist",
    "front/ios/Runner.xcodeproj/project.pbxproj",
    "front/ios/Runner.xcworkspace/contents.xcworkspacedata",
  ];

  for (const requiredFile of requiredFiles) {
    assert.ok(existsSync(path.join(root, requiredFile)), `Missing Flutter scaffold file: ${requiredFile}`);
  }

  const androidAppBuildFile = firstExisting(["front/android/app/build.gradle.kts", "front/android/app/build.gradle"]);
  const androidSettingsFile = firstExisting(["front/android/settings.gradle.kts", "front/android/settings.gradle"]);

  assert.match(read("front/pubspec.yaml"), /sdk:\s*flutter/, "pubspec.yaml must depend on the Flutter SDK");
  assert.match(read("front/pubspec.yaml"), /flutter_test:/, "pubspec.yaml must include Flutter test support");
  assert.match(read("front/lib/main.dart"), /runApp/, "Flutter entry point must call runApp");
  assert.match(read("front/lib/app/supported_platforms.dart"), /android/, "Android support must be explicit");
  assert.match(read("front/lib/app/supported_platforms.dart"), /ios/, "iOS support must be explicit");
  assert.match(read(androidAppBuildFile), /com\.aquilaxk\.maumonmobile/, "Android application id must be configured");
  assert.match(read(androidAppBuildFile), /minSdk\s*=\s*23/, "Android minimum SDK must be configured");
  assert.match(read(androidSettingsFile), /include\(":app"\)/, "Android settings must include the app module");
  assert.match(read("front/android/app/src/main/AndroidManifest.xml"), /android:label="Maum On"/, "Android app label must be configured");
  assert.match(
    read("front/android/app/src/main/kotlin/com/aquilaxk/maumonmobile/MainActivity.kt"),
    /package com\.aquilaxk\.maumonmobile/,
    "Android MainActivity package must match the application id"
  );
  assert.match(read("front/ios/Runner/Info.plist"), /Maum On/, "iOS display name must be configured");
  assert.match(read("front/ios/Runner.xcodeproj/project.pbxproj"), /com\.aquilaxk\.maumonmobile/, "iOS bundle id must be configured");
  assert.match(read("front/ios/Runner.xcodeproj/project.pbxproj"), /IPHONEOS_DEPLOYMENT_TARGET = 15\.0;/, "iOS deployment target must be configured");
  assert.ok(!existsSync(path.join(root, "front/package.json")), "React Native package.json must not remain");
});

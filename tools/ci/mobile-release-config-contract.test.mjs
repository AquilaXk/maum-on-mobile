import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

test("Android release builds require dedicated signing inputs", () => {
  const buildFile = read("front/android/app/build.gradle.kts");

  for (const name of [
    "MAUMON_ANDROID_KEYSTORE_PATH",
    "MAUMON_ANDROID_KEYSTORE_PASSWORD",
    "MAUMON_ANDROID_KEY_ALIAS",
    "MAUMON_ANDROID_KEY_PASSWORD",
  ]) {
    assert.match(buildFile, new RegExp(name), `Missing Android release signing input: ${name}`);
  }

  assert.match(buildFile, /signingConfigs\s*\{/);
  assert.match(buildFile, /create\("release"\)/);
  assert.match(buildFile, /GradleException/);
  assert.doesNotMatch(buildFile, /release\s*\{[\s\S]*signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)/);
});

test("Android store-facing metadata stays release ready", () => {
  const manifest = read("front/android/app/src/main/AndroidManifest.xml");

  assert.match(read("front/pubspec.yaml"), /^version:\s*\d+\.\d+\.\d+\+\d+/m);
  assert.match(read("front/android/app/build.gradle.kts"), /applicationId\s*=\s*"com\.aquilaxk\.maumonmobile"/);
  assert.match(manifest, /android:label="Maum On"/);
  assert.match(manifest, /android:icon="@mipmap\/ic_launcher"/);
  assert.match(manifest, /<uses-permission[^>]*android:name="android\.permission\.CAMERA"[^>]*\/?>/);
  assert.match(manifest, /android\.permission\.POST_NOTIFICATIONS/);
  assert.match(manifest, /android\.permission\.READ_MEDIA_IMAGES/);
  assert.match(manifest, /<provider[\s\S]*android:name="androidx\.core\.content\.FileProvider"[\s\S]*android:authorities="\$\{applicationId\}\.diaryimageprovider"[\s\S]*@xml\/diary_image_paths/);
  assert.doesNotMatch(manifest, /android:usesCleartextTraffic="true"/);
  assert.match(manifest, /android:scheme="maumon"/);
  assert.match(manifest, /android:host="auth"/);
  assert.match(manifest, /android:path="\/callback"/);

  for (const density of ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]) {
    assert.ok(
      existsSync(path.join(root, `front/android/app/src/main/res/mipmap-${density}/ic_launcher.png`)),
      `Missing Android launcher icon for ${density}`
    );
  }

  assert.ok(existsSync(path.join(root, "front/android/app/src/main/res/drawable/launch_background.xml")));
  assert.ok(existsSync(path.join(root, "front/android/app/src/main/res/drawable-v21/launch_background.xml")));
  assert.match(read("front/android/app/src/main/res/xml/diary_image_paths.xml"), /<cache-path[\s\S]*path="diary_images\/"/);
});

test("iOS release profile declares signing, entitlement, and version contracts", () => {
  const project = read("front/ios/Runner.xcodeproj/project.pbxproj");
  const entitlements = read("front/ios/Runner/Runner.entitlements");

  assert.match(project, /PRODUCT_BUNDLE_IDENTIFIER = com\.aquilaxk\.maumonmobile;/);
  assert.match(project, /CURRENT_PROJECT_VERSION = "\$\(FLUTTER_BUILD_NUMBER\)";/);
  assert.match(project, /ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;/);
  assert.match(project, /CODE_SIGN_ENTITLEMENTS = Runner\/Runner\.entitlements;/);
  assert.match(project, /DEVELOPMENT_TEAM = "\$\(MAUMON_IOS_DEVELOPMENT_TEAM\)";/);
  assert.match(project, /APS_ENVIRONMENT = development;/);
  assert.match(project, /APS_ENVIRONMENT = production;/);
  assert.match(entitlements, /<key>aps-environment<\/key>/);
  assert.match(entitlements, /<string>\$\(APS_ENVIRONMENT\)<\/string>/);
});

test("iOS store-facing metadata and privacy strings stay release ready", () => {
  const plist = read("front/ios/Runner/Info.plist");

  assert.match(plist, /<key>CFBundleDisplayName<\/key>\s*<string>Maum On<\/string>/);
  assert.match(plist, /<key>CFBundleName<\/key>\s*<string>Maum On<\/string>/);
  assert.match(plist, /<key>CFBundleShortVersionString<\/key>\s*<string>\$\(FLUTTER_BUILD_NAME\)<\/string>/);
  assert.match(plist, /<key>CFBundleVersion<\/key>\s*<string>\$\(FLUTTER_BUILD_NUMBER\)<\/string>/);
  assert.match(plist, /<key>CFBundleURLSchemes<\/key>\s*<array>\s*<string>maumon<\/string>/);
  assert.match(plist, /<key>NSAllowsLocalNetworking<\/key>\s*<true\/>/);
  assert.doesNotMatch(plist, /<key>NSAllowsArbitraryLoads<\/key>\s*<true\/>/);
  assert.match(plist, /<key>NSPhotoLibraryUsageDescription<\/key>\s*<string>.+<\/string>/);
  assert.match(plist, /<key>NSCameraUsageDescription<\/key>\s*<string>\s*[^<\s][^<]*<\/string>/);
  assert.match(plist, /<key>UILaunchStoryboardName<\/key>\s*<string>LaunchScreen<\/string>/);

  assert.ok(existsSync(path.join(root, "front/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png")));
  assert.ok(existsSync(path.join(root, "front/ios/Runner/Base.lproj/LaunchScreen.storyboard")));
});

test("iOS CocoaPods and privacy manifest stay release ready", () => {
  const podfile = read("front/ios/Podfile");
  const workspace = read("front/ios/Runner.xcworkspace/contents.xcworkspacedata");
  const project = read("front/ios/Runner.xcodeproj/project.pbxproj");
  const privacy = read("front/ios/Runner/PrivacyInfo.xcprivacy");

  assert.match(podfile, /platform :ios, '15\.0'/);
  assert.match(podfile, /COCOAPODS_DISABLE_STATS/);
  assert.match(podfile, /flutter_ios_podfile_setup/);
  assert.match(podfile, /target 'Runner' do/);
  assert.match(podfile, /use_frameworks!/);
  assert.match(podfile, /flutter_install_all_ios_pods File\.dirname/);
  assert.match(podfile, /target 'RunnerTests' do[\s\S]*inherit! :search_paths/);
  assert.match(podfile, /post_install do \|installer\|[\s\S]*flutter_additional_ios_build_settings/);

  assert.match(workspace, /Runner\.xcodeproj/);
  assert.match(workspace, /Pods\/Pods\.xcodeproj/);

  assert.match(project, /PrivacyInfo\.xcprivacy/);
  assert.match(project, /PrivacyInfo\.xcprivacy in Resources/);

  assert.match(privacy, /<key>NSPrivacyTracking<\/key>\s*<false\/>/);
  assert.match(privacy, /<key>NSPrivacyTrackingDomains<\/key>\s*<array>\s*<\/array>/);
  assert.match(privacy, /<key>NSPrivacyAccessedAPITypes<\/key>\s*<array>/);
  assert.match(privacy, /<key>NSPrivacyCollectedDataTypes<\/key>\s*<array>/);
  for (const dataType of [
    "NSPrivacyCollectedDataTypeEmailAddress",
    "NSPrivacyCollectedDataTypeUserID",
    "NSPrivacyCollectedDataTypeOtherUserContent",
    "NSPrivacyCollectedDataTypePhotosorVideos",
    "NSPrivacyCollectedDataTypeSensitiveInfo",
    "NSPrivacyCollectedDataTypePerformanceData",
  ]) {
    assert.match(privacy, new RegExp(dataType), `Missing privacy data type: ${dataType}`);
  }
  assert.match(privacy, /NSPrivacyCollectedDataTypePurposeAppFunctionality/);
  assert.match(privacy, /NSPrivacyCollectedDataTypePurposeAnalytics/);
});

test("CI exposes manual Android and iOS release build preflights", () => {
  const workflow = read(".github/workflows/ci.yml");

  assert.match(workflow, /workflow_dispatch:/);
  assert.match(workflow, /node --test tools\/ci\/mobile-release-config-contract\.test\.mjs/);
  assert.match(workflow, /MAUMON_ANDROID_KEYSTORE_BASE64/);
  assert.match(workflow, /flutter build appbundle --release/);
  assert.match(workflow, /flutter build ios --no-codesign/);
});

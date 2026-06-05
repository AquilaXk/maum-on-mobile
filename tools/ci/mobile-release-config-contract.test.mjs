import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, statSync } from "node:fs";
import os from "node:os";
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
  const buildFile = read("front/android/app/build.gradle.kts");
  const networkSecurityConfig = read("front/android/app/src/main/res/xml/network_security_config.xml");

  assert.match(read("front/pubspec.yaml"), /^version:\s*\d+\.\d+\.\d+\+\d+/m);
  assert.match(buildFile, /applicationId\s*=\s*"com\.aquilaxk\.maumonmobile"/);
  assert.match(buildFile, /playStoreMinimumTargetSdk\s*=\s*35/);
  assert.match(buildFile, /compileSdk\s*=\s*maxOf\(flutter\.compileSdkVersion,\s*playStoreMinimumTargetSdk\)/);
  assert.match(buildFile, /targetSdk\s*=\s*maxOf\(flutter\.targetSdkVersion,\s*playStoreMinimumTargetSdk\)/);
  assert.match(buildFile, /MAUMON_FIREBASE_APP_ID/);
  assert.match(buildFile, /MAUMON_FIREBASE_PROJECT_ID/);
  assert.match(buildFile, /MAUMON_FIREBASE_API_KEY/);
  assert.match(buildFile, /MAUMON_FIREBASE_SENDER_ID/);
  assert.match(manifest, /android:label="Maum On"/);
  assert.match(manifest, /android:icon="@mipmap\/ic_launcher"/);
  assert.match(manifest, /android:networkSecurityConfig="@xml\/network_security_config"/);
  assert.match(manifest, /<uses-permission[^>]*android:name="android\.permission\.CAMERA"[^>]*\/?>/);
  assert.match(manifest, /android\.permission\.POST_NOTIFICATIONS/);
  assert.match(manifest, /android\.permission\.READ_MEDIA_IMAGES/);
  assert.match(manifest, /<provider[\s\S]*android:name="androidx\.core\.content\.FileProvider"[\s\S]*android:authorities="\$\{applicationId\}\.diaryimageprovider"[\s\S]*@xml\/diary_image_paths/);
  assert.doesNotMatch(manifest, /android:usesCleartextTraffic="true"/);
  assert.match(manifest, /android:scheme="maumon"/);
  assert.match(manifest, /android:host="auth"/);
  assert.match(manifest, /android:path="\/callback"/);
  assert.doesNotMatch(networkSecurityConfig, /<base-config[^>]*cleartextTrafficPermitted="true"/);
  assert.match(networkSecurityConfig, /<domain-config[^>]*cleartextTrafficPermitted="true"/);
  assert.match(networkSecurityConfig, /<domain[^>]*>64\.110\.66\.27<\/domain>/);

  for (const density of ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]) {
    assert.ok(
      existsSync(path.join(root, `front/android/app/src/main/res/mipmap-${density}/ic_launcher.png`)),
      `Missing Android launcher icon for ${density}`
    );
  }

  assert.ok(existsSync(path.join(root, "front/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml")));
  assert.ok(existsSync(path.join(root, "front/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml")));
  assert.ok(existsSync(path.join(root, "front/android/app/src/main/res/drawable/ic_launcher_foreground.xml")));
  const launcherColors = read("front/android/app/src/main/res/values/colors.xml");
  const launcherForeground = read("front/android/app/src/main/res/drawable/ic_launcher_foreground.xml");
  assert.match(launcherColors, /<color name="ic_launcher_background">#18A9ED<\/color>/);
  assert.match(launcherForeground, /android:strokeColor="#FFFFFF"/);
  assert.match(launcherForeground, /android:strokeLineCap="round"/);
  assert.doesNotMatch(launcherForeground, /#10B981/);
  assert.doesNotMatch(launcherForeground, /heart|M64\.3,43\.3/i);
  assert.ok(existsSync(path.join(root, "front/android/app/src/main/res/drawable/launch_background.xml")));
  assert.ok(existsSync(path.join(root, "front/android/app/src/main/res/drawable-v21/launch_background.xml")));
  assert.match(read("front/android/app/src/main/res/xml/diary_image_paths.xml"), /<cache-path[\s\S]*path="diary_images\/"/);
});

test("Android release build config keeps Play appbundle optimization gates on", () => {
  const buildFile = read("front/android/app/build.gradle.kts");
  const proguardRules = read("front/android/app/proguard-rules.pro");

  assert.match(buildFile, /isMinifyEnabled\s*=\s*true/);
  assert.match(buildFile, /isShrinkResources\s*=\s*true/);
  assert.match(buildFile, /proguard-android-optimize\.txt/);
  assert.match(buildFile, /proguardFiles\(/);
  assert.ok(existsSync(path.join(root, "front/android/app/proguard-rules.pro")));
  assert.match(proguardRules, /com\.google\.android\.play\.core\.\*\*/);
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
  assert.match(
    plist,
    /<key>NSExceptionDomains<\/key>\s*<dict>[\s\S]*?<key>64\.110\.66\.27<\/key>\s*<dict>[\s\S]*?<key>NSExceptionAllowsInsecureHTTPLoads<\/key>\s*<true\/>[\s\S]*?<\/dict>/
  );
  assert.match(plist, /<key>NSPhotoLibraryUsageDescription<\/key>\s*<string>.+<\/string>/);
  assert.match(plist, /<key>NSCameraUsageDescription<\/key>\s*<string>\s*[^<\s][^<]*<\/string>/);
  assert.match(plist, /<key>UILaunchStoryboardName<\/key>\s*<string>LaunchScreen<\/string>/);

  assert.ok(existsSync(path.join(root, "front/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png")));
  assert.ok(existsSync(path.join(root, "front/ios/Runner/Base.lproj/LaunchScreen.storyboard")));
});

test("iOS CocoaPods and privacy manifest stay release ready", () => {
  const podfile = read("front/ios/Podfile");
  const podfileLock = read("front/ios/Podfile.lock");
  const gemfile = read("front/ios/Gemfile");
  const gemfileLock = read("front/ios/Gemfile.lock");
  const packageResolved = read("front/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved");
  const workspace = read("front/ios/Runner.xcworkspace/contents.xcworkspacedata");
  const project = read("front/ios/Runner.xcodeproj/project.pbxproj");
  const debugXcconfig = read("front/ios/Flutter/Debug.xcconfig");
  const releaseXcconfig = read("front/ios/Flutter/Release.xcconfig");
  const privacy = read("front/ios/Runner/PrivacyInfo.xcprivacy");

  assert.match(podfile, /platform :ios, '15\.0'/);
  assert.match(podfile, /COCOAPODS_DISABLE_STATS/);
  assert.match(podfile, /flutter_ios_podfile_setup/);
  assert.match(podfile, /target 'Runner' do/);
  assert.match(podfile, /use_frameworks!/);
  assert.match(podfile, /flutter_install_all_ios_pods File\.dirname/);
  assert.match(podfile, /target 'RunnerTests' do[\s\S]*inherit! :search_paths/);
  assert.match(podfile, /post_install do \|installer\|[\s\S]*flutter_additional_ios_build_settings/);

  assert.match(podfileLock, /Flutter \(1\.0\.0\)/);
  assert.match(podfileLock, /COCOAPODS: 1\.16\.2/);

  assert.match(gemfile, /source "https:\/\/rubygems\.org"/);
  assert.match(gemfile, /gem "cocoapods", "~> 1\.16"/);
  assert.match(gemfile, /gem "ffi", "~> 1\.15\.5"/);
  assert.match(gemfile, /gem "logger", "1\.3\.0"/);
  assert.match(gemfileLock, /BUNDLED WITH\s+2\./);
  assert.doesNotMatch(gemfileLock, /BUNDLED WITH\s+1\./);

  assert.match(packageResolved, /"identity" : "dkimagepickercontroller"/);
  assert.match(packageResolved, /"identity" : "sdwebimage"/);

  assert.match(workspace, /Runner\.xcodeproj/);
  assert.match(workspace, /Pods\/Pods\.xcodeproj/);

  assert.match(project, /PrivacyInfo\.xcprivacy/);
  assert.match(project, /PrivacyInfo\.xcprivacy in Resources/);
  assert.match(project, /\[CP\] Check Pods Manifest\.lock/);
  assert.match(project, /Pods_Runner\.framework in Frameworks/);

  assert.match(debugXcconfig, /Pods-Runner\.debug\.xcconfig/);
  assert.match(releaseXcconfig, /Pods-Runner\.release\.xcconfig/);

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
  assert.match(workflow, /android_release_mode:/);
  assert.match(workflow, /default: skip/);
  assert.match(workflow, /android_track_submit_mode:/);
  assert.match(workflow, /android_play_track:/);
  assert.match(workflow, /android_play_track_kind:/);
  assert.match(workflow, /android_play_release_notes:/);
  assert.match(workflow, /android_play_release_status:/);
  assert.match(workflow, /ios_release_mode:/);
  assert.match(workflow, /dry-run/);
  assert.match(workflow, /archive/);
  assert.match(workflow, /upload/);
  assert.match(workflow, /node --test tools\/ci\/mobile-release-config-contract\.test\.mjs/);
  assert.match(workflow, /MAUMON_ANDROID_KEYSTORE_BASE64/);
  assert.match(workflow, /inputs\.android_release_mode != 'skip'/);
  assert.match(workflow, /MAUMON_ANDROID_RELEASE_DRY_RUN: \$\{\{ inputs\.android_release_mode == 'dry-run' \}\}/);
  assert.match(workflow, /bash tools\/ci\/run-android-release-appbundle\.sh/);
  assert.match(workflow, /Require Android appbundle for Play submit/);
  assert.match(workflow, /inputs\.android_track_submit_mode == 'submit'/);
  assert.match(workflow, /node tools\/ci\/run-android-play-track-submit\.mjs/);
  assert.match(workflow, /MAUMON_PLAY_SERVICE_ACCOUNT_JSON_BASE64/);
  assert.match(workflow, /MAUMON_PLAY_RELEASE_DRY_RUN: \$\{\{ inputs\.android_track_submit_mode == 'dry-run' \}\}/);
  assert.match(workflow, /gem install bundler -v 2\.4\.22 --no-document/);
  assert.match(workflow, /bundle _2\.4\.22_ config set --local path vendor\/bundle/);
  assert.match(workflow, /bundle _2\.4\.22_ install --jobs 4 --retry 3/);
  assert.match(workflow, /Select Xcode 26/);
  assert.match(workflow, /Require Xcode 26 for iOS archive or upload/);
  assert.match(workflow, /ios_release_mode != 'dry-run'/);
  assert.match(workflow, /steps\.xcode\.outputs\.xcode26 != 'true'/);
  assert.match(workflow, /xcodebuild -version/);
  assert.doesNotMatch(
    workflow,
    /xcodebuild"?\s+-version\s*\|\s*head/,
    "Xcode version detection must not pipe xcodebuild into head because hosted macOS can abort on a broken pipe"
  );
  assert.match(workflow, /MAUMON_IOS_DEVELOPMENT_TEAM/);
  assert.match(workflow, /MAUMON_IOS_EXPORT_OPTIONS_PLIST_BASE64/);
  assert.match(workflow, /MAUMON_IOS_PROVISIONING_PROFILE_BASE64/);
  assert.match(workflow, /MAUMON_IOS_CERTIFICATE_P12_BASE64/);
  assert.match(workflow, /MAUMON_APP_STORE_CONNECT_API_KEY_P8_BASE64/);
  assert.match(workflow, /MAUMON_IOS_RELEASE_DRY_RUN/);
  assert.match(workflow, /MAUMON_IOS_TESTFLIGHT_UPLOAD/);
  assert.match(workflow, /bash tools\/ci\/run-ios-testflight-archive\.sh/);
  assert.match(read("tools/ci/run-mobile-release-preflight.sh"), /DEVELOPER_DIR/);
});

test("Android release appbundle script fails clearly without signing and Firebase inputs", () => {
  const script = path.join(root, "tools/ci/run-android-release-appbundle.sh");
  const scriptContents = read("tools/ci/run-android-release-appbundle.sh");

  assert.ok(existsSync(script));
  assert.ok((statSync(script).mode & 0o111) !== 0, "Android release appbundle script must be executable");
  assert.match(scriptContents, /tools\/flutterw/, "Android release appbundle script must use the repository Flutter wrapper");

  let output = "";
  try {
    execFileSync("bash", [script], {
      cwd: root,
      env: {
        ...process.env,
        MAUMON_ANDROID_RELEASE_DRY_RUN: "true",
        MAUMON_ANDROID_KEYSTORE_BASE64: "",
        MAUMON_ANDROID_KEYSTORE_PASSWORD: "",
        MAUMON_ANDROID_KEY_ALIAS: "",
        MAUMON_ANDROID_KEY_PASSWORD: "",
        MAUMON_FIREBASE_APP_ID: "",
        MAUMON_FIREBASE_PROJECT_ID: "",
        MAUMON_FIREBASE_API_KEY: "",
        MAUMON_FIREBASE_SENDER_ID: "",
      },
      encoding: "utf8",
      stdio: "pipe",
    });
    assert.fail("Expected Android release appbundle script to fail without required inputs.");
  } catch (error) {
    output = `${error.stdout ?? ""}${error.stderr ?? ""}`;
  }

  for (const name of [
    "MAUMON_ANDROID_KEYSTORE_BASE64",
    "MAUMON_ANDROID_KEYSTORE_PASSWORD",
    "MAUMON_ANDROID_KEY_ALIAS",
    "MAUMON_ANDROID_KEY_PASSWORD",
    "MAUMON_FIREBASE_APP_ID",
    "MAUMON_FIREBASE_PROJECT_ID",
    "MAUMON_FIREBASE_API_KEY",
    "MAUMON_FIREBASE_SENDER_ID",
  ]) {
    assert.match(output, new RegExp(name), `Missing clear failure for ${name}`);
  }
});

test("Android release appbundle script supports a signed dry run before building", () => {
  const script = path.join(root, "tools/ci/run-android-release-appbundle.sh");
  const output = execFileSync("bash", [script, "--dry-run"], {
    cwd: root,
    env: {
      ...process.env,
      MAUMON_ANDROID_KEYSTORE_BASE64: "ZmFrZS1rZXlzdG9yZQ==",
      MAUMON_ANDROID_KEYSTORE_PASSWORD: "password",
      MAUMON_ANDROID_KEY_ALIAS: "maumon",
      MAUMON_ANDROID_KEY_PASSWORD: "password",
      MAUMON_FIREBASE_APP_ID: "1:1234567890:android:abcdef",
      MAUMON_FIREBASE_PROJECT_ID: "maum-on",
      MAUMON_FIREBASE_API_KEY: "fake-api-key",
      MAUMON_FIREBASE_SENDER_ID: "1234567890",
    },
    encoding: "utf8",
  });

  assert.match(output, /Android release appbundle dry run ok/);
  assert.match(output, /flutter build appbundle --release/);
});

test("Android Play track submit script validates track inputs and writes closed-test evidence in dry run", () => {
  const script = path.join(root, "tools/ci/run-android-play-track-submit.mjs");
  const tempDir = mkdtempSync(path.join(os.tmpdir(), "maumon-play-track-"));
  const reportPath = path.join(tempDir, "evidence.json");
  const serviceAccount = Buffer.from(JSON.stringify({
    client_email: "play-submit@example.iam.gserviceaccount.com",
    private_key: "-----BEGIN PRIVATE KEY-----\\nfake\\n-----END PRIVATE KEY-----\\n",
    token_uri: "https://oauth2.googleapis.com/token",
  })).toString("base64");

  assert.ok(existsSync(script));
  assert.ok((statSync(script).mode & 0o111) !== 0, "Android Play submit script must be executable");

  const output = execFileSync("node", [script, "--dry-run"], {
    cwd: root,
    env: {
      ...process.env,
      MAUMON_PLAY_SERVICE_ACCOUNT_JSON_BASE64: serviceAccount,
      MAUMON_PLAY_PACKAGE_NAME: "com.aquilaxk.maumonmobile",
      MAUMON_PLAY_TRACK: "alpha",
      MAUMON_PLAY_TRACK_KIND: "closed",
      MAUMON_PLAY_RELEASE_STATUS: "draft",
      MAUMON_PLAY_RELEASE_NOTES: "Closed testing build",
      MAUMON_PLAY_RELEASE_NOTES_LANGUAGE: "ko-KR",
      MAUMON_PLAY_TESTER_GROUPS: "maumon-closed-testers@example.com",
      MAUMON_PLAY_TESTER_EMAILS: "tester1@example.com,tester2@example.com",
      MAUMON_PLAY_CLOSED_TEST_START_DATE: "2020-01-01",
      MAUMON_PLAY_CLOSED_TEST_PARTICIPANT_COUNT: "12",
      MAUMON_PLAY_CLOSED_TEST_FEEDBACK_URL: "https://example.com/feedback",
      MAUMON_PLAY_PRODUCTION_ACCESS_STATUS: "not_requested",
      MAUMON_PLAY_REPORT_PATH: reportPath,
    },
    encoding: "utf8",
  });

  assert.match(output, /Android Play track submit dry run ok/);
  assert.match(output, /track: alpha/);
  assert.match(output, /trackKind: closed/);
  assert.match(output, /releaseStatus: draft/);
  assert.match(output, /testerGroups: maumon-closed-testers@example\.com/);
  assert.match(output, /email tester list is evidence-only/);
  assert.ok(existsSync(reportPath), "Play track dry-run evidence report must be written");

  const report = JSON.parse(readFileSync(reportPath, "utf8"));
  assert.equal(report.packageName, "com.aquilaxk.maumonmobile");
  assert.equal(report.track, "alpha");
  assert.equal(report.trackKind, "closed");
  assert.equal(report.closedTest.requiredParticipants, 12);
  assert.equal(report.closedTest.participantCount, 12);
  assert.equal(report.closedTest.meetsParticipantRequirement, true);
  assert.equal(report.closedTest.requiredDays, 14);
  assert.equal(report.closedTest.meetsDurationRequirement, true);
  assert.equal(report.productionAccessStatus, "not_requested");
  assert.equal(report.emailListApiSupport, "unsupported");
});

test("Android Play track submit script fails clearly without Play inputs", () => {
  const script = path.join(root, "tools/ci/run-android-play-track-submit.mjs");

  let output = "";
  try {
    execFileSync("node", [script, "--dry-run"], {
      cwd: root,
      env: {
        ...process.env,
        MAUMON_PLAY_SERVICE_ACCOUNT_JSON_BASE64: "",
        MAUMON_PLAY_PACKAGE_NAME: "",
        MAUMON_PLAY_TRACK: "",
        MAUMON_PLAY_RELEASE_STATUS: "",
        MAUMON_PLAY_RELEASE_NOTES: "",
      },
      encoding: "utf8",
      stdio: "pipe",
    });
    assert.fail("Expected Android Play submit script to fail without required inputs.");
  } catch (error) {
    output = `${error.stdout ?? ""}${error.stderr ?? ""}`;
  }

  for (const name of [
    "MAUMON_PLAY_SERVICE_ACCOUNT_JSON_BASE64",
    "MAUMON_PLAY_PACKAGE_NAME",
    "MAUMON_PLAY_TRACK",
    "MAUMON_PLAY_RELEASE_STATUS",
    "MAUMON_PLAY_RELEASE_NOTES",
  ]) {
    assert.match(output, new RegExp(name), `Missing clear failure for ${name}`);
  }
});

test("iOS TestFlight archive script fails clearly without signing and upload inputs", () => {
  const script = path.join(root, "tools/ci/run-ios-testflight-archive.sh");
  const scriptContents = read("tools/ci/run-ios-testflight-archive.sh");

  assert.ok(existsSync(script));
  assert.ok((statSync(script).mode & 0o111) !== 0, "iOS TestFlight archive script must be executable");
  assert.match(scriptContents, /tools\/flutterw/, "iOS archive script must use the repository Flutter wrapper");
  assert.match(scriptContents, /xcodebuild -version/, "iOS archive script must report the selected Xcode version");
  assert.match(scriptContents, /Xcode\\ 26\*/, "iOS archive script must enforce Xcode 26 for real archive/export");
  assert.match(scriptContents, /flutter build ipa --release/, "iOS archive script must produce an IPA");
  assert.match(scriptContents, /xcrun altool --upload-app/, "iOS archive script must support TestFlight upload");

  let output = "";
  try {
    execFileSync("bash", [script], {
      cwd: root,
      env: {
        ...process.env,
        MAUMON_IOS_RELEASE_DRY_RUN: "false",
        MAUMON_IOS_TESTFLIGHT_UPLOAD: "true",
        MAUMON_IOS_DEVELOPMENT_TEAM: "",
        MAUMON_IOS_EXPORT_OPTIONS_PLIST_BASE64: "",
        MAUMON_IOS_PROVISIONING_PROFILE_BASE64: "",
        MAUMON_IOS_CERTIFICATE_P12_BASE64: "",
        MAUMON_IOS_CERTIFICATE_PASSWORD: "",
        MAUMON_IOS_KEYCHAIN_PASSWORD: "",
        MAUMON_APP_STORE_CONNECT_API_KEY_ID: "",
        MAUMON_APP_STORE_CONNECT_API_ISSUER_ID: "",
        MAUMON_APP_STORE_CONNECT_API_KEY_P8_BASE64: "",
      },
      encoding: "utf8",
      stdio: "pipe",
    });
    assert.fail("Expected iOS TestFlight archive script to fail without required inputs.");
  } catch (error) {
    output = `${error.stdout ?? ""}${error.stderr ?? ""}`;
  }

  for (const name of [
    "MAUMON_IOS_DEVELOPMENT_TEAM",
    "MAUMON_IOS_EXPORT_OPTIONS_PLIST_BASE64",
    "MAUMON_IOS_PROVISIONING_PROFILE_BASE64",
    "MAUMON_IOS_CERTIFICATE_P12_BASE64",
    "MAUMON_IOS_CERTIFICATE_PASSWORD",
    "MAUMON_IOS_KEYCHAIN_PASSWORD",
    "MAUMON_APP_STORE_CONNECT_API_KEY_ID",
    "MAUMON_APP_STORE_CONNECT_API_ISSUER_ID",
    "MAUMON_APP_STORE_CONNECT_API_KEY_P8_BASE64",
  ]) {
    assert.match(output, new RegExp(name), `Missing clear failure for ${name}`);
  }
});

test("iOS TestFlight archive script supports dry-run before archive and upload", () => {
  const script = path.join(root, "tools/ci/run-ios-testflight-archive.sh");
  const output = execFileSync("bash", [script], {
    cwd: root,
    env: {
      ...process.env,
      MAUMON_IOS_RELEASE_DRY_RUN: "true",
      MAUMON_IOS_TESTFLIGHT_UPLOAD: "true",
    },
    encoding: "utf8",
  });

  assert.match(output, /iOS TestFlight archive dry run ok/);
  assert.match(output, /flutter build ipa --release/);
  assert.match(output, /TestFlight upload dry run/);
});

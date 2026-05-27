import assert from "node:assert/strict";
import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const root = process.cwd();

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function assertExecutable(relativePath) {
  const mode = statSync(path.join(root, relativePath)).mode;
  assert.ok((mode & 0o111) !== 0, `${relativePath} must be executable`);
}

test("mobile release preflight script checks Android and iOS toolchains", () => {
  const scriptPath = "tools/ci/run-mobile-release-preflight.sh";
  assert.ok(existsSync(path.join(root, scriptPath)), "Missing mobile release preflight script");
  assertExecutable(scriptPath);

  const script = read(scriptPath);
  assert.match(script, /--platform/, "Preflight must accept a platform selector");
  assert.match(script, /android\|ios\|all/, "Preflight must document supported platforms");
  assert.match(script, /tools\/flutterw/, "Preflight must use the repository Flutter wrapper");
  assert.match(script, /front\/pubspec\.yaml/, "Preflight must assert the Flutter app scaffold");
  assert.match(script, /ANDROID_HOME/, "Android preflight must inspect ANDROID_HOME");
  assert.match(script, /ANDROID_SDK_ROOT/, "Android preflight must inspect ANDROID_SDK_ROOT");
  assert.match(script, /config --list/, "Android preflight must inspect Flutter's configured Android SDK");
  assert.match(script, /android-sdk:/, "Android preflight must parse Flutter's configured Android SDK");
  assert.match(script, /java -version/, "Android preflight must inspect Java");
  assert.match(script, /xcodebuild -version/, "iOS preflight must inspect full Xcode");
  assert.match(script, /Xcode 26/, "iOS preflight must inspect the Xcode 26 SDK line");
  assert.match(script, /archive\/upload requires Xcode 26/, "iOS preflight must warn instead of failing PR checks when Xcode 26 is unavailable");
  assert.match(script, /iphoneos/, "iOS preflight must inspect the iPhoneOS SDK");
  assert.match(script, /pod --version/, "iOS preflight must inspect CocoaPods");
  assert.match(script, /flutter doctor -v/, "Preflight must expose Flutter doctor diagnostics");
  assert.match(script, /mktemp/, "Preflight must use isolated temporary files");
});

test("CI runs release preflight before Android and iOS builds", () => {
  const workflow = read(".github/workflows/ci.yml");

  assert.match(workflow, /Run Android release preflight[\s\S]*tools\/ci\/run-mobile-release-preflight\.sh --platform android/);
  assert.match(workflow, /Run iOS release preflight[\s\S]*tools\/ci\/run-mobile-release-preflight\.sh --platform ios/);
  assert.ok(
    workflow.indexOf("Run Android release preflight") < workflow.indexOf("Build Flutter Android debug app"),
    "Android preflight must run before the Android build"
  );
  assert.ok(
    workflow.indexOf("Run iOS release preflight") < workflow.indexOf("Build Flutter iOS app"),
    "iOS preflight must run before the iOS build"
  );
});

test("README documents release preflight commands", () => {
  const readme = read("README.md");

  assert.match(readme, /tools\/ci\/run-mobile-release-preflight\.sh --platform android/);
  assert.match(readme, /tools\/ci\/run-mobile-release-preflight\.sh --platform ios/);
  assert.match(readme, /tools\/ci\/run-mobile-release-preflight\.sh --platform all/);
});

test("mobile release preflight rejects a missing platform value", () => {
  const result = spawnSync("tools/ci/run-mobile-release-preflight.sh", ["--platform"], {
    cwd: root,
    encoding: "utf8",
  });

  assert.equal(result.status, 2);
  assert.match(result.stderr, /Missing value for --platform/);
  assert.doesNotMatch(result.stderr, /shift/);
});

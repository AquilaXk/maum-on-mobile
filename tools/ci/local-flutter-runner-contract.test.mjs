import assert from "node:assert/strict";
import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function assertExecutable(relativePath) {
  const mode = statSync(path.join(root, relativePath)).mode;
  assert.ok((mode & 0o111) !== 0, `${relativePath} must be executable`);
}

test("repository exposes a PATH-independent Flutter wrapper", () => {
  assert.ok(existsSync(path.join(root, "tools/flutterw")), "Missing tools/flutterw");
  assertExecutable("tools/flutterw");

  const script = read("tools/flutterw");
  assert.match(script, /FLUTTER_BIN/, "Wrapper must accept an explicit Flutter binary override");
  assert.match(script, /FLUTTER_HOME/, "Wrapper must accept a Flutter home override");
  assert.match(script, /\.codex\/toolchains\/flutter\/bin\/flutter/, "Wrapper must search the repository-local Flutter cache");
  assert.match(script, /command -v flutter/, "Wrapper must fall back to PATH lookup");
  assert.match(script, /DEVELOPER_DIR/, "Wrapper must select the full local Xcode when Command Line Tools are active");
  assert.match(script, /repo_root\}\/tools:\$\{PATH\}/, "Wrapper must expose repository tool shims on PATH");
  assert.match(script, /exec "\$\{flutter_bin\}"/, "Wrapper must delegate arguments to the detected Flutter binary");
  assert.match(script, /flutter sdk not found/i, "Wrapper must print a clear missing SDK message");
});

test("repository exposes a CocoaPods wrapper for bundled iOS dependencies", () => {
  assert.ok(existsSync(path.join(root, "tools/pod")), "Missing tools/pod");
  assertExecutable("tools/pod");

  const script = read("tools/pod");
  assert.match(script, /POD_BIN/, "Wrapper must accept an explicit CocoaPods binary override");
  assert.match(script, /front\/ios/, "Wrapper must use the iOS bundle directory");
  assert.match(script, /BUNDLE_USER_HOME/, "Wrapper must keep Bundler state inside the ignored iOS bundle directory");
  assert.match(script, /bundle exec pod/, "Wrapper must prefer bundled CocoaPods");
  assert.match(script, /RUBYOPT="-rlogger/, "Wrapper must preload logger for macOS system Ruby");
  assert.match(script, /gem install bundler -v 2\.4\.22/, "Wrapper must point users at the Bundler version in Gemfile.lock");
  assert.match(script, /CocoaPods bundle is not installed/, "Wrapper must explain missing bundled dependencies");
});

test("repository exposes an xcrun wrapper for local iOS SDK lookup", () => {
  assert.ok(existsSync(path.join(root, "tools/xcrun")), "Missing tools/xcrun");
  assertExecutable("tools/xcrun");

  const script = read("tools/xcrun");
  assert.match(script, /DEVELOPER_DIR/, "Wrapper must select the full local Xcode when Command Line Tools are active");
  assert.match(script, /exec \/usr\/bin\/xcrun "\$@"/, "Wrapper must delegate to the system xcrun");
});

test("local mobile check script runs Flutter checks from the app directory", () => {
  assert.ok(existsSync(path.join(root, "tools/ci/run-local-mobile-checks.sh")), "Missing local mobile check script");
  assertExecutable("tools/ci/run-local-mobile-checks.sh");

  const script = read("tools/ci/run-local-mobile-checks.sh");
  assert.match(script, /tools\/flutterw/, "Local checks must use the repository Flutter wrapper");
  assert.match(script, /cd "\$\{repo_root\}\/front"/, "Local checks must run from front/");
  assert.match(script, /flutter pub get/, "Local checks must install Flutter dependencies");
  assert.match(script, /flutter analyze/, "Local checks must run static analysis");
  assert.match(script, /flutter test/, "Local checks must run tests");
  assert.match(script, /--doctor/, "Local checks must expose a doctor-only mode");
  assert.match(script, /ANDROID_HOME|ANDROID_SDK_ROOT/, "Doctor mode must inspect Android SDK environment");
  assert.match(script, /DEVELOPER_DIR/, "Doctor mode must select the full local Xcode when Command Line Tools are active");
  assert.match(script, /xcodebuild/, "Doctor mode must inspect Xcode availability");
  assert.match(script, /tools\/pod/, "Doctor mode must inspect CocoaPods through the repository wrapper");
});

test("README documents the local Flutter wrapper commands", () => {
  const readme = read("README.md");

  assert.match(readme, /tools\/flutterw --version/, "README must document the Flutter wrapper");
  assert.match(readme, /gem install --user-install bundler -v 2\.4\.22/, "README must document the Bundler version needed by the iOS lockfile");
  assert.match(readme, /cd front\/ios && bundle install/, "README must document bundled CocoaPods setup");
  assert.match(readme, /tools\/ci\/run-local-mobile-checks\.sh/, "README must document the one-command local check");
  assert.match(readme, /tools\/ci\/run-local-mobile-checks\.sh --doctor/, "README must document local doctor mode");
});

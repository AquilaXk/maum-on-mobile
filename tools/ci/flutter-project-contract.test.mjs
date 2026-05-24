import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

const root = process.cwd();

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

test("front uses a Flutter Android/iOS app scaffold", () => {
  const requiredFiles = [
    "front/pubspec.yaml",
    "front/analysis_options.yaml",
    "front/lib/main.dart",
    "front/lib/app/maum_on_mobile_app.dart",
    "front/lib/app/supported_platforms.dart",
    "front/lib/features/home/home_screen.dart",
    "front/test/widget_test.dart",
  ];

  for (const requiredFile of requiredFiles) {
    assert.ok(existsSync(path.join(root, requiredFile)), `Missing Flutter scaffold file: ${requiredFile}`);
  }

  assert.match(read("front/pubspec.yaml"), /sdk:\s*flutter/, "pubspec.yaml must depend on the Flutter SDK");
  assert.match(read("front/pubspec.yaml"), /flutter_test:/, "pubspec.yaml must include Flutter test support");
  assert.match(read("front/lib/main.dart"), /runApp/, "Flutter entry point must call runApp");
  assert.match(read("front/lib/app/supported_platforms.dart"), /android/, "Android support must be explicit");
  assert.match(read("front/lib/app/supported_platforms.dart"), /ios/, "iOS support must be explicit");
  assert.ok(!existsSync(path.join(root, "front/package.json")), "React Native package.json must not remain");
});

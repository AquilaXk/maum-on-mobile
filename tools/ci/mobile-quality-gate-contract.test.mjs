import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { readFileSync } from "node:fs";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const execFileAsync = promisify(execFile);

test("mobile quality gate manifest covers required mobile scenarios", () => {
  const manifest = JSON.parse(
    readFileSync(path.join(root, "tools/ci/mobile-quality-gate-scenarios.json"), "utf8"),
  );
  const scenarioIds = new Set(manifest.scenarios.map((scenario) => scenario.id));

  for (const requiredScenario of [
    "auth.login",
    "auth.external-callback",
    "navigation.tabs",
    "write.flows",
    "push.registration",
    "push.cold-start-routing",
    "realtime.lifecycle",
    "auth.logout",
    "layout.accessibility",
    "api.performance",
  ]) {
    assert.ok(scenarioIds.has(requiredScenario), `Missing quality scenario: ${requiredScenario}`);
  }

  assert.deepEqual(manifest.report.requiredFields, [
    "platform",
    "scenario",
    "status",
    "area",
    "failureStep",
    "evidence",
  ]);
  assert.deepEqual(Object.keys(manifest.platforms).sort(), ["android", "ios"]);
});

test("mobile quality gate script writes actionable reports", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-mobile-quality-"));

  await execFileAsync("node", [
    path.join(root, "tools/ci/run-mobile-quality-gate.mjs"),
    "--platform",
    "android",
    "--skip-build-artifact",
    "--report-dir",
    reportDir,
  ]);

  const report = JSON.parse(
    await readFile(path.join(reportDir, "mobile-quality-android.json"), "utf8"),
  );
  const markdown = await readFile(path.join(reportDir, "mobile-quality-android.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.ok(report.summary.scenarios >= 9);
  assert.ok(report.scenarios.every((scenario) => scenario.status === "pass"));
  assert.ok(report.scenarios.every((scenario) => scenario.area && scenario.failureStep));
  assert.match(markdown, /Mobile Quality Gate \(android\)/);
  assert.match(markdown, /layout\.accessibility/);
});

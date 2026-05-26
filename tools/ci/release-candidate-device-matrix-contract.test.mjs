import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const contractPath = "contracts/release-candidate/device-matrix.json";
const execFileAsync = promisify(execFile);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readContract() {
  const absolutePath = path.join(root, contractPath);
  assert.ok(existsSync(absolutePath), `${contractPath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

test("release candidate device matrix covers Android and iOS device profiles", () => {
  const matrix = readContract();

  assert.equal(matrix.version, 1);
  assert.deepEqual(Object.keys(matrix.platforms).sort(), ["android", "ios"]);

  for (const [platform, config] of Object.entries(matrix.platforms)) {
    assert.ok(config.deviceProfiles.length >= 1, `${platform} needs at least one device profile`);
    assert.ok(
      config.deviceProfiles.some((profile) => profile.deviceType === "physical"),
      `${platform} must include a physical device profile`,
    );
    assert.ok(config.smokeBuildCommands.length >= 2, `${platform} needs preflight and smoke build commands`);
    assert.ok(config.requiredResultFields.includes("deviceModel"));
    assert.ok(config.requiredResultFields.includes("osVersion"));
    assert.ok(config.requiredResultFields.includes("buildNumber"));
  }
});

test("release candidate device matrix covers required launch scenarios", () => {
  const matrix = readContract();
  const scenarioIds = new Set(matrix.scenarios.map((scenario) => scenario.id));

  for (const requiredScenario of [
    "permissions.notifications.allow-deny",
    "permissions.photos.allow-deny",
    "permissions.camera.allow-deny",
    "push.foreground-background-cold-start",
    "deeplink.external-login-cold-start",
    "media.camera-capture",
    "media.photo-library-pick",
    "auth.logout",
    "auth.account-deletion",
    "lifecycle.background-return",
    "accessibility.large-text",
    "accessibility.screen-reader",
    "layout.rotation",
    "network.slow-connection",
  ]) {
    assert.ok(scenarioIds.has(requiredScenario), `Missing device matrix scenario: ${requiredScenario}`);
  }

  for (const scenario of matrix.scenarios) {
    assert.match(scenario.priority, /^P[0-2]$/, `${scenario.id} must have a P0/P1/P2 priority`);
    assert.ok(["automated", "manual", "hybrid"].includes(scenario.mode), `${scenario.id} has invalid mode`);
    assert.ok(scenario.platforms.length > 0, `${scenario.id} needs platform coverage`);
    assert.ok(scenario.passCriteria.length > 0, `${scenario.id} needs pass criteria`);
    assert.ok(scenario.resultFields.includes("status"), `${scenario.id} must record status`);
    assert.ok(scenario.resultFields.includes("evidence"), `${scenario.id} must record evidence`);
    assert.ok(scenario.resultFields.includes("notes"), `${scenario.id} must record notes`);
  }
});

test("automated matrix scenarios link to existing tests and scripts", () => {
  const matrix = readContract();
  const automatedScenarios = matrix.scenarios.filter((scenario) => scenario.mode !== "manual");

  assert.ok(automatedScenarios.length >= 6);
  for (const scenario of automatedScenarios) {
    assert.ok(scenario.automation.commands.length > 0, `${scenario.id} needs automation commands`);
    assert.ok(scenario.automation.evidence.length > 0, `${scenario.id} needs evidence files`);

    for (const evidence of scenario.automation.evidence) {
      const absolutePath = path.join(root, evidence.path);
      assert.ok(existsSync(absolutePath), `${scenario.id} evidence missing: ${evidence.path}`);
      const contents = read(evidence.path);
      for (const pattern of evidence.patterns) {
        assert.ok(contents.includes(pattern), `${scenario.id} evidence ${evidence.path} missing ${pattern}`);
      }
    }
  }
});

test("release candidate device matrix report script writes PR-ready checklist", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-device-matrix-"));

  await execFileAsync("node", [
    path.join(root, "tools/ci/run-release-device-matrix.mjs"),
    "--platform",
    "android",
    "--report-dir",
    reportDir,
  ]);

  const report = JSON.parse(
    await readFile(path.join(reportDir, "release-device-matrix-android.json"), "utf8"),
  );
  const markdown = await readFile(path.join(reportDir, "release-device-matrix-android.md"), "utf8");

  assert.equal(report.platform, "android");
  assert.equal(report.status, "pending");
  assert.ok(report.summary.scenarios >= 10);
  assert.ok(report.scenarios.every((scenario) => scenario.status === "pending"));
  assert.ok(report.scenarios.every((scenario) => scenario.deviceProfiles.length >= 1));
  assert.match(markdown, /Release Candidate Device Matrix \(android\)/);
  assert.match(markdown, /permissions\.notifications\.allow-deny/);
  assert.match(markdown, /network\.slow-connection/);
});

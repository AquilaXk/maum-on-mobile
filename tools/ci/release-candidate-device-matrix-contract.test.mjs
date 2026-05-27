import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
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

test("release candidate device matrix gate fails when required physical evidence is missing", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-device-matrix-missing-"));

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, "tools/ci/run-release-device-matrix.mjs"),
      "--platform",
      "android",
      "--report-dir",
      reportDir,
      "--require-results",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /Missing release candidate device results/);
      return true;
    },
  );

  const report = JSON.parse(
    await readFile(path.join(reportDir, "release-device-matrix-android.json"), "utf8"),
  );

  assert.equal(report.status, "blocked");
  assert.ok(report.summary.pending > 0);
  assert.ok(report.failures.some((failure) => failure.reason === "missing_results"));
});

test("release candidate device matrix gate accepts pass and approved not applicable results", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-device-matrix-pass-"));
  const resultsPath = path.join(reportDir, "android-results.json");
  const resultDocument = buildPhysicalResultDocument("android");
  const notApplicable = resultDocument.results.find(
    (result) => result.scenario === "accessibility.screen-reader" && result.networkProfile === "slow-3g",
  );
  notApplicable.status = "not_applicable";
  notApplicable.notApplicableReason = "Screen reader verification is duplicated by the wifi run for the same physical build.";
  notApplicable.notApplicableApprovedBy = "release-manager@example.com";

  await writeFile(resultsPath, `${JSON.stringify(resultDocument, null, 2)}\n`);

  await execFileAsync("node", [
    path.join(root, "tools/ci/run-release-device-matrix.mjs"),
    "--platform",
    "android",
    "--report-dir",
    reportDir,
    "--results",
    resultsPath,
    "--require-results",
  ]);

  const report = JSON.parse(
    await readFile(path.join(reportDir, "release-device-matrix-android.json"), "utf8"),
  );
  const markdown = await readFile(path.join(reportDir, "release-device-matrix-android.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.equal(report.summary.fail, 0);
  assert.equal(report.summary.blocked, 0);
  assert.equal(report.summary.pending, 0);
  assert.ok(report.summary.not_applicable >= 1);
  assert.ok(report.scenarios.every((scenario) => ["pass", "not_applicable"].includes(scenario.status)));
  assert.match(markdown, /\| status \| pass \|/);
  assert.match(markdown, /release-manager@example\.com/);
});

test("release candidate device matrix gate requires issue links and retest flags for blocked results", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-device-matrix-blocked-"));
  const resultsPath = path.join(reportDir, "ios-results.json");
  const resultDocument = buildPhysicalResultDocument("ios");
  const blocked = resultDocument.results.find(
    (result) => result.scenario === "push.foreground-background-cold-start" && result.networkProfile === "wifi",
  );
  blocked.status = "blocked";
  blocked.issue = "";
  blocked.needsRetest = false;

  await writeFile(resultsPath, `${JSON.stringify(resultDocument, null, 2)}\n`);

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, "tools/ci/run-release-device-matrix.mjs"),
      "--platform",
      "ios",
      "--report-dir",
      reportDir,
      "--results",
      resultsPath,
      "--require-results",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /blocked results require issue and needsRetest=true/);
      return true;
    },
  );
});

test("ci runs physical device evidence gate only for release candidate flows", async () => {
  const workflow = read(".github/workflows/ci.yml");
  const releaseDeviceMatrix = jobBlock(workflow, "release-device-matrix");

  assert.match(releaseDeviceMatrix, /needs: changes/);
  assert.match(releaseDeviceMatrix, /github\.event_name == 'workflow_dispatch'/);
  assert.match(releaseDeviceMatrix, /startsWith\(github\.head_ref, 'release\/'\)/);
  assert.match(releaseDeviceMatrix, /startsWith\(github\.head_ref, 'rc\/'\)/);
  assert.match(releaseDeviceMatrix, /startsWith\(github\.ref, 'refs\/tags\/rc-'\)/);
  assert.match(releaseDeviceMatrix, /--require-results/);
  assert.match(releaseDeviceMatrix, /actions\/upload-artifact@[a-f0-9]{40}/);
});

function buildPhysicalResultDocument(platform) {
  const matrix = readContract();
  const platformConfig = matrix.platforms[platform];
  const deviceProfiles = platformConfig.deviceProfiles.filter((profile) => profile.required);
  const scenarios = matrix.scenarios.filter((scenario) => scenario.platforms.includes(platform));
  const results = [];

  for (const scenario of scenarios) {
    for (const profile of deviceProfiles) {
      for (const networkProfile of profile.networkProfiles) {
        results.push({
          platform,
          deviceProfile: profile.id,
          scenario: scenario.id,
          status: "pass",
          evidence: [`evidence/${platform}/${profile.id}/${networkProfile}/${scenario.id}.png`],
          notes: `${scenario.name} checked on ${profile.id}`,
          tester: "qa@example.com",
          buildNumber: `${platform}-release-42`,
          deviceModel: platform === "android" ? "Pixel 9" : "iPhone 16",
          osVersion: platform === "android" ? "Android 15" : "iOS 26.0",
          networkProfile,
          issue: "",
          needsRetest: false,
        });
      }
    }
  }

  return {
    platform,
    generatedAt: "2026-05-27T00:00:00.000Z",
    results,
  };
}

function jobBlock(workflow, jobId) {
  const expression = new RegExp(`\\n  ${escapeRegExp(jobId)}:\\n([\\s\\S]*?)(?=\\n  [a-zA-Z0-9_-]+:\\n|\\n*$)`);
  const match = workflow.match(expression);

  assert.ok(match, `Expected job '${jobId}' to exist`);

  return match[1];
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

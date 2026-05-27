import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const contractPath = "contracts/performance/release-performance-gate.json";
const runnerPath = "tools/ci/run-release-performance-gate.mjs";
const execFileAsync = promisify(execFile);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readContract() {
  const absolutePath = path.join(root, contractPath);
  assert.ok(existsSync(absolutePath), `${contractPath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

test("release performance gate contract ties app and backend budgets to one release", () => {
  const contract = readContract();

  assert.equal(contract.version, 1);
  assert.equal(contract.backendSmokeContract, "tools/ci/mobile-performance-gate.json");
  assert.deepEqual(Object.keys(contract.platforms).sort(), ["android", "ios"]);
  assert.ok(contract.releaseLinking.requiredFields.includes("releaseNumber"));
  assert.ok(contract.releaseLinking.requiredFields.includes("backendBuildNumber"));
  assert.ok(contract.releaseLinking.requiredFields.includes("androidBuildNumber"));
  assert.ok(contract.releaseLinking.requiredFields.includes("iosBuildNumber"));
  assert.ok(contract.releaseLinking.sameReleaseNumber === true);

  for (const [platform, config] of Object.entries(contract.platforms)) {
    assert.ok(
      config.deviceProfiles.some((profile) => profile.deviceType === "physical" && profile.required === true),
      `${platform} must require a physical device profile`,
    );
    assert.ok(config.requiredResultFields.includes("releaseNumber"));
    assert.ok(config.requiredResultFields.includes("buildNumber"));
    assert.ok(config.requiredResultFields.includes("deviceModel"));
    assert.ok(config.requiredResultFields.includes("osVersion"));
    assert.ok(config.requiredResultFields.includes("evidence"));
  }
});

test("release performance gate covers startup, scroll, media, consultation, network, and backend scenarios", () => {
  const contract = readContract();
  const scenarioIds = new Set(contract.scenarios.map((scenario) => scenario.id));

  for (const requiredScenario of [
    "app.cold-start",
    "app.first-interactive",
    "navigation.primary-screen-transition",
    "scroll.feed-jank",
    "media.image-attachment",
    "consultation.stream",
    "network.slow-3g-recovery",
    "network.packet-loss-retry",
    "network.offline-recovery",
    "write.duplicate-prevention",
    "backend.api-p95",
  ]) {
    assert.ok(scenarioIds.has(requiredScenario), `Missing release performance scenario: ${requiredScenario}`);
  }

  for (const scenario of contract.scenarios) {
    assert.match(scenario.priority, /^P[0-2]$/, `${scenario.id} must use P0/P1/P2 priority`);
    assert.ok(["android", "ios", "backend"].some((platform) => scenario.platforms.includes(platform)));
    assert.ok(scenario.budget, `${scenario.id} must declare a budget`);
    assert.ok(scenario.passCriteria.length > 0, `${scenario.id} must declare pass criteria`);
    assert.ok(scenario.evidenceRequired.length > 0, `${scenario.id} must declare required evidence`);
  }
});

test("release performance gate static evidence links to existing app and API performance controls", () => {
  const contract = readContract();
  const evidence = contract.staticEvidence ?? [];

  assert.ok(evidence.length >= 5);
  for (const item of evidence) {
    assert.ok(existsSync(path.join(root, item.file)), `Missing static evidence file: ${item.file}`);
    const contents = read(item.file);
    for (const pattern of item.patterns) {
      assert.match(contents, new RegExp(pattern, "m"), `${item.file} is missing ${pattern}`);
    }
  }
});

test("release performance gate runner writes pending reports without runtime evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-performance-"));

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "release-performance-report.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "release-performance-report.md"), "utf8");

  assert.equal(report.status, "pending");
  assert.equal(report.runtimeEvidence.status, "not_required");
  assert.ok(report.summary.scenarios >= 10);
  assert.match(markdown, /Release Performance Gate/);
  assert.match(markdown, /app\.cold-start/);
  assert.match(markdown, /backend\.api-p95/);
});

test("release performance gate fails release validation when runtime evidence is missing", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-performance-missing-"));

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--require-runtime-evidence",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /Missing release performance runtime evidence/);
      return true;
    },
  );

  const report = JSON.parse(await readFile(path.join(reportDir, "release-performance-report.json"), "utf8"));
  assert.equal(report.status, "blocked");
  assert.ok(report.failures.some((failure) => failure.reason === "missing_runtime_evidence"));
});

test("release performance gate accepts complete physical and backend runtime evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-performance-pass-"));
  const evidenceDir = path.join(reportDir, "runtime");
  await mkdir(evidenceDir, { recursive: true });
  const releaseNumber = "2026.05.27-rc1";

  await writeFile(
    path.join(evidenceDir, "release-performance-release.json"),
    `${JSON.stringify({
      releaseNumber,
      backendBuildNumber: "backend-410cd4b",
      androidBuildNumber: "android-20260527.1",
      iosBuildNumber: "ios-20260527.1",
      apiContractVersion: "mobile-api-v1",
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(evidenceDir, "release-performance-android-results.json"),
    `${JSON.stringify(buildPlatformResults("android", releaseNumber, "android-20260527.1"), null, 2)}\n`,
  );
  await writeFile(
    path.join(evidenceDir, "release-performance-ios-results.json"),
    `${JSON.stringify(buildPlatformResults("ios", releaseNumber, "ios-20260527.1"), null, 2)}\n`,
  );
  await writeFile(
    path.join(evidenceDir, "release-performance-backend-results.json"),
    `${JSON.stringify({
      platform: "backend",
      releaseNumber,
      buildNumber: "backend-410cd4b",
      results: [
        {
          scenario: "backend.api-p95",
          status: "pass",
          releaseNumber,
          buildNumber: "backend-410cd4b",
          p95LatencyMs: 1200,
          errorRate: 0,
          successRate: 1,
          evidence: ["build/reports/mobile-performance/mobile-performance-smoke.json"],
          notes: "Backend API p95 smoke stayed below the release budget.",
        },
      ],
    }, null, 2)}\n`,
  );

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
    "--runtime-evidence-dir",
    evidenceDir,
    "--require-runtime-evidence",
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "release-performance-report.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "release-performance-report.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.equal(report.release.releaseNumber, releaseNumber);
  assert.equal(report.summary.fail, 0);
  assert.equal(report.summary.blocked, 0);
  assert.equal(report.summary.pending, 0);
  assert.ok(report.scenarios.every((scenario) => scenario.status === "pass"));
  assert.match(markdown, /releaseNumber/);
});

test("release performance gate flags budget breaches and duplicate write regressions", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-performance-fail-"));
  const evidenceDir = path.join(reportDir, "runtime");
  await mkdir(evidenceDir, { recursive: true });
  const releaseNumber = "2026.05.27-rc2";
  const androidResults = buildPlatformResults("android", releaseNumber, "android-20260527.2");
  const slowNetwork = androidResults.results.find((result) => result.scenario === "network.slow-3g-recovery");
  slowNetwork.status = "pass";
  slowNetwork.recoveryMs = 7000;
  const duplicatePrevention = androidResults.results.find((result) => result.scenario === "write.duplicate-prevention");
  duplicatePrevention.duplicateWrites = 1;

  await writeFile(
    path.join(evidenceDir, "release-performance-release.json"),
    `${JSON.stringify({
      releaseNumber,
      backendBuildNumber: "backend-410cd4b",
      androidBuildNumber: "android-20260527.2",
      iosBuildNumber: "ios-20260527.2",
      apiContractVersion: "mobile-api-v1",
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(evidenceDir, "release-performance-android-results.json"),
    `${JSON.stringify(androidResults, null, 2)}\n`,
  );
  await writeFile(
    path.join(evidenceDir, "release-performance-ios-results.json"),
    `${JSON.stringify(buildPlatformResults("ios", releaseNumber, "ios-20260527.2"), null, 2)}\n`,
  );
  await writeFile(
    path.join(evidenceDir, "release-performance-backend-results.json"),
    `${JSON.stringify({
      platform: "backend",
      releaseNumber,
      buildNumber: "backend-410cd4b",
      results: [
        {
          scenario: "backend.api-p95",
          status: "pass",
          releaseNumber,
          buildNumber: "backend-410cd4b",
          p95LatencyMs: 1200,
          errorRate: 0,
          successRate: 1,
          evidence: ["build/reports/mobile-performance/mobile-performance-smoke.json"],
          notes: "Backend API p95 smoke stayed below the release budget.",
        },
      ],
    }, null, 2)}\n`,
  );

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--runtime-evidence-dir",
      evidenceDir,
      "--require-runtime-evidence",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /budget exceeded/);
      assert.match(error.stderr, /duplicate writes must be zero/);
      return true;
    },
  );
});

test("ci workflow publishes performance reports and wires the release performance job", () => {
  const workflow = read(".github/workflows/ci.yml");

  assert.match(workflow, /Upload mobile performance smoke report/);
  assert.match(workflow, /path: build\/reports\/mobile-performance\/mobile-performance-smoke\.json/);
  assert.match(workflow, /release-performance-gate:/);
  assert.match(workflow, /name: Release Performance Gate/);
  assert.match(workflow, /node tools\/ci\/run-release-performance-gate\.mjs/);
  assert.match(workflow, /--runtime-evidence-dir contracts\/performance\/runtime-evidence/);
  assert.match(workflow, /name: release-performance/);
});

function buildPlatformResults(platform, releaseNumber, buildNumber) {
  return {
    platform,
    releaseNumber,
    buildNumber,
    results: [
      measuredResult(platform, "app.cold-start", releaseNumber, buildNumber, {
        coldStartMs: 1500,
        firstFrameMs: 900,
      }),
      measuredResult(platform, "app.first-interactive", releaseNumber, buildNumber, {
        firstInteractiveMs: 1700,
      }),
      measuredResult(platform, "navigation.primary-screen-transition", releaseNumber, buildNumber, {
        transitionMs: 220,
      }),
      measuredResult(platform, "scroll.feed-jank", releaseNumber, buildNumber, {
        jankPercent: 1.2,
        p95FrameMs: 16,
        memoryGrowthMb: 18,
      }),
      measuredResult(platform, "media.image-attachment", releaseNumber, buildNumber, {
        imageAttachMs: 1200,
        memoryGrowthMb: 22,
      }),
      measuredResult(platform, "consultation.stream", releaseNumber, buildNumber, {
        firstChunkMs: 1100,
        streamRecoveryMs: 1800,
      }),
      measuredResult(platform, "network.slow-3g-recovery", releaseNumber, buildNumber, {
        recoveryMs: 3000,
        duplicateWrites: 0,
      }, "slow-3g"),
      measuredResult(platform, "network.packet-loss-retry", releaseNumber, buildNumber, {
        recoveryMs: 2800,
        duplicateWrites: 0,
      }, "lossy"),
      measuredResult(platform, "network.offline-recovery", releaseNumber, buildNumber, {
        recoveryMs: 3200,
        duplicateWrites: 0,
      }, "offline-return"),
      measuredResult(platform, "write.duplicate-prevention", releaseNumber, buildNumber, {
        duplicateWrites: 0,
        idempotencyHits: 1,
      }),
    ],
  };
}

function measuredResult(platform, scenario, releaseNumber, buildNumber, measurements, networkProfile = "wifi") {
  return {
    scenario,
    status: "pass",
    releaseNumber,
    buildNumber,
    deviceProfile: `${platform}-physical-primary`,
    networkProfile,
    deviceModel: platform === "android" ? "Pixel 8 physical" : "iPhone 15 physical",
    osVersion: platform === "android" ? "Android 15" : "iOS 26.0",
    evidence: [`perf/${platform}/${scenario}.json`],
    notes: "Measured on the release candidate physical-device run.",
    ...measurements,
  };
}

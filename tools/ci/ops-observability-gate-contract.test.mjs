import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const contractPath = "contracts/ops/observability-gate.json";
const runnerPath = "tools/ci/run-ops-observability-gate.mjs";
const execFileAsync = promisify(execFile);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  assert.ok(existsSync(absolutePath), `${relativePath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

test("ops observability contract covers alert rules, release linkage, and policy ownership", () => {
  const contract = readJson(contractPath);

  assert.equal(contract.version, 1);
  assert.deepEqual(contract.alertRules.map((rule) => rule.id).sort(), [
    "ai_fallback_rate",
    "android_anr",
    "api_error_rate",
    "api_p95_latency",
    "fatal_crash",
    "push_permanent_failure",
  ]);
  assert.deepEqual(contract.releaseTracking.platforms.sort(), [
    "android_vitals",
    "app_store_crash",
    "backend_metrics",
  ]);

  for (const policy of contract.alertPolicies) {
    assert.match(policy.receiver, /^ops-/);
    assert.ok(policy.severity.length > 0);
    assert.ok(policy.escalationOwner.length > 0);
    assert.ok(policy.silencePolicy.length > 0);
  }

  for (const blocker of [
    "missing_required_evidence",
    "alert_policy_missing",
    "missing_runtime_evidence",
    "runtime_alert_failed",
  ]) {
    assert.ok(contract.releaseBlockers.includes(blocker), `Missing release blocker: ${blocker}`);
  }
});

test("ops observability runner writes static alert evidence reports", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-ops-observability-"));

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "ops-observability-report.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "ops-observability-report.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.equal(report.failures.length, 0);
  assert.equal(report.staticEvidence.status, "pass");
  assert.equal(report.alertPolicies.status, "pass");
  assert.equal(report.runtimeEvidence.status, "not_required");
  assert.ok(report.alertRules.some((rule) => rule.id === "fatal_crash"));
  assert.ok(report.alertRules.some((rule) => rule.id === "android_anr"));
  assert.match(markdown, /Ops Observability Gate/);
  assert.match(markdown, /Alert Rules/);
  assert.match(markdown, /Runtime Evidence/);
});

test("ops observability runner fails when alert ownership policy is incomplete", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-ops-observability-policy-"));
  const tempDir = await mkdtemp(path.join(tmpdir(), "maum-ops-observability-contract-"));
  const contract = readJson(contractPath);
  contract.alertPolicies[0].receiver = "";
  const tempContractPath = path.join(tempDir, "observability-gate.json");
  await writeFile(tempContractPath, `${JSON.stringify(contract, null, 2)}\n`);

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--config",
      tempContractPath,
      "--report-dir",
      reportDir,
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /alert_policy_missing/);
      return true;
    },
  );
});

test("ops observability runner fails release candidates without runtime alert evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-ops-observability-runtime-missing-"));
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-ops-observability-runtime-"));

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--runtime-evidence-dir",
      runtimeDir,
      "--require-runtime-evidence",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /missing_runtime_evidence/);
      return true;
    },
  );
});

test("ops observability runner fails failed alert routing scenarios", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-ops-observability-runtime-fail-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures({
    alertOverrides: {
      fatal_crash_alert: "fail",
    },
  });

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--runtime-evidence-dir",
      runtimeDir,
      "--require-runtime-evidence",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /runtime_alert_failed/);
      return true;
    },
  );
});

test("ops observability runner accepts complete runtime alert evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-ops-observability-runtime-pass-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures();

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
    "--runtime-evidence-dir",
    runtimeDir,
    "--require-runtime-evidence",
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "ops-observability-report.json"), "utf8"));

  assert.equal(report.status, "pass");
  assert.equal(report.runtimeEvidence.status, "pass");
});

test("backend and operations UI expose sanitized release observability signals", () => {
  const telemetry = read("back/src/main/kotlin/com/maumonmobile/domain/telemetry/MobileClientTelemetry.kt");
  const telemetryTest = read("back/src/test/kotlin/com/maumonmobile/application/service/MobileTelemetryServiceTest.kt");
  const metricsRegistry = read("back/src/main/kotlin/com/maumonmobile/global/observability/MobileApiMetricsRegistry.kt");
  const operationsScreen = read("front/lib/features/operations/presentation/operations_screen.dart");
  const operationsModels = read("front/lib/features/operations/domain/operations_models.dart");
  const operationsTest = read("front/test/features/operations/operations_screen_test.dart");

  assert.match(telemetry, /CRASH_SIGNAL/);
  assert.match(telemetry, /ANR_SIGNAL/);
  assert.match(telemetryTest, /doesNotContain\("leak@example.com"\)/);
  assert.match(metricsRegistry, /recordPushDelivery/);
  assert.match(metricsRegistry, /recordAiModel/);
  assert.match(operationsScreen, /최근 장애 원인/);
  assert.match(operationsModels, /Crash signal/);
  assert.match(operationsModels, /ANR signal/);
  assert.match(operationsTest, /find\.text\('최근 장애 원인'\)/);
});

test("ci runs ops observability gate only for release candidate flows", () => {
  const workflow = read(".github/workflows/ci.yml");
  const releaseOpsObservability = jobBlock(workflow, "release-ops-observability");

  assert.match(workflow, /release_candidate_ops_gate_mode:/);
  assert.match(workflow, /release_ops_evidence_results_dir:/);
  assert.match(releaseOpsObservability, /needs: changes/);
  assert.match(releaseOpsObservability, /github\.event_name == 'workflow_dispatch'/);
  assert.match(releaseOpsObservability, /startsWith\(github\.head_ref, 'release\/'\)/);
  assert.match(releaseOpsObservability, /startsWith\(github\.head_ref, 'rc\/'\)/);
  assert.match(releaseOpsObservability, /startsWith\(github\.ref, 'refs\/tags\/rc-'\)/);
  assert.match(releaseOpsObservability, /run-ops-observability-gate\.mjs/);
  assert.match(releaseOpsObservability, /--require-runtime-evidence/);
  assert.match(releaseOpsObservability, /actions\/upload-artifact@[a-f0-9]{40}/);
});

async function writeRuntimeEvidenceFixtures(options = {}) {
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-ops-observability-runtime-fixtures-"));
  const passScenario = (id) => ({
    id,
    status: options.alertOverrides?.[id] ?? "pass",
    receiver: "ops-release-primary",
    evidenceUrl: `https://evidence.example.com/${id}`,
  });

  await writeFile(
    path.join(runtimeDir, "ops-alert-routing-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("fatal_crash_alert"),
        passScenario("anr_alert"),
        passScenario("api_p95_alert"),
        passScenario("api_error_rate_alert"),
        passScenario("push_permanent_failure_alert"),
        passScenario("ai_fallback_alert"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "ops-release-health-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("android_vitals_release_linked"),
        passScenario("app_store_crash_release_linked"),
        passScenario("backend_metrics_release_linked"),
        passScenario("alert_receiver_configured"),
      ],
    }, null, 2)}\n`,
  );

  return runtimeDir;
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

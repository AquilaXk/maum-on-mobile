import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const contractPath = "contracts/support/release-support-readiness.json";
const runnerPath = "tools/ci/run-support-readiness-gate.mjs";
const execFileAsync = promisify(execFile);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  assert.ok(existsSync(absolutePath), `${relativePath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

test("support readiness contract covers support, privacy, incident, review, and diagnostics ownership", () => {
  const contract = readJson(contractPath);

  assert.equal(contract.version, 1);
  assert.equal(contract.contacts.supportEmail, "support@maum-on.app");
  assert.equal(contract.contacts.privacyEmail, "privacy@maum-on.app");
  assert.equal(contract.contacts.supportUrl, "https://maum-on.app/support");
  assert.equal(contract.contacts.incidentNoticeUrl, "https://maum-on.app/status");
  assert.equal(contract.reviewResponse.owner, "mobile-release-owner");
  assert.match(contract.reviewResponse.contactEmail, /^[^@\s]+@[^@\s]+\.[^@\s]+$/);
  assert.ok(contract.reviewResponse.responseSlaHours <= 24);
  assert.equal(contract.reviewResponse.appStoreReviewStatus, "ready");
  assert.equal(contract.reviewResponse.googlePlayReviewStatus, "ready");
  assert.deepEqual(contract.diagnostics.requiredFields, [
    "appVersion",
    "buildNumber",
    "platform",
    "locale",
  ]);

  for (const forbiddenField of ["email", "memberId", "token", "password", "authorization"]) {
    assert.ok(contract.diagnostics.forbiddenFields.includes(forbiddenField));
  }

  for (const blocker of [
    "missing_support_contact",
    "support_contact_mismatch",
    "missing_static_evidence",
    "missing_runtime_evidence",
    "runtime_support_flow_failed",
  ]) {
    assert.ok(contract.releaseBlockers.includes(blocker), `Missing release blocker: ${blocker}`);
  }
});

test("support readiness runner writes reports without runtime evidence outside release mode", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-support-readiness-"));

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "support-readiness-report.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "support-readiness-report.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.equal(report.failures.length, 0);
  assert.equal(report.contacts.status, "pass");
  assert.equal(report.reviewResponse.status, "pass");
  assert.equal(report.diagnostics.status, "pass");
  assert.equal(report.staticEvidence.status, "pass");
  assert.equal(report.runtimeEvidence.status, "not_required");
  assert.match(markdown, /Support Readiness Gate/);
  assert.match(markdown, /Support Contacts/);
  assert.match(markdown, /Runtime Evidence/);
});

test("support readiness runner fails when store support email drifts from the contract", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-support-readiness-drift-"));
  const tempDir = await mkdtemp(path.join(tmpdir(), "maum-support-readiness-contract-"));
  const contract = readJson(contractPath);
  contract.contacts.supportEmail = "other@example.com";
  const tempContractPath = path.join(tempDir, "release-support-readiness.json");
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
      assert.match(error.stderr, /support_contact_mismatch/);
      return true;
    },
  );
});

test("support readiness runner fails release candidates without runtime support evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-support-readiness-runtime-missing-"));
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-support-readiness-runtime-"));

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

test("support readiness runner fails failed inquiry and review response scenarios", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-support-readiness-runtime-fail-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures({
    failedScenario: "settings_diagnostics_copy_sanitized",
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
      assert.match(error.stderr, /runtime_support_flow_failed/);
      return true;
    },
  );
});

test("support readiness runner accepts complete runtime support evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-support-readiness-runtime-pass-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures();

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
    "--runtime-evidence-dir",
    runtimeDir,
    "--require-runtime-evidence",
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "support-readiness-report.json"), "utf8"));

  assert.equal(report.status, "pass");
  assert.equal(report.runtimeEvidence.status, "pass");
});

test("app and operations surfaces expose support contacts and sanitized diagnostics", () => {
  const legal = read("front/lib/features/legal/domain/legal_disclosures.dart");
  const settingsScreen = read("front/lib/features/settings/presentation/settings_screen.dart");
  const settingsTest = read("front/test/features/settings/settings_screen_test.dart");
  const operationsScreen = read("front/lib/features/operations/presentation/operations_screen.dart");
  const operationsTest = read("front/test/features/operations/operations_screen_test.dart");

  assert.match(legal, /privacyEmail = 'privacy@maum-on\.app'/);
  assert.match(legal, /incidentNoticeUrl = 'https:\/\/maum-on\.app\/status'/);
  assert.match(settingsScreen, /settings-support-contact-button/);
  assert.match(settingsScreen, /settings-privacy-contact-button/);
  assert.match(settingsScreen, /settings-incident-notice-button/);
  assert.match(settingsScreen, /settings-copy-diagnostics/);
  assert.match(settingsScreen, /SupportDiagnosticInfo/);
  assert.match(settingsTest, /isNot\(contains\('me@example\.com'\)\)/);
  assert.match(operationsScreen, /심사 대응/);
  assert.match(operationsScreen, /App Store review/);
  assert.match(operationsScreen, /Google Play review/);
  assert.match(operationsTest, /operations-review-support-card/);
});

test("ci runs support readiness gate only for release candidate ops flows without adding workflow inputs", () => {
  const workflow = read(".github/workflows/ci.yml");
  const workflowDispatchInputs = workflow.match(/\n  workflow_dispatch:\n    inputs:\n([\s\S]*?)\npermissions:/);
  assert.ok(workflowDispatchInputs, "workflow_dispatch inputs must be present");

  const inputCount = [...workflowDispatchInputs[1].matchAll(/^      [a-zA-Z0-9_]+:/gm)].length;
  assert.ok(inputCount <= 25, `workflow_dispatch input count must stay within GitHub's limit: ${inputCount}`);
  assert.doesNotMatch(workflow, /release_candidate_support/);

  const job = jobBlock(workflow, "release-support-readiness");

  assert.match(job, /needs: changes/);
  assert.match(job, /github\.event_name == 'workflow_dispatch'/);
  assert.match(job, /inputs\.release_candidate_ops_gate_mode == 'validate'/);
  assert.match(job, /startsWith\(github\.head_ref, 'release\/'\)/);
  assert.match(job, /startsWith\(github\.head_ref, 'rc\/'\)/);
  assert.match(job, /startsWith\(github\.ref, 'refs\/tags\/rc-'\)/);
  assert.match(job, /run-support-readiness-gate\.mjs/);
  assert.match(job, /--require-runtime-evidence/);
  assert.match(job, /actions\/upload-artifact@[a-f0-9]{40}/);
});

async function writeRuntimeEvidenceFixtures(options = {}) {
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-support-readiness-runtime-fixtures-"));
  const passScenario = (id) => ({
    id,
    status: options.failedScenario === id ? "fail" : "pass",
    evidenceUrl: `https://evidence.example.com/${id}`,
  });

  await writeFile(
    path.join(runtimeDir, "support-inquiry-flow-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("settings_support_email_opened"),
        passScenario("settings_privacy_email_opened"),
        passScenario("settings_diagnostics_copy_sanitized"),
        passScenario("incident_notice_opened"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "review-response-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("app_store_review_contact_verified"),
        passScenario("google_play_review_contact_verified"),
        passScenario("incident_notice_ready"),
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

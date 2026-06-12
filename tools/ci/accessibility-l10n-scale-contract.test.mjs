import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const contractPath = "contracts/accessibility/l10n-scale-gate.json";
const runnerPath = "tools/ci/run-accessibility-l10n-scale-gate.mjs";
const execFileAsync = promisify(execFile);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  assert.ok(existsSync(absolutePath), `${relativePath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

test("accessibility l10n scale contract covers core screens, criteria, and release blockers", () => {
  const contract = readJson(contractPath);

  assert.equal(contract.version, 1);
  assert.equal(contract.locale, "ko-KR");
  for (const blocker of [
    "missing_accessibility_answer",
    "missing_static_evidence",
    "term_mismatch",
    "missing_runtime_evidence",
    "runtime_accessibility_smoke_failed",
  ]) {
    assert.ok(contract.releaseBlockers.includes(blocker), `Missing release blocker: ${blocker}`);
  }

  assert.deepEqual(
    contract.screens.map((screen) => screen.id).sort(),
    ["consultation", "diary", "home", "letter", "notifications", "settings", "story"],
  );
  for (const screen of contract.screens) {
    assert.ok(screen.routeKey.length > 0, `${screen.id} must map a route key`);
    assert.ok(screen.semanticLabels.length > 0, `${screen.id} must declare semantic labels`);
    assert.ok(screen.screenshotCandidate === true, `${screen.id} must be a screenshot candidate`);
  }

  assert.deepEqual(Object.keys(contract.criteria).sort(), [
    "contrast",
    "keyboardAutofill",
    "screenReader",
    "textScale",
    "touchTarget",
  ]);
  assert.deepEqual(contract.criteria.textScale.requiredScales, [1, 1.5, 2]);
  assert.equal(contract.criteria.touchTarget.minimumDp, 48);
  assert.ok(contract.terminology.length >= 8);
  assert.equal(contract.runtimeEvidence.requiredFiles.length, 3);
});

test("accessibility l10n scale runner writes reports without runtime evidence outside release mode", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-a11y-l10n-scale-"));

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "accessibility-l10n-scale-report.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "accessibility-l10n-scale-report.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.equal(report.failures.length, 0);
  assert.equal(report.screens.status, "pass");
  assert.equal(report.criteria.status, "pass");
  assert.equal(report.terminology.status, "pass");
  assert.equal(report.staticEvidence.status, "pass");
  assert.equal(report.runtimeEvidence.status, "not_required");
  assert.match(markdown, /Accessibility L10n Scale/);
  assert.match(markdown, /Core Screens/);
  assert.match(markdown, /Terminology/);
});

test("accessibility l10n scale runner fails when required static evidence is missing", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-a11y-missing-static-"));
  const tempDir = await mkdtemp(path.join(tmpdir(), "maum-a11y-contract-"));
  const contract = readJson(contractPath);
  contract.staticEvidence[0].evidenceItems[0].patterns = ["__missing_accessibility_pattern__"];
  const tempContractPath = path.join(tempDir, "l10n-scale-gate.json");
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
      assert.match(error.stderr, /missing_static_evidence/);
      return true;
    },
  );
});

test("accessibility l10n scale runner fails when a canonical term is not present in store and app evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-a11y-term-mismatch-"));
  const tempDir = await mkdtemp(path.join(tmpdir(), "maum-a11y-term-contract-"));
  const contract = readJson(contractPath);
  contract.terminology[0].canonical = "__missing_store_term__";
  const tempContractPath = path.join(tempDir, "l10n-scale-gate.json");
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
      assert.match(error.stderr, /term_mismatch/);
      return true;
    },
  );
});

test("accessibility l10n scale runner fails release candidates without runtime evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-a11y-runtime-missing-"));
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-a11y-runtime-"));

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

test("accessibility l10n scale runner fails failed runtime accessibility smoke evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-a11y-runtime-failed-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures({ failedScenario: "ios_text_scale_200" });

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
      assert.match(error.stderr, /runtime_accessibility_smoke_failed/);
      return true;
    },
  );
});

test("accessibility l10n scale runner accepts complete runtime accessibility evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-a11y-runtime-pass-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures();

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
    "--runtime-evidence-dir",
    runtimeDir,
    "--require-runtime-evidence",
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "accessibility-l10n-scale-report.json"), "utf8"));

  assert.equal(report.status, "pass");
  assert.equal(report.runtimeEvidence.status, "pass");
});

test("repository exposes accessibility, large text, touch target, and autofill evidence", () => {
  assert.match(read("front/test/theme/app_design_system_test.dart"), /TextScaler\.linear\(1\.3\)/);
  assert.match(read("front/test/quality/mobile_quality_gate_test.dart"), /textScale: 1\.35/);
  assert.match(read("front/test/features/moderation/content_moderation_feedback_panel_test.dart"), /TextScaler\.linear\(1\.8\)/);
  assert.match(read("front/test/features/story/story_screen_test.dart"), /greaterThanOrEqualTo\(48\)/);
  assert.match(read("front/lib/theme/app_theme.dart"), /minimumSize: const Size\(48, 52\)/);
  assert.match(read("front/lib/features/auth/presentation/auth_screen.dart"), /AutofillHints\.email/);
  assert.match(read("front/lib/features/auth/presentation/auth_screen.dart"), /TextInputAction\.done/);
});

test("ci runs accessibility l10n scale gate only for release candidate flows without adding workflow inputs", () => {
  const workflow = read(".github/workflows/ci.yml");
  const workflowDispatchInputs = workflow.match(/\n  workflow_dispatch:\n    inputs:\n([\s\S]*?)\npermissions:/);
  assert.ok(workflowDispatchInputs, "workflow_dispatch inputs must be present");

  const inputCount = [...workflowDispatchInputs[1].matchAll(/^      [a-zA-Z0-9_]+:/gm)].length;
  assert.ok(inputCount <= 25, `workflow_dispatch input count must stay within GitHub's limit: ${inputCount}`);
  assert.doesNotMatch(workflow, /release_candidate_accessibility/);

  const job = jobBlock(workflow, "release-accessibility-l10n-scale");

  assert.match(job, /needs: changes/);
  assert.match(job, /github\.event_name == 'workflow_dispatch'/);
  assert.match(job, /inputs\.release_candidate_device_matrix_mode == 'validate'/);
  assert.match(job, /startsWith\(github\.head_ref, 'release\/'\)/);
  assert.match(job, /startsWith\(github\.head_ref, 'rc\/'\)/);
  assert.match(job, /startsWith\(github\.ref, 'refs\/tags\/rc-'\)/);
  assert.match(job, /run-accessibility-l10n-scale-gate\.mjs/);
  assert.match(job, /--require-runtime-evidence/);
  assert.match(job, /actions\/upload-artifact@[a-f0-9]{40}/);
});

async function writeRuntimeEvidenceFixtures(options = {}) {
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-a11y-runtime-fixtures-"));
  const passScenario = (id) => ({
    id,
    status: options.failedScenario === id ? "fail" : "pass",
    evidenceUrl: `https://evidence.example.com/${id}`,
  });

  await writeFile(
    path.join(runtimeDir, "accessibility-text-scale-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("android_text_scale_100"),
        passScenario("android_text_scale_150"),
        passScenario("android_text_scale_200"),
        passScenario("ios_text_scale_100"),
        passScenario("ios_text_scale_150"),
        passScenario("ios_text_scale_200"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "accessibility-screen-reader-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("talkback_core_flow"),
        passScenario("voiceover_core_flow"),
        passScenario("focus_order_store_screenshots"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "accessibility-visual-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("contrast_smoke"),
        passScenario("touch_target_smoke"),
        passScenario("screenshot_candidate_terms"),
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

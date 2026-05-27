import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const contractPath = "contracts/store-content/app-content-permissions.json";
const runnerPath = "tools/ci/run-store-content-policy-gate.mjs";
const execFileAsync = promisify(execFile);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  assert.ok(existsSync(absolutePath), `${relativePath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

test("store content policy contract covers survey answers, owners, permissions, and UGC controls", () => {
  const contract = readJson(contractPath);

  assert.equal(contract.version, 1);
  for (const blocker of [
    "missing_store_answer",
    "missing_store_owner",
    "permission_manifest_mismatch",
    "missing_policy_evidence",
    "missing_runtime_evidence",
    "runtime_policy_smoke_failed",
  ]) {
    assert.ok(contract.releaseBlockers.includes(blocker), `Missing release blocker: ${blocker}`);
  }

  assert.deepEqual(
    [...new Set(contract.playConsole.answers.map((answer) => answer.section))].sort(),
    [
      "ads",
      "app_access",
      "content_rating",
      "data_safety",
      "permissions",
      "target_audience",
      "user_generated_content",
    ],
  );
  assert.deepEqual(
    [...new Set(contract.appStoreConnect.answers.map((answer) => answer.section))].sort(),
    [
      "age_rating",
      "app_information",
      "app_review_information",
      "encryption",
      "privacy",
      "user_generated_content",
    ],
  );

  for (const group of [contract.playConsole, contract.appStoreConnect]) {
    for (const answer of group.answers) {
      assert.ok(answer.id?.trim(), "Store answer must have id");
      assert.ok(answer.section?.trim(), `${answer.id} must have section`);
      assert.ok(answer.question?.trim(), `${answer.id} must have question`);
      assert.ok(answer.owner?.trim(), `${answer.id} must have owner`);
      assert.ok(answer.answer !== undefined && answer.answer !== null, `${answer.id} must have answer`);
      assert.ok(answer.evidence.length > 0, `${answer.id} must have evidence`);
    }
  }

  assert.deepEqual(
    contract.permissionDeclarations.map((permission) => permission.id).sort(),
    ["camera", "photos", "push_notifications"],
  );
  for (const permission of contract.permissionDeclarations) {
    assert.ok(permission.usageRationale.length > 0, `${permission.id} must have usage rationale`);
    assert.ok(permission.storeAnswerIds.playConsole.length > 0, `${permission.id} must link Play answers`);
    assert.ok(permission.storeAnswerIds.appStoreConnect.length > 0, `${permission.id} must link App Store answers`);
    assert.ok(permission.recoveryEvidence.length > 0, `${permission.id} must link permission recovery UI`);
  }

  assert.equal(contract.runtimeEvidence.requiredFiles.length, 3);
});

test("store content policy runner writes survey, permission, policy, and runtime reports", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-store-content-policy-"));

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "store-content-policy-report.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "store-content-policy-report.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.equal(report.failures.length, 0);
  assert.equal(report.playConsole.status, "pass");
  assert.equal(report.appStoreConnect.status, "pass");
  assert.equal(report.permissionDeclarations.status, "pass");
  assert.equal(report.policyEvidence.status, "pass");
  assert.equal(report.runtimeEvidence.status, "not_required");
  assert.match(markdown, /Store Content Policy/);
  assert.match(markdown, /Permission Declarations/);
  assert.match(markdown, /UGC Policy Evidence/);
});

test("store content policy runner fails when a store answer owner is missing", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-store-content-owner-missing-"));
  const tempDir = await mkdtemp(path.join(tmpdir(), "maum-store-content-contract-"));
  const contract = readJson(contractPath);
  contract.playConsole.answers[0].owner = "";
  const tempContractPath = path.join(tempDir, "app-content-permissions.json");
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
      assert.match(error.stderr, /missing_store_owner/);
      return true;
    },
  );
});

test("store content policy runner fails when permission declarations do not match native manifests", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-store-content-permission-mismatch-"));
  const tempDir = await mkdtemp(path.join(tmpdir(), "maum-store-content-permission-contract-"));
  const contract = readJson(contractPath);
  contract.permissionDeclarations.find((permission) => permission.id === "camera").androidPermissions = [
    "android.permission.RECORD_AUDIO",
  ];
  const tempContractPath = path.join(tempDir, "app-content-permissions.json");
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
      assert.match(error.stderr, /permission_manifest_mismatch/);
      return true;
    },
  );
});

test("store content policy runner fails release candidates without runtime evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-store-content-runtime-missing-"));
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-store-content-runtime-"));

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

test("store content policy runner fails when runtime policy smoke evidence fails", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-store-content-runtime-failed-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures({ failedScenario: "admin_report_action_smoke" });

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
      assert.match(error.stderr, /runtime_policy_smoke_failed/);
      return true;
    },
  );
});

test("store content policy runner accepts complete release runtime evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-store-content-runtime-pass-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures();

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
    "--runtime-evidence-dir",
    runtimeDir,
    "--require-runtime-evidence",
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "store-content-policy-report.json"), "utf8"));

  assert.equal(report.status, "pass");
  assert.equal(report.runtimeEvidence.status, "pass");
});

test("repository exposes permission recovery and UGC policy evidence used by store answers", () => {
  assert.match(read("front/lib/features/diary/presentation/diary_screen.dart"), /diary-image-settings-button/);
  assert.match(read("front/lib/features/notification/presentation/notification_report_screen.dart"), /PushNotificationState\.denied/);
  assert.match(read("front/lib/features/notification/application/notification_controller.dart"), /openPushNotificationSettings/);
  assert.match(read("front/lib/features/report/application/report_controller.dart"), /createReport/);
  assert.match(read("front/lib/features/report/application/report_controller.dart"), /_ensureModerationAllowed/);
  assert.match(read("back/src/main/kotlin/com/maumonmobile/application/service/ReportService.kt"), /REPORT_STATUS_CHANGE/);
  assert.match(read("back/src/main/kotlin/com/maumonmobile/application/service/AdminOperationsService.kt"), /blockLetterSender/);
  assert.match(read("back/src/main/kotlin/com/maumonmobile/application/service/ContentModerationService.kt"), /ContentModerationClassification\.safeFallback/);
  assert.match(read("front/lib/features/moderation/presentation/content_moderation_feedback_panel.dart"), /콘텐츠 검수 차단 안내/);
});

test("ci runs store content policy gate only for release candidate flows without adding workflow inputs", () => {
  const workflow = read(".github/workflows/ci.yml");
  const workflowDispatchInputs = workflow.match(/\n  workflow_dispatch:\n    inputs:\n([\s\S]*?)\npermissions:/);
  assert.ok(workflowDispatchInputs, "workflow_dispatch inputs must be present");

  const inputCount = [...workflowDispatchInputs[1].matchAll(/^      [a-zA-Z0-9_]+:/gm)].length;
  assert.ok(inputCount <= 25, `workflow_dispatch input count must stay within GitHub's limit: ${inputCount}`);
  assert.doesNotMatch(workflow, /release_candidate_store_content/);

  const releaseStoreContentPolicy = jobBlock(workflow, "release-store-content-policy");

  assert.match(releaseStoreContentPolicy, /needs: changes/);
  assert.match(releaseStoreContentPolicy, /github\.event_name == 'workflow_dispatch'/);
  assert.match(releaseStoreContentPolicy, /inputs\.release_candidate_privacy_gate_mode == 'validate'/);
  assert.match(releaseStoreContentPolicy, /startsWith\(github\.head_ref, 'release\/'\)/);
  assert.match(releaseStoreContentPolicy, /startsWith\(github\.head_ref, 'rc\/'\)/);
  assert.match(releaseStoreContentPolicy, /startsWith\(github\.ref, 'refs\/tags\/rc-'\)/);
  assert.match(releaseStoreContentPolicy, /run-store-content-policy-gate\.mjs/);
  assert.match(releaseStoreContentPolicy, /--require-runtime-evidence/);
  assert.match(releaseStoreContentPolicy, /actions\/upload-artifact@[a-f0-9]{40}/);
});

async function writeRuntimeEvidenceFixtures(options = {}) {
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-store-content-runtime-fixtures-"));
  const passScenario = (id) => ({
    id,
    status: options.failedScenario === id ? "fail" : "pass",
    evidenceUrl: `https://evidence.example.com/${id}`,
  });

  await writeFile(
    path.join(runtimeDir, "store-content-survey-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("play_app_content_reviewed"),
        passScenario("app_store_reviewed"),
        passScenario("permission_answers_matched"),
        passScenario("ugc_policy_reviewed"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "permission-recovery-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("android_camera_denied_settings"),
        passScenario("android_photos_denied_settings"),
        passScenario("android_notifications_denied_settings"),
        passScenario("ios_camera_denied_settings"),
        passScenario("ios_photos_denied_settings"),
        passScenario("ios_notifications_denied_settings"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "ugc-policy-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("report_submit_smoke"),
        passScenario("admin_report_action_smoke"),
        passScenario("block_member_smoke"),
        passScenario("moderation_filter_smoke"),
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

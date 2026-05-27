import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const contractPath = "contracts/privacy/lifecycle-evidence.json";
const runnerPath = "tools/ci/run-privacy-lifecycle-evidence.mjs";
const execFileAsync = promisify(execFile);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  assert.ok(existsSync(absolutePath), `${relativePath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

test("privacy lifecycle contract maps store privacy categories to deletion and export evidence", () => {
  const contract = readJson(contractPath);
  const storePrivacy = readJson(contract.storePrivacyContract);

  assert.equal(contract.version, 1);
  assert.deepEqual(
    contract.categories.map((category) => category.id).sort(),
    storePrivacy.dataCategories.map((category) => category.id).sort(),
  );

  for (const blocker of [
    "missing_required_evidence",
    "store_privacy_category_mismatch",
    "active_export_after_withdrawal",
    "residual_file_leftover",
  ]) {
    assert.ok(contract.releaseBlockers.includes(blocker), `Missing release blocker: ${blocker}`);
  }

  const categories = new Map(contract.categories.map((category) => [category.id, category]));
  assert.deepEqual(
    categories.get("account_info").evidenceItems.map((item) => item.id).sort(),
    [
      "service-revokes-session-artifacts",
      "withdraw-anonymizes-account",
      "withdraw-rejects-relogin-refresh-export",
    ],
  );
  assert.ok(categories.get("photos_or_videos").residualFileChecks.length > 0);
  assert.ok(categories.get("performance_data").retentionExceptions.length > 0);
  assert.ok(contract.dataExport.evidenceItems.some((item) => item.id === "export-owner-expiry-download"));
  assert.equal(contract.runtimeEvidence.requiredFiles.length, 3);
});

test("privacy lifecycle runner writes category, export, and residual-file evidence reports", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-privacy-lifecycle-"));

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "privacy-lifecycle-report.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "privacy-lifecycle-report.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.equal(report.failures.length, 0);
  assert.equal(report.storePrivacyAlignment.status, "pass");
  assert.equal(report.categories.length, 6);
  assert.equal(report.dataExport.status, "pass");
  assert.equal(report.runtimeEvidence.status, "not_required");
  assert.ok(report.categories.some((category) => category.id === "photos_or_videos"));
  assert.match(markdown, /Privacy Lifecycle Evidence/);
  assert.match(markdown, /Data Export/);
  assert.match(markdown, /Residual File Checks/);
});

test("privacy lifecycle runner fails when a required evidence pattern is missing", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-privacy-lifecycle-missing-"));
  const tempDir = await mkdtemp(path.join(tmpdir(), "maum-privacy-lifecycle-contract-"));
  const contract = readJson(contractPath);
  contract.categories[0].evidenceItems[0].patterns = ["__missing_privacy_evidence_pattern__"];
  const tempContractPath = path.join(tempDir, "lifecycle-evidence.json");
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
      assert.match(error.stderr, /missing_required_evidence/);
      return true;
    },
  );
});

test("privacy lifecycle runner fails release candidates without runtime evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-privacy-lifecycle-runtime-missing-"));
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-privacy-lifecycle-runtime-"));

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

test("privacy lifecycle runner fails when residual file scan reports leftovers", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-privacy-lifecycle-leftovers-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures({
    residualFileStatus: "fail",
    leftoverFiles: [
      {
        storageKey: "diary/orphaned-image.jpg",
        ownerId: 61,
        status: "active",
      },
    ],
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
      assert.match(error.stderr, /residual_file_leftover/);
      return true;
    },
  );
});

test("privacy lifecycle runner accepts complete runtime evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-privacy-lifecycle-runtime-pass-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures();

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
    "--runtime-evidence-dir",
    runtimeDir,
    "--require-runtime-evidence",
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "privacy-lifecycle-report.json"), "utf8"));

  assert.equal(report.status, "pass");
  assert.equal(report.runtimeEvidence.status, "pass");
});

test("backend data export access requires an active account", () => {
  const service = read("back/src/main/kotlin/com/maumonmobile/application/service/MemberDataExportService.kt");
  const memberTest = read("back/src/test/kotlin/com/maumonmobile/adapter/in/web/member/MemberSettingsControllerTest.kt");

  assert.match(service, /override fun get\(user: AuthenticatedUser, exportId: Long\)[\s\S]*findActiveMember\(user\)/);
  assert.match(service, /override fun download\(user: AuthenticatedUser, exportId: Long\)[\s\S]*findActiveMember\(user\)/);
  assert.match(memberTest, /\/api\/v1\/auth\/login/);
  assert.match(memberTest, /\/api\/v1\/auth\/refresh/);
  assert.match(memberTest, /\/api\/v1\/members\/me\/data-exports\/\$exportId\/download/);
});

test("ci runs privacy lifecycle gate only for release candidate flows", () => {
  const workflow = read(".github/workflows/ci.yml");
  const releasePrivacyLifecycle = jobBlock(workflow, "release-privacy-lifecycle");

  assert.match(workflow, /release_candidate_privacy_gate_mode:/);
  assert.match(workflow, /release_privacy_evidence_results_dir:/);
  assert.match(releasePrivacyLifecycle, /needs: changes/);
  assert.match(releasePrivacyLifecycle, /github\.event_name == 'workflow_dispatch'/);
  assert.match(releasePrivacyLifecycle, /startsWith\(github\.head_ref, 'release\/'\)/);
  assert.match(releasePrivacyLifecycle, /startsWith\(github\.head_ref, 'rc\/'\)/);
  assert.match(releasePrivacyLifecycle, /startsWith\(github\.ref, 'refs\/tags\/rc-'\)/);
  assert.match(releasePrivacyLifecycle, /run-privacy-lifecycle-evidence\.mjs/);
  assert.match(releasePrivacyLifecycle, /--require-runtime-evidence/);
  assert.match(releasePrivacyLifecycle, /actions\/upload-artifact@[a-f0-9]{40}/);
});

async function writeRuntimeEvidenceFixtures(options = {}) {
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-privacy-lifecycle-runtime-fixtures-"));
  const passScenario = (id) => ({ id, status: "pass", evidenceUrl: `https://evidence.example.com/${id}` });

  await writeFile(
    path.join(runtimeDir, "privacy-account-withdrawal-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("login_denied_after_withdrawal"),
        passScenario("member_data_query_denied_after_withdrawal"),
        passScenario("export_download_denied_after_withdrawal"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "privacy-data-export-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        passScenario("export_owner_only"),
        passScenario("export_expiry_denied"),
        passScenario("export_sensitive_fields_masked"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "privacy-residual-file-results.json"),
    `${JSON.stringify({
      generatedAt: "2026-05-27T00:00:00.000Z",
      scenarios: [
        {
          ...passScenario("image_object_storage_no_leftovers"),
          status: options.residualFileStatus ?? "pass",
        },
      ],
      leftoverFiles: options.leftoverFiles ?? [],
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

import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const contractPath = "contracts/release-manifest/manifest-gate.json";
const runnerPath = "tools/ci/run-release-manifest-gate.mjs";
const execFileAsync = promisify(execFile);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  assert.ok(existsSync(absolutePath), `${relativePath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

test("release manifest contract covers version, notes, approval, and rollback blockers", () => {
  const contract = readJson(contractPath);

  assert.equal(contract.version, 1);
  assert.equal(contract.defaultManifestPath, "contracts/release-manifest/current-release.json");
  assert.deepEqual(contract.versionSources.platforms.sort(), ["android", "backend", "ios"]);
  assert.deepEqual(contract.manifestSchema.requiredTopLevelFields.sort(), [
    "android",
    "apiContractVersion",
    "approval",
    "backend",
    "backendMigrationSummary",
    "ios",
    "knownIssues",
    "releaseName",
    "releaseNumber",
    "rollback",
    "storeReleaseNotes",
    "testerNotes",
  ]);
  assert.deepEqual(contract.manifestSchema.requiredStoreNoteFields.sort(), [
    "appStore",
    "googlePlay",
  ]);
  assert.deepEqual(contract.manifestSchema.requiredRollbackFields.sort(), [
    "conditions",
    "owner",
  ]);
  assert.equal(contract.manifestSchema.noteLengthLimits.googlePlay, 500);
  assert.equal(contract.manifestSchema.noteLengthLimits.appStore, 4000);
  assert.equal(contract.manifestSchema.noteLengthLimits.testerNotes, 4000);

  for (const blocker of [
    "missing_release_manifest",
    "invalid_release_manifest",
    "release_version_mismatch",
    "release_notes_missing",
    "release_approval_missing",
    "duplicate_build_number",
    "backend_compatibility_missing",
    "rollback_condition_missing",
    "missing_static_evidence",
  ]) {
    assert.ok(contract.releaseBlockers.includes(blocker), `Missing release blocker: ${blocker}`);
  }

  assert.ok(
    contract.staticEvidence.some((item) => item.file === "tools/ci/run-ios-testflight-archive.sh"),
    "iOS store submit script must be static evidence",
  );

  const runner = read(runnerPath);
  assert.match(runner, /requiredStoreNoteFields/);
  assert.match(runner, /requiredRollbackFields/);
  assert.match(runner, /noteLengthLimits/);
});

test("repository release sources and store submit scripts are wired to one manifest path", () => {
  const pubspec = read("front/pubspec.yaml");
  const androidBuild = read("front/android/app/build.gradle.kts");
  const iosPlist = read("front/ios/Runner/Info.plist");
  const backendBuild = read("back/build.gradle.kts");
  const androidSubmit = read("tools/ci/run-android-play-track-submit.mjs");
  const iosSubmit = read("tools/ci/run-ios-testflight-archive.sh");
  const workflow = read(".github/workflows/ci.yml");

  assert.match(pubspec, /^version:\s*\d+\.\d+\.\d+\+\d+/m);
  assert.match(androidBuild, /versionCode\s*=\s*flutter\.versionCode/);
  assert.match(androidBuild, /versionName\s*=\s*flutter\.versionName/);
  assert.match(iosPlist, /<key>CFBundleShortVersionString<\/key>\s*<string>\$\(FLUTTER_BUILD_NAME\)<\/string>/);
  assert.match(iosPlist, /<key>CFBundleVersion<\/key>\s*<string>\$\(FLUTTER_BUILD_NUMBER\)<\/string>/);
  assert.match(backendBuild, /version = ".+"/);

  assert.match(androidSubmit, /MAUMON_RELEASE_MANIFEST_PATH/);
  assert.match(androidSubmit, /storeReleaseNotes/);
  assert.match(androidSubmit, /googlePlay/);
  assert.match(iosSubmit, /MAUMON_RELEASE_MANIFEST_PATH/);
  assert.match(iosSubmit, /MAUMON_IOS_RELEASE_NOTES/);
  assert.match(iosSubmit, /MAUMON_IOS_TESTER_NOTES/);
  assert.match(workflow, /MAUMON_RELEASE_MANIFEST_PATH: contracts\/release-manifest\/current-release\.json/);
});

test("release manifest runner writes pending reports without a manifest outside release mode", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-manifest-pending-"));

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "release-manifest-report.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "release-manifest-report.md"), "utf8");

  assert.equal(report.status, "pending");
  assert.equal(report.manifest.status, "not_required");
  assert.equal(report.staticEvidence.status, "pass");
  assert.match(markdown, /Release Manifest Approval Gate/);
});

test("release manifest runner fails release validation when manifest is missing", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-manifest-missing-"));

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--manifest",
      path.join(reportDir, "missing-release.json"),
      "--report-dir",
      reportDir,
      "--require-manifest",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /missing_release_manifest/);
      return true;
    },
  );

  const report = JSON.parse(await readFile(path.join(reportDir, "release-manifest-report.json"), "utf8"));
  assert.equal(report.status, "blocked");
  assert.ok(report.failures.some((failure) => failure.reason === "missing_release_manifest"));
});

test("release manifest runner accepts a complete release approval manifest", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-manifest-pass-"));
  const manifestPath = path.join(reportDir, "release.json");
  await writeFile(manifestPath, `${JSON.stringify(validManifest(), null, 2)}\n`);

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--manifest",
    manifestPath,
    "--report-dir",
    reportDir,
    "--require-manifest",
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "release-manifest-report.json"), "utf8"));
  const finalManifest = JSON.parse(await readFile(path.join(reportDir, "release-manifest-final.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "release-manifest-report.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.equal(report.manifest.status, "pass");
  assert.equal(report.versions.status, "pass");
  assert.equal(report.approval.status, "pass");
  assert.equal(finalManifest.releaseNumber, "2026.05.27-rc1");
  assert.equal(finalManifest.android.versionCode, 1);
  assert.match(markdown, /Deploy Window/);
});

test("release manifest runner fails version mismatch and duplicate build numbers", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-manifest-mismatch-"));
  const manifestPath = path.join(reportDir, "release.json");
  const manifest = validManifest();
  manifest.android.versionName = "9.9.9";
  manifest.publishedBuildNumbers.android = [1];
  manifest.publishedBuildNumbers.ios = ["1"];
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--manifest",
      manifestPath,
      "--report-dir",
      reportDir,
      "--require-manifest",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /release_version_mismatch/);
      assert.match(error.stderr, /duplicate_build_number/);
      return true;
    },
  );
});

test("release manifest runner treats blank version fields as mismatches", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-manifest-blank-version-"));
  const manifestPath = path.join(reportDir, "release.json");
  const manifest = validManifest();
  manifest.android.versionName = "";
  manifest.ios.buildNumber = "";
  manifest.backend.version = "";
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--manifest",
      manifestPath,
      "--report-dir",
      reportDir,
      "--require-manifest",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /release_version_mismatch/);
      return true;
    },
  );
});

test("release manifest runner fails missing notes, approval, compatibility, and rollback inputs", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-manifest-required-"));
  const manifestPath = path.join(reportDir, "release.json");
  const manifest = validManifest();
  manifest.storeReleaseNotes.googlePlay = "";
  manifest.storeReleaseNotes.appStore = "";
  manifest.testerNotes = "";
  manifest.backendMigrationSummary = "";
  manifest.apiContractVersion = "";
  manifest.approval.approver = "";
  manifest.approval.deployWindow.end = "";
  manifest.rollback.conditions = [];
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--manifest",
      manifestPath,
      "--report-dir",
      reportDir,
      "--require-manifest",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /release_notes_missing/);
      assert.match(error.stderr, /release_approval_missing/);
      assert.match(error.stderr, /backend_compatibility_missing/);
      assert.match(error.stderr, /rollback_condition_missing/);
      return true;
    },
  );
});

test("ci runs release manifest approval for release candidate deploy validation without adding inputs", () => {
  const workflow = read(".github/workflows/ci.yml");
  const workflowDispatchInputs = workflow.match(/\n  workflow_dispatch:\n    inputs:\n([\s\S]*?)\npermissions:/);
  assert.ok(workflowDispatchInputs, "workflow_dispatch inputs must be present");

  const inputCount = [...workflowDispatchInputs[1].matchAll(/^      [a-zA-Z0-9_]+:/gm)].length;
  assert.ok(inputCount <= 25, `workflow_dispatch input count must stay within GitHub's limit: ${inputCount}`);
  assert.doesNotMatch(workflow, /release_candidate_manifest/);

  const job = jobBlock(workflow, "release-manifest-approval");

  assert.match(job, /needs: changes/);
  assert.match(job, /github\.event_name == 'workflow_dispatch'/);
  assert.match(job, /inputs\.release_candidate_deploy_gate_mode == 'validate'/);
  assert.match(job, /startsWith\(github\.head_ref, 'release\/'\)/);
  assert.match(job, /startsWith\(github\.head_ref, 'rc\/'\)/);
  assert.match(job, /startsWith\(github\.ref, 'refs\/tags\/rc-'\)/);
  assert.match(job, /run-release-manifest-gate\.mjs/);
  assert.match(job, /--require-manifest/);
  assert.match(job, /actions\/upload-artifact@[a-f0-9]{40}/);
});

function validManifest() {
  return {
    releaseNumber: "2026.05.27-rc1",
    releaseName: "Maum On 0.1.0",
    android: {
      versionName: "0.1.0",
      versionCode: 1,
    },
    ios: {
      shortVersion: "0.1.0",
      buildNumber: "1",
    },
    backend: {
      version: "0.0.1-SNAPSHOT",
    },
    apiContractVersion: "mobile-api-v1",
    storeReleaseNotes: {
      googlePlay: "First internal testing release.",
      appStore: "First TestFlight release.",
    },
    testerNotes: "Prioritize login, diary writing, and consultation flow checks.",
    backendMigrationSummary: "No manual migration is required for this release.",
    knownIssues: ["Consultation responses can be delayed by production AI connectivity."],
    rollback: {
      owner: "mobile-release-owner",
      conditions: ["Rollback when login success rate drops by 5 percentage points."],
    },
    approval: {
      approver: "mobile-release-owner",
      changeScope: "Android and iOS testing release with backend 0.0.1-SNAPSHOT compatibility.",
      deployWindow: {
        start: "2026-05-27T10:00:00+09:00",
        end: "2026-05-27T12:00:00+09:00",
      },
    },
    publishedBuildNumbers: {
      android: [],
      ios: [],
    },
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

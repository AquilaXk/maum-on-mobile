import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const contractPath = "contracts/security-release/security-gate.json";
const runnerPath = "tools/ci/run-release-security-gate.mjs";
const execFileAsync = promisify(execFile);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  assert.ok(existsSync(absolutePath), `${relativePath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

test("release security gate contract covers dependency ecosystems and release blockers", () => {
  const contract = readJson(contractPath);

  assert.equal(contract.version, 1);
  assert.deepEqual(contract.ecosystems.map((ecosystem) => ecosystem.id).sort(), [
    "flutter",
    "gradle",
    "node",
    "ruby",
  ]);
  assert.equal(contract.auditInputs.severityThreshold, "high");

  for (const blocker of [
    "high_or_higher_vulnerability",
    "secret_exposure",
    "binary_artifact_committed",
    "unapproved_license",
    "ios_privacy_manifest_missing",
    "android_cleartext_traffic_allowed",
    "weak_jwt_secret_policy",
  ]) {
    assert.ok(contract.releaseBlockers.includes(blocker), `Missing release blocker: ${blocker}`);
  }

  for (const license of ["Apache-2.0", "BSD-3-Clause", "MIT", "MPL-2.0"]) {
    assert.ok(contract.licenseAllowList.includes(license), `Missing allowed license: ${license}`);
  }
});

test("release security gate writes SBOM, license, and static security reports", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-security-"));

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "release-security-report.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "release-security-report.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.ok(report.sbom.components.some((component) => component.ecosystem === "flutter"));
  assert.ok(report.sbom.components.some((component) => component.ecosystem === "gradle"));
  assert.ok(report.sbom.components.some((component) => component.ecosystem === "ruby"));
  assert.ok(report.sbom.ecosystems.some((ecosystem) => ecosystem.id === "node" && ecosystem.present === false));
  assert.ok(report.licenses.every((entry) => entry.allowed === true));
  assert.equal(report.staticChecks.secretScan.status, "pass");
  assert.equal(report.staticChecks.binaryArtifactScan.status, "pass");
  assert.equal(report.staticChecks.mobileSecurity.status, "pass");
  assert.match(markdown, /Release Security Gate/);
  assert.match(markdown, /SBOM Components/);
  assert.match(markdown, /License Summary/);
});

test("release security gate fails release candidates without required audit results", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-security-missing-"));

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--require-audits",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /Missing required audit result/);
      return true;
    },
  );

  const report = JSON.parse(await readFile(path.join(reportDir, "release-security-report.json"), "utf8"));

  assert.equal(report.status, "blocked");
  assert.ok(report.failures.some((failure) => failure.reason === "missing_audit_result"));
});

test("release security gate fails on high or higher vulnerabilities", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-security-vuln-"));
  const auditDir = await writeAuditFixtures({
    flutter: [
      {
        id: "CVE-2099-0001",
        package: "dio",
        severity: "high",
        fixedVersion: "5.9.1",
      },
    ],
  });

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--audit-dir",
      auditDir,
      "--require-audits",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /high_or_higher_vulnerability/);
      return true;
    },
  );
});

test("release security gate passes with clean audit evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-release-security-clean-"));
  const auditDir = await writeAuditFixtures({});

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
    "--audit-dir",
    auditDir,
    "--require-audits",
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "release-security-report.json"), "utf8"));

  assert.equal(report.status, "pass");
  assert.ok(report.auditResults.every((audit) => audit.status === "pass" || audit.status === "not_present"));
});

test("backend JWT properties enforce a release-grade secret length", () => {
  const jwtProperties = read("back/src/main/kotlin/com/maumonmobile/global/security/JwtProperties.kt");

  assert.match(jwtProperties, /import jakarta\.validation\.constraints\.Size/);
  assert.match(jwtProperties, /@field:Size\(min = 32/);
});

test("ci runs release security gate only for release candidate flows", () => {
  const workflow = read(".github/workflows/ci.yml");
  const releaseSecurityGate = jobBlock(workflow, "release-security-gate");

  assert.match(releaseSecurityGate, /needs: changes/);
  assert.match(releaseSecurityGate, /github\.event_name == 'workflow_dispatch'/);
  assert.match(releaseSecurityGate, /startsWith\(github\.head_ref, 'release\/'\)/);
  assert.match(releaseSecurityGate, /startsWith\(github\.head_ref, 'rc\/'\)/);
  assert.match(releaseSecurityGate, /startsWith\(github\.ref, 'refs\/tags\/rc-'\)/);
  assert.match(releaseSecurityGate, /run-release-security-gate\.mjs/);
  assert.match(releaseSecurityGate, /--require-audits/);
  assert.match(releaseSecurityGate, /actions\/upload-artifact@[a-f0-9]{40}/);
});

async function writeAuditFixtures(overrides) {
  const auditDir = await mkdtemp(path.join(tmpdir(), "maum-release-security-audits-"));

  for (const ecosystem of ["flutter", "gradle", "ruby"]) {
    await writeFile(
      path.join(auditDir, `${ecosystem}-audit.json`),
      `${JSON.stringify({
        ecosystem,
        vulnerabilities: overrides[ecosystem] ?? [],
      }, null, 2)}\n`,
    );
  }

  return auditDir;
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

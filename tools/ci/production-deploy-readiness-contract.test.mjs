import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { promisify } from "node:util";

const root = process.cwd();
const contractPath = "contracts/infra/production-deploy-readiness.json";
const runnerPath = "tools/ci/run-production-deploy-readiness.mjs";
const execFileAsync = promisify(execFile);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  const absolutePath = path.join(root, relativePath);
  assert.ok(existsSync(absolutePath), `${relativePath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
}

test("production deploy readiness contract covers deploy, recovery, storage, and compatibility gates", () => {
  const contract = readJson(contractPath);

  assert.equal(contract.version, 1);
  assert.deepEqual(contract.environments.map((environment) => environment.id).sort(), [
    "production",
    "staging",
  ]);
  assert.deepEqual(contract.gates.map((gate) => gate.id).sort(), [
    "app_backend_compatibility",
    "backup_restore",
    "environment",
    "migration_rollback",
    "object_storage",
  ]);
  assert.ok(
    contract.environments
      .flatMap((environment) => environment.requiredVariables)
      .some((variable) => variable.name === "MAUMON_PROD_DB_URL"),
  );
  assert.ok(
    contract.commonRequiredVariables.some(
      (variable) => variable.name === "MAUMON_API_CONTRACT_VERSION",
    ),
  );
  assert.equal(contract.runtimeEvidence.requiredFiles.length, 5);

  for (const blocker of [
    "missing_required_env",
    "unsafe_env_value",
    "missing_required_evidence",
    "missing_runtime_evidence",
    "runtime_smoke_failed",
    "compatibility_mismatch",
  ]) {
    assert.ok(contract.releaseBlockers.includes(blocker), `Missing release blocker: ${blocker}`);
  }
});

test("production deploy readiness runner validates env files and writes reports", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-production-readiness-"));
  const envFile = await writeEnvFixture();

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
    "--env-file",
    envFile,
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "production-deploy-readiness-report.json"), "utf8"));
  const markdown = await readFile(path.join(reportDir, "production-deploy-readiness-report.md"), "utf8");

  assert.equal(report.status, "pass");
  assert.equal(report.environment.status, "pass");
  assert.equal(report.staticEvidence.status, "pass");
  assert.equal(report.runtimeEvidence.status, "not_required");
  assert.ok(report.environment.environments.some((environment) => environment.id === "production"));
  assert.match(markdown, /Production Deploy Readiness/);
  assert.match(markdown, /Runtime Evidence/);
});

test("production deploy readiness runner accepts compatibility manifest env", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-production-readiness-manifest-"));
  const envFile = await writeEnvFixture({
    MAUMON_BACKEND_DEPLOY_VERSION: "",
    MAUMON_ANDROID_APP_VERSION: "",
    MAUMON_IOS_APP_VERSION: "",
    MAUMON_API_CONTRACT_VERSION: "",
  });

  await execFileAsync(
    "node",
    [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--env-file",
      envFile,
    ],
    {
      env: {
        ...process.env,
        MAUMON_DEPLOY_COMPATIBILITY_MANIFEST: JSON.stringify({
          backendVersion: "2026.05.27+ba48b8b",
          androidVersion: "1.0.0+100",
          iosVersion: "1.0.0+100",
          apiContractVersion: "mobile-api-v1",
        }),
      },
    },
  );

  const report = JSON.parse(await readFile(path.join(reportDir, "production-deploy-readiness-report.json"), "utf8"));
  assert.equal(report.compatibility.status, "pass");
});

test("production deploy readiness runner fails when required env is missing", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-production-readiness-missing-env-"));
  const envFile = await writeEnvFixture({
    MAUMON_PROD_DB_PASSWORD: "",
  });

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--env-file",
      envFile,
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /missing_required_env/);
      return true;
    },
  );
});

test("production deploy readiness runner fails release candidates without runtime evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-production-readiness-runtime-missing-"));
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-production-readiness-runtime-"));
  const envFile = await writeEnvFixture();

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--env-file",
      envFile,
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

test("production deploy readiness runner fails failed recovery smoke scenarios", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-production-readiness-runtime-fail-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures({
    scenarioOverrides: {
      test_db_restore_smoke: "fail",
    },
  });
  const envFile = await writeEnvFixture();

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--env-file",
      envFile,
      "--runtime-evidence-dir",
      runtimeDir,
      "--require-runtime-evidence",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /runtime_smoke_failed/);
      return true;
    },
  );
});

test("production deploy readiness runner fails mismatched runtime API contract evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-production-readiness-contract-mismatch-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures({
    apiContractVersion: "mobile-api-v2",
  });
  const envFile = await writeEnvFixture();

  await assert.rejects(
    execFileAsync("node", [
      path.join(root, runnerPath),
      "--report-dir",
      reportDir,
      "--env-file",
      envFile,
      "--runtime-evidence-dir",
      runtimeDir,
      "--require-runtime-evidence",
    ]),
    (error) => {
      assert.equal(error.code, 1);
      assert.match(error.stderr, /compatibility_mismatch/);
      return true;
    },
  );
});

test("production deploy readiness runner accepts complete runtime evidence", async () => {
  const reportDir = await mkdtemp(path.join(tmpdir(), "maum-production-readiness-runtime-pass-"));
  const runtimeDir = await writeRuntimeEvidenceFixtures();
  const envFile = await writeEnvFixture();

  await execFileAsync("node", [
    path.join(root, runnerPath),
    "--report-dir",
    reportDir,
    "--env-file",
    envFile,
    "--runtime-evidence-dir",
    runtimeDir,
    "--require-runtime-evidence",
  ]);

  const report = JSON.parse(await readFile(path.join(reportDir, "production-deploy-readiness-report.json"), "utf8"));

  assert.equal(report.status, "pass");
  assert.equal(report.runtimeEvidence.status, "pass");
  assert.equal(report.compatibility.status, "pass");
});

test("repository exposes deployment, migration, storage, and compatibility evidence", () => {
  const applicationConfig = read("back/src/main/resources/application.yml");
  const migrations = read("back/src/main/resources/db/migration/V2__mobile_persistence.sql");
  const objectStorage = read("back/src/main/kotlin/com/maumonmobile/adapter/out/storage/image/ObjectImageStorage.kt");
  const pubspec = read("front/pubspec.yaml");
  const app = read("front/lib/app/maum_on_mobile_app.dart");
  const backendBuild = read("back/build.gradle.kts");

  assert.match(applicationConfig, /url: \$\{DB_URL\}/);
  assert.match(applicationConfig, /secret: \$\{APP_JWT_SECRET\}/);
  assert.match(applicationConfig, /flyway:[\s\S]*enabled: true/);
  assert.match(applicationConfig, /PUSH_FCM_PROJECT_ID/);
  assert.match(applicationConfig, /PUSH_APNS_AUTHORIZATION_TOKEN/);
  assert.match(applicationConfig, /GOOGLE_APPLICATION_CREDENTIALS/);
  assert.match(migrations, /create table/);
  assert.match(objectStorage, /@Profile\("object-storage"\)/);
  assert.match(pubspec, /^version:\s*\d+\.\d+\.\d+\+\d+/m);
  assert.match(app, /String\.fromEnvironment\(\s*'APP_VERSION'/);
  assert.match(backendBuild, /version = ".+"/);
});

test("ci runs production deploy readiness gate only for release candidate flows", () => {
  const workflow = read(".github/workflows/ci.yml");
  const releaseDeployReadiness = jobBlock(workflow, "release-deploy-readiness");

  assert.match(workflow, /release_candidate_deploy_gate_mode:/);
  assert.match(workflow, /release_deploy_evidence_results_dir:/);
  assert.match(workflow, /release_deploy_compatibility_manifest:/);
  assert.match(releaseDeployReadiness, /needs: changes/);
  assert.match(releaseDeployReadiness, /github\.event_name == 'workflow_dispatch'/);
  assert.match(releaseDeployReadiness, /startsWith\(github\.head_ref, 'release\/'\)/);
  assert.match(releaseDeployReadiness, /startsWith\(github\.head_ref, 'rc\/'\)/);
  assert.match(releaseDeployReadiness, /startsWith\(github\.ref, 'refs\/tags\/rc-'\)/);
  assert.match(releaseDeployReadiness, /run-production-deploy-readiness\.mjs/);
  assert.match(releaseDeployReadiness, /--require-env/);
  assert.match(releaseDeployReadiness, /--require-runtime-evidence/);
  assert.match(releaseDeployReadiness, /MAUMON_PROD_DB_URL/);
  assert.match(releaseDeployReadiness, /actions\/upload-artifact@[a-f0-9]{40}/);
});

test("ci keeps workflow dispatch inputs within GitHub Actions limits", () => {
  const workflow = read(".github/workflows/ci.yml");
  const workflowDispatch = workflow.match(/  workflow_dispatch:\n    inputs:\n(?<body>[\s\S]*?)\n\npermissions:/);
  assert.ok(workflowDispatch?.groups?.body, "workflow_dispatch inputs block must exist");

  const inputNames = Array.from(
    workflowDispatch.groups.body.matchAll(/^      ([a-zA-Z0-9_-]+):$/gm),
    (match) => match[1],
  );

  assert.ok(inputNames.length <= 25, `workflow_dispatch inputs exceed 25: ${inputNames.length}`);
});

async function writeEnvFixture(overrides = {}) {
  const envPath = path.join(
    await mkdtemp(path.join(tmpdir(), "maum-production-readiness-env-")),
    "release.env",
  );
  const env = {
    MAUMON_PROD_SPRING_PROFILES_ACTIVE: "production,object-storage",
    MAUMON_PROD_DB_URL: "jdbc:postgresql://prod-db.example.com:5432/maumon",
    MAUMON_PROD_DB_USERNAME: "prod_user",
    MAUMON_PROD_DB_PASSWORD: "prod-password",
    MAUMON_STAGING_SPRING_PROFILES_ACTIVE: "staging,object-storage",
    MAUMON_STAGING_DB_URL: "jdbc:postgresql://staging-db.example.com:5432/maumon",
    MAUMON_STAGING_DB_USERNAME: "staging_user",
    MAUMON_STAGING_DB_PASSWORD: "staging-password",
    MAUMON_OBJECT_STORAGE_BUCKET: "maumon-release-images",
    MAUMON_OBJECT_STORAGE_ENDPOINT: "https://storage.example.com",
    MAUMON_OBJECT_STORAGE_ACCESS_KEY: "object-access",
    MAUMON_OBJECT_STORAGE_SECRET_KEY: "object-secret",
    MAUMON_PUSH_FCM_PROJECT_ID: "maumon-prod",
    MAUMON_PUSH_FCM_ACCESS_TOKEN: "fcm-token",
    MAUMON_PUSH_APNS_TOPIC: "com.maumon.mobile",
    MAUMON_PUSH_APNS_AUTHORIZATION_TOKEN: "apns-token",
    MAUMON_GOOGLE_CLOUD_PROJECT_ID: "maumon-ai",
    MAUMON_GOOGLE_APPLICATION_CREDENTIALS: "/secrets/vertex.json",
    MAUMON_AI_CONSULTATION_ENDPOINT: "https://ai.example.com/consultation",
    MAUMON_AI_CONSULTATION_AUTHORIZATION_TOKEN: "consultation-token",
    MAUMON_AI_MODERATION_ENDPOINT: "https://ai.example.com/moderation",
    MAUMON_AI_MODERATION_AUTHORIZATION_TOKEN: "moderation-token",
    MAUMON_APP_JWT_SECRET: "01234567890123456789012345678901",
    MAUMON_BACKEND_DEPLOY_VERSION: "2026.05.27+ba48b8b",
    MAUMON_ANDROID_APP_VERSION: "1.0.0+100",
    MAUMON_IOS_APP_VERSION: "1.0.0+100",
    MAUMON_API_CONTRACT_VERSION: "mobile-api-v1",
    ...overrides,
  };

  const body = Object.entries(env)
    .map(([key, value]) => `${key}=${value}`)
    .join("\n");
  await writeFile(envPath, `${body}\n`);
  return envPath;
}

async function writeRuntimeEvidenceFixtures(options = {}) {
  const runtimeDir = await mkdtemp(path.join(tmpdir(), "maum-production-readiness-runtime-fixtures-"));
  const passScenario = (id) => ({
    id,
    status: options.scenarioOverrides?.[id] ?? "pass",
    evidenceUrl: `https://evidence.example.com/${id}`,
  });

  await writeFile(
    path.join(runtimeDir, "deploy-env-validation-results.json"),
    `${JSON.stringify({
      scenarios: [
        passScenario("production_env_present"),
        passScenario("staging_env_present"),
        passScenario("secret_rotation_window_confirmed"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "migration-rollback-results.json"),
    `${JSON.stringify({
      scenarios: [
        passScenario("flyway_migration_dry_run"),
        passScenario("pre_migration_api_smoke"),
        passScenario("post_migration_api_smoke"),
        {
          ...passScenario("rollback_decision_recorded"),
          rollbackDecision: "restore-backup-and-disable-release",
        },
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "backup-restore-results.json"),
    `${JSON.stringify({
      scenarios: [
        {
          ...passScenario("db_backup_created"),
          backupArtifact: "s3://maumon-backups/release.sql.gz",
        },
        passScenario("test_db_restore_smoke"),
        passScenario("core_query_after_restore"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "object-storage-results.json"),
    `${JSON.stringify({
      scenarios: [
        passScenario("object_upload_smoke"),
        passScenario("object_download_smoke"),
        passScenario("object_delete_smoke"),
      ],
    }, null, 2)}\n`,
  );
  await writeFile(
    path.join(runtimeDir, "app-backend-compatibility-results.json"),
    `${JSON.stringify({
      scenarios: [
        passScenario("android_backend_compatible"),
        passScenario("ios_backend_compatible"),
        passScenario("backend_version_recorded"),
      ],
      apiContractVersion: options.apiContractVersion ?? "mobile-api-v1",
    }, null, 2)}\n`,
  );

  return runtimeDir;
}

function jobBlock(workflow, jobName) {
  const lines = workflow.split("\n");
  const start = lines.findIndex((line) => line === `  ${jobName}:`);
  assert.notEqual(start, -1, `${jobName} job must exist`);

  let end = lines.length;
  for (let index = start + 1; index < lines.length; index += 1) {
    if (/^  [a-zA-Z0-9_-]+:/.test(lines[index])) {
      end = index;
      break;
    }
  }
  return lines.slice(start, end).join("\n");
}

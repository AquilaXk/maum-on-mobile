import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();

const read = (filePath) => readFileSync(path.join(root, filePath), "utf8");

test("mobile performance gate manifest covers long-running domain scenarios", () => {
  const manifest = JSON.parse(read("tools/ci/mobile-performance-gate.json"));
  const scenarioIds = new Set(manifest.scenarios.map((scenario) => scenario.id));

  for (const requiredScenario of [
    "auth.session",
    "home.feed",
    "diary.write",
    "story.feed",
    "letter.flow",
    "report.flow",
    "notification.flow",
  ]) {
    assert.ok(scenarioIds.has(requiredScenario), `Missing performance scenario: ${requiredScenario}`);
  }

  assert.deepEqual(manifest.report.requiredFields, [
    "runId",
    "profile",
    "status",
    "summary",
    "scenarios",
    "cleanup",
    "reproduce",
  ]);
  assert.ok(manifest.budgets.p95LatencyMs > 0);
  assert.ok(manifest.budgets.maxErrorRate >= 0);
  assert.ok(manifest.budgets.minSuccessRate > 0);
});

test("mobile performance smoke script uses the shared environment contract", () => {
  const script = read("tools/ci/run-mobile-performance-smoke.sh");

  for (const envName of [
    "MOBILE_PERFORMANCE_PROFILE",
    "MOBILE_PERFORMANCE_SAMPLES",
    "MOBILE_PERFORMANCE_REPORT_DIR",
    "MOBILE_PERFORMANCE_P95_BUDGET_MS",
    "MOBILE_PERFORMANCE_ERROR_RATE_BUDGET",
    "MOBILE_PERFORMANCE_MIN_SUCCESS_RATE",
  ]) {
    assert.match(script, new RegExp(envName), `${envName} must be part of the smoke contract`);
  }

  assert.match(script, /mobile-performance-smoke\.json/);
  assert.match(script, /com\.maumonmobile\.performance\.MobileApiPerformanceSmokeTest/);
});

test("manual mobile performance workflow runs the same smoke script", () => {
  const workflow = read(".github/workflows/mobile-performance.yml");

  assert.match(workflow, /^on:\n  workflow_dispatch:/m);
  assert.match(workflow, /MOBILE_PERFORMANCE_PROFILE:/);
  assert.match(workflow, /tools\/ci\/run-mobile-performance-smoke\.sh/);
  assert.match(workflow, /mobile-performance-smoke\.json/);
});

test("performance test data endpoint is bound to the performance profile only", () => {
  const controller = read(
    "back/src/main/kotlin/com/maumonmobile/adapter/in/web/performance/PerformanceTestDataController.kt",
  );
  const service = read(
    "back/src/main/kotlin/com/maumonmobile/application/service/PerformanceTestDataService.kt",
  );
  const security = read("back/src/main/kotlin/com/maumonmobile/global/security/SecurityConfig.kt");

  assert.match(controller, /@Profile\("performance"\)/);
  assert.match(service, /@Profile\("performance"\)/);
  assert.match(controller, /\/api\/v1\/performance\/test-data/);
  assert.match(security, /acceptsProfiles\(Profiles\.of\("performance"\)\)/);
  assert.doesNotMatch(security, /requestMatchers\("\/api\/v1\/performance\/\*\*"\)\s*\.permitAll\(\)\s*\.requestMatchers/);
});

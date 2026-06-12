import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const contractPath = "tools/ci/mobile-usability-release-criteria.json";

const readContract = () => {
  const absolutePath = path.join(root, contractPath);
  assert.ok(existsSync(absolutePath), `${contractPath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
};

test("mobile usability release criteria cover every launch screen and state", () => {
  const contract = readContract();
  const screenIds = new Set(contract.screens.map((screen) => screen.id));

  for (const requiredScreen of [
    "home",
    "diary",
    "story",
    "letter",
    "consultation",
    "notifications",
    "settings",
  ]) {
    assert.ok(screenIds.has(requiredScreen), `Missing launch screen criteria: ${requiredScreen}`);
  }

  for (const screen of contract.screens) {
    assert.match(screen.priority, /^P[0-2]$/, `${screen.id} must have a P0/P1/P2 priority`);
    assert.ok(screen.entryFlow.length > 0, `${screen.id} needs an entry flow`);
    assert.ok(screen.primaryUserGoal.length > 0, `${screen.id} needs a primary user goal`);
    assert.deepEqual(Object.keys(screen.states).sort(), [
      "empty",
      "error",
      "loading",
      "permissionDenied",
      "sessionExpired",
    ]);

    for (const [stateName, state] of Object.entries(screen.states)) {
      assert.ok(state.message.length > 0, `${screen.id}.${stateName} needs state copy`);
      assert.ok(state.primaryAction.length > 0, `${screen.id}.${stateName} needs a primary action`);
      assert.match(state.priority, /^P[0-2]$/, `${screen.id}.${stateName} must have a priority`);
    }
  }
});

test("mobile usability release criteria split automated and manual checks", () => {
  const contract = readContract();

  assert.deepEqual([...contract.platforms].sort(), ["android", "ios"]);
  assert.deepEqual(Object.keys(contract.viewportMatrix).sort(), [
    "largePhone",
    "smallPhone",
    "tabletWidth",
  ]);

  for (const viewport of Object.values(contract.viewportMatrix)) {
    assert.ok(viewport.safeAreaRule.length > 0);
    assert.ok(viewport.largeTextRule.length > 0);
    assert.ok(viewport.oneHandRule.length > 0);
  }

  assert.ok(contract.automation.flutterTests.length >= 4);
  assert.ok(contract.manualQa.length >= 4);

  for (const automatedCheck of contract.automation.flutterTests) {
    assert.match(automatedCheck.priority, /^P[0-2]$/);
    assert.ok(automatedCheck.target.length > 0);
    assert.ok(automatedCheck.assertion.length > 0);
  }

  for (const manualCheck of contract.manualQa) {
    assert.match(manualCheck.priority, /^P[0-2]$/);
    assert.ok(manualCheck.platform.length > 0);
    assert.ok(manualCheck.evidence.length > 0);
  }
});

test("mobile usability release criteria identify component reuse and new component needs", () => {
  const contract = readContract();

  assert.ok(contract.componentPlan.reuse.length >= 4);
  assert.ok(contract.componentPlan.newComponents.length >= 2);

  for (const item of contract.componentPlan.reuse) {
    assert.ok(item.component.length > 0);
    assert.ok(item.appliesTo.length > 0);
    assert.match(item.priority, /^P[0-2]$/);
  }

  for (const item of contract.componentPlan.newComponents) {
    assert.ok(item.component.length > 0);
    assert.ok(item.reason.length > 0);
    assert.match(item.priority, /^P[0-2]$/);
  }

  assert.deepEqual(Object.keys(contract.accessibility).sort(), [
    "darkMode",
    "largeText",
    "screenReader",
    "touchTarget",
  ]);
});

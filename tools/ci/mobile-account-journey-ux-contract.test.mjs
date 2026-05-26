import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();

const readJson = (filePath) => {
  const absolutePath = path.join(root, filePath);
  assert.ok(existsSync(absolutePath), `${filePath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
};

test("mobile account journey UX contract covers every account flow state", () => {
  const contract = readJson("tools/ci/mobile-account-journey-ux.json");
  const journeys = new Map(contract.journeys.map((journey) => [journey.id, journey]));

  for (const requiredJourney of [
    "login",
    "signup",
    "password_reset_request",
    "password_reset_confirm",
    "account_withdrawal",
  ]) {
    assert.ok(journeys.has(requiredJourney), `Missing account journey: ${requiredJourney}`);
  }

  for (const journey of journeys.values()) {
    assert.ok(journey.primaryCta.length > 0, `${journey.id} needs a primary CTA`);
    assert.ok(journey.pendingState.label.length > 0, `${journey.id} needs pending copy`);
    assert.ok(journey.successState.message.length > 0, `${journey.id} needs success copy`);
    assert.ok(journey.failureState.message.length > 0, `${journey.id} needs failure copy`);
    assert.ok(journey.accessibility.summaryLabel.length > 0, `${journey.id} needs a summary label`);
    assert.ok(journey.layout.smallScreenRule.length > 0, `${journey.id} needs a small-screen rule`);
  }
});

test("mobile account journey UX contract fixes input, permission, and dangerous-action rules", () => {
  const contract = readJson("tools/ci/mobile-account-journey-ux.json");

  assert.deepEqual([...contract.platforms].sort(), ["android", "ios"]);
  assert.deepEqual(Object.keys(contract.inputRules.signup.fields).sort(), [
    "email",
    "nickname",
    "password",
    "passwordConfirm",
    "requiredTerms",
  ]);

  for (const fieldRule of Object.values(contract.inputRules.signup.fields)) {
    assert.ok(fieldRule.errorMessage.length > 0);
  }

  assert.deepEqual(Object.keys(contract.permissionPrompts).sort(), [
    "camera",
    "notifications",
    "photos",
  ]);

  for (const prompt of Object.values(contract.permissionPrompts)) {
    assert.equal(prompt.requestTiming, "just_in_time");
    assert.equal(prompt.deniedRecovery.action, "open_settings");
    assert.ok(prompt.deniedRecovery.message.length > 0);
  }

  assert.equal(contract.dangerousActions.accountWithdrawal.requiresReauthentication, true);
  assert.ok(contract.dangerousActions.accountWithdrawal.confirmationText.length > 0);
  assert.ok(contract.dangerousActions.accountWithdrawal.cancelLabel.length > 0);
  assert.deepEqual(Object.keys(contract.responsiveAccessibility).sort(), [
    "darkMode",
    "largeText",
    "screenReader",
    "smallScreen",
  ]);
});

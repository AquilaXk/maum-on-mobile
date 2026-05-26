import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const contractPath = path.join(root, "contracts/store-review/ios-login-review.json");

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

test("iOS login review contract fixes App Review sign-in policy", () => {
  const contract = readJson(contractPath);

  assert.equal(contract.version, 1);
  assert.equal(contract.platform, "ios");
  assert.equal(contract.submissionPolicy.emailLoginRequired, true);
  assert.equal(
    contract.submissionPolicy.externalProviderHandling,
    "disabled_until_sign_in_with_apple_is_available",
  );
  assert.equal(
    contract.submissionPolicy.signInWithApple.requiredWhenThirdPartyProviderEnabled,
    true,
  );
  assert.equal(contract.submissionPolicy.signInWithApple.currentStatus, "not_enabled");
  assert.match(
    contract.submissionPolicy.signInWithApple.releaseGate,
    /iOS.*third-party.*Sign in with Apple/i,
  );

  const email = contract.loginOptions.find((option) => option.id === "email");
  const kakao = contract.loginOptions.find((option) => option.id === "kakao");
  assert.ok(email, "email login option must be declared");
  assert.ok(kakao, "kakao login option must be declared");
  assert.ok(email.platforms.includes("ios"));
  assert.ok(email.testKeys.includes("login-email-field"));
  assert.ok(email.testKeys.includes("login-password-field"));
  assert.deepEqual(kakao.platforms, ["android"]);
  assert.ok(!kakao.platforms.includes("ios"));
  assert.equal(kakao.iosReviewState, "hidden");
});

test("iOS review account readiness avoids committed credentials", () => {
  const contract = readJson(contractPath);

  assert.equal(contract.reviewAccount.storage, "app_store_connect_review_notes");
  assert.equal(contract.reviewAccount.credentialsCommitted, false);
  assert.deepEqual(contract.reviewAccount.secretNames, [
    "MAUMON_REVIEW_ACCOUNT_EMAIL",
    "MAUMON_REVIEW_ACCOUNT_PASSWORD",
  ]);
  assert.ok(contract.reviewAccount.requiredFields.includes("role"));
  assert.ok(contract.reviewAccount.requiredFields.includes("testDataScope"));
  assert.ok(contract.reviewAccount.testDataScope.includes("settings.member_withdrawal"));
  assert.equal(contract.fallbacks.externalLoginFailure, "email_password_login");
  assert.equal(contract.fallbacks.accountDeletionPath, "settings.member_withdrawal");
});

test("iOS login review contract is wired to automated checks", () => {
  const contract = readJson(contractPath);
  const authScreenTest = read("front/test/features/auth/auth_screen_test.dart");
  const pathFilterTest = read("tools/ci/ci-path-filter-contract.test.mjs");

  assert.deepEqual(contract.qualityGate.commands, [
    "flutter test test/features/auth/auth_screen_test.dart",
    "node --test tools/ci/ios-login-review-readiness-contract.test.mjs",
  ]);
  assert.match(authScreenTest, /external-login-kakao-button/);
  assert.match(authScreenTest, /ios-review-email-login-guidance/);
  assert.match(pathFilterTest, /contracts\/store-review\/ios-login-review\.json/);
});

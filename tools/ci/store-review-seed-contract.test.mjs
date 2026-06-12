import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const contractPath = path.join(root, "contracts/store-review/review-seed.json");

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

test("store review seed contract declares protected backend seed inputs", () => {
  assert.ok(existsSync(contractPath), "Missing store review seed contract");
  const contract = readJson(contractPath);

  assert.equal(contract.version, 1);
  assert.equal(contract.profile, "store-review-seed");
  assert.equal(contract.credentialsCommitted, false);
  assert.equal(contract.secretOptIn.required, true);
  assert.equal(contract.secretOptIn.headerName, "X-Maumon-Review-Seed-Secret");
  assert.ok(contract.secretOptIn.secretNames.includes("MAUMON_STORE_REVIEW_SEED_SECRET"));
  assert.ok(contract.secretOptIn.secretNames.includes("MAUMON_REVIEW_ACCOUNT_PASSWORD"));
  assert.ok(!contract.secretOptIn.secretNames.includes("MAUMON_REVIEW_OPERATIONS_PASSWORD"));
});

test("store review seed contract covers reviewer access", () => {
  const contract = readJson(contractPath);
  const accounts = new Map(contract.accounts.map((account) => [account.id, account]));

  assert.equal(accounts.get("reviewer").role, "USER");
  assert.equal(accounts.get("reviewer").emailSecretName, "MAUMON_REVIEW_ACCOUNT_EMAIL");
  assert.ok(accounts.get("reviewer").accessPaths.includes("auth.login"));
  assert.ok(!accounts.has("operations"));
});

test("store review seed contract covers required journey data", () => {
  const contract = readJson(contractPath);
  const dataScope = new Set(contract.testDataScope);

  for (const scope of [
    "diary.create_delete",
    "story.create_comment",
    "letter.send_receive",
    "consultation.chat",
    "notifications.open",
    "report.submit",
    "settings.data_export",
    "settings.member_withdrawal",
  ]) {
    assert.ok(dataScope.has(scope), `Missing review seed scope: ${scope}`);
  }
});

test("store review seed contract is wired to automated checks", () => {
  const contract = readJson(contractPath);
  const pathFilterTest = read("tools/ci/ci-path-filter-contract.test.mjs");

  assert.ok(contract.qualityGate.commands.includes("tools/ci/run-store-review-seed-dry-run.sh"));
  assert.ok(contract.qualityGate.commands.includes("./back/gradlew check --no-daemon"));
  assert.ok(existsSync(path.join(root, "tools/ci/run-store-review-seed-dry-run.sh")));
  assert.match(pathFilterTest, /contracts\/store-review\/review-seed\.json/);
});

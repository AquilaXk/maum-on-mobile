import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

const root = process.cwd();
const contractPath = path.join(root, "contracts/mobile-api/response-snapshots.json");

function readContract() {
  assert.ok(existsSync(contractPath), `Missing shared mobile API contract snapshot file: ${contractPath}`);
  return JSON.parse(readFileSync(contractPath, "utf8"));
}

test("mobile API response snapshots are stored in the shared contract location", () => {
  const contract = readContract();

  assert.equal(contract.version, 1);
  assert.deepEqual(contract.schema.envelopeKeys, ["success", "data", "error"]);
  assert.deepEqual(contract.schema.pageKeys, ["content", "page", "size", "totalElements", "totalPages", "last", "hasNext"]);
  assert.deepEqual(contract.schema.errorKeys, ["code", "message", "fieldErrors", "retryable", "cause"]);
});

test("mobile API response snapshots cover core parser and release-gate areas", () => {
  const contract = readContract();
  const areas = new Set(contract.snapshots.map((snapshot) => snapshot.area));
  const ids = new Set(contract.snapshots.map((snapshot) => snapshot.id));

  assert.deepEqual([...areas].sort(), [
    "auth",
    "consultation",
    "diary",
    "home",
    "letter",
    "moderation",
    "notification",
    "operations",
    "report",
    "settings",
    "story",
  ]);

  for (const requiredId of [
    "common.validation-error",
    "common.permission-changed",
    "story.list.success",
    "diary.list.success",
    "notification.list.success",
    "operations.metrics.success",
  ]) {
    assert.ok(ids.has(requiredId), `Missing mobile API snapshot: ${requiredId}`);
  }
});

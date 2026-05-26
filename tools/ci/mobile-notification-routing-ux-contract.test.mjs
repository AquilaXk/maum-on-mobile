import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();

const readJson = (filePath) => {
  const absolutePath = path.join(root, filePath);
  assert.ok(existsSync(absolutePath), `${filePath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
};

test("mobile notification routing UX contract covers every actionable notification type", () => {
  const contract = readJson("tools/ci/mobile-notification-routing-ux.json");
  const routes = new Map(contract.routes.map((route) => [route.type, route]));

  for (const type of [
    "new_letter",
    "letter_read",
    "writing_status",
    "reply_arrival",
    "consultation_reply",
    "report_status",
    "operations_action",
    "fallback",
  ]) {
    assert.ok(routes.has(type), `Missing notification UX route: ${type}`);
  }

  for (const route of routes.values()) {
    assert.match(route.destination, /^(letter|consultation|notifications|operations)$/);
    assert.ok(route.fallback.destination === "notifications", `${route.type} must fall back to notifications`);
    assert.ok(route.tapBehavior.markReadBeforeNavigate, `${route.type} must mark read before navigation`);
    assert.ok(route.tapBehavior.dedupeByNotificationId, `${route.type} must dedupe tap handling`);
    assert.ok(route.emptyState.title.length > 0, `${route.type} needs an empty-state title`);
    assert.ok(route.errorState.targetMissing.length > 0, `${route.type} needs target missing copy`);
    assert.ok(route.accessibilityLabelTemplate.includes("{readState}"));
    assert.ok(route.accessibilityLabelTemplate.includes("{destination}"));
  }
});

test("mobile notification routing UX contract defines permission and connection states", () => {
  const contract = readJson("tools/ci/mobile-notification-routing-ux.json");

  assert.deepEqual(Object.keys(contract.permissionStates).sort(), [
    "denied",
    "error",
    "granted",
    "requestable",
  ]);
  assert.deepEqual(Object.keys(contract.connectionStates).sort(), [
    "connected",
    "connecting",
    "disconnected",
    "unstable",
  ]);
  assert.deepEqual([...contract.platforms].sort(), ["android", "ios"]);
});

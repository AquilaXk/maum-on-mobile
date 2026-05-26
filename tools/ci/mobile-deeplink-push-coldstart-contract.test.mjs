import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const contractPath = "tools/ci/mobile-deeplink-push-coldstart.json";

const readContract = () => {
  const absolutePath = path.join(root, contractPath);
  assert.ok(existsSync(absolutePath), `${contractPath} must exist`);
  return JSON.parse(readFileSync(absolutePath, "utf8"));
};

test("deeplink and push cold-start contract covers launch and auth states", () => {
  const contract = readContract();

  assert.deepEqual([...contract.platforms].sort(), ["android", "ios"]);
  assert.deepEqual([...contract.launchStates].sort(), [
    "background",
    "coldStart",
    "foreground",
  ]);
  assert.deepEqual([...contract.authStates].sort(), [
    "authenticated",
    "expired",
    "restoring",
  ]);
  assert.deepEqual([...contract.externalLoginCallback.statuses].sort(), [
    "cancelled",
    "duplicate",
    "error",
    "success",
  ]);
  assert.equal(contract.externalLoginCallback.dedupeBy, "provider+code+state");
});

test("push cold-start contract defines every required notification route", () => {
  const contract = readContract();
  const routes = new Map(contract.pushRoutes.map((route) => [route.destination, route]));

  for (const destination of [
    "story",
    "letter",
    "consultation",
    "notifications",
    "operations",
  ]) {
    assert.ok(routes.has(destination), `Missing cold-start route: ${destination}`);
  }

  for (const route of routes.values()) {
    assert.equal(route.fallback.destination, "notifications");
    assert.ok(route.recoveryMessage.length > 0, `${route.destination} needs recovery copy`);
    assert.ok(route.sources.includes("coldStart"), `${route.destination} must cover cold start`);
    assert.ok(route.sources.includes("background"), `${route.destination} must cover background`);
    assert.ok(route.sources.includes("foreground"), `${route.destination} must cover foreground`);
  }
});

test("platform contract detects missing native deep link and push settings", () => {
  const contract = readContract();
  const androidManifest = readFileSync(
    path.join(root, "front/android/app/src/main/AndroidManifest.xml"),
    "utf8",
  );
  const iosInfoPlist = readFileSync(path.join(root, "front/ios/Runner/Info.plist"), "utf8");
  const iosEntitlements = readFileSync(
    path.join(root, "front/ios/Runner/Runner.entitlements"),
    "utf8",
  );

  for (const pattern of contract.nativeChecks.android.manifestPatterns) {
    assert.match(androidManifest, new RegExp(pattern), `Android manifest missing ${pattern}`);
  }
  for (const pattern of contract.nativeChecks.ios.infoPlistPatterns) {
    assert.match(iosInfoPlist, new RegExp(pattern), `iOS Info.plist missing ${pattern}`);
  }
  for (const pattern of contract.nativeChecks.ios.entitlementPatterns) {
    assert.match(iosEntitlements, new RegExp(pattern), `iOS entitlement missing ${pattern}`);
  }
});

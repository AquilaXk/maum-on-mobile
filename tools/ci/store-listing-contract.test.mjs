import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const contractPath = "contracts/store-listing/store-listing.json";

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function screenRoutes(contract) {
  return new Set(contract.screenshots.flatMap((set) => set.captures.map((capture) => capture.routeKey)));
}

test("store listing contract covers required app metadata and links", () => {
  assert.ok(existsSync(path.join(root, contractPath)), "Missing store listing contract");

  const listing = readJson(contractPath);
  const privacy = readJson("contracts/store-privacy/data-safety.json");
  const legal = read("front/lib/features/legal/domain/legal_disclosures.dart");

  assert.equal(listing.version, 1);
  assert.equal(listing.appName, "Maum On");
  assert.equal(listing.locale, "ko-KR");
  assert.equal(listing.links.privacyPolicyUrl, privacy.storeLinks.privacyPolicyUrl);
  assert.equal(listing.links.termsUrl, privacy.storeLinks.termsUrl);
  assert.equal(listing.links.supportEmail, privacy.storeLinks.supportEmail);
  assert.match(legal, new RegExp(escapeRegExp(listing.links.privacyPolicyUrl)));
  assert.match(legal, new RegExp(escapeRegExp(listing.links.termsUrl)));
  assert.match(legal, new RegExp(escapeRegExp(listing.links.supportEmail)));

  assert.equal(listing.googlePlay.packageName, "com.aquilaxk.maumonmobile");
  assert.equal(listing.googlePlay.category, "Health & Fitness");
  assert.ok(listing.googlePlay.tags.length >= 3);
  assert.ok(listing.googlePlay.shortDescription.length <= 80);
  assert.ok(listing.googlePlay.longDescription.length <= 4000);
  assert.equal(listing.googlePlay.supportEmail, listing.links.supportEmail);
  assert.equal(listing.googlePlay.privacyPolicyUrl, listing.links.privacyPolicyUrl);
  assert.equal(listing.googlePlay.termsUrl, listing.links.termsUrl);

  assert.ok(listing.appStore.subtitle.length <= 30);
  assert.ok(Buffer.byteLength(listing.appStore.keywords, "utf8") <= 100);
  assert.ok(listing.appStore.description.length <= 4000);
  assert.equal(listing.appStore.supportUrl, "https://maum-on.app/support");
  assert.equal(listing.appStore.marketingUrl, "https://maum-on.app");
  assert.equal(listing.appStore.privacyPolicyUrl, listing.links.privacyPolicyUrl);
  assert.equal(listing.appStore.reviewNotes.includes("test account"), true);
});

test("store listing contract defines screenshot and feature graphic production specs", () => {
  const listing = readJson(contractPath);
  const routes = screenRoutes(listing);

  for (const routeKey of ["home", "diary", "story", "letter", "consultation", "notifications", "settings"]) {
    assert.ok(routes.has(routeKey), `Missing store screenshot capture for ${routeKey}`);
    assert.match(read("front/lib/app/app_routes.dart"), new RegExp(`key: '${routeKey}'`));
  }

  assert.deepEqual(listing.featureGraphic.dimensions, { width: 1024, height: 500 });
  assert.equal(listing.featureGraphic.alpha, false);
  assert.match(listing.featureGraphic.path, /^store-assets\/google-play\/ko-KR\/feature-graphic-1024x500\.(png|jpg|jpeg)$/);
  assert.ok(listing.featureGraphic.altText.length > 0);
  assert.ok(listing.featureGraphic.altText.length <= 140);

  const sets = new Map(listing.screenshots.map((set) => [set.id, set]));
  assert.deepEqual(sets.get("android_phone").dimensions, { width: 1080, height: 1920 });
  assert.deepEqual(sets.get("iphone_6_9").dimensions, { width: 1320, height: 2868 });
  assert.deepEqual(sets.get("ipad_13").dimensions, { width: 2064, height: 2752 });

  for (const set of sets.values()) {
    assert.equal(set.orientation, "portrait");
    assert.ok(set.captures.length >= 2);
    assert.ok(set.captures.length <= set.maxCount);
    for (const capture of set.captures) {
      assert.equal(capture.actualAppScreen, true);
      assert.ok(capture.altText.length > 0);
      assert.ok(capture.altText.length <= 140);
      assert.match(
        capture.path,
        new RegExp(`^store-assets/${set.platform}/ko-KR/${set.id}/[0-9]{2}-${capture.routeKey}-${set.dimensions.width}x${set.dimensions.height}\\.png$`)
      );
    }
  }
});

test("store listing device and orientation policy matches native settings", () => {
  const listing = readJson(contractPath);
  const manifest = read("front/android/app/src/main/AndroidManifest.xml");
  const plist = read("front/ios/Runner/Info.plist");
  const project = read("front/ios/Runner.xcodeproj/project.pbxproj");

  assert.deepEqual(listing.devicePolicy.android.devices, ["phone"]);
  assert.deepEqual(listing.devicePolicy.android.orientations, ["portrait"]);
  assert.match(manifest, /android:screenOrientation="portrait"/);

  assert.deepEqual(listing.devicePolicy.ios.devices, ["iphone", "ipad"]);
  assert.deepEqual(listing.devicePolicy.ios.orientations, ["portrait"]);
  assert.match(project, /TARGETED_DEVICE_FAMILY = "1,2";/);
  assert.match(
    plist,
    /<key>UISupportedInterfaceOrientations<\/key>\s*<array>\s*<string>UIInterfaceOrientationPortrait<\/string>\s*<\/array>/
  );
  assert.match(
    plist,
    /<key>UISupportedInterfaceOrientations~ipad<\/key>\s*<array>\s*<string>UIInterfaceOrientationPortrait<\/string>\s*<\/array>/
  );
});

test("store listing validator reports package readiness", () => {
  const output = execFileSync("node", ["tools/ci/validate-store-listing.mjs"], {
    cwd: root,
    encoding: "utf8",
  });

  assert.match(output, /Store listing contract ok/);
  assert.match(output, /android_phone/);
  assert.match(output, /iphone_6_9/);
  assert.match(output, /ipad_13/);
});

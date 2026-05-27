#!/usr/bin/env node
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
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

function fail(message) {
  console.error(`Store listing contract error: ${message}`);
  process.exit(1);
}

function validateNoForbiddenStoreCopy(value, fieldName) {
  const forbidden = [
    /best/i,
    /#1/i,
    /top/i,
    /download now/i,
    /install now/i,
    /try now/i,
    /million downloads/i,
    /무료\s*행사/,
    /최고/,
    /1위/,
  ];
  for (const pattern of forbidden) {
    if (pattern.test(value)) {
      fail(`${fieldName} contains store-risk copy: ${pattern}`);
    }
  }
}

function validateMetadata(listing, privacy, legal) {
  assert.equal(listing.version, 1);
  assert.equal(listing.appName, "Maum On");
  assert.equal(listing.locale, "ko-KR");
  assert.equal(listing.links.privacyPolicyUrl, privacy.storeLinks.privacyPolicyUrl);
  assert.equal(listing.links.termsUrl, privacy.storeLinks.termsUrl);
  assert.equal(listing.links.supportEmail, privacy.storeLinks.supportEmail);

  for (const value of [
    listing.links.privacyPolicyUrl,
    listing.links.termsUrl,
    listing.links.supportEmail,
  ]) {
    assert.match(legal, new RegExp(escapeRegExp(value)));
  }

  assert.equal(listing.googlePlay.packageName, "com.aquilaxk.maumonmobile");
  assert.equal(listing.googlePlay.category, "Health & Fitness");
  assert.ok(listing.googlePlay.tags.length >= 3);
  assert.ok(listing.googlePlay.shortDescription.length <= 80);
  assert.ok(listing.googlePlay.longDescription.length <= 4000);
  assert.equal(listing.googlePlay.supportEmail, listing.links.supportEmail);
  assert.equal(listing.googlePlay.privacyPolicyUrl, listing.links.privacyPolicyUrl);
  assert.equal(listing.googlePlay.termsUrl, listing.links.termsUrl);
  validateNoForbiddenStoreCopy(listing.googlePlay.shortDescription, "googlePlay.shortDescription");
  validateNoForbiddenStoreCopy(listing.googlePlay.longDescription, "googlePlay.longDescription");

  assert.ok(listing.appStore.subtitle.length <= 30);
  assert.ok(Buffer.byteLength(listing.appStore.keywords, "utf8") <= 100);
  assert.ok(listing.appStore.description.length <= 4000);
  assert.equal(listing.appStore.supportUrl, listing.links.supportUrl);
  assert.equal(listing.appStore.marketingUrl, listing.links.marketingUrl);
  assert.equal(listing.appStore.privacyPolicyUrl, listing.links.privacyPolicyUrl);
  validateNoForbiddenStoreCopy(listing.appStore.description, "appStore.description");
}

function validateGraphic(listing) {
  assert.deepEqual(listing.featureGraphic.dimensions, { width: 1024, height: 500 });
  assert.equal(listing.featureGraphic.alpha, false);
  assert.match(listing.featureGraphic.path, /^store-assets\/google-play\/ko-KR\/feature-graphic-1024x500\.(png|jpg|jpeg)$/);
  assert.ok(listing.featureGraphic.altText.length > 0);
  assert.ok(listing.featureGraphic.altText.length <= 140);
}

function validateScreenshots(listing, appRoutes) {
  const requiredRoutes = ["home", "diary", "story", "letter", "consultation", "notifications", "settings"];
  const sets = new Map(listing.screenshots.map((set) => [set.id, set]));

  assert.deepEqual(sets.get("android_phone")?.dimensions, { width: 1080, height: 1920 });
  assert.deepEqual(sets.get("iphone_6_9")?.dimensions, { width: 1320, height: 2868 });
  assert.deepEqual(sets.get("ipad_13")?.dimensions, { width: 2064, height: 2752 });

  const routeCoverage = new Set();
  for (const set of sets.values()) {
    assert.equal(set.orientation, "portrait");
    assert.ok(set.captures.length >= set.minCount);
    assert.ok(set.captures.length <= set.maxCount);
    for (const capture of set.captures) {
      routeCoverage.add(capture.routeKey);
      assert.match(appRoutes, new RegExp(`key: '${escapeRegExp(capture.routeKey)}'`));
      assert.equal(capture.actualAppScreen, true);
      assert.ok(capture.altText.length > 0);
      assert.ok(capture.altText.length <= 140);
      assert.match(
        capture.path,
        new RegExp(`^store-assets/${set.platform}/ko-KR/${set.id}/[0-9]{2}-${escapeRegExp(capture.routeKey)}-${set.dimensions.width}x${set.dimensions.height}\\.png$`)
      );
    }
  }

  for (const routeKey of requiredRoutes) {
    assert.ok(routeCoverage.has(routeKey), `Missing route capture: ${routeKey}`);
  }
}

function validateDevicePolicy(listing, manifest, plist, project) {
  assert.deepEqual(listing.devicePolicy.android.devices, ["phone"]);
  assert.deepEqual(listing.devicePolicy.android.orientations, ["portrait"]);
  assert.match(manifest, /android:screenOrientation="portrait"/);

  assert.deepEqual(listing.devicePolicy.ios.devices, ["iphone", "ipad"]);
  assert.deepEqual(listing.devicePolicy.ios.orientations, ["portrait"]);
  assert.equal(listing.devicePolicy.ios.targetedDeviceFamily, "1,2");
  assert.match(project, /TARGETED_DEVICE_FAMILY = "1,2";/);
  assert.match(
    plist,
    /<key>UISupportedInterfaceOrientations<\/key>\s*<array>\s*<string>UIInterfaceOrientationPortrait<\/string>\s*<\/array>/
  );
  assert.match(
    plist,
    /<key>UISupportedInterfaceOrientations~ipad<\/key>\s*<array>\s*<string>UIInterfaceOrientationPortrait<\/string>\s*<\/array>/
  );
}

try {
  const listing = readJson(contractPath);
  validateMetadata(
    listing,
    readJson("contracts/store-privacy/data-safety.json"),
    read("front/lib/features/legal/domain/legal_disclosures.dart")
  );
  validateGraphic(listing);
  validateScreenshots(listing, read("front/lib/app/app_routes.dart"));
  validateDevicePolicy(
    listing,
    read("front/android/app/src/main/AndroidManifest.xml"),
    read("front/ios/Runner/Info.plist"),
    read("front/ios/Runner.xcodeproj/project.pbxproj")
  );

  console.log("Store listing contract ok");
  console.log(`screenshot sets: ${listing.screenshots.map((set) => set.id).join(", ")}`);
  console.log(`captures: ${listing.screenshots.reduce((count, set) => count + set.captures.length, 0)}`);
} catch (error) {
  fail(error.message);
}

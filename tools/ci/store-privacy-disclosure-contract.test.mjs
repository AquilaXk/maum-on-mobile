import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const contractPath = "contracts/store-privacy/data-safety.json";

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readJson(relativePath) {
  return JSON.parse(read(relativePath));
}

test("store privacy disclosure contract covers app data and rights", () => {
  assert.ok(existsSync(path.join(root, contractPath)), "Missing store privacy disclosure contract");

  const contract = readJson(contractPath);
  assert.equal(contract.version, 1);
  assert.match(contract.storeLinks.privacyPolicyUrl, /^https:\/\/.+/);
  assert.match(contract.storeLinks.termsUrl, /^https:\/\/.+/);
  assert.match(contract.storeLinks.supportEmail, /^[^@\s]+@[^@\s]+\.[^@\s]+$/);
  assert.equal(contract.storeLinks.accountDeletionPath, "settings.member_withdrawal");
  assert.equal(contract.storeLinks.dataExportPath, "settings.data_export");

  const categories = new Map(contract.dataCategories.map((category) => [category.id, category]));
  for (const id of [
    "account_info",
    "user_generated_content",
    "photos_or_videos",
    "sensitive_info",
    "push_token",
    "performance_data",
  ]) {
    assert.ok(categories.has(id), `Missing store data category: ${id}`);
  }

  for (const category of categories.values()) {
    assert.equal(category.collected, true, `${category.id} must declare collection`);
    assert.equal(typeof category.shared, "boolean", `${category.id} must declare sharing`);
    assert.equal(typeof category.deleteAvailable, "boolean", `${category.id} must declare deletion`);
    assert.ok(category.label.length > 0, `${category.id} must have a label`);
    assert.ok(category.purposes.length > 0, `${category.id} must have purposes`);
    assert.ok(category.retention.length > 0, `${category.id} must have retention guidance`);
    assert.ok(category.googlePlayDataTypes.length > 0, `${category.id} must map Google Play data types`);
    assert.ok(category.appStoreDataTypes.length > 0, `${category.id} must map App Store data types`);
  }

  assert.equal(categories.get("account_info").deleteAvailable, true);
  assert.equal(categories.get("push_token").deleteAvailable, true);
  assert.equal(categories.get("sensitive_info").deleteAvailable, true);
  assert.equal(categories.get("performance_data").deleteAvailable, false);
  assert.equal([...categories.values()].some((category) => category.shared), false);
});

test("store privacy disclosure contract matches platform permissions and privacy labels", () => {
  const contract = readJson(contractPath);
  const manifest = read("front/android/app/src/main/AndroidManifest.xml");
  const plist = read("front/ios/Runner/Info.plist");
  const privacyManifest = read("front/ios/Runner/PrivacyInfo.xcprivacy");

  const permissions = new Map(contract.permissions.map((permission) => [permission.id, permission]));
  for (const id of ["camera", "photos", "push_notifications"]) {
    assert.ok(permissions.has(id), `Missing permission disclosure: ${id}`);
  }

  for (const permission of permissions.values()) {
    for (const androidPermission of permission.androidPermissions) {
      assert.match(manifest, new RegExp(androidPermission.replaceAll(".", "\\.")));
    }
    for (const plistKey of permission.iosUsageDescriptionKeys) {
      assert.match(plist, new RegExp(`<key>${plistKey}<\\/key>\\s*<string>\\s*[^<\\s][^<]*<\\/string>`));
    }
    assert.ok(permission.userFacingNotice.length > 0, `${permission.id} must have user-facing notice`);
  }

  const appStoreDataTypes = new Set(
    contract.dataCategories.flatMap((category) => category.appStoreDataTypes)
  );
  for (const dataType of appStoreDataTypes) {
    assert.match(privacyManifest, new RegExp(dataType), `Missing App Store privacy data type: ${dataType}`);
  }
});

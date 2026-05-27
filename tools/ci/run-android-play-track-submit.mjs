#!/usr/bin/env node
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const defaultAabPath = path.join(repoRoot, "front/build/app/outputs/bundle/release/app-release.aab");
const requiredParticipants = 12;
const requiredDays = 14;
const validStatuses = new Set(["draft", "completed", "inProgress", "halted"]);

let dryRun = process.env.MAUMON_PLAY_RELEASE_DRY_RUN === "true";
for (const arg of process.argv.slice(2)) {
  if (arg === "--dry-run") {
    dryRun = true;
  } else if (arg === "-h" || arg === "--help") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

function usage() {
  console.log(`Usage: tools/ci/run-android-play-track-submit.mjs [--dry-run]

Submits a signed AAB to a Google Play testing track through Android Publisher edits.
Dry-run mode validates inputs and writes the release evidence report without network calls.`);
}

function env(name, fallback = "") {
  return process.env[name]?.trim() || fallback;
}

function stringValue(value) {
  if (value === undefined || value === null) {
    return "";
  }
  return String(value).trim();
}

function splitList(value) {
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function relativeDisplayPath(filePath) {
  const relativePath = path.relative(repoRoot, filePath);
  return relativePath.startsWith("..") ? filePath : relativePath;
}

function loadReleaseManifest() {
  const configuredPath = env("MAUMON_RELEASE_MANIFEST_PATH");
  if (!configuredPath) {
    return {
      path: "",
      document: null,
    };
  }

  const manifestPath = path.resolve(repoRoot, configuredPath);
  if (!existsSync(manifestPath)) {
    return {
      path: manifestPath,
      document: null,
    };
  }

  try {
    return {
      path: manifestPath,
      document: JSON.parse(readFileSync(manifestPath, "utf8")),
    };
  } catch (error) {
    console.error(`MAUMON_RELEASE_MANIFEST_PATH must point to valid JSON: ${relativeDisplayPath(manifestPath)} (${error.message})`);
    process.exit(1);
  }
}

function failMissing(names) {
  if (names.length === 0) {
    return;
  }

  console.error("Android Play track submit requires the following environment variables:");
  for (const name of names) {
    console.error(` - ${name}`);
  }
  process.exit(1);
}

function parseServiceAccount() {
  const encoded = env("MAUMON_PLAY_SERVICE_ACCOUNT_JSON_BASE64");
  try {
    const account = JSON.parse(Buffer.from(encoded, "base64").toString("utf8"));
    assert.equal(typeof account.client_email, "string");
    assert.equal(typeof account.private_key, "string");
    return {
      token_uri: account.token_uri || "https://oauth2.googleapis.com/token",
      client_email: account.client_email,
      private_key: account.private_key,
    };
  } catch {
    console.error("MAUMON_PLAY_SERVICE_ACCOUNT_JSON_BASE64 must be a base64-encoded service account JSON.");
    process.exit(1);
  }
}

function pubspecVersionCode() {
  const pubspec = readFileSync(path.join(repoRoot, "front/pubspec.yaml"), "utf8");
  const match = pubspec.match(/^version:\s*[^+\n]+\+(\d+)/m);
  return match?.[1] ?? "unknown";
}

function closedTestEvidence(trackKind, testerGroups, testerEmails) {
  if (trackKind !== "closed") {
    return null;
  }

  const missing = [];
  for (const name of [
    "MAUMON_PLAY_CLOSED_TEST_START_DATE",
    "MAUMON_PLAY_CLOSED_TEST_PARTICIPANT_COUNT",
    "MAUMON_PLAY_CLOSED_TEST_FEEDBACK_URL",
    "MAUMON_PLAY_PRODUCTION_ACCESS_STATUS",
  ]) {
    if (!env(name)) {
      missing.push(name);
    }
  }
  if (testerGroups.length === 0 && testerEmails.length === 0) {
    missing.push("MAUMON_PLAY_TESTER_GROUPS or MAUMON_PLAY_TESTER_EMAILS");
  }
  failMissing(missing);

  const startDate = env("MAUMON_PLAY_CLOSED_TEST_START_DATE");
  const startDateMs = Date.parse(`${startDate}T00:00:00Z`);
  if (Number.isNaN(startDateMs)) {
    console.error("MAUMON_PLAY_CLOSED_TEST_START_DATE must use YYYY-MM-DD.");
    process.exit(1);
  }

  const participantCount = Number.parseInt(env("MAUMON_PLAY_CLOSED_TEST_PARTICIPANT_COUNT"), 10);
  if (!Number.isInteger(participantCount) || participantCount < 0) {
    console.error("MAUMON_PLAY_CLOSED_TEST_PARTICIPANT_COUNT must be a non-negative integer.");
    process.exit(1);
  }

  const daysElapsed = Math.max(0, Math.floor((Date.now() - startDateMs) / 86_400_000));
  return {
    startDate,
    requiredParticipants,
    participantCount,
    meetsParticipantRequirement: participantCount >= requiredParticipants,
    requiredDays,
    daysElapsed,
    meetsDurationRequirement: daysElapsed >= requiredDays,
    feedbackUrl: env("MAUMON_PLAY_CLOSED_TEST_FEEDBACK_URL"),
  };
}

function validateInputs() {
  const releaseManifest = loadReleaseManifest();
  const manifestReleaseNotes = stringValue(releaseManifest.document?.storeReleaseNotes?.googlePlay);
  const manifestReleaseName = stringValue(releaseManifest.document?.releaseName);
  const manifestTesterNotes = stringValue(releaseManifest.document?.testerNotes);
  const releaseNotes = manifestReleaseNotes || env("MAUMON_PLAY_RELEASE_NOTES");
  const required = [
    "MAUMON_PLAY_SERVICE_ACCOUNT_JSON_BASE64",
    "MAUMON_PLAY_PACKAGE_NAME",
    "MAUMON_PLAY_TRACK",
    "MAUMON_PLAY_RELEASE_STATUS",
  ];
  if (!releaseNotes) {
    required.push("MAUMON_PLAY_RELEASE_NOTES");
  }
  failMissing(required.filter((name) => !env(name)));

  const releaseStatus = env("MAUMON_PLAY_RELEASE_STATUS");
  if (!validStatuses.has(releaseStatus)) {
    console.error(`MAUMON_PLAY_RELEASE_STATUS must be one of: ${Array.from(validStatuses).join(", ")}`);
    process.exit(1);
  }

  const trackKind = env("MAUMON_PLAY_TRACK_KIND", env("MAUMON_PLAY_TRACK") === "internal" ? "internal" : "closed");
  if (!["internal", "closed"].includes(trackKind)) {
    console.error("MAUMON_PLAY_TRACK_KIND must be internal or closed.");
    process.exit(1);
  }

  const aabPath = path.resolve(repoRoot, env("MAUMON_ANDROID_AAB_PATH", defaultAabPath));
  if (!dryRun && !existsSync(aabPath)) {
    console.error(`Android AAB is required for Play submit: ${aabPath}`);
    process.exit(1);
  }

  const testerGroups = splitList(env("MAUMON_PLAY_TESTER_GROUPS"));
  const testerEmails = splitList(env("MAUMON_PLAY_TESTER_EMAILS"));
  const closedTest = closedTestEvidence(trackKind, testerGroups, testerEmails);

  return {
    serviceAccount: parseServiceAccount(),
    packageName: env("MAUMON_PLAY_PACKAGE_NAME"),
    track: env("MAUMON_PLAY_TRACK"),
    trackKind,
    releaseStatus,
    releaseNotes,
    releaseNotesLanguage: env("MAUMON_PLAY_RELEASE_NOTES_LANGUAGE", "ko-KR"),
    releaseName: manifestReleaseName || env("MAUMON_PLAY_RELEASE_NAME"),
    testerNotes: manifestTesterNotes,
    releaseManifestPath: releaseManifest.path ? relativeDisplayPath(releaseManifest.path) : "",
    releaseManifestPresent: releaseManifest.document !== null,
    userFraction: env("MAUMON_PLAY_USER_FRACTION"),
    aabPath,
    testerGroups,
    testerEmails,
    closedTest,
    productionAccessStatus: env("MAUMON_PLAY_PRODUCTION_ACCESS_STATUS"),
    reportPath: path.resolve(repoRoot, env("MAUMON_PLAY_REPORT_PATH", "build/reports/android-play-track/android-play-track-evidence.json")),
  };
}

function writeEvidence(config, result = {}) {
  const evidence = {
    generatedAt: new Date().toISOString(),
    dryRun,
    packageName: config.packageName,
    track: config.track,
    trackKind: config.trackKind,
    releaseStatus: config.releaseStatus,
    releaseNotes: {
      language: config.releaseNotesLanguage,
      textLength: config.releaseNotes.length,
    },
    testerNotes: {
      textLength: config.testerNotes.length,
    },
    releaseManifest: {
      path: config.releaseManifestPath || null,
      present: config.releaseManifestPresent,
    },
    versionCode: result.versionCode?.toString() ?? pubspecVersionCode(),
    aabPath: config.aabPath,
    testerGroups: config.testerGroups,
    testerEmails: config.testerEmails,
    emailListApiSupport: "unsupported",
    closedTest: config.closedTest,
    productionAccessStatus: config.productionAccessStatus,
    editId: result.editId ?? null,
    committed: result.committed ?? false,
    apiPlan: [
      "edits.insert",
      "edits.bundles.upload",
      ...(config.testerGroups.length > 0 ? ["edits.testers.patch"] : []),
      "edits.tracks.update",
      "edits.commit",
    ],
  };

  mkdirSync(path.dirname(config.reportPath), { recursive: true });
  writeFileSync(config.reportPath, `${JSON.stringify(evidence, null, 2)}\n`);
  return evidence;
}

function base64url(input) {
  return Buffer.from(input).toString("base64url");
}

async function accessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: serviceAccount.token_uri,
    exp: now + 3600,
    iat: now,
  };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  const signature = crypto.createSign("RSA-SHA256").update(signingInput).sign(serviceAccount.private_key, "base64url");
  const assertion = `${signingInput}.${signature}`;

  const response = await fetch(serviceAccount.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw await playError("OAuth token exchange", response);
  }
  const body = await response.json();
  return body.access_token;
}

async function playError(step, response) {
  const text = await response.text();
  let detail = text;
  try {
    const parsed = JSON.parse(text);
    detail = parsed.error?.message || parsed.error_description || text;
  } catch {
    // Keep raw text when Google does not return JSON.
  }
  const duplicateHint = /versionCode|already exists|already been uploaded/i.test(detail)
    ? "\nVersionCode duplicate hint: increment front/pubspec.yaml build number before uploading a new AAB."
    : "";
  return new Error(`${step} failed with HTTP ${response.status}: ${detail}${duplicateHint}`);
}

async function googleJson(token, step, url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
  if (!response.ok) {
    throw await playError(step, response);
  }
  return response.json();
}

async function submit(config) {
  const token = await accessToken(config.serviceAccount);
  const packagePath = encodeURIComponent(config.packageName);
  const base = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packagePath}`;

  const edit = await googleJson(token, "edits.insert", `${base}/edits`, { method: "POST", body: "{}" });
  const editId = edit.id;
  const uploadUrl = `https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${packagePath}/edits/${encodeURIComponent(editId)}/bundles?uploadType=media`;
  const uploadResponse = await fetch(uploadUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/octet-stream",
    },
    body: readFileSync(config.aabPath),
  });
  if (!uploadResponse.ok) {
    throw await playError("edits.bundles.upload", uploadResponse);
  }
  const bundle = await uploadResponse.json();
  const versionCode = bundle.versionCode.toString();

  if (config.testerGroups.length > 0) {
    await googleJson(
      token,
      "edits.testers.patch",
      `${base}/edits/${encodeURIComponent(editId)}/testers/${encodeURIComponent(config.track)}`,
      {
        method: "PATCH",
        body: JSON.stringify({ googleGroups: config.testerGroups }),
      },
    );
  }

  const release = {
    name: config.releaseName || `Maum On ${versionCode}`,
    versionCodes: [versionCode],
    releaseNotes: [{ language: config.releaseNotesLanguage, text: config.releaseNotes }],
    status: config.releaseStatus,
  };
  if (config.userFraction) {
    release.userFraction = Number(config.userFraction);
  }

  await googleJson(
    token,
    "edits.tracks.update",
    `${base}/edits/${encodeURIComponent(editId)}/tracks/${encodeURIComponent(config.track)}`,
    {
      method: "PUT",
      body: JSON.stringify({ releases: [release] }),
    },
  );
  await googleJson(token, "edits.commit", `${base}/edits/${encodeURIComponent(editId)}:commit`, { method: "POST" });

  return { editId, versionCode, committed: true };
}

const config = validateInputs();
if (dryRun) {
  const evidence = writeEvidence(config);
  console.log("Android Play track submit dry run ok");
  console.log(`package: ${config.packageName}`);
  console.log(`track: ${config.track}`);
  console.log(`trackKind: ${config.trackKind}`);
  console.log(`releaseStatus: ${config.releaseStatus}`);
  console.log(`versionCode: ${evidence.versionCode}`);
  console.log(`releaseManifest: ${config.releaseManifestPath || "none"}`);
  console.log(`releaseNotesLength: ${config.releaseNotes.length}`);
  console.log(`testerNotesLength: ${config.testerNotes.length}`);
  console.log(`testerGroups: ${config.testerGroups.join(",") || "none"}`);
  if (config.testerEmails.length > 0) {
    console.log("email tester list is evidence-only; Android Publisher testers API supports Google Groups only");
  }
  console.log(`evidence: ${config.reportPath}`);
  process.exit(0);
}

try {
  const result = await submit(config);
  writeEvidence(config, result);
  console.log("Android Play track submit completed");
  console.log(`track: ${config.track}`);
  console.log(`versionCode: ${result.versionCode}`);
  console.log(`evidence: ${config.reportPath}`);
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

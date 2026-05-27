#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { isAbsolute, relative, resolve } from "node:path";

const repoRoot = process.cwd();
const args = parseArgs(process.argv.slice(2));
const contractPath = resolvePath(args.config ?? "contracts/release-manifest/manifest-gate.json");
const contract = readJson(contractPath);
const reportDir = resolvePath(args.reportDir ?? "build/reports/release-manifest");
const manifestPath = resolvePath(args.manifest ?? contract.defaultManifestPath ?? "contracts/release-manifest/current-release.json");
const requireManifest = args.requireManifest === true;
const failures = [];

const staticEvidence = validateStaticEvidence(contract.staticEvidence ?? []);
failures.push(...staticEvidence.failures);

const sourceVersions = readSourceVersions();
failures.push(...sourceVersions.failures);

const manifest = readReleaseManifest(manifestPath, requireManifest);
failures.push(...manifest.failures);

const versions = validateVersions(manifest.document, sourceVersions);
failures.push(...versions.failures);

const notes = validateNotes(manifest.document);
failures.push(...notes.failures);

const approval = validateApproval(manifest.document);
failures.push(...approval.failures);

const rollback = validateRollback(manifest.document);
failures.push(...rollback.failures);

const compatibility = validateCompatibility(manifest.document, sourceVersions);
failures.push(...compatibility.failures);

const duplicates = validateDuplicateBuildNumbers(manifest.document, sourceVersions);
failures.push(...duplicates.failures);

const report = {
  status: determineStatus(failures, manifest.status),
  generatedAt: new Date().toISOString(),
  contract: {
    path: relativeDisplayPath(contractPath),
    version: contract.version,
  },
  releaseBlockers: contract.releaseBlockers ?? [],
  manifest,
  sourceVersions,
  versions,
  notes,
  approval,
  rollback,
  compatibility,
  duplicates,
  staticEvidence,
  failures,
};

mkdirSync(reportDir, { recursive: true });
writeFileSync(resolve(reportDir, "release-manifest-report.json"), `${JSON.stringify(report, null, 2)}\n`);
if (manifest.document) {
  writeFileSync(resolve(reportDir, "release-manifest-final.json"), `${JSON.stringify(normalizeManifest(manifest.document), null, 2)}\n`);
}
writeFileSync(resolve(reportDir, "release-manifest-report.md"), renderMarkdown(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdown(report)}\n`, { flag: "a" });
}

console.log(`Release manifest report: ${resolve(reportDir, "release-manifest-report.json")}`);
console.log(renderConsoleSummary(report));

if (report.status === "blocked") {
  for (const failure of failures.slice(0, 50)) {
    console.error(`${failure.reason}: ${failure.message}`);
  }
  if (failures.length > 50) {
    console.error(`Additional failures omitted from log: ${failures.length - 50}`);
  }
  process.exit(1);
}

function readReleaseManifest(filePath, required) {
  if (!existsSync(filePath)) {
    if (!required) {
      return {
        status: "not_required",
        path: relativeDisplayPath(filePath),
        required,
        document: null,
        failures: [],
      };
    }

    return {
      status: "fail",
      path: relativeDisplayPath(filePath),
      required,
      document: null,
      failures: [
        {
          reason: "missing_release_manifest",
          message: `Missing release manifest: ${relativeDisplayPath(filePath)}`,
        },
      ],
    };
  }

  let document;
  try {
    document = JSON.parse(readFileSync(filePath, "utf8"));
  } catch (error) {
    return {
      status: "fail",
      path: relativeDisplayPath(filePath),
      required,
      document: null,
      failures: [
        {
          reason: "invalid_release_manifest",
          message: `Invalid release manifest JSON: ${relativeDisplayPath(filePath)} (${error.message})`,
        },
      ],
    };
  }

  const shapeFailures = validateManifestShape(document);
  return {
    status: shapeFailures.length === 0 ? "pass" : "fail",
    path: relativeDisplayPath(filePath),
    required,
    document,
    failures: shapeFailures,
  };
}

function validateManifestShape(document) {
  const shapeFailures = [];

  if (!document || typeof document !== "object" || Array.isArray(document)) {
    return [
      {
        reason: "invalid_release_manifest",
        message: "Release manifest must be a JSON object.",
      },
    ];
  }

  for (const field of contract.manifestSchema?.requiredTopLevelFields ?? []) {
    if (!hasField(document, field)) {
      shapeFailures.push({
        reason: "invalid_release_manifest",
        message: `Release manifest is missing '${field}'.`,
        field,
      });
    }
  }

  for (const [platform, fields] of Object.entries(contract.manifestSchema?.requiredPlatformFields ?? {})) {
    for (const field of fields) {
      const fieldPath = `${platform}.${field}`;
      if (!hasField(document, fieldPath)) {
        shapeFailures.push({
          reason: "invalid_release_manifest",
          message: `Release manifest is missing '${fieldPath}'.`,
          field: fieldPath,
        });
      }
    }
  }

  if (hasField(document, "knownIssues") && !Array.isArray(document.knownIssues)) {
    shapeFailures.push({
      reason: "invalid_release_manifest",
      message: "Release manifest knownIssues must be an array.",
      field: "knownIssues",
    });
  }

  return shapeFailures;
}

function validateVersions(document, sources) {
  if (!document) {
    return {
      status: "not_available",
      expected: sources.versions,
      actual: {},
      failures: [],
    };
  }

  const expected = sources.versions;
  const actual = {
    androidVersionName: stringValue(getValue(document, "android.versionName")),
    androidVersionCode: stringValue(getValue(document, "android.versionCode")),
    iosShortVersion: stringValue(getValue(document, "ios.shortVersion")),
    iosBuildNumber: stringValue(getValue(document, "ios.buildNumber")),
    backendVersion: stringValue(getValue(document, "backend.version")),
    apiContractVersion: stringValue(document.apiContractVersion),
  };
  const versionFailures = [];

  compareVersion(versionFailures, "android.versionName", actual.androidVersionName, expected.android.versionName);
  compareVersion(versionFailures, "android.versionCode", actual.androidVersionCode, expected.android.versionCode);
  compareVersion(versionFailures, "ios.shortVersion", actual.iosShortVersion, expected.ios.shortVersion);
  compareVersion(versionFailures, "ios.buildNumber", actual.iosBuildNumber, expected.ios.buildNumber);
  compareVersion(versionFailures, "backend.version", actual.backendVersion, expected.backend.version);
  compareVersion(versionFailures, "apiContractVersion", actual.apiContractVersion, expected.apiContractVersion);

  return {
    status: versionFailures.length === 0 ? "pass" : "fail",
    expected,
    actual,
    failures: versionFailures,
  };
}

function compareVersion(versionFailures, field, actual, expected) {
  if (!actual || !expected) {
    return;
  }

  if (actual !== expected) {
    versionFailures.push({
      reason: "release_version_mismatch",
      message: `Release manifest '${field}' is '${actual}', expected '${expected}'.`,
      field,
      actual,
      expected,
    });
  }
}

function validateNotes(document) {
  if (!document) {
    return { status: "not_available", failures: [] };
  }

  const noteFailures = [];
  const googlePlay = stringValue(getValue(document, "storeReleaseNotes.googlePlay"));
  const appStore = stringValue(getValue(document, "storeReleaseNotes.appStore"));
  const testerNotes = stringValue(document.testerNotes);

  for (const [field, value] of [
    ["storeReleaseNotes.googlePlay", googlePlay],
    ["storeReleaseNotes.appStore", appStore],
    ["testerNotes", testerNotes],
  ]) {
    if (!value) {
      noteFailures.push({
        reason: "release_notes_missing",
        message: `Release manifest is missing '${field}'.`,
        field,
      });
    }
  }

  if (googlePlay.length > 500) {
    noteFailures.push({
      reason: "release_notes_missing",
      message: "Google Play release notes must stay at or below 500 characters.",
      field: "storeReleaseNotes.googlePlay",
    });
  }

  if (appStore.length > 4000 || testerNotes.length > 4000) {
    noteFailures.push({
      reason: "release_notes_missing",
      message: "App Store and tester notes must stay at or below 4000 characters.",
      field: "storeReleaseNotes.appStore",
    });
  }

  return {
    status: noteFailures.length === 0 ? "pass" : "fail",
    googlePlayLength: googlePlay.length,
    appStoreLength: appStore.length,
    testerNotesLength: testerNotes.length,
    failures: noteFailures,
  };
}

function validateApproval(document) {
  if (!document) {
    return { status: "not_available", failures: [] };
  }

  const approvalFailures = [];
  for (const field of contract.manifestSchema?.requiredApprovalFields ?? []) {
    const fieldPath = `approval.${field}`;
    if (isBlank(getValue(document, fieldPath))) {
      approvalFailures.push({
        reason: "release_approval_missing",
        message: `Release manifest approval is missing '${fieldPath}'.`,
        field: fieldPath,
      });
    }
  }

  return {
    status: approvalFailures.length === 0 ? "pass" : "fail",
    approver: stringValue(getValue(document, "approval.approver")),
    changeScope: stringValue(getValue(document, "approval.changeScope")),
    deployWindow: {
      start: stringValue(getValue(document, "approval.deployWindow.start")),
      end: stringValue(getValue(document, "approval.deployWindow.end")),
    },
    failures: approvalFailures,
  };
}

function validateRollback(document) {
  if (!document) {
    return { status: "not_available", failures: [] };
  }

  const rollbackFailures = [];
  const owner = stringValue(getValue(document, "rollback.owner"));
  const conditions = Array.isArray(getValue(document, "rollback.conditions"))
    ? getValue(document, "rollback.conditions").map(stringValue).filter(Boolean)
    : [];

  if (!owner) {
    rollbackFailures.push({
      reason: "rollback_condition_missing",
      message: "Release manifest rollback owner is missing.",
      field: "rollback.owner",
    });
  }
  if (conditions.length === 0) {
    rollbackFailures.push({
      reason: "rollback_condition_missing",
      message: "Release manifest rollback conditions are missing.",
      field: "rollback.conditions",
    });
  }

  return {
    status: rollbackFailures.length === 0 ? "pass" : "fail",
    owner,
    conditionCount: conditions.length,
    failures: rollbackFailures,
  };
}

function validateCompatibility(document, sources) {
  if (!document) {
    return { status: "not_available", failures: [] };
  }

  const compatibilityFailures = [];
  const backendVersion = stringValue(getValue(document, "backend.version"));
  const apiContractVersion = stringValue(document.apiContractVersion);
  const backendMigrationSummary = stringValue(document.backendMigrationSummary);

  if (!backendVersion) {
    compatibilityFailures.push({
      reason: "backend_compatibility_missing",
      message: "Release manifest backend version is missing.",
      field: "backend.version",
    });
  }
  if (!apiContractVersion) {
    compatibilityFailures.push({
      reason: "backend_compatibility_missing",
      message: "Release manifest API contract version is missing.",
      field: "apiContractVersion",
    });
  }
  if (apiContractVersion && !apiContractVersion.startsWith("mobile-api-v")) {
    compatibilityFailures.push({
      reason: "backend_compatibility_missing",
      message: "Release manifest API contract version must use the mobile-api-v prefix.",
      field: "apiContractVersion",
    });
  }
  if (!backendMigrationSummary) {
    compatibilityFailures.push({
      reason: "backend_compatibility_missing",
      message: "Release manifest backend migration summary is missing.",
      field: "backendMigrationSummary",
    });
  }

  return {
    status: compatibilityFailures.length === 0 ? "pass" : "fail",
    backendVersion,
    expectedBackendVersion: sources.versions.backend.version,
    apiContractVersion,
    expectedApiContractVersion: sources.versions.apiContractVersion,
    backendMigrationSummaryPresent: Boolean(backendMigrationSummary),
    failures: compatibilityFailures,
  };
}

function validateDuplicateBuildNumbers(document, sources) {
  if (!document) {
    return { status: "not_available", failures: [] };
  }

  const duplicateFailures = [];
  const androidBuildNumber = stringValue(getValue(document, "android.versionCode")) || sources.versions.android.versionCode;
  const iosBuildNumber = stringValue(getValue(document, "ios.buildNumber")) || sources.versions.ios.buildNumber;
  const publishedAndroid = arrayValues(getValue(document, "publishedBuildNumbers.android"));
  const publishedIos = arrayValues(getValue(document, "publishedBuildNumbers.ios"));

  if (publishedAndroid.includes(androidBuildNumber)) {
    duplicateFailures.push({
      reason: "duplicate_build_number",
      message: `Android versionCode '${androidBuildNumber}' already appears in published build numbers.`,
      platform: "android",
      buildNumber: androidBuildNumber,
    });
  }

  if (publishedIos.includes(iosBuildNumber)) {
    duplicateFailures.push({
      reason: "duplicate_build_number",
      message: `iOS build number '${iosBuildNumber}' already appears in published build numbers.`,
      platform: "ios",
      buildNumber: iosBuildNumber,
    });
  }

  return {
    status: duplicateFailures.length === 0 ? "pass" : "fail",
    publishedAndroidCount: publishedAndroid.length,
    publishedIosCount: publishedIos.length,
    failures: duplicateFailures,
  };
}

function readSourceVersions() {
  const sourceFailures = [];
  const pubspec = readText("front/pubspec.yaml");
  const pubspecMatch = pubspec.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)/m);
  if (!pubspecMatch) {
    sourceFailures.push({
      reason: "missing_static_evidence",
      message: "front/pubspec.yaml must define version as x.y.z+n.",
      file: "front/pubspec.yaml",
    });
  }

  const backendBuild = readText("back/build.gradle.kts");
  const backendMatch = backendBuild.match(/version = "([^"]+)"/);
  if (!backendMatch) {
    sourceFailures.push({
      reason: "missing_static_evidence",
      message: "back/build.gradle.kts must define a backend version.",
      file: "back/build.gradle.kts",
    });
  }

  let apiContractVersion = "";
  try {
    const apiContract = readJson(resolvePath("contracts/mobile-api/response-snapshots.json"));
    if (Number.isInteger(apiContract.version)) {
      apiContractVersion = `mobile-api-v${apiContract.version}`;
    }
  } catch (error) {
    sourceFailures.push({
      reason: "missing_static_evidence",
      message: `Could not read mobile API contract version: ${error.message}`,
      file: "contracts/mobile-api/response-snapshots.json",
    });
  }

  const versionName = pubspecMatch?.[1] ?? "";
  const buildNumber = pubspecMatch?.[2] ?? "";
  return {
    status: sourceFailures.length === 0 ? "pass" : "fail",
    versions: {
      android: {
        versionName,
        versionCode: buildNumber,
      },
      ios: {
        shortVersion: versionName,
        buildNumber,
      },
      backend: {
        version: backendMatch?.[1] ?? "",
      },
      apiContractVersion,
    },
    failures: sourceFailures,
  };
}

function validateStaticEvidence(items) {
  const evidenceItems = items.map(validateEvidenceItem);
  const evidenceFailures = evidenceItems.flatMap((item) => item.failures);
  if (items.length === 0) {
    evidenceFailures.push({
      reason: "missing_static_evidence",
      message: "At least one static evidence item is required.",
    });
  }

  return {
    status: evidenceFailures.length === 0 ? "pass" : "fail",
    evidenceItems,
    failures: evidenceFailures,
  };
}

function validateEvidenceItem(item) {
  const itemFailures = [];
  const filePath = resolvePath(item.file);
  const fileExists = existsSync(filePath);
  const content = fileExists ? readFileSync(filePath, "utf8") : "";
  const patterns = item.patterns ?? [];
  const patternResults = patterns.map((pattern) => {
    const matched = fileExists && new RegExp(pattern, "m").test(content);
    if (!matched) {
      itemFailures.push({
        reason: "missing_static_evidence",
        message: `Evidence '${item.id}' is missing pattern '${pattern}' in ${item.file}.`,
        itemId: item.id,
        file: item.file,
        pattern,
      });
    }
    return { pattern, matched };
  });

  if (!fileExists) {
    itemFailures.push({
      reason: "missing_static_evidence",
      message: `Evidence '${item.id}' file does not exist: ${item.file}`,
      itemId: item.id,
      file: item.file,
    });
  }
  if (patterns.length === 0) {
    itemFailures.push({
      reason: "missing_static_evidence",
      message: `Evidence '${item.id}' must declare at least one pattern.`,
      itemId: item.id,
      file: item.file,
    });
  }

  return {
    id: item.id,
    file: item.file,
    status: itemFailures.length === 0 ? "pass" : "fail",
    patternResults,
    failures: itemFailures,
  };
}

function normalizeManifest(document) {
  return {
    releaseNumber: document.releaseNumber,
    releaseName: document.releaseName,
    android: document.android,
    ios: document.ios,
    backend: document.backend,
    apiContractVersion: document.apiContractVersion,
    storeReleaseNotes: document.storeReleaseNotes,
    testerNotes: document.testerNotes,
    backendMigrationSummary: document.backendMigrationSummary,
    knownIssues: Array.isArray(document.knownIssues) ? document.knownIssues : [],
    rollback: document.rollback,
    approval: document.approval,
    publishedBuildNumbers: document.publishedBuildNumbers ?? {
      android: [],
      ios: [],
    },
  };
}

function determineStatus(currentFailures, manifestStatus) {
  if (currentFailures.length > 0) {
    return "blocked";
  }
  if (manifestStatus === "not_required") {
    return "pending";
  }
  return "pass";
}

function renderMarkdown(report) {
  const lines = [
    "# Release Manifest Approval Gate",
    "",
    `- Status: ${report.status}`,
    `- Manifest: ${report.manifest.path}`,
    `- Manifest status: ${report.manifest.status}`,
    `- Android: ${report.versions.actual?.androidVersionName ?? ""}+${report.versions.actual?.androidVersionCode ?? ""}`,
    `- iOS: ${report.versions.actual?.iosShortVersion ?? ""}+${report.versions.actual?.iosBuildNumber ?? ""}`,
    `- Backend: ${report.versions.actual?.backendVersion ?? ""}`,
    `- API contract: ${report.versions.actual?.apiContractVersion ?? ""}`,
    "",
    "## Deploy Window",
    "",
    `- Approver: ${report.approval.approver ?? ""}`,
    `- Start: ${report.approval.deployWindow?.start ?? ""}`,
    `- End: ${report.approval.deployWindow?.end ?? ""}`,
    "",
    "## Notes",
    "",
    `- Google Play notes length: ${report.notes.googlePlayLength ?? 0}`,
    `- App Store notes length: ${report.notes.appStoreLength ?? 0}`,
    `- Tester notes length: ${report.notes.testerNotesLength ?? 0}`,
    "",
    "## Failures",
    "",
  ];

  if (report.failures.length === 0) {
    lines.push("- None");
  } else {
    for (const failure of report.failures) {
      lines.push(`- ${failure.reason}: ${failure.message}`);
    }
  }

  return `${lines.join("\n")}\n`;
}

function renderConsoleSummary(report) {
  return [
    `status: ${report.status}`,
    `manifest: ${report.manifest.status}`,
    `versions: ${report.versions.status}`,
    `notes: ${report.notes.status}`,
    `approval: ${report.approval.status}`,
    `rollback: ${report.rollback.status}`,
    `compatibility: ${report.compatibility.status}`,
    `duplicates: ${report.duplicates.status}`,
    `failures: ${report.failures.length}`,
  ].join("\n");
}

function parseArgs(rawArgs) {
  const parsed = {};
  for (let index = 0; index < rawArgs.length; index += 1) {
    const arg = rawArgs[index];
    if (arg === "--require-manifest") {
      parsed.requireManifest = true;
    } else if (arg === "--config" || arg === "--manifest" || arg === "--report-dir") {
      const value = rawArgs[index + 1];
      if (!value) {
        console.error(`${arg} requires a value.`);
        process.exit(2);
      }
      parsed[toCamel(arg.slice(2))] = value;
      index += 1;
    } else if (arg === "-h" || arg === "--help") {
      usage();
      process.exit(0);
    } else {
      console.error(`Unknown argument: ${arg}`);
      usage();
      process.exit(2);
    }
  }
  return parsed;
}

function usage() {
  console.log(`Usage: tools/ci/run-release-manifest-gate.mjs [--config path] [--manifest path] [--report-dir path] [--require-manifest]

Validates release manifest approval data against Android, iOS, backend, store note, and rollback release contracts.`);
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function readText(relativePath) {
  const filePath = resolvePath(relativePath);
  if (!existsSync(filePath)) {
    return "";
  }
  return readFileSync(filePath, "utf8");
}

function resolvePath(filePath) {
  return isAbsolute(filePath) ? filePath : resolve(repoRoot, filePath);
}

function relativeDisplayPath(filePath) {
  const relativePath = relative(repoRoot, filePath);
  return relativePath.startsWith("..") ? filePath : relativePath;
}

function getValue(object, fieldPath) {
  return fieldPath.split(".").reduce((current, key) => {
    if (current === undefined || current === null) {
      return undefined;
    }
    return current[key];
  }, object);
}

function hasField(object, fieldPath) {
  return getValue(object, fieldPath) !== undefined && getValue(object, fieldPath) !== null;
}

function stringValue(value) {
  if (value === undefined || value === null) {
    return "";
  }
  return String(value).trim();
}

function isBlank(value) {
  return stringValue(value) === "";
}

function arrayValues(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map(stringValue).filter(Boolean);
}

function toCamel(value) {
  return value.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
}

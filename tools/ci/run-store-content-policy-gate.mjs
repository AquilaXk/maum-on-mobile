import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, isAbsolute, relative, resolve } from "node:path";

const repoRoot = process.cwd();
const args = parseArgs(process.argv.slice(2));
const contractPath = resolvePath(args.config ?? "contracts/store-content/app-content-permissions.json");
const reportDir = resolvePath(args.reportDir ?? "build/reports/store-content-policy");
const contract = readJson(contractPath);
const storePrivacy = readJson(resolvePath(contract.storePrivacyContract ?? "contracts/store-privacy/data-safety.json"));
const failures = [];

const playConsole = validateStoreAnswers("play-console", contract.playConsole ?? {});
failures.push(...playConsole.failures);

const appStoreConnect = validateStoreAnswers("app-store-connect", contract.appStoreConnect ?? {});
failures.push(...appStoreConnect.failures);

const permissionDeclarations = validatePermissionDeclarations(
  contract.permissionDeclarations ?? [],
  storePrivacy,
  playConsole.answerIdSet,
  appStoreConnect.answerIdSet,
);
failures.push(...permissionDeclarations.failures);

const policyEvidence = validatePolicyEvidence(contract.policyEvidence ?? []);
failures.push(...policyEvidence.failures);

const runtimeEvidence = validateRuntimeEvidence(contract.runtimeEvidence ?? {});
failures.push(...runtimeEvidence.failures);

const report = {
  status: failures.length === 0 ? "pass" : "blocked",
  generatedAt: new Date().toISOString(),
  contract: {
    path: relativeDisplayPath(contractPath),
    version: contract.version,
  },
  releaseBlockers: contract.releaseBlockers ?? [],
  playConsole,
  appStoreConnect,
  permissionDeclarations,
  policyEvidence,
  runtimeEvidence,
  failures,
};

mkdirSync(reportDir, { recursive: true });
writeFileSync(resolve(reportDir, "store-content-policy-report.json"), `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(resolve(reportDir, "store-content-policy-runtime-evidence.json"), `${JSON.stringify(runtimeEvidence, null, 2)}\n`);
writeFileSync(resolve(reportDir, "store-content-policy-report.md"), renderMarkdown(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdown(report)}\n`, { flag: "a" });
}

console.log(`Store content policy report: ${resolve(reportDir, "store-content-policy-report.json")}`);
console.log(renderConsoleSummary(report));

if (report.status !== "pass") {
  for (const failure of failures.slice(0, 40)) {
    console.error(`${failure.reason}: ${failure.message}`);
  }
  if (failures.length > 40) {
    console.error(`Additional failures omitted from log: ${failures.length - 40}`);
  }
  process.exit(1);
}

function validateStoreAnswers(groupId, config) {
  const answerIdSet = new Set();
  const answerResults = [];
  const groupFailures = [];
  const sectionSet = new Set();

  for (const answer of config.answers ?? []) {
    const answerFailures = [];
    if (!answer.id || answer.id.trim().length === 0) {
      answerFailures.push({
        reason: "missing_store_answer",
        message: `${groupId} answer is missing id.`,
      });
    } else if (answerIdSet.has(answer.id)) {
      answerFailures.push({
        reason: "missing_store_answer",
        message: `${groupId} answer '${answer.id}' is duplicated.`,
        answerId: answer.id,
      });
    } else {
      answerIdSet.add(answer.id);
    }

    if (!answer.section || answer.section.trim().length === 0) {
      answerFailures.push({
        reason: "missing_store_answer",
        message: `${groupId} answer '${answer.id ?? "unknown"}' is missing section.`,
        answerId: answer.id,
      });
    } else {
      sectionSet.add(answer.section);
    }

    if (!answer.question || answer.question.trim().length === 0) {
      answerFailures.push({
        reason: "missing_store_answer",
        message: `${groupId} answer '${answer.id ?? "unknown"}' is missing question.`,
        answerId: answer.id,
      });
    }

    if (!answer.owner || answer.owner.trim().length === 0) {
      answerFailures.push({
        reason: "missing_store_owner",
        message: `${groupId} answer '${answer.id ?? "unknown"}' is missing owner.`,
        answerId: answer.id,
      });
    }

    if (!hasAnswerValue(answer.answer)) {
      answerFailures.push({
        reason: "missing_store_answer",
        message: `${groupId} answer '${answer.id ?? "unknown"}' is missing answer value.`,
        answerId: answer.id,
      });
    }

    const evidence = validateEvidenceGroup(`${groupId}:${answer.id ?? "unknown"}`, answer.evidence ?? []);
    answerFailures.push(...evidence.failures);
    groupFailures.push(...answerFailures);

    answerResults.push({
      id: answer.id,
      section: answer.section,
      question: answer.question,
      owner: answer.owner,
      status: answerFailures.length === 0 ? "pass" : "fail",
      evidence,
      failures: answerFailures,
    });
  }

  for (const requiredSection of config.requiredSections ?? []) {
    if (!sectionSet.has(requiredSection)) {
      groupFailures.push({
        reason: "missing_store_answer",
        message: `${groupId} is missing required section '${requiredSection}'.`,
        section: requiredSection,
      });
    }
  }

  if ((config.answers ?? []).length === 0) {
    groupFailures.push({
      reason: "missing_store_answer",
      message: `${groupId} must declare at least one store answer.`,
    });
  }

  const result = {
    status: groupFailures.length === 0 ? "pass" : "fail",
    owner: config.owner,
    requiredSections: config.requiredSections ?? [],
    sections: [...sectionSet].sort(),
    answerIds: [...answerIdSet].sort(),
    answers: answerResults,
    failures: groupFailures,
  };
  Object.defineProperty(result, "answerIdSet", {
    enumerable: false,
    value: answerIdSet,
  });
  return result;
}

function validatePermissionDeclarations(declarations, storePrivacy, playAnswerIds, appStoreAnswerIds) {
  const manifest = readFile("front/android/app/src/main/AndroidManifest.xml");
  const plist = readFile("front/ios/Runner/Info.plist");
  const storePermissions = new Map((storePrivacy.permissions ?? []).map((permission) => [permission.id, permission]));
  const declarationsById = new Map(declarations.map((permission) => [permission.id, permission]));
  const permissionResults = [];
  const declarationFailures = [];

  for (const storePermission of storePermissions.values()) {
    if (!declarationsById.has(storePermission.id)) {
      declarationFailures.push({
        reason: "permission_manifest_mismatch",
        message: `Missing permission declaration for '${storePermission.id}'.`,
        permissionId: storePermission.id,
      });
    }
  }

  for (const declaration of declarations) {
    const permissionFailures = [];
    const privacyPermission = storePermissions.get(declaration.privacyPermissionId ?? declaration.id);

    if (!privacyPermission) {
      permissionFailures.push({
        reason: "permission_manifest_mismatch",
        message: `Permission '${declaration.id}' does not map to the store privacy contract.`,
        permissionId: declaration.id,
      });
    } else {
      if (!sameStringSet(declaration.androidPermissions ?? [], privacyPermission.androidPermissions ?? [])) {
        permissionFailures.push({
          reason: "permission_manifest_mismatch",
          message: `Android permissions for '${declaration.id}' do not match the store privacy contract.`,
          permissionId: declaration.id,
        });
      }
      if (!sameStringSet(declaration.iosUsageDescriptionKeys ?? [], privacyPermission.iosUsageDescriptionKeys ?? [])) {
        permissionFailures.push({
          reason: "permission_manifest_mismatch",
          message: `iOS usage keys for '${declaration.id}' do not match the store privacy contract.`,
          permissionId: declaration.id,
        });
      }
      if (declaration.userFacingNotice !== privacyPermission.userFacingNotice) {
        permissionFailures.push({
          reason: "permission_manifest_mismatch",
          message: `User-facing notice for '${declaration.id}' does not match the store privacy contract.`,
          permissionId: declaration.id,
        });
      }
    }

    if (!declaration.usageRationale || declaration.usageRationale.trim().length === 0) {
      permissionFailures.push({
        reason: "missing_store_answer",
        message: `Permission '${declaration.id}' is missing usage rationale.`,
        permissionId: declaration.id,
      });
    }

    for (const androidPermission of declaration.androidPermissions ?? []) {
      if (!hasAndroidPermission(manifest, androidPermission)) {
        permissionFailures.push({
          reason: "permission_manifest_mismatch",
          message: `Android manifest is missing permission '${androidPermission}' for '${declaration.id}'.`,
          permissionId: declaration.id,
          androidPermission,
        });
      }
    }

    for (const legacyPermission of declaration.legacyAndroidPermissions ?? []) {
      if (!hasAndroidPermission(manifest, legacyPermission.name, legacyPermission.maxSdkVersion)) {
        permissionFailures.push({
          reason: "permission_manifest_mismatch",
          message: `Android manifest is missing legacy permission '${legacyPermission.name}' with maxSdkVersion '${legacyPermission.maxSdkVersion}'.`,
          permissionId: declaration.id,
          androidPermission: legacyPermission.name,
        });
      }
    }

    for (const plistKey of declaration.iosUsageDescriptionKeys ?? []) {
      if (!hasPlistUsageDescription(plist, plistKey)) {
        permissionFailures.push({
          reason: "permission_manifest_mismatch",
          message: `Info.plist is missing usage description '${plistKey}' for '${declaration.id}'.`,
          permissionId: declaration.id,
          plistKey,
        });
      }
    }

    if (declaration.iosRemoteNotificationBackgroundModeRequired === true && !hasRemoteNotificationMode(plist)) {
      permissionFailures.push({
        reason: "permission_manifest_mismatch",
        message: `Info.plist is missing remote-notification background mode for '${declaration.id}'.`,
        permissionId: declaration.id,
      });
    }

    for (const answerId of declaration.storeAnswerIds?.playConsole ?? []) {
      if (!playAnswerIds.has(answerId)) {
        permissionFailures.push({
          reason: "missing_store_answer",
          message: `Permission '${declaration.id}' links missing Play Console answer '${answerId}'.`,
          permissionId: declaration.id,
          answerId,
        });
      }
    }

    for (const answerId of declaration.storeAnswerIds?.appStoreConnect ?? []) {
      if (!appStoreAnswerIds.has(answerId)) {
        permissionFailures.push({
          reason: "missing_store_answer",
          message: `Permission '${declaration.id}' links missing App Store Connect answer '${answerId}'.`,
          permissionId: declaration.id,
          answerId,
        });
      }
    }

    const recoveryEvidence = validateEvidenceGroup(`permission:${declaration.id}`, declaration.recoveryEvidence ?? []);
    permissionFailures.push(...recoveryEvidence.failures);
    declarationFailures.push(...permissionFailures);

    permissionResults.push({
      id: declaration.id,
      label: declaration.label,
      status: permissionFailures.length === 0 ? "pass" : "fail",
      androidPermissions: declaration.androidPermissions ?? [],
      iosUsageDescriptionKeys: declaration.iosUsageDescriptionKeys ?? [],
      recoveryEvidence,
      failures: permissionFailures,
    });
  }

  return {
    status: declarationFailures.length === 0 ? "pass" : "fail",
    declarations: permissionResults,
    failures: declarationFailures,
  };
}

function validatePolicyEvidence(groups) {
  const groupResults = [];
  const groupFailures = [];

  for (const group of groups) {
    const evidence = validateEvidenceGroup(group.id ?? "unknown", group.evidenceItems ?? []);
    const failures = [...evidence.failures];
    for (const field of ["id", "label", "owner"]) {
      if (!group[field] || group[field].toString().trim().length === 0) {
        failures.push({
          reason: "missing_policy_evidence",
          message: `Policy evidence group '${group.id ?? "unknown"}' is missing ${field}.`,
          groupId: group.id,
          field,
        });
      }
    }
    if ((group.evidenceItems ?? []).length === 0) {
      failures.push({
        reason: "missing_policy_evidence",
        message: `Policy evidence group '${group.id ?? "unknown"}' must include evidence items.`,
        groupId: group.id,
      });
    }

    groupFailures.push(...failures);
    groupResults.push({
      id: group.id,
      label: group.label,
      owner: group.owner,
      status: failures.length === 0 ? "pass" : "fail",
      evidence,
      failures,
    });
  }

  if (groups.length === 0) {
    groupFailures.push({
      reason: "missing_policy_evidence",
      message: "At least one UGC policy evidence group is required.",
    });
  }

  return {
    status: groupFailures.length === 0 ? "pass" : "fail",
    groups: groupResults,
    failures: groupFailures,
  };
}

function validateEvidenceGroup(groupId, items) {
  const evidenceItems = items.map((item) => validateEvidenceItem(groupId, item));
  const groupFailures = evidenceItems.flatMap((item) => item.failures);

  if (items.length === 0) {
    groupFailures.push({
      reason: "missing_policy_evidence",
      message: `Evidence group '${groupId}' must declare at least one item.`,
      groupId,
    });
  }

  return {
    status: groupFailures.length === 0 ? "pass" : "fail",
    evidenceItems,
    failures: groupFailures,
  };
}

function validateEvidenceItem(groupId, item) {
  const itemFailures = [];
  const filePath = resolvePath(item.file);
  const fileExists = Boolean(item.file) && existsSync(filePath);
  const content = fileExists ? readFileSync(filePath, "utf8") : "";
  const patternResults = (item.patterns ?? []).map((pattern) => {
    const matched = fileExists && new RegExp(pattern, "m").test(content);
    if (!matched && item.required !== false) {
      itemFailures.push({
        reason: "missing_policy_evidence",
        message: `Evidence '${item.id ?? "unknown"}' is missing pattern '${pattern}' in ${item.file ?? "unknown"}.`,
        groupId,
        itemId: item.id,
        file: item.file,
        pattern,
      });
    }
    return {
      pattern,
      matched,
    };
  });

  if (!item.id || item.id.trim().length === 0) {
    itemFailures.push({
      reason: "missing_policy_evidence",
      message: `Evidence item in group '${groupId}' is missing id.`,
      groupId,
    });
  }

  if (!fileExists && item.required !== false) {
    itemFailures.push({
      reason: "missing_policy_evidence",
      message: `Evidence '${item.id ?? "unknown"}' file does not exist: ${item.file ?? "unknown"}`,
      groupId,
      itemId: item.id,
      file: item.file,
    });
  }

  if ((item.patterns ?? []).length === 0 && item.required !== false) {
    itemFailures.push({
      reason: "missing_policy_evidence",
      message: `Evidence '${item.id ?? "unknown"}' must declare at least one pattern.`,
      groupId,
      itemId: item.id,
    });
  }

  return {
    id: item.id,
    file: item.file,
    status: itemFailures.length === 0 ? "pass" : "fail",
    patterns: patternResults,
    failures: itemFailures,
  };
}

function validateRuntimeEvidence(config) {
  const runtimeDir = resolvePath(args.runtimeEvidenceDir ?? config.defaultDirectory ?? "contracts/store-content/runtime-evidence");
  const requireRuntimeEvidence = args.requireRuntimeEvidence === true;

  if (!requireRuntimeEvidence && !existsSync(runtimeDir)) {
    return {
      status: "not_required",
      directory: relativeDisplayPath(runtimeDir),
      files: [],
      failures: [],
    };
  }

  const files = [];
  const runtimeFailures = [];

  for (const requiredFile of config.requiredFiles ?? []) {
    const filePath = resolve(runtimeDir, requiredFile.filename);
    if (!existsSync(filePath)) {
      const failure = {
        reason: "missing_runtime_evidence",
        message: `Missing required store content runtime evidence file: ${requiredFile.filename}`,
        file: requiredFile.filename,
      };
      if (requireRuntimeEvidence) {
        runtimeFailures.push(failure);
      }
      files.push({
        id: requiredFile.id,
        filename: requiredFile.filename,
        status: "missing",
        scenarios: [],
        failures: requireRuntimeEvidence ? [failure] : [],
      });
      continue;
    }

    const evidence = readJson(filePath);
    const scenarioById = new Map((evidence.scenarios ?? []).map((scenario) => [scenario.id, scenario]));
    const fileFailures = [];
    const scenarioResults = [];

    for (const scenarioId of requiredFile.requiredScenarios ?? []) {
      const scenario = scenarioById.get(scenarioId);
      if (!scenario) {
        fileFailures.push({
          reason: "missing_runtime_evidence",
          message: `Missing required runtime scenario '${scenarioId}' in ${requiredFile.filename}`,
          file: requiredFile.filename,
          scenarioId,
        });
        continue;
      }

      if (scenario.status !== "pass") {
        fileFailures.push({
          reason: "runtime_policy_smoke_failed",
          message: `Runtime policy scenario '${scenarioId}' did not pass in ${requiredFile.filename}.`,
          file: requiredFile.filename,
          scenarioId,
          status: scenario.status,
        });
      }

      if (!scenario.evidenceUrl || scenario.evidenceUrl.trim().length === 0) {
        fileFailures.push({
          reason: "missing_runtime_evidence",
          message: `Runtime policy scenario '${scenarioId}' is missing evidenceUrl in ${requiredFile.filename}.`,
          file: requiredFile.filename,
          scenarioId,
        });
      }

      scenarioResults.push({
        id: scenarioId,
        status: scenario.status,
        evidenceUrl: scenario.evidenceUrl,
      });
    }

    runtimeFailures.push(...fileFailures);
    files.push({
      id: requiredFile.id,
      filename: requiredFile.filename,
      status: fileFailures.length === 0 ? "pass" : "fail",
      scenarios: scenarioResults,
      generatedAt: evidence.generatedAt,
      failures: fileFailures,
    });
  }

  return {
    status: runtimeFailures.length === 0 ? "pass" : "fail",
    directory: relativeDisplayPath(runtimeDir),
    required: requireRuntimeEvidence,
    files,
    failures: runtimeFailures,
  };
}

function hasAnswerValue(value) {
  if (value === null || value === undefined) {
    return false;
  }
  if (typeof value === "string") {
    return value.trim().length > 0;
  }
  if (Array.isArray(value)) {
    return value.length > 0;
  }
  if (typeof value === "object") {
    return Object.keys(value).length > 0;
  }
  return true;
}

function sameStringSet(left, right) {
  return left.length === right.length && left.every((value) => right.includes(value));
}

function hasAndroidPermission(manifest, permissionName, maxSdkVersion) {
  const permissionBlock = manifest.match(
    new RegExp(`<uses-permission\\b[\\s\\S]*?android:name="${escapeRegExp(permissionName)}"[\\s\\S]*?(?:/>|</uses-permission>)`, "m"),
  )?.[0];
  if (!permissionBlock) {
    return false;
  }
  if (maxSdkVersion === undefined || maxSdkVersion === null) {
    return true;
  }
  return new RegExp(`android:maxSdkVersion="${escapeRegExp(maxSdkVersion.toString())}"`).test(permissionBlock);
}

function hasPlistUsageDescription(plist, key) {
  return new RegExp(`<key>${escapeRegExp(key)}<\\/key>\\s*<string>\\s*[^<\\s][^<]*<\\/string>`, "m").test(plist);
}

function hasRemoteNotificationMode(plist) {
  return /<key>UIBackgroundModes<\/key>\s*<array>[\s\S]*<string>remote-notification<\/string>[\s\S]*<\/array>/m.test(plist);
}

function readFile(relativePath) {
  return readFileSync(resolvePath(relativePath), "utf8");
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function resolvePath(value) {
  if (!value || typeof value !== "string") {
    return repoRoot;
  }
  return isAbsolute(value) ? value : resolve(repoRoot, value);
}

function relativeDisplayPath(value) {
  const resolved = resolvePath(value);
  const display = relative(repoRoot, resolved);
  return display && !display.startsWith("..") ? display : resolved;
}

function renderConsoleSummary(report) {
  return [
    `status=${report.status}`,
    `playConsole=${report.playConsole.status}`,
    `appStoreConnect=${report.appStoreConnect.status}`,
    `permissions=${report.permissionDeclarations.status}`,
    `policyEvidence=${report.policyEvidence.status}`,
    `runtimeEvidence=${report.runtimeEvidence.status}`,
    `failures=${report.failures.length}`,
  ].join("\n");
}

function renderMarkdown(report) {
  const lines = [
    "# Store Content Policy",
    "",
    `- Status: ${report.status}`,
    `- Contract: ${report.contract.path}`,
    `- Release blockers: ${report.releaseBlockers.join(", ")}`,
    "",
    "## Store Survey Answers",
    "",
    `- Play Console: ${report.playConsole.status} (${report.playConsole.answers.length} answers)`,
    `- App Store Connect: ${report.appStoreConnect.status} (${report.appStoreConnect.answers.length} answers)`,
    "",
    "## Permission Declarations",
    "",
    `- Status: ${report.permissionDeclarations.status}`,
    ...report.permissionDeclarations.declarations.map((permission) => (
      `- ${permission.id}: ${permission.status} (${permission.androidPermissions.join(", ") || "no Android permission"} / ${permission.iosUsageDescriptionKeys.join(", ") || "no iOS usage key"})`
    )),
    "",
    "## UGC Policy Evidence",
    "",
    `- Status: ${report.policyEvidence.status}`,
    ...report.policyEvidence.groups.map((group) => `- ${group.id}: ${group.status}`),
    "",
    "## Runtime Evidence",
    "",
    `- Status: ${report.runtimeEvidence.status}`,
    `- Directory: ${report.runtimeEvidence.directory}`,
  ];

  if (report.failures.length > 0) {
    lines.push("", "## Failures", "");
    for (const failure of report.failures) {
      lines.push(`- ${failure.reason}: ${failure.message}`);
    }
  }

  return `${lines.join("\n")}\n`;
}

function parseArgs(values) {
  const parsed = {};

  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (!value.startsWith("--")) {
      continue;
    }
    const key = value
      .slice(2)
      .replace(/-([a-z])/g, (_, character) => character.toUpperCase());
    const next = values[index + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = true;
      continue;
    }
    parsed[key] = next;
    index += 1;
  }

  return parsed;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

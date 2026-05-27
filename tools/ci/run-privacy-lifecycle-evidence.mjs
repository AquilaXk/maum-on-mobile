import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, isAbsolute, resolve } from "node:path";

const repoRoot = process.cwd();
const args = parseArgs(process.argv.slice(2));
const contractPath = resolvePath(args.config ?? "contracts/privacy/lifecycle-evidence.json");
const reportDir = resolvePath(args.reportDir ?? "build/reports/privacy-lifecycle");
const contract = readJson(contractPath);
const storePrivacy = readJson(resolvePath(contract.storePrivacyContract));
const failures = [];

const storePrivacyAlignment = validateStorePrivacyAlignment(contract, storePrivacy);
failures.push(...storePrivacyAlignment.failures);

const appLinks = validateNamedEvidence("app-links", Object.entries(contract.appLinks ?? {}).map(([id, entry]) => ({
  id,
  kind: "app-link",
  ...entry,
})));
failures.push(...appLinks.failures);

const dataExport = validateEvidenceGroup("data-export", contract.dataExport?.evidenceItems ?? []);
failures.push(...dataExport.failures);

const categories = validateCategories(contract.categories ?? [], storePrivacy);
for (const category of categories) {
  failures.push(...category.failures);
}

const runtimeEvidence = validateRuntimeEvidence(contract.runtimeEvidence ?? {});
failures.push(...runtimeEvidence.failures);

const report = {
  status: failures.length === 0 ? "pass" : "blocked",
  generatedAt: new Date().toISOString(),
  contract: {
    path: relativeDisplayPath(contractPath),
    version: contract.version,
  },
  storePrivacyAlignment,
  appLinks,
  dataExport,
  categories,
  runtimeEvidence,
  releaseBlockers: contract.releaseBlockers ?? [],
  failures,
};

mkdirSync(reportDir, { recursive: true });
writeFileSync(resolve(reportDir, "privacy-lifecycle-report.json"), `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(resolve(reportDir, "privacy-lifecycle-categories.json"), `${JSON.stringify(categories, null, 2)}\n`);
writeFileSync(resolve(reportDir, "privacy-lifecycle-runtime-evidence.json"), `${JSON.stringify(runtimeEvidence, null, 2)}\n`);
writeFileSync(resolve(reportDir, "privacy-lifecycle-report.md"), renderMarkdown(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdown(report)}\n`, { flag: "a" });
}

console.log(`Privacy lifecycle report: ${resolve(reportDir, "privacy-lifecycle-report.json")}`);
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

function validateStorePrivacyAlignment(config, privacy) {
  const groupFailures = [];
  const contractIds = new Set((config.categories ?? []).map((category) => category.id));
  const storeIds = new Set((privacy.dataCategories ?? []).map((category) => category.id));

  for (const id of contractIds) {
    if (!storeIds.has(id)) {
      groupFailures.push({
        reason: "store_privacy_category_mismatch",
        message: `Privacy lifecycle category is missing from store disclosure: ${id}`,
        categoryId: id,
      });
    }
  }
  for (const id of storeIds) {
    if (!contractIds.has(id)) {
      groupFailures.push({
        reason: "store_privacy_category_mismatch",
        message: `Store disclosure category is missing from privacy lifecycle contract: ${id}`,
        categoryId: id,
      });
    }
  }

  for (const [key, value] of Object.entries(config.storeLinks ?? {})) {
    if (privacy.storeLinks?.[key] !== value) {
      groupFailures.push({
        reason: "store_privacy_link_mismatch",
        message: `Privacy lifecycle store link '${key}' does not match store disclosure.`,
        expected: privacy.storeLinks?.[key],
        actual: value,
      });
    }
  }

  for (const category of config.categories ?? []) {
    const storeCategory = (privacy.dataCategories ?? []).find((entry) => entry.id === category.id);
    if (storeCategory && storeCategory.deleteAvailable !== category.deleteAvailable) {
      groupFailures.push({
        reason: "store_privacy_category_mismatch",
        message: `Delete availability for '${category.id}' does not match store disclosure.`,
        categoryId: category.id,
        expected: storeCategory.deleteAvailable,
        actual: category.deleteAvailable,
      });
    }
  }

  return {
    status: groupFailures.length === 0 ? "pass" : "fail",
    contractCategories: [...contractIds].sort(),
    storeCategories: [...storeIds].sort(),
    storeLinks: config.storeLinks ?? {},
    failures: groupFailures,
  };
}

function validateNamedEvidence(groupId, entries) {
  const evidenceItems = entries.map((entry) => validateEvidenceItem(groupId, entry));
  const groupFailures = evidenceItems.flatMap((item) => item.failures);

  return {
    status: groupFailures.length === 0 ? "pass" : "fail",
    evidenceItems,
    failures: groupFailures,
  };
}

function validateEvidenceGroup(groupId, entries) {
  return validateNamedEvidence(groupId, entries);
}

function validateCategories(categoriesConfig, privacy) {
  return categoriesConfig.map((category) => {
    const storeCategory = (privacy.dataCategories ?? []).find((entry) => entry.id === category.id);
    const evidence = validateEvidenceGroup(category.id, category.evidenceItems ?? []);
    const residualFileChecks = validateEvidenceGroup(`${category.id}:residual-files`, category.residualFileChecks ?? []);
    const retentionExceptions = validateRetentionExceptions(category);
    const categoryFailures = [
      ...evidence.failures,
      ...residualFileChecks.failures,
      ...retentionExceptions.failures,
    ];

    if (!storeCategory) {
      categoryFailures.push({
        reason: "store_privacy_category_mismatch",
        message: `Store disclosure category is missing: ${category.id}`,
        categoryId: category.id,
      });
    }

    if (category.deleteAvailable === false && (category.retentionExceptions ?? []).length === 0) {
      categoryFailures.push({
        reason: "missing_required_evidence",
        message: `Non-deletable category '${category.id}' must explain retention exceptions.`,
        categoryId: category.id,
      });
    }

    return {
      id: category.id,
      label: storeCategory?.label ?? category.id,
      deleteAvailable: category.deleteAvailable,
      status: categoryFailures.length === 0 ? "pass" : "fail",
      evidence,
      residualFileChecks,
      retentionExceptions,
      failures: categoryFailures,
    };
  });
}

function validateRetentionExceptions(category) {
  const failures = [];
  const entries = category.retentionExceptions ?? [];

  for (const entry of entries) {
    if (!entry.id || !entry.reason || !entry.duration) {
      failures.push({
        reason: "missing_required_evidence",
        message: `Retention exception for '${category.id}' must include id, reason, and duration.`,
        categoryId: category.id,
      });
    }
  }

  return {
    status: failures.length === 0 ? "pass" : "fail",
    entries,
    failures,
  };
}

function validateEvidenceItem(groupId, item) {
  const itemFailures = [];
  const filePath = resolvePath(item.file);
  const fileExists = existsSync(filePath);
  const content = fileExists ? readFileSync(filePath, "utf8") : "";
  const patternResults = (item.patterns ?? []).map((pattern) => {
    const matched = fileExists && new RegExp(pattern, "m").test(content);
    if (!matched && item.required !== false) {
      itemFailures.push({
        reason: "missing_required_evidence",
        message: `Evidence '${item.id}' is missing pattern '${pattern}' in ${item.file}.`,
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

  if (!fileExists && item.required !== false) {
    itemFailures.push({
      reason: "missing_required_evidence",
      message: `Evidence '${item.id}' file does not exist: ${item.file}`,
      groupId,
      itemId: item.id,
      file: item.file,
    });
  }

  if ((item.patterns ?? []).length === 0 && item.required !== false) {
    itemFailures.push({
      reason: "missing_required_evidence",
      message: `Evidence '${item.id}' must declare at least one pattern.`,
      groupId,
      itemId: item.id,
    });
  }

  return {
    id: item.id,
    kind: item.kind,
    file: item.file,
    status: itemFailures.length === 0 ? "pass" : "fail",
    patterns: patternResults,
    failures: itemFailures,
  };
}

function validateRuntimeEvidence(config) {
  const runtimeDir = resolvePath(args.runtimeEvidenceDir ?? config.defaultDirectory ?? "contracts/privacy/runtime-evidence");
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
        message: `Missing required runtime privacy evidence file: ${requiredFile.filename}`,
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
    const scenarios = evidence.scenarios ?? [];
    const scenarioById = new Map(scenarios.map((scenario) => [scenario.id, scenario]));
    const fileFailures = [];

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
          reason: "runtime_evidence_failed",
          message: `Runtime scenario '${scenarioId}' reported status '${scenario.status}'.`,
          file: requiredFile.filename,
          scenarioId,
          status: scenario.status,
        });
      }
    }

    const leftoverField = requiredFile.leftoverFilesField;
    const leftoverFiles = leftoverField ? evidence[leftoverField] ?? [] : [];
    if (leftoverField && leftoverFiles.length > 0) {
      fileFailures.push({
        reason: "residual_file_leftover",
        message: `${requiredFile.filename} reported ${leftoverFiles.length} residual file(s).`,
        file: requiredFile.filename,
        leftoverCount: leftoverFiles.length,
      });
    }

    runtimeFailures.push(...fileFailures);
    files.push({
      id: requiredFile.id,
      filename: requiredFile.filename,
      status: fileFailures.length === 0 ? "pass" : "fail",
      scenarios,
      leftoverFiles,
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

function renderMarkdown(report) {
  const lines = [
    "# Privacy Lifecycle Evidence",
    "",
    `- Status: ${report.status}`,
    `- Generated at: ${report.generatedAt}`,
    `- Contract: ${report.contract.path}`,
    `- Store privacy alignment: ${report.storePrivacyAlignment.status}`,
    `- App links: ${report.appLinks.status}`,
    "",
    "## Categories",
    "",
    "| Category | Delete available | Status | Evidence |",
    "| --- | --- | --- | --- |",
  ];

  for (const category of report.categories) {
    lines.push(
      `| ${category.id} | ${category.deleteAvailable ? "yes" : "no"} | ${category.status} | ${category.evidence.evidenceItems.length} |`,
    );
  }

  lines.push(
    "",
    "## Data Export",
    "",
    `- Status: ${report.dataExport.status}`,
    `- Evidence items: ${report.dataExport.evidenceItems.length}`,
    "",
    "## Residual File Checks",
    "",
  );

  for (const category of report.categories.filter((entry) => entry.residualFileChecks.evidenceItems.length > 0)) {
    lines.push(`- ${category.id}: ${category.residualFileChecks.status}`);
  }

  lines.push(
    "",
    "## Runtime Evidence",
    "",
    `- Status: ${report.runtimeEvidence.status}`,
    `- Directory: ${report.runtimeEvidence.directory}`,
    "",
    "## Failures",
    "",
  );

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
    `status=${report.status}`,
    `categories=${report.categories.length}`,
    `dataExport=${report.dataExport.status}`,
    `runtimeEvidence=${report.runtimeEvidence.status}`,
    `failures=${report.failures.length}`,
  ].join(" ");
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--config") {
      parsed.config = argv[++index];
    } else if (arg === "--report-dir") {
      parsed.reportDir = argv[++index];
    } else if (arg === "--runtime-evidence-dir") {
      parsed.runtimeEvidenceDir = argv[++index];
    } else if (arg === "--require-runtime-evidence") {
      parsed.requireRuntimeEvidence = true;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return parsed;
}

function readJson(pathOrRelative) {
  const path = resolvePath(pathOrRelative);
  return JSON.parse(readFileSync(path, "utf8"));
}

function resolvePath(pathOrRelative) {
  return isAbsolute(pathOrRelative) ? pathOrRelative : resolve(repoRoot, pathOrRelative);
}

function relativeDisplayPath(pathOrRelative) {
  const absolutePath = resolvePath(pathOrRelative);
  if (absolutePath.startsWith(`${repoRoot}/`)) {
    return absolutePath.slice(repoRoot.length + 1);
  }
  return basename(absolutePath);
}

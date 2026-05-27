import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { isAbsolute, relative, resolve } from "node:path";

const repoRoot = process.cwd();
const args = parseArgs(process.argv.slice(2));
const contractPath = resolvePath(args.config ?? "contracts/performance/release-performance-gate.json");
const reportDir = resolvePath(args.reportDir ?? "build/reports/release-performance");
const contract = readJson(contractPath);
const failures = [];

const staticEvidence = validateEvidenceGroup("static-evidence", contract.staticEvidence ?? []);
failures.push(...staticEvidence.failures);

const runtimeEvidence = validateRuntimeEvidence(contract.runtimeEvidence ?? {});
failures.push(...runtimeEvidence.failures);

const release = validateRelease(contract.releaseLinking ?? {}, runtimeEvidence.release);
failures.push(...release.failures);

const scenarios = validateScenarioResults(contract, runtimeEvidence, release);
failures.push(...scenarios.flatMap((scenario) => scenario.failures));

const summary = summarizeScenarios(scenarios);
const report = {
  status: determineStatus(failures, runtimeEvidence.status),
  generatedAt: new Date().toISOString(),
  contract: {
    path: relativeDisplayPath(contractPath),
    version: contract.version,
  },
  backendSmokeContract: contract.backendSmokeContract,
  release,
  staticEvidence,
  runtimeEvidence,
  summary,
  failures,
  scenarios,
};

mkdirSync(reportDir, { recursive: true });
writeFileSync(resolve(reportDir, "release-performance-report.json"), `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(
  resolve(reportDir, "release-performance-runtime-evidence.json"),
  `${JSON.stringify(runtimeEvidence, null, 2)}\n`,
);
writeFileSync(resolve(reportDir, "release-performance-report.md"), renderMarkdown(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdown(report)}\n`, { flag: "a" });
}

console.log(`Release performance report: ${resolve(reportDir, "release-performance-report.json")}`);
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

function validateRuntimeEvidence(config) {
  const runtimeDir = resolvePath(args.runtimeEvidenceDir ?? config.defaultDirectory ?? "contracts/performance/runtime-evidence");
  const requiredFiles = config.requiredFiles ?? [
    "release-performance-release.json",
    "release-performance-android-results.json",
    "release-performance-ios-results.json",
    "release-performance-backend-results.json",
  ];
  const requireRuntimeEvidence = args.requireRuntimeEvidence === true;

  if (!existsSync(runtimeDir)) {
    if (!requireRuntimeEvidence) {
      return {
        status: "not_required",
        directory: relativeDisplayPath(runtimeDir),
        requiredFiles,
        documents: {},
        release: undefined,
        failures: [],
      };
    }

    return {
      status: "fail",
      directory: relativeDisplayPath(runtimeDir),
      requiredFiles,
      documents: {},
      release: undefined,
      failures: [
        {
          reason: "missing_runtime_evidence",
          message: `Missing release performance runtime evidence directory: ${relativeDisplayPath(runtimeDir)}`,
        },
      ],
    };
  }

  const documents = {};
  const runtimeFailures = [];
  for (const fileName of requiredFiles) {
    const filePath = resolve(runtimeDir, fileName);
    const key = runtimeDocumentKey(fileName);

    if (!existsSync(filePath)) {
      if (requireRuntimeEvidence) {
        runtimeFailures.push({
          reason: "missing_runtime_evidence",
          message: `Missing release performance runtime evidence file: ${relativeDisplayPath(filePath)}`,
          file: fileName,
        });
      }
      continue;
    }

    try {
      documents[key] = JSON.parse(readFileSync(filePath, "utf8"));
    } catch (error) {
      runtimeFailures.push({
        reason: "invalid_runtime_evidence",
        message: `Invalid release performance runtime evidence JSON: ${relativeDisplayPath(filePath)} (${error.message})`,
        file: fileName,
      });
    }
  }

  if (!requireRuntimeEvidence && Object.keys(documents).length === 0) {
    return {
      status: "not_required",
      directory: relativeDisplayPath(runtimeDir),
      requiredFiles,
      documents: {},
      release: undefined,
      failures: [],
    };
  }

  return {
    status: runtimeFailures.length === 0 ? "present" : "fail",
    directory: relativeDisplayPath(runtimeDir),
    requiredFiles,
    documents,
    release: documents.release,
    failures: runtimeFailures,
  };
}

function validateRelease(linking, releaseDocument) {
  if (!releaseDocument) {
    return {
      status: args.requireRuntimeEvidence ? "fail" : "pending",
      releaseNumber: "",
      requiredFields: linking.requiredFields ?? [],
      sameReleaseNumber: linking.sameReleaseNumber === true,
      failures: args.requireRuntimeEvidence
        ? [
            {
              reason: "missing_runtime_evidence",
              message: "Missing release performance runtime evidence release metadata.",
            },
          ]
        : [],
    };
  }

  const releaseFailures = [];
  for (const field of linking.requiredFields ?? []) {
    if (isBlank(releaseDocument[field])) {
      releaseFailures.push({
        reason: "missing_release_field",
        message: `Release performance metadata is missing '${field}'.`,
        field,
      });
    }
  }

  return {
    status: releaseFailures.length === 0 ? "pass" : "fail",
    ...releaseDocument,
    requiredFields: linking.requiredFields ?? [],
    sameReleaseNumber: linking.sameReleaseNumber === true,
    failures: releaseFailures,
  };
}

function validateScenarioResults(currentContract, runtime, release) {
  const resultIndex = indexRuntimeResults(runtime.documents ?? {});

  return (currentContract.scenarios ?? []).flatMap((scenario) => {
    return (scenario.platforms ?? []).map((platform) => {
      const result = resultIndex.get(resultKey(platform, scenario.id));
      const scenarioFailures = [];

      if (runtime.status === "not_required") {
        return scenarioReport(platform, scenario, "pending", undefined, scenarioFailures);
      }

      if (!result) {
        scenarioFailures.push({
          reason: "missing_runtime_evidence",
          message: `Missing release performance runtime evidence for ${platform}:${scenario.id}.`,
          platform,
          scenario: scenario.id,
        });
        return scenarioReport(platform, scenario, "fail", undefined, scenarioFailures);
      }

      scenarioFailures.push(...validateRequiredFields(platform, result, currentContract));
      scenarioFailures.push(...validateReleaseMatch(platform, result, release));
      scenarioFailures.push(...validateStatus(result, platform, scenario.id));

      if (result.status === "pass") {
        scenarioFailures.push(...validateBudget(platform, scenario, result));
      }

      return scenarioReport(
        platform,
        scenario,
        scenarioFailures.length === 0 ? result.status : "fail",
        result,
        scenarioFailures,
      );
    });
  });
}

function indexRuntimeResults(documents) {
  const resultIndex = new Map();
  for (const [documentKey, document] of Object.entries(documents)) {
    if (documentKey === "release") {
      continue;
    }

    const platform = document.platform ?? documentKey;
    for (const result of document.results ?? []) {
      const key = resultKey(result.platform ?? platform, result.scenario);
      if (resultIndex.has(key)) {
        const duplicate = resultIndex.get(key);
        duplicate.__duplicates = [...(duplicate.__duplicates ?? []), result];
        continue;
      }
      resultIndex.set(key, {
        platform,
        ...result,
      });
    }
  }
  return resultIndex;
}

function validateRequiredFields(platform, result, currentContract) {
  const requiredFields = platform === "backend"
    ? currentContract.backend?.requiredResultFields ?? []
    : currentContract.platforms?.[platform]?.requiredResultFields ?? [];
  const fieldFailures = [];

  for (const field of requiredFields) {
    if (field === "evidence") {
      if (!Array.isArray(result.evidence) || result.evidence.length === 0) {
        fieldFailures.push({
          reason: "missing_required_evidence",
          message: `${platform}:${result.scenario} is missing evidence.`,
          platform,
          scenario: result.scenario,
          field,
        });
      }
      continue;
    }

    if (isBlank(result[field])) {
      fieldFailures.push({
        reason: "missing_required_evidence",
        message: `${platform}:${result.scenario} is missing '${field}'.`,
        platform,
        scenario: result.scenario,
        field,
      });
    }
  }

  if ((result.__duplicates ?? []).length > 0) {
    fieldFailures.push({
      reason: "duplicate_runtime_evidence",
      message: `Duplicate release performance runtime evidence for ${platform}:${result.scenario}.`,
      platform,
      scenario: result.scenario,
    });
  }

  return fieldFailures;
}

function validateReleaseMatch(platform, result, release) {
  if (!release.releaseNumber) {
    return [];
  }

  const releaseFailures = [];
  const shouldMatchReleaseNumber = release.sameReleaseNumber === true;
  if (shouldMatchReleaseNumber && result.releaseNumber !== release.releaseNumber) {
    releaseFailures.push({
      reason: "release_number_mismatch",
      message: `${platform}:${result.scenario} releaseNumber '${result.releaseNumber}' does not match '${release.releaseNumber}'.`,
      platform,
      scenario: result.scenario,
    });
  }

  const expectedBuildNumber = buildNumberForPlatform(platform, release);
  if (shouldMatchReleaseNumber && expectedBuildNumber && result.buildNumber !== expectedBuildNumber) {
    releaseFailures.push({
      reason: "build_number_mismatch",
      message: `${platform}:${result.scenario} buildNumber '${result.buildNumber}' does not match '${expectedBuildNumber}'.`,
      platform,
      scenario: result.scenario,
    });
  }

  return releaseFailures;
}

function validateStatus(result, platform, scenarioId) {
  const status = result.status;
  if (!["pass", "fail", "blocked", "not_applicable"].includes(status)) {
    return [
      {
        reason: "invalid_status",
        message: `${platform}:${scenarioId} has invalid status '${status}'.`,
        platform,
        scenario: scenarioId,
      },
    ];
  }

  if (status === "not_applicable") {
    const failures = [];
    if (isBlank(result.notApplicableReason)) {
      failures.push({
        reason: "not_applicable_unapproved",
        message: `${platform}:${scenarioId} not_applicable result needs a reason.`,
        platform,
        scenario: scenarioId,
      });
    }
    if (isBlank(result.notApplicableApprovedBy)) {
      failures.push({
        reason: "not_applicable_unapproved",
        message: `${platform}:${scenarioId} not_applicable result needs an approver.`,
        platform,
        scenario: scenarioId,
      });
    }
    return failures;
  }

  if (status !== "pass") {
    return [
      {
        reason: "runtime_evidence_failed",
        message: `${platform}:${scenarioId} runtime evidence status is '${status}'.`,
        platform,
        scenario: scenarioId,
      },
    ];
  }

  return [];
}

function validateBudget(platform, scenario, result) {
  const budgetFailures = [];
  for (const threshold of scenario.budget?.thresholds ?? []) {
    const rawValue = result[threshold.metric];
    const value = Number(rawValue);

    if (!Number.isFinite(value)) {
      budgetFailures.push({
        reason: "missing_measurement",
        message: `${platform}:${scenario.id} is missing numeric measurement '${threshold.metric}'.`,
        platform,
        scenario: scenario.id,
        metric: threshold.metric,
      });
      continue;
    }

    if (threshold.max !== undefined && value > Number(threshold.max)) {
      budgetFailures.push({
        reason: "budget_exceeded",
        message: threshold.message
          ? `${platform}:${scenario.id} ${threshold.message} (${threshold.metric}=${value}, max=${threshold.max})`
          : `${platform}:${scenario.id} ${threshold.metric} budget exceeded (${value} > ${threshold.max}).`,
        platform,
        scenario: scenario.id,
        metric: threshold.metric,
        value,
        max: threshold.max,
      });
    }

    if (threshold.min !== undefined && value < Number(threshold.min)) {
      budgetFailures.push({
        reason: "budget_exceeded",
        message: `${platform}:${scenario.id} ${threshold.metric} budget exceeded (${value} < ${threshold.min}).`,
        platform,
        scenario: scenario.id,
        metric: threshold.metric,
        value,
        min: threshold.min,
      });
    }
  }

  return budgetFailures;
}

function scenarioReport(platform, scenario, status, result, scenarioFailures) {
  return {
    id: `${platform}:${scenario.id}`,
    platform,
    scenario: scenario.id,
    priority: scenario.priority,
    status,
    budget: scenario.budget,
    passCriteria: scenario.passCriteria ?? [],
    evidenceRequired: scenario.evidenceRequired ?? [],
    result: result
      ? {
          status: result.status,
          releaseNumber: result.releaseNumber,
          buildNumber: result.buildNumber,
          deviceProfile: result.deviceProfile,
          networkProfile: result.networkProfile,
          deviceModel: result.deviceModel,
          osVersion: result.osVersion,
          evidence: result.evidence ?? [],
          notes: result.notes ?? "",
        }
      : undefined,
    failures: scenarioFailures,
  };
}

function validateEvidenceGroup(groupId, items) {
  const evidenceItems = items.map((item) => validateEvidenceItem(groupId, item));
  const groupFailures = evidenceItems.flatMap((item) => item.failures);

  return {
    status: groupFailures.length === 0 ? "pass" : "fail",
    evidenceItems,
    failures: groupFailures,
  };
}

function validateEvidenceItem(groupId, item) {
  const itemFailures = [];
  const filePath = resolvePath(item.file);
  const fileExists = existsSync(filePath);
  const content = fileExists ? readFileSync(filePath, "utf8") : "";
  const patternResults = (item.patterns ?? []).map((pattern) => {
    const matched = fileExists && new RegExp(pattern, "m").test(content);
    if (!matched) {
      itemFailures.push({
        reason: "missing_static_evidence",
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

  if (!fileExists) {
    itemFailures.push({
      reason: "missing_static_evidence",
      message: `Evidence '${item.id}' file does not exist: ${item.file}`,
      groupId,
      itemId: item.id,
      file: item.file,
    });
  }
  if ((item.patterns ?? []).length === 0) {
    itemFailures.push({
      reason: "missing_static_evidence",
      message: `Evidence '${item.id}' must declare at least one pattern.`,
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

function summarizeScenarios(currentScenarios) {
  const summary = {
    scenarios: currentScenarios.length,
    pass: 0,
    fail: 0,
    blocked: 0,
    pending: 0,
    not_applicable: 0,
  };

  for (const scenario of currentScenarios) {
    if (Object.hasOwn(summary, scenario.status)) {
      summary[scenario.status] += 1;
    }
  }

  return summary;
}

function determineStatus(currentFailures, runtimeStatus) {
  if (currentFailures.length > 0) {
    return "blocked";
  }
  if (runtimeStatus === "not_required") {
    return "pending";
  }
  return "pass";
}

function renderMarkdown(report) {
  const rows = report.scenarios
    .map((scenario) => (
      `| ${scenario.id} | ${scenario.status} | ${scenario.result?.buildNumber ?? ""} | ${scenario.failures.length} |`
    ))
    .join("\n");

  return `# Release Performance Gate

| field | value |
| --- | --- |
| status | ${report.status} |
| releaseNumber | ${report.release.releaseNumber ?? ""} |
| scenarios | ${report.summary.scenarios} |
| pass | ${report.summary.pass} |
| fail | ${report.summary.fail} |
| blocked | ${report.summary.blocked} |
| pending | ${report.summary.pending} |

| scenario | status | build | failures |
| --- | --- | --- | --- |
${rows}
`;
}

function renderConsoleSummary(report) {
  return [
    `status=${report.status}`,
    `releaseNumber=${report.release.releaseNumber ?? ""}`,
    `scenarios=${report.summary.scenarios}`,
    `pass=${report.summary.pass}`,
    `failures=${report.failures.length}`,
  ].join(" ");
}

function runtimeDocumentKey(fileName) {
  if (fileName.includes("release-performance-release")) {
    return "release";
  }
  if (fileName.includes("android")) {
    return "android";
  }
  if (fileName.includes("ios")) {
    return "ios";
  }
  if (fileName.includes("backend")) {
    return "backend";
  }
  return fileName.replace(/\.json$/i, "");
}

function buildNumberForPlatform(platform, release) {
  if (platform === "android") {
    return release.androidBuildNumber;
  }
  if (platform === "ios") {
    return release.iosBuildNumber;
  }
  if (platform === "backend") {
    return release.backendBuildNumber;
  }
  return "";
}

function resultKey(platform, scenarioId) {
  return `${platform}:${scenarioId}`;
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function resolvePath(filePath) {
  return isAbsolute(filePath) ? filePath : resolve(repoRoot, filePath);
}

function relativeDisplayPath(filePath) {
  const relativePath = relative(repoRoot, filePath);
  return relativePath.startsWith("..") ? filePath : relativePath;
}

function isBlank(value) {
  return value === undefined || value === null || value.toString().trim().length === 0;
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith("--")) {
      continue;
    }

    const key = toCamelCase(arg.slice(2));
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      index += 1;
    }
  }
  return parsed;
}

function toCamelCase(value) {
  return value.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
}

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "../..");

const args = parseArgs(process.argv.slice(2));
const platform = args.platform;
const reportDir = resolve(repoRoot, args.reportDir ?? "build/reports/release-device-matrix");
const configPath = resolve(repoRoot, args.config ?? "contracts/release-candidate/device-matrix.json");
const resultsPath = args.results ? resolve(repoRoot, args.results) : undefined;

if (!["android", "ios"].includes(platform)) {
  failUsage("Expected --platform to be either android or ios.");
}

const matrix = JSON.parse(readFileSync(configPath, "utf8"));
const platformConfig = matrix.platforms?.[platform];
if (!platformConfig) {
  failUsage(`Missing platform configuration for ${platform}.`);
}

const resultsDocument = resultsPath ? readResultsDocument(resultsPath) : undefined;
const failures = [];
const resultLookup = new Map();

if (resultsDocument) {
  for (const result of normalizeResults(resultsDocument)) {
    const key = resultKey({
      platform: result.platform ?? platform,
      deviceProfile: result.deviceProfile,
      networkProfile: result.networkProfile,
      scenario: result.scenario,
    });

    if (resultLookup.has(key)) {
      failures.push({
        reason: "duplicate_result",
        message: `Duplicate device result for ${key}.`,
        result,
      });
    }

    resultLookup.set(key, result);
  }
}

const scenarios = matrix.scenarios
  .filter((scenario) => scenario.platforms.includes(platform))
  .flatMap((scenario) => platformConfig.deviceProfiles
    .filter((profile) => profile.required)
    .flatMap((profile) => profile.networkProfiles.map((networkProfile) => {
      const base = {
        platform,
        deviceProfile: profile.id,
        deviceType: profile.deviceType,
        deviceProfiles: [profile.id],
        networkProfile,
        scenario: scenario.id,
        name: scenario.name,
        priority: scenario.priority,
        area: scenario.area,
        mode: scenario.mode,
        required: profile.required === true,
        status: "pending",
        passCriteria: scenario.passCriteria,
        evidenceRequired: scenario.evidenceRequired ?? [],
        automationCommands: scenario.automation?.commands ?? [],
        resultFields: scenario.resultFields,
        evidence: [],
        notes: "",
        tester: "",
        buildNumber: "",
        deviceModel: "",
        osVersion: "",
        issue: "",
        needsRetest: false,
        notApplicableReason: "",
        notApplicableApprovedBy: "",
        validationErrors: [],
      };
      const result = resultLookup.get(resultKey(base));

      return result ? applyResult(base, result) : base;
    })));

if (args.requireResults && !resultsDocument) {
  failures.push({
    reason: "missing_results",
    message: "Missing release candidate device results. Provide --results when --require-results is set.",
    platform,
  });
}

if (args.requireResults && resultsDocument?.missingFile) {
  failures.push({
    reason: "missing_results_file",
    message: `Missing release candidate device results file: ${resultsDocument.missingFile}.`,
    platform,
  });
}

for (const result of resultLookup.values()) {
  if ((result.platform ?? platform) !== platform) {
    failures.push({
      reason: "platform_mismatch",
      message: `Result platform ${result.platform} does not match requested platform ${platform}.`,
      result,
    });
    continue;
  }

  const key = resultKey({
    platform,
    deviceProfile: result.deviceProfile,
    networkProfile: result.networkProfile,
    scenario: result.scenario,
  });
  if (!scenarios.some((scenario) => resultKey(scenario) === key)) {
    failures.push({
      reason: "unknown_result",
      message: `Unknown release candidate device result: ${key}.`,
      result,
    });
  }
}

if (args.requireResults) {
  for (const scenario of scenarios) {
    failures.push(...validateScenarioResult(scenario, matrix.report.allowedStatuses, platformConfig.requiredResultFields));
  }
}

const summary = summarizeScenarios(scenarios);
const reportStatus = determineReportStatus(summary, failures, args.requireResults);
const report = {
  platform,
  status: reportStatus,
  generatedAt: new Date().toISOString(),
  requiredResultFields: platformConfig.requiredResultFields,
  smokeBuildCommands: platformConfig.smokeBuildCommands,
  deviceProfiles: platformConfig.deviceProfiles,
  summary,
  reportContract: matrix.report,
  failures,
  scenarios,
};

mkdirSync(reportDir, { recursive: true });
const jsonReportPath = resolve(reportDir, `release-device-matrix-${platform}.json`);
const markdownReportPath = resolve(reportDir, `release-device-matrix-${platform}.md`);

writeFileSync(jsonReportPath, `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(markdownReportPath, renderMarkdownReport(report));

console.log(`Release candidate device matrix report: ${jsonReportPath}`);
console.log(renderConsoleSummary(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdownReport(report)}\n`, { flag: "a" });
}

if (args.requireResults && report.status !== "pass") {
  for (const failure of failures) {
    console.error(failure.message);
  }
  process.exit(1);
}

function applyResult(base, result) {
  return {
    ...base,
    status: result.status ?? base.status,
    evidence: normalizeEvidence(result.evidence),
    notes: stringValue(result.notes),
    tester: stringValue(result.tester),
    buildNumber: stringValue(result.buildNumber),
    deviceModel: stringValue(result.deviceModel),
    osVersion: stringValue(result.osVersion),
    issue: stringValue(result.issue),
    needsRetest: result.needsRetest === true,
    notApplicableReason: stringValue(result.notApplicableReason),
    notApplicableApprovedBy: stringValue(result.notApplicableApprovedBy),
    rawResult: result,
  };
}

function validateScenarioResult(scenario, allowedStatuses, requiredResultFields) {
  const scenarioFailures = [];
  const status = scenario.status;

  if (!scenario.rawResult) {
    scenarioFailures.push(failureForScenario(scenario, "missing_required_result", "Missing required physical-device result."));
  }

  if (!allowedStatuses.includes(status)) {
    scenarioFailures.push(failureForScenario(scenario, "invalid_status", `Invalid status '${status}'.`));
  }

  if (status === "pending") {
    scenarioFailures.push(failureForScenario(scenario, "pending_result", "Pending results cannot pass a release candidate gate."));
  }

  for (const field of requiredResultFields) {
    if (isBlank(scenario[field])) {
      scenarioFailures.push(failureForScenario(scenario, `missing_${field}`, `Missing required field '${field}'.`));
    }
  }

  for (const field of ["status", "evidence", "notes"]) {
    if (field === "evidence") {
      if (scenario.evidence.length === 0) {
        scenarioFailures.push(failureForScenario(scenario, "missing_evidence", "Missing required evidence path."));
      }
    } else if (isBlank(scenario[field])) {
      scenarioFailures.push(failureForScenario(scenario, `missing_${field}`, `Missing required field '${field}'.`));
    }
  }

  if (status === "not_applicable") {
    if (isBlank(scenario.notApplicableReason) || isBlank(scenario.notApplicableApprovedBy)) {
      scenarioFailures.push(
        failureForScenario(
          scenario,
          "unapproved_not_applicable",
          "not_applicable results require notApplicableReason and notApplicableApprovedBy.",
        ),
      );
    }
  }

  if (status === "fail" || status === "blocked") {
    if (isBlank(scenario.issue) || scenario.needsRetest !== true) {
      scenarioFailures.push(
        failureForScenario(
          scenario,
          "missing_failure_follow_up",
          `${status} results require issue and needsRetest=true.`,
        ),
      );
    }
    scenarioFailures.push(
      failureForScenario(
        scenario,
        `${status}_result`,
        `${status} results cannot pass a release candidate gate.`,
      ),
    );
  }

  scenario.validationErrors = scenarioFailures.map((failure) => failure.reason);

  return scenarioFailures;
}

function failureForScenario(scenario, reason, message) {
  return {
    reason,
    message: `${scenario.platform}/${scenario.deviceProfile}/${scenario.networkProfile}/${scenario.scenario}: ${message}`,
    platform: scenario.platform,
    deviceProfile: scenario.deviceProfile,
    networkProfile: scenario.networkProfile,
    scenario: scenario.scenario,
  };
}

function summarizeScenarios(scenarios) {
  const summary = {
    scenarios: scenarios.length,
    automated: scenarios.filter((scenario) => scenario.mode === "automated").length,
    hybrid: scenarios.filter((scenario) => scenario.mode === "hybrid").length,
    manual: scenarios.filter((scenario) => scenario.mode === "manual").length,
    pending: 0,
    pass: 0,
    fail: 0,
    blocked: 0,
    not_applicable: 0,
  };

  for (const scenario of scenarios) {
    if (Object.hasOwn(summary, scenario.status)) {
      summary[scenario.status] += 1;
    }
  }

  return summary;
}

function determineReportStatus(summary, failures, requireResults) {
  if (failures.length === 0 && summary.pending === 0 && summary.fail === 0 && summary.blocked === 0) {
    return "pass";
  }
  if (!requireResults && summary.pending > 0) {
    return "pending";
  }
  if (summary.fail > 0) {
    return "fail";
  }
  return "blocked";
}

function readResultsDocument(path) {
  if (!existsSync(path)) {
    return {
      platform,
      results: [],
      missingFile: path,
    };
  }

  return JSON.parse(readFileSync(path, "utf8"));
}

function normalizeResults(document) {
  if (Array.isArray(document)) {
    return document;
  }
  if (Array.isArray(document.results)) {
    return document.results;
  }
  return [];
}

function normalizeEvidence(evidence) {
  if (Array.isArray(evidence)) {
    return evidence.map(stringValue).filter((value) => value.length > 0);
  }
  const value = stringValue(evidence);
  return value.length > 0 ? [value] : [];
}

function resultKey(result) {
  return [result.platform, result.deviceProfile, result.networkProfile, result.scenario].join(":");
}

function stringValue(value) {
  return typeof value === "string" ? value.trim() : "";
}

function isBlank(value) {
  if (Array.isArray(value)) {
    return value.length === 0;
  }
  return stringValue(value).length === 0;
}

function renderMarkdownReport(report) {
  const lines = [
    `### Release Candidate Device Matrix (${report.platform})`,
    "",
    "| field | value |",
    "| --- | --- |",
    `| status | ${report.status} |`,
    `| scenarios | ${report.summary.scenarios} |`,
    `| pass | ${report.summary.pass} |`,
    `| not_applicable | ${report.summary.not_applicable} |`,
    `| pending | ${report.summary.pending} |`,
    `| fail | ${report.summary.fail} |`,
    `| blocked | ${report.summary.blocked} |`,
    "",
    "#### Smoke Build Commands",
    "",
    ...report.smokeBuildCommands.map((command) => `- \`${command}\``),
    "",
    "#### Device Profiles",
    "",
    ...report.deviceProfiles.map((profile) => `- ${profile.id}: ${profile.deviceType}, ${profile.formFactor}, ${profile.osRange}`),
    "",
    "#### Scenario Results",
    "",
    "| done | profile | network | status | scenario | tester | build | evidence | follow-up |",
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ...report.scenarios.map((scenario) => {
      const done = scenario.status === "pass" || scenario.status === "not_applicable" ? "x" : " ";
      const evidence = scenario.evidence.length > 0 ? scenario.evidence.join("<br>") : "";
      const followUp = [
        scenario.issue,
        scenario.needsRetest ? "needsRetest" : "",
        scenario.notApplicableApprovedBy,
        scenario.notApplicableReason,
      ].filter(Boolean).join("<br>");

      return `| [${done}] | ${scenario.deviceProfile} | ${scenario.networkProfile} | ${scenario.status} | ${scenario.scenario} | ${scenario.tester} | ${scenario.buildNumber} | ${evidence} | ${followUp} |`;
    }),
  ];

  if (report.failures.length > 0) {
    lines.push("", "#### Gate Failures", "");
    lines.push(...report.failures.map((failure) => `- ${failure.reason}: ${failure.message}`));
  }

  return `${lines.join("\n")}\n`;
}

function renderConsoleSummary(report) {
  return [
    `status=${report.status}`,
    `platform=${report.platform}`,
    `scenarios=${report.summary.scenarios}`,
    `manual=${report.summary.manual}`,
    `hybrid=${report.summary.hybrid}`,
    `automated=${report.summary.automated}`,
    `pass=${report.summary.pass}`,
    `not_applicable=${report.summary.not_applicable}`,
    `pending=${report.summary.pending}`,
    `fail=${report.summary.fail}`,
    `blocked=${report.summary.blocked}`,
  ].join("\n");
}

function parseArgs(rawArgs) {
  const parsed = {
    platform: undefined,
    reportDir: undefined,
    config: undefined,
    results: undefined,
    requireResults: false,
  };

  for (let index = 0; index < rawArgs.length; index += 1) {
    const arg = rawArgs[index];
    if (arg === "--platform") {
      parsed.platform = rawArgs[++index];
    } else if (arg === "--report-dir") {
      parsed.reportDir = rawArgs[++index];
    } else if (arg === "--config") {
      parsed.config = rawArgs[++index];
    } else if (arg === "--results") {
      parsed.results = rawArgs[++index];
    } else if (arg === "--require-results") {
      parsed.requireResults = true;
    } else {
      failUsage(`Unknown argument: ${arg}`);
    }
  }

  return parsed;
}

function failUsage(message) {
  console.error(message);
  console.error("Usage: node tools/ci/run-release-device-matrix.mjs --platform <android|ios> [--report-dir path] [--config path] [--results path] [--require-results]");
  process.exit(2);
}

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, isAbsolute, resolve } from "node:path";

const repoRoot = process.cwd();
const args = parseArgs(process.argv.slice(2));
const contractPath = resolvePath(args.config ?? "contracts/ops/observability-gate.json");
const reportDir = resolvePath(args.reportDir ?? "build/reports/ops-observability");
const contract = readJson(contractPath);
const failures = [];

const alertPolicies = validateAlertPolicies(contract.alertPolicies ?? []);
failures.push(...alertPolicies.failures);

const staticEvidence = validateEvidenceGroup("static-evidence", contract.staticEvidence ?? []);
failures.push(...staticEvidence.failures);

const alertRules = validateAlertRules(contract.alertRules ?? []);
for (const rule of alertRules) {
  failures.push(...rule.failures);
}

const releaseTracking = validateReleaseTracking(contract.releaseTracking ?? {});
failures.push(...releaseTracking.failures);

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
  releaseTracking,
  alertPolicies,
  staticEvidence,
  alertRules,
  runtimeEvidence,
  failures,
};

mkdirSync(reportDir, { recursive: true });
writeFileSync(resolve(reportDir, "ops-observability-report.json"), `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(resolve(reportDir, "ops-observability-alert-rules.json"), `${JSON.stringify(alertRules, null, 2)}\n`);
writeFileSync(resolve(reportDir, "ops-observability-runtime-evidence.json"), `${JSON.stringify(runtimeEvidence, null, 2)}\n`);
writeFileSync(resolve(reportDir, "ops-observability-report.md"), renderMarkdown(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdown(report)}\n`, { flag: "a" });
}

console.log(`Ops observability report: ${resolve(reportDir, "ops-observability-report.json")}`);
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

function validateAlertPolicies(policies) {
  const policyFailures = [];
  for (const policy of policies) {
    for (const field of ["id", "receiver", "severity", "escalationOwner", "silencePolicy"]) {
      if (!policy[field] || policy[field].toString().trim().length === 0) {
        policyFailures.push({
          reason: "alert_policy_missing",
          message: `Alert policy '${policy.id ?? "unknown"}' is missing ${field}.`,
          policyId: policy.id,
          field,
        });
      }
    }
  }
  if (policies.length === 0) {
    policyFailures.push({
      reason: "alert_policy_missing",
      message: "At least one alert policy is required.",
    });
  }

  return {
    status: policyFailures.length === 0 ? "pass" : "fail",
    policies,
    failures: policyFailures,
  };
}

function validateReleaseTracking(tracking) {
  const trackingFailures = [];
  const requiredContext = tracking.requiredContext ?? [];
  for (const field of ["appVersion", "buildNumber", "platform", "endpoint", "userAction"]) {
    if (!requiredContext.includes(field)) {
      trackingFailures.push({
        reason: "missing_required_evidence",
        message: `Release tracking context is missing '${field}'.`,
        field,
      });
    }
  }
  for (const platform of ["android_vitals", "app_store_crash", "backend_metrics"]) {
    if (!(tracking.platforms ?? []).includes(platform)) {
      trackingFailures.push({
        reason: "missing_required_evidence",
        message: `Release tracking platform is missing '${platform}'.`,
        platform,
      });
    }
  }

  return {
    status: trackingFailures.length === 0 ? "pass" : "fail",
    ...tracking,
    failures: trackingFailures,
  };
}

function validateAlertRules(rules) {
  return rules.map((rule) => {
    const evidence = validateEvidenceGroup(rule.id, rule.evidenceItems ?? []);
    const ruleFailures = [...evidence.failures];
    for (const field of ["id", "signal", "threshold", "severity", "runtimeScenario"]) {
      if (!rule[field] || rule[field].toString().trim().length === 0) {
        ruleFailures.push({
          reason: "missing_required_evidence",
          message: `Alert rule '${rule.id ?? "unknown"}' is missing ${field}.`,
          ruleId: rule.id,
          field,
        });
      }
    }

    return {
      id: rule.id,
      signal: rule.signal,
      threshold: rule.threshold,
      severity: rule.severity,
      runtimeScenario: rule.runtimeScenario,
      status: ruleFailures.length === 0 ? "pass" : "fail",
      evidence,
      failures: ruleFailures,
    };
  });
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
    file: item.file,
    status: itemFailures.length === 0 ? "pass" : "fail",
    patterns: patternResults,
    failures: itemFailures,
  };
}

function validateRuntimeEvidence(config) {
  const runtimeDir = resolvePath(args.runtimeEvidenceDir ?? config.defaultDirectory ?? "contracts/ops/runtime-evidence");
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
        message: `Missing required ops runtime evidence file: ${requiredFile.filename}`,
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
          reason: "runtime_alert_failed",
          message: `Runtime scenario '${scenarioId}' reported status '${scenario.status}'.`,
          file: requiredFile.filename,
          scenarioId,
          status: scenario.status,
        });
      }
      if (!scenario.receiver || scenario.receiver.toString().trim().length === 0) {
        fileFailures.push({
          reason: "alert_policy_missing",
          message: `Runtime scenario '${scenarioId}' is missing alert receiver evidence.`,
          file: requiredFile.filename,
          scenarioId,
        });
      }
    }

    runtimeFailures.push(...fileFailures);
    files.push({
      id: requiredFile.id,
      filename: requiredFile.filename,
      status: fileFailures.length === 0 ? "pass" : "fail",
      scenarios,
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
    "# Ops Observability Gate",
    "",
    `- Status: ${report.status}`,
    `- Generated at: ${report.generatedAt}`,
    `- Contract: ${report.contract.path}`,
    `- Alert policies: ${report.alertPolicies.status}`,
    `- Static evidence: ${report.staticEvidence.status}`,
    "",
    "## Alert Rules",
    "",
    "| Rule | Severity | Threshold | Status |",
    "| --- | --- | --- | --- |",
  ];

  for (const rule of report.alertRules) {
    lines.push(`| ${rule.id} | ${rule.severity} | ${rule.threshold} | ${rule.status} |`);
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
    `alertRules=${report.alertRules.length}`,
    `alertPolicies=${report.alertPolicies.status}`,
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

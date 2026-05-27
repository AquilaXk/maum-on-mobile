import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, isAbsolute, resolve } from "node:path";

const repoRoot = process.cwd();
const args = parseArgs(process.argv.slice(2));
const contractPath = resolvePath(args.config ?? "contracts/infra/production-deploy-readiness.json");
const reportDir = resolvePath(args.reportDir ?? "build/reports/production-deploy-readiness");
const contract = readJson(contractPath);
const failures = [];

const envValues = loadEnvironment(args.envFile);
const environment = validateEnvironment(contract, envValues);
failures.push(...environment.failures);

const staticEvidence = validateEvidenceGroup("static-evidence", contract.staticEvidence ?? []);
failures.push(...staticEvidence.failures);

const gates = validateGates(contract.gates ?? []);
failures.push(...gates.failures);

const compatibility = validateCompatibility(contract.compatibility ?? {}, envValues, environment.status);
failures.push(...compatibility.failures);

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
  environment,
  staticEvidence,
  gates,
  compatibility,
  runtimeEvidence,
  failures,
};

mkdirSync(reportDir, { recursive: true });
writeFileSync(resolve(reportDir, "production-deploy-readiness-report.json"), `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(resolve(reportDir, "production-deploy-readiness-environment.json"), `${JSON.stringify(environment, null, 2)}\n`);
writeFileSync(resolve(reportDir, "production-deploy-readiness-runtime-evidence.json"), `${JSON.stringify(runtimeEvidence, null, 2)}\n`);
writeFileSync(resolve(reportDir, "production-deploy-readiness-report.md"), renderMarkdown(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdown(report)}\n`, { flag: "a" });
}

console.log(`Production deploy readiness report: ${resolve(reportDir, "production-deploy-readiness-report.json")}`);
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

function validateEnvironment(config, envValues) {
  const requireEnv = args.requireEnv === true || Boolean(args.envFile);
  if (!requireEnv) {
    return {
      status: "not_required",
      required: false,
      environments: [],
      commonVariables: [],
      failures: [],
    };
  }

  const failures = [];
  const commonVariables = validateVariables("common", config.commonRequiredVariables ?? [], envValues, failures);
  const environments = (config.environments ?? []).map((environment) => {
    const variableResults = validateVariables(environment.id, environment.requiredVariables ?? [], envValues, failures);
    return {
      id: environment.id,
      requiredProfiles: environment.requiredProfiles ?? [],
      variables: variableResults,
      status: variableResults.every((variable) => variable.status === "pass") ? "pass" : "fail",
    };
  });

  if (environments.length === 0) {
    failures.push({
      reason: "missing_required_env",
      message: "At least one deployment environment must be declared.",
    });
  }

  return {
    status: failures.length === 0 ? "pass" : "fail",
    required: requireEnv,
    environments,
    commonVariables,
    failures,
  };
}

function validateVariables(scope, variables, envValues, failures) {
  return variables.map((variable) => {
    const value = envValues.get(variable.name)?.trim() ?? "";
    const variableFailures = [];

    if (!value) {
      variableFailures.push({
        reason: "missing_required_env",
        message: `${scope} env '${variable.name}' is missing.`,
        scope,
        variable: variable.name,
      });
    } else {
      variableFailures.push(...validateVariableValue(scope, variable, value));
    }

    failures.push(...variableFailures);
    return {
      name: variable.name,
      kind: variable.kind,
      status: variableFailures.length === 0 ? "pass" : "fail",
      present: value.length > 0,
      failures: variableFailures,
    };
  });
}

function validateVariableValue(scope, variable, value) {
  const failures = [];
  if (isUnsafeValue(value)) {
    failures.push({
      reason: "unsafe_env_value",
      message: `${scope} env '${variable.name}' uses an unsafe placeholder value.`,
      scope,
      variable: variable.name,
    });
  }

  if (variable.minLength && value.length < variable.minLength) {
    failures.push({
      reason: "unsafe_env_value",
      message: `${scope} env '${variable.name}' must be at least ${variable.minLength} characters.`,
      scope,
      variable: variable.name,
    });
  }

  if (variable.kind === "url" && !isHttpUrl(value)) {
    failures.push({
      reason: "unsafe_env_value",
      message: `${scope} env '${variable.name}' must be an HTTP URL.`,
      scope,
      variable: variable.name,
    });
  }

  if (variable.kind === "jdbc_url" && !/^jdbc:[a-z0-9]+:/i.test(value)) {
    failures.push({
      reason: "unsafe_env_value",
      message: `${scope} env '${variable.name}' must be a JDBC URL.`,
      scope,
      variable: variable.name,
    });
  }

  if (variable.kind === "profile_list") {
    const tokens = value
      .split(/[,\s]+/)
      .map((token) => token.trim())
      .filter(Boolean);
    for (const token of variable.requiredTokens ?? []) {
      if (!tokens.includes(token)) {
        failures.push({
          reason: "unsafe_env_value",
          message: `${scope} env '${variable.name}' must include profile '${token}'.`,
          scope,
          variable: variable.name,
          token,
        });
      }
    }
  }

  if (variable.kind === "mobile_version" && !/^\d+\.\d+\.\d+\+\d+$/.test(value)) {
    failures.push({
      reason: "compatibility_mismatch",
      message: `${scope} env '${variable.name}' must use semantic mobile version format like 1.0.0+1.`,
      scope,
      variable: variable.name,
    });
  }

  return failures;
}

function validateCompatibility(config, envValues, environmentStatus) {
  if (environmentStatus === "not_required") {
    return {
      status: "not_required",
      failures: [],
    };
  }

  const failures = [];
  const apiContractVersion = envValues.get(config.apiContractVariable)?.trim() ?? "";
  const backendVersion = envValues.get(config.backendVersionVariable)?.trim() ?? "";
  const androidVersion = envValues.get(config.androidVersionVariable)?.trim() ?? "";
  const iosVersion = envValues.get(config.iosVersionVariable)?.trim() ?? "";

  if (!apiContractVersion.startsWith(config.requiredContractPrefix ?? "")) {
    failures.push({
      reason: "compatibility_mismatch",
      message: `${config.apiContractVariable} must start with '${config.requiredContractPrefix}'.`,
      variable: config.apiContractVariable,
    });
  }
  if (!backendVersion || !androidVersion || !iosVersion) {
    failures.push({
      reason: "compatibility_mismatch",
      message: "Backend, Android, and iOS deploy versions must all be present.",
    });
  }
  if (androidVersion && iosVersion && androidVersion !== iosVersion) {
    failures.push({
      reason: "compatibility_mismatch",
      message: "Android and iOS app versions must match for one release candidate.",
    });
  }

  return {
    status: failures.length === 0 ? "pass" : "fail",
    apiContractVariable: config.apiContractVariable,
    backendVersionVariable: config.backendVersionVariable,
    androidVersionVariable: config.androidVersionVariable,
    iosVersionVariable: config.iosVersionVariable,
    apiContractVersionPresent: apiContractVersion.length > 0,
    backendVersionPresent: backendVersion.length > 0,
    androidVersionPresent: androidVersion.length > 0,
    iosVersionPresent: iosVersion.length > 0,
    failures,
  };
}

function validateGates(gates) {
  const failures = [];
  const gateResults = gates.map((gate) => {
    const gateFailures = [];
    if (!gate.id || gate.id.trim().length === 0) {
      gateFailures.push({
        reason: "missing_required_evidence",
        message: "Deployment gate is missing id.",
      });
    }
    if ((gate.requiredScenarios ?? []).length === 0) {
      gateFailures.push({
        reason: "missing_required_evidence",
        message: `Deployment gate '${gate.id ?? "unknown"}' must declare required scenarios.`,
        gateId: gate.id,
      });
    }
    failures.push(...gateFailures);
    return {
      id: gate.id,
      requiredScenarios: gate.requiredScenarios ?? [],
      status: gateFailures.length === 0 ? "pass" : "fail",
      failures: gateFailures,
    };
  });

  if (gateResults.length === 0) {
    failures.push({
      reason: "missing_required_evidence",
      message: "At least one deployment gate is required.",
    });
  }

  return {
    status: failures.length === 0 ? "pass" : "fail",
    gates: gateResults,
    failures,
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
  const runtimeDir = resolvePath(args.runtimeEvidenceDir ?? config.defaultDirectory ?? "contracts/infra/runtime-evidence");
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
        message: `Missing required deploy runtime evidence file: ${requiredFile.filename}`,
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

    for (const field of requiredFile.requiredTopLevelFields ?? []) {
      if (!evidence[field] || evidence[field].toString().trim().length === 0) {
        fileFailures.push({
          reason: "missing_runtime_evidence",
          message: `Runtime evidence file '${requiredFile.filename}' is missing top-level field '${field}'.`,
          file: requiredFile.filename,
          field,
        });
      }
    }

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
          reason: "runtime_smoke_failed",
          message: `Runtime scenario '${scenarioId}' reported status '${scenario.status}'.`,
          file: requiredFile.filename,
          scenarioId,
          status: scenario.status,
        });
      }
      for (const field of requiredFile.requiredScenarioFields?.[scenarioId] ?? []) {
        if (!scenario[field] || scenario[field].toString().trim().length === 0) {
          fileFailures.push({
            reason: "missing_runtime_evidence",
            message: `Runtime scenario '${scenarioId}' is missing field '${field}'.`,
            file: requiredFile.filename,
            scenarioId,
            field,
          });
        }
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

function loadEnvironment(envFile) {
  const values = new Map(Object.entries(process.env).map(([key, value]) => [key, value ?? ""]));
  if (!envFile) {
    applyCompatibilityManifest(values);
    return values;
  }

  const content = readFileSync(resolvePath(envFile), "utf8");
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }
    const normalized = line.startsWith("export ") ? line.slice("export ".length).trim() : line;
    const equalsIndex = normalized.indexOf("=");
    if (equalsIndex === -1) {
      continue;
    }
    const key = normalized.slice(0, equalsIndex).trim();
    const value = normalized.slice(equalsIndex + 1).trim().replace(/^['"]|['"]$/g, "");
    values.set(key, value);
  }
  applyCompatibilityManifest(values);
  return values;
}

function applyCompatibilityManifest(values) {
  const rawManifest = values.get("MAUMON_DEPLOY_COMPATIBILITY_MANIFEST")?.trim() ?? "";
  if (!rawManifest) {
    return;
  }

  const manifest = JSON.parse(rawManifest);
  const fields = [
    ["backendVersion", "MAUMON_BACKEND_DEPLOY_VERSION"],
    ["androidVersion", "MAUMON_ANDROID_APP_VERSION"],
    ["iosVersion", "MAUMON_IOS_APP_VERSION"],
    ["apiContractVersion", "MAUMON_API_CONTRACT_VERSION"],
  ];

  for (const [manifestKey, envName] of fields) {
    const value = manifest[manifestKey];
    if (typeof value === "string" && value.trim().length > 0) {
      values.set(envName, value.trim());
    }
  }
}

function isUnsafeValue(value) {
  return /^(changeme|change-me|placeholder|todo|dummy)$/i.test(value.trim());
}

function isHttpUrl(value) {
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" || parsed.protocol === "http:";
  } catch {
    return false;
  }
}

function renderMarkdown(report) {
  const lines = [
    "# Production Deploy Readiness",
    "",
    `- Status: ${report.status}`,
    `- Generated at: ${report.generatedAt}`,
    `- Contract: ${report.contract.path}`,
    `- Environment: ${report.environment.status}`,
    `- Static evidence: ${report.staticEvidence.status}`,
    `- Compatibility: ${report.compatibility.status}`,
    "",
    "## Gates",
    "",
    "| Gate | Status | Required scenarios |",
    "| --- | --- | --- |",
  ];

  for (const gate of report.gates.gates) {
    lines.push(`| ${gate.id} | ${gate.status} | ${gate.requiredScenarios.length} |`);
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
    `environment=${report.environment.status}`,
    `staticEvidence=${report.staticEvidence.status}`,
    `compatibility=${report.compatibility.status}`,
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
    } else if (arg === "--env-file") {
      parsed.envFile = argv[++index];
    } else if (arg === "--runtime-evidence-dir") {
      parsed.runtimeEvidenceDir = argv[++index];
    } else if (arg === "--require-env") {
      parsed.requireEnv = true;
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
